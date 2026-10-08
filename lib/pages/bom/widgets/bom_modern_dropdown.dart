import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

// ============================================================================
// ENTERPRISE MODERN POPOVER DROPDOWN (BOM MODULE DESIGN SYSTEM)
// ============================================================================

class BomDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? badgeColor;

  const BomDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.badgeColor,
  });
}

class BomModernDropdown<T> extends StatefulWidget {
  final T? value;
  final String hintText;
  final String dropdownTitle;
  final IconData? titleIcon;
  final List<BomDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FocusNode? focusNode;
  final Color accentColor;
  final Color hoverBorderColor;
  final double height;
  final double borderRadius;
  final bool enableSearch;
  final double maxMenuHeight;
  final double? menuWidth;

  const BomModernDropdown({
    super.key,
    required this.value,
    required this.hintText,
    required this.dropdownTitle,
    this.titleIcon,
    required this.items,
    required this.onChanged,
    this.focusNode,
    this.accentColor = const Color(0xFF0C3B2E),
    this.hoverBorderColor = const Color(0xFFA7F3D0),
    this.height = 34,
    this.borderRadius = 8,
    this.enableSearch = false,
    this.maxMenuHeight = 260.0,
    this.menuWidth,
  });

  @override
  State<BomModernDropdown<T>> createState() => _BomModernDropdownState<T>();
}

