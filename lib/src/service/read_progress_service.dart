import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';

ReadProgressService readProgressService = ReadProgressService();

class ReadProgressService extends GetxController with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String readProgressUpdateId = 'readProgress';

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([localConfigService]);

  /// Cache for read progress: gid -> readIndex
  final Map<String, int> _progressCache = {};

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  int? peekReadProgress(String recordKey) {
    return _progressCache[recordKey];
  }

  /// Get read progress for a gallery with cache
  Future<int> getReadProgress(int gid) async {
    return getReadProgressByKey(gid.toString());
  }

  Future<int> getReadProgressByKey(String recordKey) async {
    // Return from cache if available
    if (_progressCache.containsKey(recordKey)) {
      return _progressCache[recordKey]!;
    }

    // Read from storage
    final data = await localConfigService.read(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
    );

    final progress = int.tryParse(data ?? '') ?? 0;
    _progressCache[recordKey] = progress;
    return progress;
  }

  /// Update read progress and notify listeners
  Future<void> updateReadProgress(String recordKey, int index) async {
    _progressCache[recordKey] = index;
    await localConfigService.write(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
      value: index.toString(),
    );
    updateSafely(['$readProgressUpdateId::$recordKey']);
  }
}
