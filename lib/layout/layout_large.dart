import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_header.dart';
import '../state/layout_state.dart';
import '../state/status_state.dart';
import '../pages/dashboard_page.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';

import '../pages/project_master_page.dart';
import '../pages/location_master_page.dart';
import '../pages/store_master_page.dart';
import '../pages/operator_master_page.dart';
import '../pages/operation_master_page.dart';
import '../pages/department_master_page.dart';
import '../pages/sub_department_master_page.dart';
import '../pages/head_master_page.dart';
import '../pages/book_master_page.dart';
import '../pages/non_stockable_item_master_page.dart';
import '../pages/fabric_size_master_page.dart';
import '../pages/makers_master_page.dart';
import '../pages/capital_consumable_master_page.dart';
import '../pages/grade_master_page.dart';
import '../pages/main_group_master_page.dart';
import '../pages/group_master_page.dart';
import '../pages/group_master_definition_page.dart';
// import '../pages/charges_master_page.dart';
import '../pages/placeholder_module_pages.dart';

import 'widgets/modern_collapsed_rail.dart';

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
    final bool isOpen = layoutState.isNavbarOpen;
    const double m = AppDimensions.sidebarFloatingMargin;
    const double sw = AppDimensions.sidebarWidth;
    const double rw = AppDimensions.sidebarCollapsedWidth;
    
    // When open: shifts by sw + m * 2
    // When closed (rail visible): shifts by rw + m * 2
    final double contentShift = isOpen ? (sw + m * 2) : (rw + m * 2);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // ── Content area — shifts smoothly with animated padding ─────────
          AnimatedPadding(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(left: contentShift),
            child: Column(
              children: [
                AppHeader(
                  title: _getPageTitle(layoutState.currentPageIndex),
                  isNavbarOpen: isOpen,
                  onMenuTap: layoutState.toggleNavbar,
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey('page_${layoutState.currentPageIndex}_${layoutState.currentPageIndex == 1 ? layoutState.selectedMasterSubItem : ""}'),
                    child: _buildPage(layoutState.currentPageIndex),
                  ),
                ),
              ],
            ),
          ),

          // ── Collapsed Vertical Rail (Visible when sidebar is closed) ─────
          Positioned(
            left: m,
            top: m,
            bottom: m,
            width: rw,
            child: IgnorePointer(
              ignoring: isOpen,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                opacity: isOpen ? 0.0 : 1.0,
                child: ModernCollapsedRail(
                  currentIndex: layoutState.currentPageIndex,
                  onItemSelected: (idx) {
                    if (idx == 1) {
                      layoutState.setMasterSubItem('Project Master');
                    } else {
                      layoutState.setPage(idx);
                    }
                  },
                  onExpand: layoutState.toggleNavbar,
                ),
              ),
            ),
          ),

          // ── Floating Expanded Sidebar Overlay (Springs in when open) ─────
          _FloatingSidebarAnimator(
            isOpen: isOpen,
            sidebarWidth: sw,
            margin: m,
            child: Sidebar(
              currentIndex: layoutState.currentPageIndex,
              activeSubItem: layoutState.selectedMasterSubItem,
              onItemSelected: layoutState.setPage,
              onSubItemSelected: layoutState.setMasterSubItem,
              onToggle: layoutState.toggleNavbar,
              isOpen: isOpen,
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'Dashboard';
      case 1:
        return layoutState.selectedMasterSubItem.isNotEmpty
            ? layoutState.selectedMasterSubItem
            : 'Project Master';
      case 2:
        return 'Transactions';
      case 3:
        return 'Reports';
      case 4:
        return 'Box Register';
      case 5:
        return 'Tools';
      case 6:
        return 'Live Updates';
      case 7:
        return 'Download';
      default:
        return 'Dashboard';
    }
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const DashboardPage(key: ValueKey('dashboard_page'));
      case 1:
        return KeyedSubtree(
          key: ValueKey('master_${layoutState.selectedMasterSubItem}'),
          child: _buildMasterPage(),
        );
      case 2:
        return const TransactionsPage(key: ValueKey('transactions_page'));
      case 3:
        return const ReportsPage(key: ValueKey('reports_page'));
      case 4:
        return const BoxRegisterPage(key: ValueKey('box_register_page'));
      case 5:
        return const ToolsPage(key: ValueKey('tools_page'));
      case 6:
        return const LiveUpdatesPage(key: ValueKey('live_updates_page'));
      case 7:
        return const DownloadPage(key: ValueKey('download_page'));
      default:
        return const DashboardPage(key: ValueKey('default_dashboard'));
    }
  }

  Widget _buildMasterPage() {
    final sub = layoutState.selectedMasterSubItem;
    if (sub == 'Location Master') return const LocationMasterPage();
    if (sub == 'Store Master') return const StoreMasterPage();
    if (sub == 'Operator Master') return const OperatorMasterPage();
    if (sub == 'Operation Master') return const OperationMasterPage();
    if (sub == 'Department Master' || sub == 'Department') {
      return const DepartmentMasterPage();
    }
    if (sub == 'Sub-Department Master' ||
        sub == 'Sub-Department' ||
        sub == 'Sub Department') {
      return const SubDepartmentMasterPage();
    }
    if (sub == 'Head Master' ||
        sub == 'Head Master (Costing Head)' ||
        sub == 'Costing Head') {
      return const HeadMasterPage();
    }
    if (sub == 'Book Master' || sub == 'Book') {
      return const BookMasterPage();
    }
    if (sub == 'Fabric Size Master' || sub == 'Fabric Size') {
      return const FabricSizeMasterPage();
    }
    if (sub == 'Makers Master' || sub == 'Makers' || sub == 'Maker Master') {
      return const MakersMasterPage();
    }
    if (sub == 'Capital / Consumable' ||
        sub == 'Capital Consumable Master' ||
        sub == 'Capital / Consumable Master' ||
        sub == 'Capital Consumable') {
      return const CapitalConsumableMasterPage();
    }
    if (sub == 'Grade Master' ||
        sub == 'Grade' ||
        sub == 'Grade Definition') {
      return const GradeMasterPage();
    }
    if (sub == 'Main Group Master' ||
        sub == 'Main Group' ||
        sub == 'Main Group (WIPMST)') {
      return const MainGroupMasterPage();
    }
    if (sub == 'Group Master' ||
        sub == 'Group Master (Category)' ||
        sub == 'Category Master' ||
        sub == 'Group (Category)') {
      return const GroupMasterPage();
    }
    if (sub == 'Group Master Definition' ||
        sub == 'Group Definition' ||
        sub == 'Group Definition Master' ||
        sub == 'Sub Group Mapping') {
      return const GroupMasterDefinitionPage();
    }
    if (sub == 'Non-Stockable Item' ||
        sub == 'Non-Stockable Item Master') {
      return const NonStockableItemMasterPage();
    }
    return const ProjectMasterPage();
  }
}

