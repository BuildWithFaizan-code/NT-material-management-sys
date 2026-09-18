import 'package:flutter/material.dart';
import 'expandable_nav_accordion.dart';

/// Data class representing an entry in the Transaction navigation submenu.
class TransactionMenuEntry {
  final String title;
  final IconData icon;

  const TransactionMenuEntry({
    required this.title,
    required this.icon,
  });
}

/// Data class representing a sub-section in the Transaction navigation submenu.
class TransactionSubSection {
  final String? sectionTitle;
  final IconData? sectionIcon;
  final List<TransactionMenuEntry> items;

  const TransactionSubSection({
    this.sectionTitle,
    this.sectionIcon,
    required this.items,
  });
}

/// The complete, ordered list of Transaction sub-sections and menu entries.
const List<TransactionSubSection> transactionSubSections = [
  // Unlabeled top group — no section header
  TransactionSubSection(
    sectionTitle: null,
    items: [
      TransactionMenuEntry(
        title: 'Bill of Material (BOM)',
        icon: Icons.account_tree_outlined,
      ),
      TransactionMenuEntry(
        title: 'Production Order',
        icon: Icons.precision_manufacturing_outlined,
      ),
      TransactionMenuEntry(
        title: 'BOM Followup',
        icon: Icons.timeline_outlined,
      ),
      TransactionMenuEntry(
        title: 'Production Order Close',
        icon: Icons.task_alt_outlined,
      ),
      TransactionMenuEntry(
        title: 'Repack Production Order',
        icon: Icons.inventory_2_outlined,
      ),
      TransactionMenuEntry(
        title: 'WIP Followup',
        icon: Icons.pending_actions_outlined,
      ),
      TransactionMenuEntry(
        title: 'Estimate Requirements',
        icon: Icons.calculate_outlined,
      ),
      TransactionMenuEntry(
        title: 'Requisition',
        icon: Icons.post_add_outlined,
      ),
      TransactionMenuEntry(
        title: 'Requisition Status',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ],
  ),

  // Indent
  TransactionSubSection(
    sectionTitle: 'Indent',
    sectionIcon: Icons.description_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Create Indent',
        icon: Icons.note_add_outlined,
      ),
      TransactionMenuEntry(
        title: 'Indent Approval',
        icon: Icons.approval_outlined,
      ),
      TransactionMenuEntry(
        title: 'Enquiry Creation',
        icon: Icons.contact_support_outlined,
      ),
      TransactionMenuEntry(
        title: 'Quotation Manager',
        icon: Icons.request_quote_outlined,
      ),
    ],
  ),

  // Sales Order
  TransactionSubSection(
    sectionTitle: 'Sales Order',
    sectionIcon: Icons.point_of_sale_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Generate Sales Order',
        icon: Icons.add_shopping_cart_outlined,
      ),
      TransactionMenuEntry(
        title: 'Release Sales Order',
        icon: Icons.shopping_cart_checkout_outlined,
      ),
    ],
  ),

  // Purchase Order
  TransactionSubSection(
    sectionTitle: 'Purchase Order',
    sectionIcon: Icons.shopping_basket_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Generate Purchase Order',
        icon: Icons.shopping_basket_outlined,
      ),
      TransactionMenuEntry(
        title: 'Release Purchase Order',
        icon: Icons.mark_email_read_outlined,
      ),
      TransactionMenuEntry(
        title: 'PO Advance Entry',
        icon: Icons.payments_outlined,
      ),
      TransactionMenuEntry(
        title: 'Freight Memo',
        icon: Icons.local_shipping_outlined,
      ),
    ],
  ),

  // Material Inward
  TransactionSubSection(
    sectionTitle: 'Material Inward',
    sectionIcon: Icons.login_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Gate Entry Manager',
        icon: Icons.sensor_door_outlined,
      ),
      TransactionMenuEntry(
        title: 'Material Receipt',
        icon: Icons.receipt_outlined,
      ),
      TransactionMenuEntry(
        title: 'Inter Company Inward',
        icon: Icons.sync_alt_outlined,
      ),
      TransactionMenuEntry(
        title: 'Material Inspection',
        icon: Icons.verified_outlined,
      ),
      TransactionMenuEntry(
        title: 'Party Payment',
        icon: Icons.paid_outlined,
      ),
    ],
  ),

  // Issue
  TransactionSubSection(
    sectionTitle: 'Issue',
    sectionIcon: Icons.output_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Stock Transfer',
        icon: Icons.swap_horiz_outlined,
      ),
      TransactionMenuEntry(
        title: 'Issue Manager',
        icon: Icons.output_outlined,
      ),
      TransactionMenuEntry(
        title: 'WIP Approval',
        icon: Icons.thumb_up_alt_outlined,
      ),
      TransactionMenuEntry(
        title: 'Material Return From/To',
        icon: Icons.replay_outlined,
      ),
      TransactionMenuEntry(
        title: 'Input Screen',
        icon: Icons.input_outlined,
      ),
    ],
  ),

  // Consumption Module
  TransactionSubSection(
    sectionTitle: 'Consumption Module',
    sectionIcon: Icons.pie_chart_outline_rounded,
    items: [
      TransactionMenuEntry(
        title: 'Cost of Maintenance',
        icon: Icons.build_outlined,
      ),
      TransactionMenuEntry(
        title: 'Operation Master',
        icon: Icons.settings_suggest_outlined,
      ),
      TransactionMenuEntry(
        title: 'Cost Of Material',
        icon: Icons.monetization_on_outlined,
      ),
      TransactionMenuEntry(
        title: 'Pallet Returnable Entry',
        icon: Icons.move_down_outlined,
      ),
      TransactionMenuEntry(
        title: 'Gate Pass',
        icon: Icons.badge_outlined,
      ),
      TransactionMenuEntry(
        title: 'Stock Adjustment',
        icon: Icons.tune_outlined,
      ),
      TransactionMenuEntry(
        title: 'Roll Cutting Entry',
        icon: Icons.content_cut_outlined,
      ),
    ],
  ),

  // Job Work
  TransactionSubSection(
    sectionTitle: 'Job Work',
    sectionIcon: Icons.engineering_outlined,
    items: [
      TransactionMenuEntry(
        title: 'Jobwork Manager',
        icon: Icons.engineering_outlined,
      ),
      TransactionMenuEntry(
        title: 'Job Order',
        icon: Icons.work_outline_rounded,
      ),
      TransactionMenuEntry(
        title: 'Jobwork Receipt',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ],
  ),

  // Work Order
  TransactionSubSection(
    sectionTitle: 'Work Order',
    sectionIcon: Icons.assignment_outlined,
    items: [
      TransactionMenuEntry(
        title: 'RGP',
        icon: Icons.outbox_outlined,
      ),
      TransactionMenuEntry(
        title: 'Create Work Order',
        icon: Icons.note_alt_outlined,
      ),
      TransactionMenuEntry(
        title: 'Work Order Approval',
        icon: Icons.how_to_reg_outlined,
      ),
      TransactionMenuEntry(
        title: 'Work Order Gate Entry',
        icon: Icons.meeting_room_outlined,
      ),
      TransactionMenuEntry(
        title: 'Work Order GRN',
        icon: Icons.markunread_mailbox_outlined,
      ),
      TransactionMenuEntry(
        title: 'RGP RECEIVED',
        icon: Icons.move_to_inbox_outlined,
      ),
    ],
  ),
];

