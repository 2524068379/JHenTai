import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';

import '../service/log.dart';

Future<void> requestStoragePermission() async {
  try {
    await Permission.manageExternalStorage.request().isGranted;
    log.info(await Permission.manageExternalStorage.status);
  } on Exception catch (e) {
    log.error('Request manageExternalStorage permission failed!', e);
  }

  try {
    await Permission.storage.request().isGranted;
    log.info(await Permission.storage.status);
  } on Exception catch (e) {
    log.error('Request storage permission failed!', e);
  }
}

Future<void> requestAlbumPermission() async {
  final deviceInfoPlugin = DeviceInfoPlugin();
  final deviceInfo = await deviceInfoPlugin.androidInfo;
  final sdkInt = deviceInfo.version.sdkInt;
  bool statuses = sdkInt < 29 ? await Permission.storage.request().isGranted : true;
  
  log.info('requestPermission result: $statuses');
}

bool checkPermissionForPath(String path) {
  try {
    File file = File(join(path, 'JHenTaiTest'));
    file.createSync(recursive: true);
    file.deleteSync();
  } on FileSystemException catch (e) {
    log.error('${'invalidPath'.tr}:$path', e);
    log.uploadError(e, extraInfos: {'path': path});
    return false;
  }

  return true;
}
