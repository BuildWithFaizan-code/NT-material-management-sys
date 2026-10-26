import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../indent_models.dart';
import '../indent_service.dart';

/// 100% Parity with Group Master Show Record Table UI
class IndentItemLookupDialog extends StatefulWidget {
  final IndentService service;

  const IndentItemLookupDialog({super.key, required this.service});

  @override
  State<IndentItemLookupDialog> createState() => _IndentItemLookupDialogState();
}

class _IndentItemLookupDialogState extends State<IndentItemLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  String _error = '';

  List<IndentItemLookup> _items = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 150;
  String _selectedAlphabet = 'ALL';
  int _selectedIndex = -1;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _keyboardFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 1;
        _selectedIndex = -1;
      });
      _fetchItems();
    });
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await widget.service.searchItems(
        search: _searchCtrl.text.trim(),
        page: _currentPage,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _items = res.items;
          _totalCount = res.totalCount;
          _isLoading = false;
          if (_items.isNotEmpty) {
            _selectedIndex = 0;
          }
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

  List<IndentItemLookup> get _filteredByAlphabet {
    if (_selectedAlphabet == 'ALL') return _items;
    return _items.where((i) {
      final name = i.itName.trim().toUpperCase();
      if (_selectedAlphabet == '#') {
        return name.isNotEmpty && !RegExp(r'^[A-Z]').hasMatch(name);
      }
      return name.startsWith(_selectedAlphabet);
    }).toList();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final list = _filteredByAlphabet;
    if (list.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, list.length - 1);
        _scrollToIndex(_selectedIndex);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, list.length - 1);
        _scrollToIndex(_selectedIndex);
      });
    } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_selectedIndex >= 0 && _selectedIndex < list.length) {
        Navigator.of(context).pop(list[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToIndex(int index) {
    if (!_tableScrollCtrl.hasClients) return;
    final target = (index * 40.0) - 120.0;
    _tableScrollCtrl.animateTo(
      target.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredByAlphabet;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Container(
          width: 1280,
          height: 680,
          constraints: const BoxConstraints(maxWidth: 1350),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
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
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
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
                      const SizedBox(width: 12),
                      const Text(
                        'Select Item Catalog Record',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 12),

                      // Green Count Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Text(
                          '${list.length} / $_totalCount Items',
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
                              '↑/↓ navigate | Enter to select | Esc to close',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // 2. SEARCH & ALPHABET BAR (EXACT GROUP MASTER PARITY)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Column(
                    children: [
                      // Alphabet Quick Selector Row
                      SizedBox(
                        height: 28,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _alphabets.length,
                          separatorBuilder: (ctx, i) => const SizedBox(width: 4),
                          itemBuilder: (ctx, i) {
                            final alpha = _alphabets[i];
                            final isSelected = _selectedAlphabet == alpha;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedAlphabet = alpha;
                                  _selectedIndex = 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  alpha,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Search Input Box
                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: _onSearchChanged,
                                style: const TextStyle(fontSize: 12.5),
                                decoration: const InputDecoration(
                                  hintText: 'Search by item code, description, or HSN...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_searchCtrl.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                                child: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. TABLE COLUMN HEADERS
                Container(
                  height: 36,
                  color: const Color(0xFF0C3B2E),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Row(
                    children: [
                      SizedBox(width: 50, child: Text('#', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 140, child: Text('ITEM CODE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      Expanded(flex: 4, child: Text('ITEM NAME / DESCRIPTION', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 80, child: Text('UOM', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 110, child: Text('CURRENT STOCK', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 100, child: Text('MIN QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 100, child: Text('MAX QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 100, child: Text('REORDER ON', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                      SizedBox(width: 80, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

                // 4. DATA ROWS LIST (EXACT 38PX COMPACT ROWS MATCHING GROUP MASTER)
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0C3B2E)),
                          ),
                        )
                      : _error.isNotEmpty
                          ? Center(
                              child: Text('Error: $_error', style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                            )
                          : list.isEmpty
                              ? const Center(
                                  child: Text('No item catalog records found.',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                )
                              : ListView.builder(
                                  controller: _tableScrollCtrl,
                                  itemCount: list.length,
                                  itemBuilder: (ctx, idx) {
                                    final item = list[idx];
                                    final isSelected = _selectedIndex == idx;
                                    final isEven = idx.isEven;

                                    return InkWell(
                                      onTap: () {
                                        setState(() => _selectedIndex = idx);
                                        Navigator.of(context).pop(item);
                                      },
                                      onHover: (hovered) {
                                        if (hovered && _selectedIndex != idx) {
                                          setState(() => _selectedIndex = idx);
                                        }
                                      },
                                      child: Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFFEAF5EE)
                                              : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 50,
                                              child: Text('${idx + 1}',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            ),
                                            SizedBox(
                                              width: 140,
                                              child: Text(
                                                item.iCode,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0C3B2E),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                item.itName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text(item.unitName.isEmpty ? '-' : item.unitName,
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                                            ),
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                item.stk.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: item.stk <= item.minQty ? Colors.redAccent : const Color(0xFF0F766E),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                item.minQty.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                item.maxQty.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 100,
                                              child: Text(
                                                item.orderOn.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    'Select',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),

                // 5. FOOTER STATUS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      const Text(
                        'Double click or press Enter on any row to select item into indent detail',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
