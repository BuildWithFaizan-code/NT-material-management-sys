import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'expandable_nav_accordion.dart';

/// Data class representing a Master sub-navigation section.
class MasterSubSection {
  final String title;
  final IconData icon;
  final bool isSkuGroup;
  final List<String>? skuSubItems;

  const MasterSubSection({
    required this.title,
    required this.icon,
    this.isSkuGroup = false,
    this.skuSubItems,
  });
}

/// The complete list of Master sub-sections (Exactly 18 Master Modules).
const List<MasterSubSection> masterSubSections = [
  MasterSubSection(title: 'Project Master', icon: Icons.folder_open_rounded),
  MasterSubSection(title: 'Location Master', icon: Icons.location_on_outlined),
  MasterSubSection(title: 'Store Master', icon: Icons.storefront_outlined),
  MasterSubSection(title: 'Operator Master', icon: Icons.badge_outlined),
  MasterSubSection(title: 'Operation Master', icon: Icons.settings_suggest_outlined),
  MasterSubSection(title: 'Department Master', icon: Icons.corporate_fare_outlined),
  MasterSubSection(title: 'Sub-Department Master', icon: Icons.account_tree_outlined),
  MasterSubSection(title: 'Non-Stockable Item', icon: Icons.remove_shopping_cart_outlined),
  MasterSubSection(title: 'Head Master', icon: Icons.account_balance_outlined),
  MasterSubSection(title: 'Book Master', icon: Icons.auto_stories_outlined),
  MasterSubSection(title: 'Fabric Size Master', icon: Icons.straighten_outlined),
  MasterSubSection(title: 'Makers Master', icon: Icons.precision_manufacturing_outlined),
  MasterSubSection(title: 'Capital / Consumable', icon: Icons.account_balance_wallet_outlined),
  MasterSubSection(title: 'Grade Master', icon: Icons.military_tech_outlined),
  MasterSubSection(title: 'Main Group Master', icon: Icons.grid_view_rounded),
  MasterSubSection(title: 'Group Master', icon: Icons.category_outlined),
  MasterSubSection(title: 'Group Master Definition', icon: Icons.folder_copy_outlined),
  MasterSubSection(title: 'Charges Master', icon: Icons.receipt_outlined),
];

/// Collapsible accordion item for "Master" navigation tab with nested sub-items
/// styled matching the reference image tree hierarchy with a dark pill active header
/// and pure white elevated capsule sub-item indicator.
///
/// PERMISSION FILTERING:
/// Non-admin users see ONLY the modules for which they have granted "View" permission.
/// Administrators have blanket visibility to all 18 Master modules.
class MasterNavItem extends StatelessWidget {
  final bool isMasterSelected;
  final String activeSubItem;
  final VoidCallback onMasterHeaderTap;
  final ValueChanged<String> onSubItemSelected;

  const MasterNavItem({
    super.key,
    required this.isMasterSelected,
    required this.activeSubItem,
    required this.onMasterHeaderTap,
    required this.onSubItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        final bool isAdmin = (auth.currentUser?.isAdmin ?? false) ||
            (auth.myPermissions?.isAdmin ?? false);
        final perms = auth.myPermissions;

        // Filter sections: admins see all 18, non-admins see only modules where View permission is granted
        final visibleSections = masterSubSections.where((sub) {
          if (isAdmin) return true;
          return perms?.canViewModule(sub.title) ?? false;
        }).toList();

        return ExpandableNavAccordion(
          icon: Icons.inventory_2_outlined,
          title: 'Master',
          isSelected: isMasterSelected,
          onHeaderTap: onMasterHeaderTap,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (visibleSections.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'No master modules assigned',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...visibleSections.map((sub) {
                  if (sub.isSkuGroup) {
                    return _SkuMasterNestedGroup(
                      subSection: sub,
                      activeSubItem: activeSubItem,
                      onSubItemSelected: onSubItemSelected,
                    );
                  }

                  final bool isSubSelected = activeSubItem == sub.title;
                  return NavSubItemTile(
                    icon: sub.icon,
                    title: sub.title,
                    isSelected: isSubSelected,
                    onTap: () => onSubItemSelected(sub.title),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

/// Nested Dropdown Group specifically for SKU Master -> Raw Material & Finish Material
class _SkuMasterNestedGroup extends StatelessWidget {
  final MasterSubSection subSection;
  final String activeSubItem;
  final ValueChanged<String> onSubItemSelected;

  const _SkuMasterNestedGroup({
    required this.subSection,
    required this.activeSubItem,
    required this.onSubItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final skuItems = subSection.skuSubItems ?? [];
    final bool hasActiveChild =
        skuItems.contains(activeSubItem) || activeSubItem == 'SKU Master';

    return NavNestedDropdown(
      title: subSection.title,
      icon: subSection.icon,
      hasActiveChild: hasActiveChild,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: skuItems.map((title) {
          final bool isSelected = activeSubItem == title;
          final IconData itemIcon = title == 'Raw Material'
              ? Icons.token_outlined
              : Icons.check_circle_outline_rounded;

          return NavSubItemTile(
            icon: itemIcon,
            title: title,
            isSelected: isSelected,
            onTap: () => onSubItemSelected(title),
          );
        }).toList(),
      ),
    );
  }
}
