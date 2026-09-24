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
import '../pages/charges_master_page.dart';
import '../pages/placeholder_module_pages.dart';
import '../pages/transactions/transaction_placeholder_page.dart';
import '../pages/user_management_page.dart';
import '../services/auth_service.dart';
import 'widgets/master_nav_item.dart';
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
                    key: ValueKey(
                        'page_${layoutState.currentPageIndex}_${layoutState.currentPageIndex == 1 ? layoutState.selectedMasterSubItem : (layoutState.currentPageIndex == 2 ? layoutState.selectedTransactionSubItem : "")}'),
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
                      final auth = AuthService.instance;
                      final isAdmin = (auth.currentUser?.isAdmin ?? false) ||
                          (auth.myPermissions?.isAdmin ?? false);
                      final perms = auth.myPermissions;
                      String defaultModule = 'Project Master';
                      if (!isAdmin && perms != null) {
                        final permitted = masterSubSections
                            .where((s) => perms.canViewModule(s.title))
                            .toList();
                        if (permitted.isNotEmpty) {
                          defaultModule = permitted.first.title;
                        }
                      }
                      layoutState.setMasterSubItem(defaultModule);
                    } else if (idx == 2) {
                      layoutState.setTransactionSubItem(
                        layoutState.selectedTransactionSubItem.isNotEmpty
                            ? layoutState.selectedTransactionSubItem
                            : 'Bill of Material (BOM)',
                      );
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
              activeTransactionSubItem: layoutState.selectedTransactionSubItem,
              onItemSelected: layoutState.setPage,
              onSubItemSelected: layoutState.setMasterSubItem,
              onTransactionSubItemSelected: layoutState.setTransactionSubItem,
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
        return layoutState.selectedTransactionSubItem.isNotEmpty
            ? layoutState.selectedTransactionSubItem
            : 'Bill of Material (BOM)';
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
      case 8:
        return 'User Management';
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
        return KeyedSubtree(
          key: ValueKey('transaction_${layoutState.selectedTransactionSubItem}'),
          child: _buildTransactionPage(),
        );
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
      case 8:
        return const UserManagementPage(key: ValueKey('user_management_page'));
      default:
        return const DashboardPage(key: ValueKey('default_dashboard'));
    }
  }

  Widget _buildTransactionPage() {
    final sub = layoutState.selectedTransactionSubItem.isNotEmpty
        ? layoutState.selectedTransactionSubItem
        : 'Bill of Material (BOM)';

    switch (sub) {
      // Top group
      case 'Bill of Material (BOM)':
        return const TransactionPlaceholderPage(
          title: 'Bill of Material (BOM)',
          icon: Icons.account_tree_outlined,
        );
      case 'Production Order':
        return const TransactionPlaceholderPage(
          title: 'Production Order',
          icon: Icons.precision_manufacturing_outlined,
        );
      case 'BOM Followup':
        return const TransactionPlaceholderPage(
          title: 'BOM Followup',
          icon: Icons.timeline_outlined,
        );
      case 'Production Order Close':
        return const TransactionPlaceholderPage(
          title: 'Production Order Close',
          icon: Icons.task_alt_outlined,
        );
      case 'Repack Production Order':
        return const TransactionPlaceholderPage(
          title: 'Repack Production Order',
          icon: Icons.inventory_2_outlined,
        );
      case 'WIP Followup':
        return const TransactionPlaceholderPage(
          title: 'WIP Followup',
          icon: Icons.pending_actions_outlined,
        );
      case 'Estimate Requirements':
        return const TransactionPlaceholderPage(
          title: 'Estimate Requirements',
          icon: Icons.calculate_outlined,
        );
      case 'Requisition':
        return const TransactionPlaceholderPage(
          title: 'Requisition',
          icon: Icons.post_add_outlined,
        );
      case 'Requisition Status':
        return const TransactionPlaceholderPage(
          title: 'Requisition Status',
          icon: Icons.assignment_turned_in_outlined,
        );

      // Indent
      case 'Create Indent':
        return const TransactionPlaceholderPage(
          title: 'Create Indent',
          icon: Icons.note_add_outlined,
        );
      case 'Indent Approval':
        return const TransactionPlaceholderPage(
          title: 'Indent Approval',
          icon: Icons.approval_outlined,
        );
      case 'Enquiry Creation':
        return const TransactionPlaceholderPage(
          title: 'Enquiry Creation',
          icon: Icons.contact_support_outlined,
        );
      case 'Quotation Manager':
        return const TransactionPlaceholderPage(
          title: 'Quotation Manager',
          icon: Icons.request_quote_outlined,
        );

      // Sales Order
      case 'Generate Sales Order':
        return const TransactionPlaceholderPage(
          title: 'Generate Sales Order',
          icon: Icons.add_shopping_cart_outlined,
        );
      case 'Release Sales Order':
        return const TransactionPlaceholderPage(
          title: 'Release Sales Order',
          icon: Icons.shopping_cart_checkout_outlined,
        );

      // Purchase Order
      case 'Generate Purchase Order':
        return const TransactionPlaceholderPage(
          title: 'Generate Purchase Order',
          icon: Icons.shopping_basket_outlined,
        );
      case 'Release Purchase Order':
        return const TransactionPlaceholderPage(
          title: 'Release Purchase Order',
          icon: Icons.mark_email_read_outlined,
        );
      case 'PO Advance Entry':
        return const TransactionPlaceholderPage(
          title: 'PO Advance Entry',
          icon: Icons.payments_outlined,
        );
      case 'Freight Memo':
        return const TransactionPlaceholderPage(
          title: 'Freight Memo',
          icon: Icons.local_shipping_outlined,
        );

      // Material Inward
      case 'Gate Entry Manager':
        return const TransactionPlaceholderPage(
          title: 'Gate Entry Manager',
          icon: Icons.sensor_door_outlined,
        );
      case 'Material Receipt':
        return const TransactionPlaceholderPage(
          title: 'Material Receipt',
          icon: Icons.receipt_outlined,
        );
      case 'Inter Company Inward':
        return const TransactionPlaceholderPage(
          title: 'Inter Company Inward',
          icon: Icons.sync_alt_outlined,
        );
      case 'Material Inspection':
        return const TransactionPlaceholderPage(
          title: 'Material Inspection',
          icon: Icons.verified_outlined,
        );
      case 'Party Payment':
        return const TransactionPlaceholderPage(
          title: 'Party Payment',
          icon: Icons.paid_outlined,
        );

      // Issue
      case 'Stock Transfer':
        return const TransactionPlaceholderPage(
          title: 'Stock Transfer',
          icon: Icons.swap_horiz_outlined,
        );
      case 'Issue Manager':
        return const TransactionPlaceholderPage(
          title: 'Issue Manager',
          icon: Icons.output_outlined,
        );
      case 'WIP Approval':
        return const TransactionPlaceholderPage(
          title: 'WIP Approval',
          icon: Icons.thumb_up_alt_outlined,
        );
      case 'Material Return From/To':
        return const TransactionPlaceholderPage(
          title: 'Material Return From/To',
          icon: Icons.replay_outlined,
        );
      case 'Input Screen':
        return const TransactionPlaceholderPage(
          title: 'Input Screen',
          icon: Icons.input_outlined,
        );

      // Consumption Module
      case 'Cost of Maintenance':
        return const TransactionPlaceholderPage(
          title: 'Cost of Maintenance',
          icon: Icons.build_outlined,
        );
      case 'Operation Master':
        return const TransactionPlaceholderPage(
          title: 'Operation Master',
          icon: Icons.settings_suggest_outlined,
        );
      case 'Cost Of Material':
        return const TransactionPlaceholderPage(
          title: 'Cost Of Material',
          icon: Icons.monetization_on_outlined,
        );
      case 'Pallet Returnable Entry':
        return const TransactionPlaceholderPage(
          title: 'Pallet Returnable Entry',
          icon: Icons.move_down_outlined,
        );
      case 'Gate Pass':
        return const TransactionPlaceholderPage(
          title: 'Gate Pass',
          icon: Icons.badge_outlined,
        );
      case 'Stock Adjustment':
        return const TransactionPlaceholderPage(
          title: 'Stock Adjustment',
          icon: Icons.tune_outlined,
        );
      case 'Roll Cutting Entry':
        return const TransactionPlaceholderPage(
          title: 'Roll Cutting Entry',
          icon: Icons.content_cut_outlined,
        );

      // Job Work
      case 'Jobwork Manager':
        return const TransactionPlaceholderPage(
          title: 'Jobwork Manager',
          icon: Icons.engineering_outlined,
        );
      case 'Job Order':
        return const TransactionPlaceholderPage(
          title: 'Job Order',
          icon: Icons.work_outline_rounded,
        );
      case 'Jobwork Receipt':
        return const TransactionPlaceholderPage(
          title: 'Jobwork Receipt',
          icon: Icons.assignment_turned_in_outlined,
        );

      // Work Order
      case 'RGP':
        return const TransactionPlaceholderPage(
          title: 'RGP',
          icon: Icons.outbox_outlined,
        );
      case 'Create Work Order':
        return const TransactionPlaceholderPage(
          title: 'Create Work Order',
          icon: Icons.note_alt_outlined,
        );
      case 'Work Order Approval':
        return const TransactionPlaceholderPage(
          title: 'Work Order Approval',
          icon: Icons.how_to_reg_outlined,
        );
      case 'Work Order Gate Entry':
        return const TransactionPlaceholderPage(
          title: 'Work Order Gate Entry',
          icon: Icons.meeting_room_outlined,
        );
      case 'Work Order GRN':
        return const TransactionPlaceholderPage(
          title: 'Work Order GRN',
          icon: Icons.markunread_mailbox_outlined,
        );
      case 'RGP RECEIVED':
        return const TransactionPlaceholderPage(
          title: 'RGP RECEIVED',
          icon: Icons.move_to_inbox_outlined,
        );

      default:
        return TransactionPlaceholderPage(
          title: sub,
          icon: Icons.receipt_long_outlined,
        );
    }
  }

  Widget _buildMasterPage() {
    final sub = layoutState.selectedMasterSubItem.isNotEmpty
        ? layoutState.selectedMasterSubItem
        : 'Project Master';

    // Route Guard (Defense-in-depth UX enforcement):
    // If user is non-admin and lacks View permission for the requested Master module,
    // render access-restricted screen.
    final auth = AuthService.instance;
    final bool isAdmin = (auth.currentUser?.isAdmin ?? false) ||
        (auth.myPermissions?.isAdmin ?? false);
    final perms = auth.myPermissions;

    if (!isAdmin && perms != null && !perms.canViewModule(sub)) {
      return _buildAccessDenied(sub);
    }

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
    if (sub == 'Charges Master' || sub == 'Charges') {
      return const ChargesMasterPage();
    }
    return const ProjectMasterPage();
  }

  Widget _buildAccessDenied(String moduleName) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                size: 36,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your role does not have permission to view "$moduleName".\n'
              'Please contact your system administrator if you require access to this section.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
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