// ============================================================================
// FLOATING SIDEBAR ANIMATOR — spring expand, fast collapse
// ============================================================================
class _FloatingSidebarAnimator extends StatefulWidget {
  final bool isOpen;
  final double sidebarWidth;
  final double margin;
  final Widget child;

  const _FloatingSidebarAnimator({
    required this.isOpen,
    required this.sidebarWidth,
    required this.margin,
    required this.child,
  });

  @override
  State<_FloatingSidebarAnimator> createState() =>
      _FloatingSidebarAnimatorState();
}

class _FloatingSidebarAnimatorState extends State<_FloatingSidebarAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _buildAnimations(opening: widget.isOpen);
    if (widget.isOpen) _controller.value = 1.0;
  }

  void _buildAnimations({required bool opening}) {
    final curve = opening ? Curves.easeOutCubic : Curves.easeInCubic;

    _slideAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: curve),
    );
    _opacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: curve,
      ),
    );
  }

  @override
  void didUpdateWidget(_FloatingSidebarAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _buildAnimations(opening: widget.isOpen);
      if (widget.isOpen) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse(from: 1.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!widget.isOpen && _controller.value == 0.0) {
          return const SizedBox.shrink();
        }
        final t = _slideAnim.value;
        final left = widget.margin -
            widget.sidebarWidth * (1.0 - t.clamp(0.0, 1.0));
        return Positioned(
          left: left,
          top: widget.margin,
          bottom: widget.margin,
          width: widget.sidebarWidth,
          child: IgnorePointer(
            ignoring: !widget.isOpen,
            child: Opacity(
              opacity: _opacityAnim.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scaleAnim.value.clamp(0.5, 1.0),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
