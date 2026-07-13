import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'state/layout_state.dart';
import 'state/status_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final layoutState = LayoutState();
  final statusState = StatusState();

  runApp(App(
    layoutState: layoutState,
    statusState: statusState,
  ));
}