/// Collapsible accordion item for "Transaction" navigation tab with grouped sub-items.
class TransactionNavItem extends StatelessWidget {
  final bool isTransactionSelected;
  final String activeSubItem;
  final VoidCallback onTransactionHeaderTap;
  final ValueChanged<String> onSubItemSelected;

  const TransactionNavItem({
    super.key,
    required this.isTransactionSelected,
    required this.activeSubItem,
    required this.onTransactionHeaderTap,
    required this.onSubItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ExpandableNavAccordion(
      icon: Icons.receipt_long_outlined,
      title: 'Transaction',
      isSelected: isTransactionSelected,
      onHeaderTap: onTransactionHeaderTap,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _buildSubList(),
      ),
    );
  }

  List<Widget> _buildSubList() {
    final List<Widget> widgets = [];

    for (final section in transactionSubSections) {
      if (section.sectionTitle == null) {
        // Unlabeled top group: render items directly
        for (final item in section.items) {
          final bool isSelected = activeSubItem == item.title;
          widgets.add(
            NavSubItemTile(
              icon: item.icon,
              title: item.title,
              isSelected: isSelected,
              onTap: () => onSubItemSelected(item.title),
            ),
          );
        }
      } else {
        // Sub-section with dropdown
        final bool hasActiveChild =
            section.items.any((item) => item.title == activeSubItem);

        widgets.add(
          NavNestedDropdown(
            title: section.sectionTitle!,
            icon: section.sectionIcon,
            hasActiveChild: hasActiveChild,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: section.items.map((item) {
                final bool isSelected = activeSubItem == item.title;
                return NavSubItemTile(
                  icon: item.icon,
                  title: item.title,
                  isSelected: isSelected,
                  onTap: () => onSubItemSelected(item.title),
                );
              }).toList(),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}
