import 'package:flutter/material.dart';
import 'widgets/sidebar.dart';
import 'widgets/app_header.dart';
import 'widgets/deferred_widget.dart';
import '../state/layout_state.dart';
import '../state/status_state.dart';
import '../pages/dashboard_page.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';

import '../pages/project_master_page.dart' deferred as project_page;
import '../pages/location_master_page.dart' deferred as location_page;
import '../pages/store_master_page.dart' deferred as store_page;
import '../pages/operator_master_page.dart' deferred as operator_page;
import '../pages/operation_master_page.dart' deferred as operation_page;
import '../pages/department_master_page.dart' deferred as department_page;
import '../pages/sub_department_master_page.dart' deferred as sub_dept_page;
import '../pages/head_master_page.dart' deferred as head_page;
import '../pages/book_master_page.dart' deferred as book_page;
import '../pages/non_stockable_item_master_page.dart' deferred as non_stock_page;
import '../pages/fabric_size_master_page.dart' deferred as fabric_page;
import '../pages/makers_master_page.dart' deferred as makers_page;
import '../pages/capital_consumable_master_page.dart' deferred as capital_page;
import '../pages/grade_master_page.dart' deferred as grade_page;
import '../pages/main_group_master_page.dart' deferred as main_group_page;
import '../pages/group_master_page.dart' deferred as group_page;
import '../pages/group_master_definition_page.dart' deferred as group_def_page;
import '../pages/charges_master_page.dart' deferred as charges_page;
import '../pages/placeholder_module_pages.dart';
import '../pages/transactions/bill_of_material_page.dart' deferred as bom_page;
import '../pages/transactions/transaction_placeholder_page.dart';
import '../pages/bom/bom_followup_page.dart' deferred as bom_followup_page;
import '../pages/purchase_order/purchase_order_page.dart' deferred as po_page;
import '../pages/purchase_order_approval/po_approval_page.dart' deferred as po_approval_page;
import '../pages/purchase_order_advance/po_advance_page.dart' deferred as po_advance_page;
import '../pages/sales_order/sales_order_page.dart' deferred as so_page;
import '../pages/sales_order_approval/so_approval_page.dart' deferred as so_approval_page;
import '../pages/indent/indent_page.dart' deferred as indent_page;
import '../pages/indent_approval/indent_approval_page.dart' deferred as indent_approval_page;
import '../pages/stock_transfer/stock_transfer_page.dart' deferred as stock_transfer_page;
import '../pages/issue_manager/issue_manager_page.dart' deferred as issue_manager_page;
import '../pages/material_return/material_return_page.dart' deferred as mat_return_page;
import '../pages/user_management_page.dart' deferred as user_mgmt_page;
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
                RepaintBoundary(
                  child: AppHeader(
                    title: _getPageTitle(layoutState.currentPageIndex),
                    isNavbarOpen: isOpen,
                    onMenuTap: layoutState.toggleNavbar,
                  ),
                ),
                Expanded(
                  child: RepaintBoundary(
                    child: KeyedSubtree(
                      key: ValueKey(
                          'page_${layoutState.currentPageIndex}_${layoutState.currentPageIndex == 1 ? layoutState.selectedMasterSubItem : (layoutState.currentPageIndex == 2 ? layoutState.selectedTransactionSubItem : "")}'),
                      child: _buildPage(layoutState.currentPageIndex),
                    ),
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
            child: RepaintBoundary(
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
          ),

          // ── Floating Expanded Sidebar Overlay (Springs in when open) ─────
          _FloatingSidebarAnimator(
            isOpen: isOpen,
            sidebarWidth: sw,
            margin: m,
            child: RepaintBoundary(
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
        return DeferredWidget(
          key: const ValueKey('user_management_page'),
          loader: user_mgmt_page.loadLibrary,
          builder: () => user_mgmt_page.UserManagementPage(key: const ValueKey('user_management_page')),
        );
      default:
        return const DashboardPage(key: ValueKey('default_dashboard'));
    }
  }

  Widget _buildTransactionPage() {
    final sub = layoutState.selectedTransactionSubItem.isNotEmpty
        ? layoutState.selectedTransactionSubItem
        : 'Bill of Material (BOM)';

    // Route Guard (Defense-in-depth UX enforcement):
    final auth = AuthService.instance;
    final bool isAdmin = (auth.currentUser?.isAdmin ?? false) ||
        (auth.myPermissions?.isAdmin ?? false);
    final perms = auth.myPermissions;

    if (!isAdmin && perms != null && !perms.canViewModule(sub)) {
      return _buildAccessDenied(sub);
    }

    switch (sub) {
      // Top group
      case 'Bill of Material (BOM)':
        return DeferredWidget(
          key: const ValueKey('deferred_bom_page'),
          loader: bom_page.loadLibrary,
          builder: () => bom_page.BillOfMaterialPage(),
        );
      case 'Production Order':
        return const TransactionPlaceholderPage(
          title: 'Production Order',
          icon: Icons.precision_manufacturing_outlined,
        );
      case 'BOM Followup':
        return DeferredWidget(
          key: const ValueKey('deferred_bom_followup_page'),
          loader: bom_followup_page.loadLibrary,
          builder: () => bom_followup_page.BomFollowupPage(),
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
        return DeferredWidget(
          key: const ValueKey('deferred_indent_page'),
          loader: indent_page.loadLibrary,
          builder: () => indent_page.IndentPage(),
        );
      case 'Indent Approval':
        return DeferredWidget(
          key: const ValueKey('deferred_indent_approval_page'),
          loader: indent_approval_page.loadLibrary,
          builder: () => indent_approval_page.IndentApprovalPage(),
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
        return DeferredWidget(
          key: const ValueKey('deferred_so_page'),
          loader: so_page.loadLibrary,
          builder: () => so_page.SalesOrderPage(),
        );
      case 'Release Sales Order':
        return DeferredWidget(
          key: const ValueKey('deferred_so_approval_page'),
          loader: so_approval_page.loadLibrary,
          builder: () => so_approval_page.SoApprovalPage(),
        );

      // Purchase Order
      case 'Generate Purchase Order':
        return DeferredWidget(
          key: const ValueKey('deferred_po_page'),
          loader: po_page.loadLibrary,
          builder: () => po_page.PurchaseOrderPage(),
        );
      case 'Release Purchase Order':
        return DeferredWidget(
          key: const ValueKey('deferred_po_approval_page'),
          loader: po_approval_page.loadLibrary,
          builder: () => po_approval_page.PoApprovalPage(),
        );
      case 'PO Advance Entry':
        return DeferredWidget(
          key: const ValueKey('deferred_po_advance_page'),
          loader: po_advance_page.loadLibrary,
          builder: () => po_advance_page.PoAdvancePage(),
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
        return DeferredWidget(
          key: const ValueKey('deferred_stock_transfer_page'),
          loader: stock_transfer_page.loadLibrary,
          builder: () => stock_transfer_page.StockTransferPage(),
        );
      case 'Issue Manager':
        return DeferredWidget(
          key: const ValueKey('deferred_issue_manager_page'),
          loader: issue_manager_page.loadLibrary,
          builder: () => issue_manager_page.IssueManagerPage(),
        );
      case 'WIP Approval':
        return const TransactionPlaceholderPage(
          title: 'WIP Approval',
          icon: Icons.thumb_up_alt_outlined,
        );
      case 'Material Return From/To':
        return DeferredWidget(
          key: const ValueKey('deferred_mat_return_page'),
          loader: mat_return_page.loadLibrary,
          builder: () => mat_return_page.MaterialReturnPage(),
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

    if (sub == 'Location Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_location_master'),
        loader: location_page.loadLibrary,
        builder: () => location_page.LocationMasterPage(),
      );
    }
    if (sub == 'Store Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_store_master'),
        loader: store_page.loadLibrary,
        builder: () => store_page.StoreMasterPage(),
      );
    }
    if (sub == 'Operator Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_operator_master'),
        loader: operator_page.loadLibrary,
        builder: () => operator_page.OperatorMasterPage(),
      );
    }
    if (sub == 'Operation Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_operation_master'),
        loader: operation_page.loadLibrary,
        builder: () => operation_page.OperationMasterPage(),
      );
    }
    if (sub == 'Department Master' || sub == 'Department') {
      return DeferredWidget(
        key: const ValueKey('deferred_department_master'),
        loader: department_page.loadLibrary,
        builder: () => department_page.DepartmentMasterPage(),
      );
    }
    if (sub == 'Sub-Department Master' ||
        sub == 'Sub-Department' ||
        sub == 'Sub Department') {
      return DeferredWidget(
        key: const ValueKey('deferred_sub_department_master'),
        loader: sub_dept_page.loadLibrary,
        builder: () => sub_dept_page.SubDepartmentMasterPage(),
      );
    }
    if (sub == 'Head Master' ||
        sub == 'Head Master (Costing Head)' ||
        sub == 'Costing Head') {
      return DeferredWidget(
        key: const ValueKey('deferred_head_master'),
        loader: head_page.loadLibrary,
        builder: () => head_page.HeadMasterPage(),
      );
    }
    if (sub == 'Book Master' || sub == 'Book') {
      return DeferredWidget(
        key: const ValueKey('deferred_book_master'),
        loader: book_page.loadLibrary,
        builder: () => book_page.BookMasterPage(),
      );
    }
    if (sub == 'Fabric Size Master' || sub == 'Fabric Size') {
      return DeferredWidget(
        key: const ValueKey('deferred_fabric_size_master'),
        loader: fabric_page.loadLibrary,
        builder: () => fabric_page.FabricSizeMasterPage(),
      );
    }
    if (sub == 'Makers Master' || sub == 'Makers' || sub == 'Maker Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_makers_master'),
        loader: makers_page.loadLibrary,
        builder: () => makers_page.MakersMasterPage(),
      );
    }
    if (sub == 'Capital / Consumable' ||
        sub == 'Capital Consumable Master' ||
        sub == 'Capital / Consumable Master' ||
        sub == 'Capital Consumable') {
      return DeferredWidget(
        key: const ValueKey('deferred_capital_consumable_master'),
        loader: capital_page.loadLibrary,
        builder: () => capital_page.CapitalConsumableMasterPage(),
      );
    }
    if (sub == 'Grade Master' ||
        sub == 'Grade' ||
        sub == 'Grade Definition') {
      return DeferredWidget(
        key: const ValueKey('deferred_grade_master'),
        loader: grade_page.loadLibrary,
        builder: () => grade_page.GradeMasterPage(),
      );
    }
    if (sub == 'Main Group Master' ||
        sub == 'Main Group' ||
        sub == 'Main Group (WIPMST)') {
      return DeferredWidget(
        key: const ValueKey('deferred_main_group_master'),
        loader: main_group_page.loadLibrary,
        builder: () => main_group_page.MainGroupMasterPage(),
      );
    }
    if (sub == 'Group Master' ||
        sub == 'Group Master (Category)' ||
        sub == 'Category Master' ||
        sub == 'Group (Category)') {
      return DeferredWidget(
        key: const ValueKey('deferred_group_master'),
        loader: group_page.loadLibrary,
        builder: () => group_page.GroupMasterPage(),
      );
    }
    if (sub == 'Group Master Definition' ||
        sub == 'Group Definition' ||
        sub == 'Group Definition Master' ||
        sub == 'Sub Group Mapping') {
      return DeferredWidget(
        key: const ValueKey('deferred_group_master_definition'),
        loader: group_def_page.loadLibrary,
        builder: () => group_def_page.GroupMasterDefinitionPage(),
      );
    }
    if (sub == 'Non-Stockable Item' ||
        sub == 'Non-Stockable Item Master') {
      return DeferredWidget(
        key: const ValueKey('deferred_non_stockable_item_master'),
        loader: non_stock_page.loadLibrary,
        builder: () => non_stock_page.NonStockableItemMasterPage(),
      );
    }
    if (sub == 'Charges Master' || sub == 'Charges') {
      return DeferredWidget(
        key: const ValueKey('deferred_charges_master'),
        loader: charges_page.loadLibrary,
        builder: () => charges_page.ChargesMasterPage(),
      );
    }
    return DeferredWidget(
      key: const ValueKey('deferred_project_master'),
      loader: project_page.loadLibrary,
      builder: () => project_page.ProjectMasterPage(),
    );
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

