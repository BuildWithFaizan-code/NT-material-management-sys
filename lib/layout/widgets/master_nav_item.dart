import 'package:flutter/material.dart';
import 'modern_navbar_theme.dart';

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

/// The complete list of Master sub-sections.
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
];

/// Collapsible accordion item for "Master" navigation tab with nested sub-items
/// styled matching the reference image tree hierarchy with a dark pill active header
/// and pure white elevated capsule sub-item indicator.
class MasterNavItem extends StatefulWidget {
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
  State<MasterNavItem> createState() => _MasterNavItemState();
}

class _MasterNavItemState extends State<MasterNavItem>
    with TickerProviderStateMixin {
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;

  bool _isExpanded = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.fastOutSlowIn,
    );

    // At startup or restart, do not expand dropdown; only expand if Master is currently active
    if (widget.isMasterSelected) {
      _isExpanded = true;
      _expandCtrl.value = 1.0;
    } else {
      _isExpanded = false;
      _expandCtrl.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(MasterNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMasterSelected && !oldWidget.isMasterSelected && !_isExpanded) {
      _toggleExpand();
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandCtrl.forward();
      } else {
        _expandCtrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isMasterSelected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master Header Pill Tile
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: () {
              widget.onMasterHeaderTap();
              if (!widget.isMasterSelected) {
                if (!_isExpanded) {
                  _toggleExpand();
                }
              } else {
                _toggleExpand();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? ModernNavbarTheme.activePillBg
                    : (_isHovering
                        ? ModernNavbarTheme.hoverBg
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: isSelected
                        ? ModernNavbarTheme.activePillFg
                        : ModernNavbarTheme.inactiveIcon,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Master',
                      style: TextStyle(
                        color: isSelected
                            ? ModernNavbarTheme.activePillFg
                            : ModernNavbarTheme.inactiveFg,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  // Expand / collapse indicator matching reference (minus `—` or plus `+`)
                  Icon(
                    _isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    size: 14,
                    color: isSelected
                        ? ModernNavbarTheme.activePillFg
                        : ModernNavbarTheme.inactiveFg,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Accordion Expanded Sub-List with vertical connector line
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: Container(
            margin: const EdgeInsets.only(left: 20, top: 3, bottom: 3),
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: ModernNavbarTheme.connectorLine,
                  width: 1.1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: masterSubSections.map((sub) {
                if (sub.isSkuGroup) {
                  return _SkuMasterNestedGroup(
                    subSection: sub,
                    activeSubItem: widget.activeSubItem,
                    onSubItemSelected: widget.onSubItemSelected,
                  );
                }

                final bool isSubSelected = widget.activeSubItem == sub.title;
                return _SubItemTile(
                  icon: sub.icon,
                  title: sub.title,
                  isSelected: isSubSelected,
                  onTap: () => widget.onSubItemSelected(sub.title),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nested Dropdown Group specifically for SKU Master -> Raw Material & Finish Material
class _SkuMasterNestedGroup extends StatefulWidget {
  final MasterSubSection subSection;
  final String activeSubItem;
  final ValueChanged<String> onSubItemSelected;

  const _SkuMasterNestedGroup({
    required this.subSection,
    required this.activeSubItem,
    required this.onSubItemSelected,
  });

  @override
  State<_SkuMasterNestedGroup> createState() => _SkuMasterNestedGroupState();
}

class _SkuMasterNestedGroupState extends State<_SkuMasterNestedGroup>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;

  bool _isExpanded = false;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.fastOutSlowIn);

    final skuItems = widget.subSection.skuSubItems ?? [];
    if (skuItems.contains(widget.activeSubItem) || widget.activeSubItem == 'SKU Master') {
      _isExpanded = true;
      _ctrl.value = 1.0;
    }
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _ctrl.forward();
      } else {
        _ctrl.reverse();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isParentSelected = widget.activeSubItem == 'SKU Master';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isParentSelected
                    ? ModernNavbarTheme.activeSubPillBg
                    : (_isHovering
                        ? ModernNavbarTheme.hoverBg
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isParentSelected ? ModernNavbarTheme.activeSubPillShadow : null,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.subSection.icon,
                    size: 14,
                    color: isParentSelected
                        ? ModernNavbarTheme.activeSubPillFg
                        : ModernNavbarTheme.inactiveIcon,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.subSection.title,
                      style: TextStyle(
                        color: isParentSelected
                            ? ModernNavbarTheme.activeSubPillFg
                            : ModernNavbarTheme.inactiveFg,
                        fontSize: 11.5,
                        fontWeight: isParentSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    size: 12,
                    color: isParentSelected
                        ? ModernNavbarTheme.activeSubPillFg
                        : ModernNavbarTheme.inactiveFg,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Nested Sub-Items for SKU Master
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.only(left: 8),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: ModernNavbarTheme.connectorLine,
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: (widget.subSection.skuSubItems ?? []).map((title) {
                final bool isSelected = widget.activeSubItem == title;
                final IconData itemIcon = title == 'Raw Material'
                    ? Icons.token_outlined
                    : Icons.check_circle_outline_rounded;

                return _SubItemTile(
                  icon: itemIcon,
                  title: title,
                  isSelected: isSelected,
                  onTap: () => widget.onSubItemSelected(title),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single Sub-Item Tile with Hover & Pure White Elevated Pill matching reference
class _SubItemTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubItemTile({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SubItemTile> createState() => _SubItemTileState();
}

class _SubItemTileState extends State<_SubItemTile> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? ModernNavbarTheme.activeSubPillBg
                : (_isHovering
                    ? ModernNavbarTheme.hoverBg
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected ? ModernNavbarTheme.activeSubPillShadow : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: isSelected
                    ? ModernNavbarTheme.activeSubPillFg
                    : ModernNavbarTheme.inactiveIcon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    color: isSelected
                        ? ModernNavbarTheme.activeSubPillFg
                        : ModernNavbarTheme.inactiveFg,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
