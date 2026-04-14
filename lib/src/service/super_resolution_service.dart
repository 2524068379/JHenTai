import 'dart:io';

import 'package:drift/drift.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:path/path.dart';

import '../database/dao/super_resolution_info_dao.dart';
import '../model/gallery_image.dart';
import '../utils/table.dart' as util;
import '../utils/toast_util.dart';
import '../widget/loading_state_indicator.dart';
import 'archive_download_service.dart';
import 'gallery_download_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

SuperResolutionService superResolutionService = SuperResolutionService();

class SuperResolutionService extends GetxController with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String downloadId = 'downloadId';
  static const String superResolutionId = 'superResolutionId';
  static const String superResolutionImageId = 'superResolutionImageId';

  LoadingState downloadState = LoadingState.idle;
  String downloadProgress = '0%';

  util.Table<int, SuperResolutionType, SuperResolutionInfo> superResolutionInfoTable = util.Table();

  static const String imageDirName = 'super_resolution';

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies
    ..add(galleryDownloadService)
    ..add(archiveDownloadService);

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);

    if (!await galleryDownloadService.completed) {
      return;
    }
    if (!await archiveDownloadService.completed) {
      return;
    }

    List<SuperResolutionInfoData> superResolutionInfoDatas = await _selectAllSuperResolutionInfo();
    for (SuperResolutionInfoData data in superResolutionInfoDatas) {
      superResolutionInfoTable.put(
        data.gid,
        SuperResolutionType.values[data.type],
        SuperResolutionInfo(
          SuperResolutionType.values[data.type],
          SuperResolutionStatus.values[data.status],
          data.imageStatuses
              .split(SuperResolutionInfo.imageStatusesSeparator)
              .map(int.parse)
              .map((index) => SuperResolutionStatus.values[index])
              .toList(),
        ),
      );
    }

    await _checkInfoSourceExists();
    await _normalizeUnsupportedTasks();

    super.onInit();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  SuperResolutionInfo? get(int gid, SuperResolutionType type) => superResolutionInfoTable.get(gid, type);

  Future<void> downloadModelFile(ModelType model) async {
    downloadState = LoadingState.error;
    downloadProgress = '0%';
    updateSafely([downloadId]);
    toast('error'.tr);
  }

  Future<bool> superResolve(int gid, SuperResolutionType type) async {
    toast('error'.tr);
    return false;
  }

  Future<void> pauseSuperResolve(int gid, SuperResolutionType type) async {
    SuperResolutionInfo? superResolutionInfo = get(gid, type);

    if (superResolutionInfo == null ||
        superResolutionInfo.status == SuperResolutionStatus.success ||
        superResolutionInfo.status == SuperResolutionStatus.paused) {
      return;
    }

    bool? success = superResolutionInfo.currentProcess?.kill();
    log.info('pause super resolution: $gid $success');

    superResolutionInfo.status = SuperResolutionStatus.paused;
    for (int i = 0; i < superResolutionInfo.imageStatuses.length; i++) {
      if (superResolutionInfo.imageStatuses[i] == SuperResolutionStatus.running) {
        superResolutionInfo.imageStatuses[i] = SuperResolutionStatus.paused;
      }
    }
    await _updateSuperResolutionInfoStatus(gid, superResolutionInfo);
    updateSafely(['$superResolutionId::$gid']);
  }

  Future<void> deleteSuperResolve(int gid, SuperResolutionType type) async {
    SuperResolutionInfo? superResolutionInfo = get(gid, type);
    if (superResolutionInfo == null) {
      return;
    }

    log.info('delete super resolution: $gid');

    superResolutionInfo.currentProcess?.kill();
    superResolutionInfoTable.remove(gid, type);
    await SuperResolutionInfoDao.deleteSuperResolutionInfo(gid, type.index);

    String? dirPath;
    if (type == SuperResolutionType.gallery) {
      for (GalleryDownloadedData gallery in galleryDownloadService.gallerys) {
        if (gallery.gid == gid) {
          dirPath = join(galleryDownloadService.computeGalleryDownloadAbsolutePath(gallery.title, gallery.gid), imageDirName);
          break;
        }
      }
    } else {
      for (ArchiveDownloadedData archive in archiveDownloadService.archives) {
        if (archive.gid == gid) {
          dirPath = join(archiveDownloadService.computeArchiveUnpackingPath(archive.title, archive.gid), imageDirName);
          break;
        }
      }
    }

    if (dirPath != null) {
      Directory directory = Directory(dirPath);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }

    updateSafely(['$superResolutionId::$gid']);
  }

  Future<void> _normalizeUnsupportedTasks() async {
    for (TableEntry<int, SuperResolutionType, SuperResolutionInfo> entry in superResolutionInfoTable.entries()) {
      bool changed = false;

      if (entry.value.status == SuperResolutionStatus.running) {
        entry.value.status = SuperResolutionStatus.paused;
        changed = true;
      }

      for (int i = 0; i < entry.value.imageStatuses.length; i++) {
        if (entry.value.imageStatuses[i] == SuperResolutionStatus.running) {
          entry.value.imageStatuses[i] = SuperResolutionStatus.paused;
          changed = true;
        }
      }

      if (changed) {
        await _updateSuperResolutionInfoStatus(entry.key1, entry.value);
      }
    }
  }

  Future<void> _checkInfoSourceExists() async {
    List<TableEntry<int, SuperResolutionType, SuperResolutionInfo>> targetEntries = [];

    for (TableEntry<int, SuperResolutionType, SuperResolutionInfo> entry in superResolutionInfoTable.entries()) {
      if (entry.key2 == SuperResolutionType.gallery && galleryDownloadService.galleryDownloadInfos.containsKey(entry.key1)) {
        continue;
      }
      if (entry.key2 == SuperResolutionType.archive && archiveDownloadService.archiveDownloadInfos.containsKey(entry.key1)) {
        continue;
      }

      log.error('Try to init super-resolution info but image source not exists: $entry');
      targetEntries.add(entry);
    }

    for (TableEntry<int, SuperResolutionType, SuperResolutionInfo> entry in targetEntries) {
      await deleteSuperResolve(entry.key1, entry.key2);
    }
  }

  Future<List<SuperResolutionInfoData>> _selectAllSuperResolutionInfo() async {
    return SuperResolutionInfoDao.selectAllSuperResolutionInfo();
  }

  Future<bool> _insertSuperResolutionInfo(int gid, SuperResolutionInfo superResolutionInfo) async {
    return await SuperResolutionInfoDao.insertSuperResolutionInfo(
          SuperResolutionInfoData(
            gid: gid,
            type: superResolutionInfo.type.index,
            status: superResolutionInfo.status.index,
            imageStatuses: superResolutionInfo.imageStatuses.map((status) => status.index).join(SuperResolutionInfo.imageStatusesSeparator),
          ),
        ) >
        0;
  }

  Future<bool> _updateSuperResolutionInfoStatus(int gid, SuperResolutionInfo superResolutionInfo) async {
    return await SuperResolutionInfoDao.updateSuperResolutionInfo(
          SuperResolutionInfoCompanion(
            gid: Value(gid),
            type: Value(superResolutionInfo.type.index),
            status: Value(superResolutionInfo.status.index),
            imageStatuses: Value(superResolutionInfo.imageStatuses.map((status) => status.index).join(SuperResolutionInfo.imageStatusesSeparator)),
          ),
        ) >
        0;
  }

  Future<void> copyImageInfo(GalleryDownloadedData oldGallery, GalleryDownloadedData newGallery, int oldImageSerialNo, int newImageSerialNo) async {
    SuperResolutionInfo? oldGallerySuperResolutionInfo = get(oldGallery.gid, SuperResolutionType.gallery);
    if (oldGallerySuperResolutionInfo == null) {
      return;
    }

    if (oldGallerySuperResolutionInfo.imageStatuses[oldImageSerialNo] != SuperResolutionStatus.success) {
      return;
    }

    log.debug('copy old super resolution image to new gallery, old: ${oldGallery.gid} $oldImageSerialNo, new: ${newGallery.gid} $newImageSerialNo');

    SuperResolutionInfo? newGallerySuperResolutionInfo = get(newGallery.gid, SuperResolutionType.gallery);
    String oldPath = computeImageOutputAbsolutePath(galleryDownloadService.galleryDownloadInfos[oldGallery.gid]!.images[oldImageSerialNo]!.path!);
    String newPath = computeImageOutputAbsolutePath(galleryDownloadService.galleryDownloadInfos[newGallery.gid]!.images[newImageSerialNo]!.path!);

    if (newGallerySuperResolutionInfo == null) {
      newGallerySuperResolutionInfo = SuperResolutionInfo(
        SuperResolutionType.gallery,
        SuperResolutionStatus.paused,
        List.generate(galleryDownloadService.galleryDownloadInfos[newGallery.gid]!.images.length, (_) => SuperResolutionStatus.paused),
      );
      superResolutionInfoTable.put(newGallery.gid, SuperResolutionType.gallery, newGallerySuperResolutionInfo);
      await _insertSuperResolutionInfo(newGallery.gid, newGallerySuperResolutionInfo);
      File(newPath).parent.createSync(recursive: true);
      updateSafely(['$superResolutionId::${newGallery.gid}']);
    }

    try {
      File imageFile = File(oldPath);
      await imageFile.copy(newPath);
    } on Exception catch (e) {
      log.error('copy super resolution image failed', e);
      log.uploadError(e);
    }

    newGallerySuperResolutionInfo.imageStatuses[newImageSerialNo] = SuperResolutionStatus.success;
    await _updateSuperResolutionInfoStatus(newGallery.gid, newGallerySuperResolutionInfo);
    updateSafely(['$superResolutionId::${newGallery.gid}', '$superResolutionImageId::${newGallery.gid}::$newImageSerialNo']);
  }

  String computeImageOutputAbsolutePath(String rawImagePath) {
    return join(pathService.getVisibleDir().path, computeImageOutputRelativePath(rawImagePath));
  }

  String computeImageOutputRelativePath(String rawImagePath) {
    return join(computeImageOutputDirPath(rawImagePath), basenameWithoutExtension(rawImagePath) + (extension(rawImagePath) == '.gif' ? '.gif' : '.png'));
  }

  String computeImageOutputDirPath(String rawImagePath) {
    return join(dirname(rawImagePath), imageDirName);
  }
}

class SuperResolutionInfo {
  Process? currentProcess;

  SuperResolutionType type;

  SuperResolutionStatus status;

  List<SuperResolutionStatus> imageStatuses;

  static const imageStatusesSeparator = ',';

  SuperResolutionInfo(this.type, this.status, this.imageStatuses);
}

enum SuperResolutionType { gallery, archive }

enum SuperResolutionStatus { paused, running, success }