class _BomModernDropdownState<T> extends State<BomModernDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _chevronAnim;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutCubic,
      ),
    );
    _chevronAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant BomModernDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOpen && _overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _closeMenu(instant: true);
    _animCtrl.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (widget.items.isEmpty) return;
    _closeMenu(instant: true);

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - (offset.dy + size.height);

    final bool showSearch = widget.enableSearch || widget.items.length > 5;
    final double headerHeight = 36.0;
    final double searchHeight = showSearch ? 38.0 : 0.0;
    final double itemHeight = 38.0;
    final double totalItemsHeight = widget.items.length * itemHeight;
    final double maxMenuHeight = widget.maxMenuHeight;
    final double calculatedHeight = math.min(
      headerHeight + searchHeight + totalItemsHeight + 12.0,
      maxMenuHeight,
    );

    final bool openUpwards = spaceBelow < (calculatedHeight + 14) && offset.dy > calculatedHeight;
    final double offsetY = openUpwards ? -(calculatedHeight + 4) : (size.height + 4);

    final double targetWidth = widget.menuWidth ?? math.max(size.width, 220.0);
    final double horizontalOffset =
        (offset.dx + targetWidth > screenSize.width - 16) ? -(targetWidth - size.width) : 0.0;

    _searchCtrl.clear();

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return _BomDropdownMenuContent<T>(
          layerLink: _layerLink,
          offsetY: offsetY,
          horizontalOffset: horizontalOffset,
          width: targetWidth,
          openUpwards: openUpwards,
          fadeAnim: _fadeAnim,
          scaleAnim: _scaleAnim,
          maxMenuHeight: maxMenuHeight,
          title: widget.dropdownTitle,
          titleIcon: widget.titleIcon,
          accentColor: widget.accentColor,
          items: widget.items,
          selectedValue: widget.value,
          showSearch: showSearch,
          searchCtrl: _searchCtrl,
          scrollController: _scrollController,
          onDismiss: _closeMenu,
          onSelect: (val) {
            _closeMenu();
            widget.onChanged?.call(val);
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _animCtrl.forward(from: 0.0);
  }

  void _closeMenu({bool instant = false}) {
    if (!_isOpen && _overlayEntry == null) return;
    setState(() => _isOpen = false);
    if (instant) {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
      _animCtrl.value = 0.0;
    } else {
      _animCtrl.reverse().then((_) {
        if (_overlayEntry != null) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    BomDropdownItem<T>? selectedItem;
    if (widget.value != null) {
      for (final it in widget.items) {
        if (it.value == widget.value) {
          selectedItem = it;
          break;
        }
      }
    }

    final bool isEnabled = widget.onChanged != null;
    final bool isUnmatched = widget.value != null && selectedItem == null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => isEnabled ? setState(() => _isHovered = true) : null,
        onExit: (_) => isEnabled ? setState(() => _isHovered = false) : null,
        cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: isEnabled ? _toggleMenu : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: !isEnabled
                  ? const Color(0xFFF1F5F9)
                  : (_isOpen
                      ? widget.accentColor.withValues(alpha: 0.04)
                      : (isUnmatched
                          ? const Color(0xFFFEF2F2)
                          : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white))),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: isUnmatched
                    ? const Color(0xFFFCA5A5)
                    : (_isOpen
                        ? widget.accentColor
                        : (_isHovered ? widget.hoverBorderColor : const Color(0xFFCBD5E1))),
                width: _isOpen ? 1.5 : (_isHovered || isUnmatched ? 1.2 : 1.0),
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : (_isHovered && isEnabled
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null),
            ),
            child: Row(
              children: [
                if (selectedItem != null) ...[
                  if (selectedItem.icon != null) ...[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selectedItem.badgeColor ?? widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        selectedItem.icon,
                        size: 12,
                        color: selectedItem.iconColor ?? widget.accentColor,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    child: Text(
                      selectedItem.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else if (widget.value != null) ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Unmatched (Code: ${widget.value})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      widget.hintText,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (isEnabled)
                  RotationTransition(
                    turns: _chevronAnim,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: _isOpen || _isHovered ? widget.accentColor : const Color(0xFF64748B),
                    ),
                  )
                else
                  const Icon(
                    Icons.lock_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BomDropdownMenuContent<T> extends StatefulWidget {
  final LayerLink layerLink;
  final double offsetY;
  final double horizontalOffset;
  final double width;
  final bool openUpwards;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;
  final double maxMenuHeight;
  final String title;
  final IconData? titleIcon;
  final Color accentColor;
  final List<BomDropdownItem<T>> items;
  final T? selectedValue;
  final bool showSearch;
  final TextEditingController searchCtrl;
  final ScrollController scrollController;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelect;

  const _BomDropdownMenuContent({
    required this.layerLink,
    required this.offsetY,
    required this.horizontalOffset,
    required this.width,
    required this.openUpwards,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.maxMenuHeight,
    required this.title,
    this.titleIcon,
    required this.accentColor,
    required this.items,
    required this.selectedValue,
    required this.showSearch,
    required this.searchCtrl,
    required this.scrollController,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_BomDropdownMenuContent<T>> createState() => _BomDropdownMenuContentState<T>();
}

class _BomDropdownMenuContentState<T> extends State<_BomDropdownMenuContent<T>> {
  String _filter = '';

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _filter = widget.searchCtrl.text.trim().toLowerCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((it) {
      if (_filter.isEmpty) return true;
      final matchLabel = it.label.toLowerCase().contains(_filter);
      final matchSub = it.subtitle?.toLowerCase().contains(_filter) ?? false;
      return matchLabel || matchSub;
    }).toList();

    return Stack(
      children: [
        // Barrier to dismiss when clicking outside
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => widget.onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),

        // Positioned Dropdown Menu with entrance animation
        Positioned(
          width: widget.width,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: Offset(widget.horizontalOffset, widget.offsetY),
            child: FadeTransition(
              opacity: widget.fadeAnim,
              child: ScaleTransition(
                scale: widget.scaleAnim,
                alignment: widget.openUpwards ? Alignment.bottomCenter : Alignment.topCenter,
                child: Material(
                  elevation: 16,
                  shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.20),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(
                                  widget.titleIcon ?? Icons.format_list_bulleted_rounded,
                                  size: 12,
                                  color: widget.accentColor,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  widget.title.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.items.length} ${widget.items.length == 1 ? "Option" : "Options"}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Optional Search Bar
                        if (widget.showSearch)
                          Container(
                            height: 28,
                            margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.search_rounded, size: 13, color: Color(0xFF94A3B8)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: widget.searchCtrl,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Filter options...',
                                      hintStyle: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (widget.searchCtrl.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => widget.searchCtrl.clear(),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Scrollable List of Options
                        Flexible(
                          child: filtered.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.search_off_rounded, size: 20, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 4),
                                      Text(
                                        'No matching options',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RawScrollbar(
                                  controller: widget.scrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  thickness: 4,
                                  radius: const Radius.circular(4),
                                  thumbColor: const Color(0xFF94A3B8),
                                  trackVisibility: true,
                                  trackColor: const Color(0xFFF1F5F9),
                                  trackRadius: const Radius.circular(4),
                                  trackBorderColor: Colors.transparent,
                                  padding: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
                                  minThumbLength: 24,
                                  pressDuration: Duration.zero,
                                  child: Listener(
                                    onPointerSignal: (pointerSignal) {
                                      if (pointerSignal is PointerScrollEvent &&
                                          widget.scrollController.hasClients &&
                                          widget.scrollController.position.hasContentDimensions) {
                                        GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (event) {
                                          final scrollEvent = event as PointerScrollEvent;
                                          final currentOffset = widget.scrollController.offset;
                                          final maxOffset = widget.scrollController.position.maxScrollExtent;
                                          final targetOffset =
                                              (currentOffset + scrollEvent.scrollDelta.dy * 0.75).clamp(0.0, maxOffset);
                                          widget.scrollController.animateTo(
                                            targetOffset,
                                            duration: const Duration(milliseconds: 140),
                                            curve: Curves.easeOutCubic,
                                          );
                                        });
                                      }
                                    },
                                    child: ListView.builder(
                                      controller: widget.scrollController,
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      itemCount: filtered.length,
                                      itemBuilder: (ctx, index) {
                                        final item = filtered[index];
                                        final isSelected = widget.selectedValue == item.value;
                                        return _BomDropdownOptionTile<T>(
                                          item: item,
                                          isSelected: isSelected,
                                          accentColor: widget.accentColor,
                                          onTap: () => widget.onSelect(item.value),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BomDropdownOptionTile<T> extends StatefulWidget {
  final BomDropdownItem<T> item;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _BomDropdownOptionTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_BomDropdownOptionTile<T>> createState() => _BomDropdownOptionTileState<T>();
}

class _BomDropdownOptionTileState<T> extends State<_BomDropdownOptionTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final accent = widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : (_isHovered ? accent.withValues(alpha: 0.07) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: accent.withValues(alpha: 0.35), width: 1.0)
                : (_isHovered
                    ? Border.all(color: accent.withValues(alpha: 0.18), width: 1.0)
                    : Border.all(color: Colors.transparent, width: 1.0)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 3.5,
                height: 18,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (_isHovered ? accent.withValues(alpha: 0.4) : Colors.transparent),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              if (item.icon != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.badgeColor ??
                        (isSelected
                            ? accent.withValues(alpha: 0.15)
                            : (_isHovered
                                ? accent.withValues(alpha: 0.10)
                                : const Color(0xFFF1F5F9))),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    item.icon,
                    size: 13,
                    color: item.iconColor ??
                        (isSelected ? accent : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : (_isHovered ? FontWeight.w700 : FontWeight.w600),
                        color: isSelected ? accent : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: accent,
                  ),
                )
              else if (_isHovered)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: accent.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
