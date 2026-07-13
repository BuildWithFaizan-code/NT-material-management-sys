import 'package:flutter/material.dart';
import 'design/app_theme.dart';
import 'layout/app_shell.dart';
import 'state/layout_state.dart';
import 'state/status_state.dart';

class App extends StatelessWidget {
  final LayoutState layoutState;
  final StatusState statusState;

  const App({
    super.key,
    required this.layoutState,
    required this.statusState,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewTech MMS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: AppShell(
        layoutState: layoutState,
        statusState: statusState,
      ),
    );
  }
}
