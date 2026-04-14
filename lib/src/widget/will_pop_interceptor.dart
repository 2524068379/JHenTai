import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/toast_util.dart';

class WillPopInterceptor extends StatefulWidget {
  final Widget child;

  const WillPopInterceptor({Key? key, required this.child}) : super(key: key);

  @override
  State<WillPopInterceptor> createState() => _WillPopInterceptorState();
}

class _WillPopInterceptorState extends State<WillPopInterceptor> {
  DateTime? _lastPopTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: widget.child,
      canPop: Platform.isAndroid ? false : true,
      onPopInvokedWithResult: (bool didPop, FormData? result) async {
        if (didPop) {
          return;
        }

        final bool shouldPop = await _handlePopApp();
        if (context.mounted && shouldPop) {
          SystemNavigator.pop(animated: true);
        }
      },
    );
  }

  /// system back
  Future<bool> _handlePopApp() => _handleDoubleTapPopApp();

  /// double tap back button to exit app
  Future<bool> _handleDoubleTapPopApp() {
    if (_lastPopTime == null) {
      _lastPopTime = DateTime.now();
      toast('TapAgainToExit'.tr, isCenter: false);
      return Future.value(false);
    }

    if (DateTime.now().difference(_lastPopTime!).inMilliseconds <= 800) {
      return Future.value(true);
    }

    _lastPopTime = DateTime.now();
    toast('TapAgainToExit'.tr, isCenter: false);
    return Future.value(false);
  }
}
