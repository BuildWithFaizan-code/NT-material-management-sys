import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';
import '../sales_order_service.dart';
import 'so_export_modal_dialog.dart';

class ItemLookupDialog extends StatefulWidget {
  final SalesOrderService service;
  final ValueChanged<SalesOrderItemLookup>? onSelect;

  const ItemLookupDialog({
    super.key,
    required this.service,
    this.onSelect,
  });

  @override
  State<ItemLookupDialog> createState() => _ItemLookupDialogState();
}

class _ItemLookupDialogState extends State<ItemLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();

  List<SalesOrderItemLookup> _allItems = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  int _focusedIndex = 0;
  int? _hoveredIndex;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
        _focusedIndex = 0;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _keyboardFocusNode.dispose();
    _tableScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await widget.service.fetchItemsLookup(
        search: '',
        page: 1,
        pageSize: 500,
      );
      if (mounted) {
        setState(() {
          _allItems = res.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<SalesOrderItemLookup> get _filteredAndSorted {
    List<SalesOrderItemLookup> list = List.from(_allItems);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) {
        return i.iCode.toLowerCase().contains(_searchQuery) ||
            i.iName.toLowerCase().contains(_searchQuery) ||
            i.unitName.toLowerCase().contains(_searchQuery) ||
            i.hsnCode.toLowerCase().contains(_searchQuery) ||
            i.groupName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((i) {
          final first = i.iName.trim().isNotEmpty ? i.iName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((i) {
          final nameStr = i.iName.trim();
          final codeStr = i.iCode.trim();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    // Sort alphabetically by Item Name
    list.sort((a, b) => a.iName.toLowerCase().compareTo(b.iName.toLowerCase()));
    return list;
  }

  void _selectItem(SalesOrderItemLookup item) {
    if (widget.onSelect != null) {
      widget.onSelect!(item);
    }
    Navigator.of(context).pop(item);
  }

  void _openExportModal(List<SalesOrderItemLookup> list) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => ItemExportModalDialog(items: list),
    );
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final list = _filteredAndSorted;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (list.isNotEmpty && _focusedIndex < list.length - 1) {
        setState(() {
          _focusedIndex++;
        });
        _scrollToIndex(_focusedIndex);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() {
          _focusedIndex--;
        });
        _scrollToIndex(_focusedIndex);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (list.isNotEmpty && _focusedIndex >= 0 && _focusedIndex < list.length) {
        _selectItem(list[_focusedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToIndex(int index) {
    if (!_tableScrollCtrl.hasClients) return;
    const double rowHeight = 44.0;
    final double targetOffset = (index * rowHeight) - 80.0;
    _tableScrollCtrl.animateTo(
      math.max(0.0, targetOffset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.88).clamp(850.0, 1350.0);
    final dialogHeight = (size.height * 0.82).clamp(520.0, 680.0);
    final list = _filteredAndSorted;

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKey,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
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
                // 1. TOP HEADER BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
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
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Item Catalog Record',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 10),

                      // Green Count Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          '${list.length} / ${_allItems.length} Items',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ),

                      const Spacer(),

                      // Keyboard Navigation Helper Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 4),
                            Text(
                              '↑/↓ to navigate | Enter to select | Esc to close',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 18,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // 2. SEARCH BAR & EXPORT ORBIT BUTTON ROW
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Type to live filter by Item Code, Description, UOM, HSN, Group...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF10B981)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () => _searchCtrl.clear(),
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

                      const SizedBox(width: 14),

                      // Standalone Export Orbit Button
                      SoAnimatedExportButton(onPressed: () => _openExportModal(list)),
                    ],
                  ),
                ),

                // 3. ALPHABETICAL A TO Z FILTRATION BAR
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
                          onTap: () => setState(() => _selectedAlphabet = alpha),
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

                // 4. RESPONSIVE ITEM DATA TABLE
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primaryColor),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                                  const SizedBox(height: 10),
                                  Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _fetchItems,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Try Again'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : list.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No Item records match your filter',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    const double minTableWidth = 1100.0;
                                    final double tableWidth = math.max(constraints.maxWidth, minTableWidth);

                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: SizedBox(
                                        width: tableWidth,
                                        child: Column(
                                          children: [
                                            // Table Header Row with Vector Icons & Natural Color Accents
                                            Container(
                                              height: 38,
                                              color: const Color(0xFFF8FAFC),
                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                              child: const Row(
                                                children: [
                                                  SizedBox(
                                                    width: 110,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.sell_outlined, size: 13, color: Color(0xFF2563EB)),
                                                        SizedBox(width: 4),
                                                        Text('ITEM CODE', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.category_rounded, size: 13, color: Color(0xFF059669)),
                                                        SizedBox(width: 4),
                                                        Text('ITEM DESCRIPTION', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF0891B2)),
                                                        SizedBox(width: 4),
                                                        Text('UOM', style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 100,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFFD97706)),
                                                        SizedBox(width: 4),
                                                        Text('HSN', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.folder_open_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                                        SizedBox(width: 4),
                                                        Text('GROUP', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.inventory_rounded, size: 13, color: Color(0xFFEA580C)),
                                                        SizedBox(width: 4),
                                                        Text('STOCK', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.currency_rupee_rounded, size: 13, color: Color(0xFF10B981)),
                                                        SizedBox(width: 4),
                                                        Text('RATE', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Center(
                                                      child: Text('ACTION', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                            // ListView Rows with Alternating Background & Hover Effects
                                            Expanded(
                                              child: ListView.separated(
                                                controller: _tableScrollCtrl,
                                                itemCount: list.length,
                                                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                                itemBuilder: (ctx, idx) {
                                                  final item = list[idx];
                                                  final isHovered = _hoveredIndex == idx;
                                                  final isFocused = _focusedIndex == idx;
                                                  final isZebra = idx % 2 == 1;

                                                  Color rowBg = isZebra ? const Color(0xFFF8FAFC) : Colors.white;
                                                  if (isFocused) {
                                                    rowBg = const Color(0xFFEFF6FF);
                                                  } else if (isHovered) {
                                                    rowBg = const Color(0xFFF1F5F9);
                                                  }

                                                  return MouseRegion(
                                                    onEnter: (_) => setState(() => _hoveredIndex = idx),
                                                    onExit: (_) => setState(() => _hoveredIndex = null),
                                                    child: InkWell(
                                                      onTap: () => _selectItem(item),
                                                      child: Container(
                                                        height: 42,
                                                        color: rowBg,
                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                        child: Row(
                                                          children: [
                                                            // Item Code Pill Badge
                                                            SizedBox(
                                                              width: 110,
                                                              child: Align(
                                                                alignment: Alignment.centerLeft,
                                                                child: Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFEEF2FF),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                    border: Border.all(color: const Color(0xFFC7D2FE)),
                                                                  ),
                                                                  child: Text(
                                                                    item.iCode,
                                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),

                                                            // Item Name / Description
                                                            Expanded(
                                                              flex: 3,
                                                              child: Text(
                                                                item.iName,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                              ),
                                                            ),

                                                            // UOM
                                                            SizedBox(
                                                              width: 80,
                                                              child: Text(
                                                                item.unitName.isNotEmpty ? item.unitName : '—',
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                                              ),
                                                            ),

                                                            // HSN Code
                                                            SizedBox(
                                                              width: 100,
                                                              child: Text(
                                                                item.hsnCode.isNotEmpty ? item.hsnCode : '—',
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
                                                              ),
                                                            ),

                                                            // Group
                                                            Expanded(
                                                              flex: 2,
                                                              child: Text(
                                                                item.groupName.isNotEmpty ? item.groupName : '—',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                              ),
                                                            ),

                                                            // Stock Bal
                                                            SizedBox(
                                                              width: 90,
                                                              child: Text(
                                                                item.balQty.toStringAsFixed(1),
                                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFFEA580C)),
                                                              ),
                                                            ),

                                                            // Rate
                                                            SizedBox(
                                                              width: 90,
                                                              child: Text(
                                                                '₹ ${item.rate.toStringAsFixed(2)}',
                                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                              ),
                                                            ),

                                                            // Select Action Button
                                                            SizedBox(
                                                              width: 90,
                                                              child: Center(
                                                                child: ElevatedButton(
                                                                  onPressed: () => _selectItem(item),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: const Color(0xFF10B981),
                                                                    foregroundColor: Colors.white,
                                                                    elevation: 0,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                    minimumSize: const Size(64, 28),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                                                  ),
                                                                  child: const Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
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
