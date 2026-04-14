import 'package:flutter/material.dart';

class EHWheelSpeedController extends StatelessWidget {
  final ScrollController? controller;
  final Widget child;

  const EHWheelSpeedController(
      {Key? key, required this.controller, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
