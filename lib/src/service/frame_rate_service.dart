import 'package:flutter_displaymode/flutter_displaymode.dart';

import 'jh_service.dart';

FrameRateService frameRateService = FrameRateService();

class FrameRateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  @override
  Future<void> doInitBean() async {
    await FlutterDisplayMode.setHighRefreshRate();
  }

  @override
  Future<void> doAfterBeanReady() async {}
}
