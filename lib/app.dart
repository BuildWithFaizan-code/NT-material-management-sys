import 'package:flutter/material.dart';
import 'design/app_colors.dart';
import 'design/app_theme.dart';
import 'design/web_scroll_behavior.dart';
import 'layout/app_shell.dart';
import 'pages/head_master_page.dart';
import 'pages/login_page.dart';
import 'pages/sub_department_master_page.dart';
import 'services/auth_service.dart';
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
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        Widget homeWidget;

        if (!AuthService.instance.isInitialized) {
          homeWidget = const Scaffold(
            backgroundColor: AppColors.backgroundColor,
            body: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
          );
        } else if (AuthService.instance.isLoggedIn && !AuthService.instance.mustChangePassword) {
          homeWidget = AppShell(
            layoutState: layoutState,
            statusState: statusState,
          );
        } else {
          homeWidget = const LoginPage();
        }

        return MaterialApp(
          title: 'NewTech MMS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          scrollBehavior: const AppScrollBehavior(),
          home: homeWidget,
          routes: {
            '/sub-department-master': (context) => const SubDepartmentMasterPage(),
            '/head-master': (context) => const HeadMasterPage(),
          },
        );
      },
    );
  }
}
