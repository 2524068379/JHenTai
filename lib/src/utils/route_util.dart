import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

Future<T?>? toRoute<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  bool? offAllBefore,
  Map<String, String>? parameters,
  int? id,
}) {
  if (preventDuplicates && Get.currentRoute == routeName) {
    return null;
  }

  return Get.toNamed(
    routeName,
    arguments: arguments,
    parameters: parameters,
    preventDuplicates: preventDuplicates,
  );
}

void backRoute<T>({
  String? currentRoute,
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
  );
}

void popLeftRoute<T>({
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
  );
}

void popRightRoute<T>({
  T? result,
  bool closeOverlays = false,
  bool canPop = true,
}) {
  return Get.back(
    result: result,
    closeOverlays: closeOverlays,
    canPop: canPop,
  );
}

Future<T?>? offRoute<T>(
  String routeName, {
  dynamic arguments,
  bool preventDuplicates = true,
  Map<String, String>? parameters,
}) {
  return Get.offNamed(
    routeName,
    arguments: arguments,
    preventDuplicates: preventDuplicates,
    parameters: parameters,
  );
}

void untilRoute({String? currentRoute, required RoutePredicate predicate}) {
  return Get.until(predicate);
}

void untilRoute2BlankPage() {
  Get.until((route) => route.settings.name == '/');
}

void untilRoute2DesktopHomePage() {
  Get.until((route) => route.settings.name == '/');
}

bool isRouteAtTop(String routeName) {
  return Get.currentRoute == routeName;
}
