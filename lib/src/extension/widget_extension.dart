// ignore_for_file: invalid_use_of_protected_member

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/ui_config.dart';

extension WidgetExtension on Widget {
  Widget center([Key? key]) {
    return Center(key: key, child: this);
  }

  Widget fadeIn([Key? key]) {
    return FadeIn(key: key, child: this);
  }

  Widget fadeOut([Key? key]) {
    return FadeOut(key: key, animate: true, child: this);
  }

  Widget withListTileTheme(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.copyWith(
              bodyMedium: TextStyle(fontSize: UIConfig.settingPageListTileSubTitleTextSize, color: UIConfig.onBackGroundColor(context)),
              bodySmall: TextStyle(color: UIConfig.settingPageListTileSubTitleColor(context)),
            ),
      ),
      child: this,
    );
  }
}

extension StateExtension on State {
  void setStateSafely(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }
}
