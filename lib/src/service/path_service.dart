import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'jh_service.dart';

PathService pathService = PathService();

class PathService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late Directory tempDir;

  Directory? externalStorageDir;

  @override
  List<JHLifeCircleBean> get initDependencies => [];

  @override
  Future<void> doInitBean() async {
    await Future.wait([
      getTemporaryDirectory().then((value) => tempDir = value),
      getExternalStorageDirectory().then((value) => externalStorageDir = value).catchError((error) => null),
    ]);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Directory getVisibleDir() {
    return externalStorageDir ?? tempDir;
  }
}
