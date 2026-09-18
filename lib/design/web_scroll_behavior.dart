import 'dart:ui';
import 'package:flutter/material.dart';

/// A customized scroll behavior that enables drag-scrolling via mouse, trackpad,
/// touch, and stylus, ensuring fluid data table and list scrolling on the web.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
      };
}
