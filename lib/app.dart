import 'package:flutter/material.dart';
import 'design/app_theme.dart';
import 'design/web_scroll_behavior.dart';
import 'layout/app_shell.dart';
import 'state/layout_state.dart';
import 'state/status_state.dart';
import 'pages/sub_department_master_page.dart';
import 'pages/head_master_page.dart';

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
      scrollBehavior: const AppScrollBehavior(),
      home: AppShell(
        layoutState: layoutState,
        statusState: statusState,
      ),
      routes: {
        '/sub-department-master': (context) => const SubDepartmentMasterPage(),
        '/head-master': (context) => const HeadMasterPage(),
      },
    );
  }
}
