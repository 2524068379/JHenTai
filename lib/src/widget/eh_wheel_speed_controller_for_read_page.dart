import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class EHWheelSpeedControllerForReadPage extends StatelessWidget {
  final Widget child;
  final ScrollOffsetController scrollOffsetController;

  const EHWheelSpeedControllerForReadPage({
    super.key,
    required this.child,
    required this.scrollOffsetController,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
