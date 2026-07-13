import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_header.dart';
import 'widgets/status_bar.dart';
import '../state/layout_state.dart';
import '../state/status_state.dart';
import '../pages/dashboard_page.dart';
import '../design/app_colors.dart';

class LargeScreenLayout extends StatelessWidget {
  final LayoutState layoutState;
  final StatusState statusState;

  const LargeScreenLayout({
    super.key,
    required this.layoutState,
    required this.statusState,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Row(
        children: [
          Sidebar(
            currentIndex: layoutState.currentPageIndex,
            onItemSelected: layoutState.setPage,
          ),
          Expanded(
            child: Column(
              children: [
                const AppHeader(),
                Expanded(
                  child: _buildPage(layoutState.currentPageIndex),
                ),
                StatusBar(status: statusState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
      default:
        return const DashboardPage();
    }
  }
}
