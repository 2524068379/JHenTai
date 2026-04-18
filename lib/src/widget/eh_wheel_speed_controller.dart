import 'package:flutter/material.dart';

class EHWheelSpeedController extends StatelessWidget {
  final ScrollController? controller;
  final Widget child;

  const EHWheelSpeedController(
      {super.key, required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
