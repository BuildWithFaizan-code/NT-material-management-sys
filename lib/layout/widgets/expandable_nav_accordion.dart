import 'package:flutter/material.dart';
import 'modern_navbar_theme.dart';

/// Reusable collapsible accordion widget for sidebar navigation items (e.g. Master, Transaction).
/// Provides consistent header styling, expand/collapse animation, and vertical tree connector line.
class ExpandableNavAccordion extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onHeaderTap;
  final Widget content;

  const ExpandableNavAccordion({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onHeaderTap,
    required this.content,
  });

  @override
  State<ExpandableNavAccordion> createState() => _ExpandableNavAccordionState();
}

class _ExpandableNavAccordionState extends State<ExpandableNavAccordion>
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

    if (widget.isSelected) {
      _isExpanded = true;
      _expandCtrl.value = 1.0;
    } else {
      _isExpanded = false;
      _expandCtrl.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(ExpandableNavAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected && !_isExpanded) {
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
    final isSelected = widget.isSelected;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Pill Tile
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onHeaderTap();
              if (!widget.isSelected) {
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
                    widget.icon,
                    size: 16,
                    color: isSelected
                        ? ModernNavbarTheme.activePillFg
                        : ModernNavbarTheme.inactiveIcon,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        color: isSelected
                            ? ModernNavbarTheme.activePillFg
                            : ModernNavbarTheme.inactiveFg,
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
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
            child: widget.content,
          ),
        ),
      ],
    );
  }
}

/// Single Sub-Item Tile with Hover & Pure White Elevated Pill matching reference
class NavSubItemTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const NavSubItemTile({
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<NavSubItemTile> createState() => _NavSubItemTileState();
}

class _NavSubItemTileState extends State<NavSubItemTile> {
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

/// Nested collapsible dropdown group inside a navigation accordion (e.g. Indent, SKU Master).
class NavNestedDropdown extends StatefulWidget {
  final String title;
  final IconData? icon;
  final bool hasActiveChild;
  final Widget content;

  const NavNestedDropdown({
    super.key,
    required this.title,
    this.icon,
    required this.hasActiveChild,
    required this.content,
  });

  @override
  State<NavNestedDropdown> createState() => _NavNestedDropdownState();
}

class _NavNestedDropdownState extends State<NavNestedDropdown>
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

    if (widget.hasActiveChild) {
      _isExpanded = true;
      _ctrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(NavNestedDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasActiveChild && !oldWidget.hasActiveChild && !_isExpanded) {
      _toggle();
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.hasActiveChild
                    ? ModernNavbarTheme.activeSubPillBg.withValues(alpha: 0.6)
                    : (_isHovering
                        ? ModernNavbarTheme.hoverBg
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 14,
                      color: ModernNavbarTheme.activeSubPillFg,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: ModernNavbarTheme.activeSubPillFg,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                    size: 12,
                    color: ModernNavbarTheme.activeSubPillFg,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Nested Sub-Items
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
            child: widget.content,
          ),
        ),
      ],
    );
  }
}
