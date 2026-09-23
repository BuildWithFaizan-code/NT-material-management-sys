import 'package:flutter/material.dart';
import 'widgets/app_header.dart';
import 'widgets/status_bar.dart';
import 'widgets/navigation_drawer.dart';
import '../state/layout_state.dart';
import '../state/status_state.dart';
import '../pages/dashboard_page.dart';
import '../pages/project_master_page.dart';

import '../pages/placeholder_module_pages.dart';
import '../pages/user_management_page.dart';

class SmallScreenLayout extends StatelessWidget {
  final LayoutState layoutState;
  final StatusState statusState;

  const SmallScreenLayout({
    super.key,
    required this.layoutState,
    required this.statusState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: layoutState.scaffoldKey,
      drawer: NavigationDrawerWidget(
        currentIndex: layoutState.currentPageIndex,
        onItemSelected: layoutState.setPage,
      ),
      body: Column(
        children: [
          AppHeader(
            onMenuTap: layoutState.openDrawer,
          ),
          Expanded(
            child: _buildPage(layoutState.currentPageIndex),
          ),
          StatusBar(status: statusState),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardPage();
      case 1:
        return const ProjectMasterPage();
      case 2:
        return const TransactionsPage();
      case 3:
        return const ReportsPage();
      case 4:
        return const BoxRegisterPage();
      case 5:
        return const ToolsPage();
      case 6:
        return const LiveUpdatesPage();
      case 7:
        return const DownloadPage();
      case 8:
        return const UserManagementPage();
      default:
        return const DashboardPage();
    }
  }
}
