import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';
import '../bom_service.dart';

/// "SELECT FINISHED GOOD ITEM" LOOKUP MODAL (QUERY 4)
/// Converted to 100% Group Master Show Record Table UI parity:
/// - Top header with count badge & keyboard navigation helper pill
/// - Live filter search input with emerald border
/// - A-Z alphabetical filter bar
/// - Professional ERP table layout with column icons & distinct typography
/// - Emerald capsule badges, status pills, and interactive hover effects
class FinishedGoodLookupDialog extends StatefulWidget {
  final BomMode mode;
  final String? initialQuery;
  final BomService? bomService;

  const FinishedGoodLookupDialog({
    super.key,
    required this.mode,
    this.initialQuery,
    this.bomService,
  });

  @override
  State<FinishedGoodLookupDialog> createState() => _FinishedGoodLookupDialogState();
}

class _FinishedGoodLookupDialogState extends State<FinishedGoodLookupDialog> {
  late final BomService _bomService;
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  List<FinishedGoodItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  int _selectedIndex = 0;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _bomService = widget.bomService ?? BomService();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
      _searchQuery = widget.initialQuery!.toLowerCase();
    }
    _loadItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final results = await _bomService.fetchFinishedGoods(
      mode: widget.mode,
      query: _searchCtrl.text.trim(),
    );
    if (mounted) {
      setState(() {
        _items = results;
        _isLoading = false;
        _selectedIndex = 0;
      });
    }
  }

  List<FinishedGoodItem> get _filteredItems {
    List<FinishedGoodItem> list = List.from(_items);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) {
        return i.iCode.toLowerCase().contains(_searchQuery) ||
            i.itName.toLowerCase().contains(_searchQuery) ||
            i.unitName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter (Group Master Parity)
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((i) {
          final first = i.itName.trim().isNotEmpty ? i.itName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((i) {
          final nameStr = i.itName.trim();
          final codeStr = i.iCode.trim();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    return list;
  }

  void _handleSelect(FinishedGoodItem item) {
    Navigator.of(context).pop(item);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final filtered = _filteredItems;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (filtered.isNotEmpty && _selectedIndex < filtered.length - 1) {
        setState(() => _selectedIndex++);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (filtered.isNotEmpty && _selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (filtered.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < filtered.length) {
        _handleSelect(filtered[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (_tableScrollCtrl.hasClients) {
      final double targetOffset = math.max(0.0, (_selectedIndex * 43.0) - 80.0);
      _tableScrollCtrl.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = widget.mode == BomMode.job ? const Color(0xFF2563EB) : const Color(0xFF059669);
    final modeBg = widget.mode == BomMode.job ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final modeBorder = widget.mode == BomMode.job ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);
    final filtered = _filteredItems;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          width: 1040,
          height: 640,
          constraints: const BoxConstraints(maxWidth: 1100),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // 1. TOP HEADER BAR (EXACT GROUP MASTER PARITY)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.manage_search_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Select Finished Good Item',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),

                      // Mode Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: modeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: modeBorder),
                        ),
                        child: Text(
                          '${widget.mode.label} (SKU: ${widget.mode.skuCross})',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: modeColor),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Green Count Pill Badge (Group Master image style)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          '${filtered.length} / ${_items.length} Items',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ),

                      const Spacer(),

                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 2. SEARCH BAR ROW (EXACT GROUP MASTER PARITY)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocusNode,
                            autofocus: true,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim().toLowerCase();
                                _selectedIndex = 0;
                              });
                            },
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Type to live filter by Material Code, Description, UOM...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF10B981)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _selectedIndex = 0;
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0xFF10B981)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0xFF10B981)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Color(0xFF059669), width: 2.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Keyboard Navigation Helper Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 13, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text(
                              '↑/↓ to navigate | Enter to select',
                              style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. ALPHABETICAL A TO Z FILTRATION BAR (EXACT GROUP MASTER PARITY)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _alphabets.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(width: 4),
                      itemBuilder: (ctx, idx) {
                        final alpha = _alphabets[idx];
                        final isSelected = _selectedAlphabet == alpha;

                        return InkWell(
                          onTap: () => setState(() {
                            _selectedAlphabet = alpha;
                            _selectedIndex = 0;
                          }),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.symmetric(
                              horizontal: alpha == 'ALL' ? 12 : 9,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF10B981) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              alpha,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 4. DATA TABLE (GROUP MASTER PARITY)
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Color(0xFF059669)),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No Finished Good records match your filter',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Table Header Row with Vector Icons & Natural Color Accents
                                Container(
                                  height: 38,
                                  color: const Color(0xFFF8FAFC),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: const Row(
                                    children: [
                                      SizedBox(
                                        width: 230,
                                        child: Row(
                                          children: [
                                            Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF2563EB)),
                                            SizedBox(width: 5),
                                            Text('MATERIAL CODE', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Icon(Icons.category_rounded, size: 13, color: Color(0xFF059669)),
                                            SizedBox(width: 5),
                                            Text('DESCRIPTION', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 80,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.straighten_rounded, size: 13, color: Color(0xFFD97706)),
                                            SizedBox(width: 4),
                                            Text('UOM', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 90,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.verified_rounded, size: 13, color: Color(0xFF0D9488)),
                                            SizedBox(width: 4),
                                            Text('STATUS', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 95,
                                        child: Center(
                                          child: Text('ACTIONS', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                // ListView Rows
                                Expanded(
                                  child: ListView.separated(
                                    controller: _tableScrollCtrl,
                                    itemCount: filtered.length,
                                    separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (ctx, idx) {
                                      final item = filtered[idx];
                                      final isSelected = idx == _selectedIndex;
                                      final isBlocked = item.status == 'BLOCKED';

                                      return _FinishedGoodRow(
                                        item: item,
                                        idx: idx,
                                        isSelected: isSelected,
                                        isBlocked: isBlocked,
                                        onSelect: () => _handleSelect(item),
                                        onHover: () => setState(() => _selectedIndex = idx),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FinishedGoodRow extends StatefulWidget {
  final FinishedGoodItem item;
  final int idx;
  final bool isSelected;
  final bool isBlocked;
  final VoidCallback onSelect;
  final VoidCallback onHover;

  const _FinishedGoodRow({
    required this.item,
    required this.idx,
    required this.isSelected,
    required this.isBlocked,
    required this.onSelect,
    required this.onHover,
  });

  @override
  State<_FinishedGoodRow> createState() => _FinishedGoodRowState();
}

class _FinishedGoodRowState extends State<_FinishedGoodRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isBlocked = widget.isBlocked;
    final isHovered = _isHovered;

    Color rowBgColor;
    Color? rowBorderColor;
    List<BoxShadow> rowShadows = [];

    if (isSelected) {
      rowBgColor = const Color(0xFFF1F5F9);
      rowBorderColor = const Color(0xFFCBD5E1);
      rowShadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (isHovered) {
      rowBgColor = const Color(0xFFF8FAFC);
      rowBorderColor = const Color(0xFFE2E8F0);
    } else {
      rowBgColor = widget.idx % 2 == 0 ? const Color(0xFFFAFAFA) : Colors.white;
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        widget.onHover();
      },
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isBlocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: InkWell(
        onTap: isBlocked ? null : widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: rowBgColor,
            border: rowBorderColor != null ? Border.all(color: rowBorderColor, width: 1.0) : null,
            boxShadow: rowShadows,
          ),
          child: Row(
            children: [
              // Material Code in Emerald/Blue Capsule Badge (Group Master parity)
              SizedBox(
                width: 230,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFA7F3D0),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      item.iCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // Description
              Expanded(
                child: Text(
                  item.itName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: (isHovered || isSelected) ? FontWeight.w800 : FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // UOM Badge
              SizedBox(
                width: 80,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.unitName,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Status Badge
              SizedBox(
                width: 90,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isBlocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isBlocked ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isBlocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),

              // Select Action Button (Group Master style + Test compatibility)
              SizedBox(
                width: 95,
                child: Center(
                  child: ElevatedButton(
                    onPressed: isBlocked ? null : widget.onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(60, 26),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Select', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
