import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'state/layout_state.dart';
import 'state/status_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final layoutState = LayoutState();
  final statusState = StatusState();

  // Initialize auth session (silently queries cookie on web, checks secure storage on native)
  await AuthService.instance.initialize();

  runApp(App(
    layoutState: layoutState,
    statusState: statusState,
  ));
}
