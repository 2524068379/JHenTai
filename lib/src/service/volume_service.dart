import 'dart:async';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'jh_service.dart';
import 'log.dart';

VolumeService volumeService = VolumeService();

class VolumeService extends GetxService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  late final MethodChannel methodChannel;

  static const int volumeUp = 1;
  static const int volumeDown = -1;

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {
    methodChannel = const MethodChannel('top.jtmonster.jhentai.volume.event.intercept');
  }

  @override
  void onClose() {
    super.onClose();

    cancelListen();
  }

  Future<void> setInterceptVolumeEvent(bool value) async {
    try {
      await methodChannel.invokeMethod('set', value);
    } on PlatformException catch (e) {
      log.error('Set intercept volume event error!', e);
      log.uploadError(e);
    }
  }

  void listen(Function(VolumeEventType)? onData) {
    methodChannel.setMethodCallHandler((MethodCall call) {
      if (call.method == 'event') {
        final int eventType = call.arguments as int;
        if (eventType == volumeUp) {
          onData?.call(VolumeEventType.volumeUp);
        } else if (eventType == volumeDown) {
          onData?.call(VolumeEventType.volumeDown);
        }
      }
      return Future.value();
    });
  }

  void cancelListen() {
    methodChannel.setMethodCallHandler(null);
  }
}

enum VolumeEventType { volumeUp, volumeDown }
