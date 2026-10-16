import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';
import '../sales_order_service.dart';
import 'so_export_modal_dialog.dart';

class CustomerLookupDialog extends StatefulWidget {
  final SalesOrderService service;
  final ValueChanged<CustomerLookup>? onSelect;

  const CustomerLookupDialog({
    super.key,
    required this.service,
    this.onSelect,
  });

  @override
  State<CustomerLookupDialog> createState() => _CustomerLookupDialogState();
}

class _CustomerLookupDialogState extends State<CustomerLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();

  List<CustomerLookup> _allCustomers = [];
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
    _fetchCustomers();
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

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await widget.service.fetchCustomersLookup(
        search: '',
        page: 1,
        pageSize: 500,
      );
      if (mounted) {
        setState(() {
          _allCustomers = res.items;
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

  List<CustomerLookup> get _filteredAndSorted {
    List<CustomerLookup> list = List.from(_allCustomers);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((c) {
        return c.pCode.toString().contains(_searchQuery) ||
            c.pName.toLowerCase().contains(_searchQuery) ||
            c.gstIn.toLowerCase().contains(_searchQuery) ||
            c.state.toLowerCase().contains(_searchQuery) ||
            c.mobile.toLowerCase().contains(_searchQuery) ||
            c.address.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((c) {
          final first = c.pName.trim().isNotEmpty ? c.pName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((c) {
          final nameStr = c.pName.trim();
          final codeStr = c.pCode.toString();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    // Sort alphabetically by Customer Name
    list.sort((a, b) => a.pName.toLowerCase().compareTo(b.pName.toLowerCase()));
    return list;
  }

  void _selectCustomer(CustomerLookup item) {
    if (widget.onSelect != null) {
      widget.onSelect!(item);
    }
    Navigator.of(context).pop(item);
  }

  void _openExportModal(List<CustomerLookup> list) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CustomerExportModalDialog(customers: list),
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
        _selectCustomer(list[_focusedIndex]);
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
                        child: const Icon(Icons.manage_search_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Customer / Debtor Record',
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
                          '${list.length} / ${_allCustomers.length} Customers',
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
                              hintText: 'Type to live filter by Customer Name, Code, GSTIN, State, Mobile...',
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

                // 4. RESPONSIVE CUSTOMER DATA TABLE
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
                                    onPressed: _fetchCustomers,
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
                                        'No Customer / Debtor records match your filter',
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
                                                    width: 90,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.sell_outlined, size: 13, color: Color(0xFF2563EB)),
                                                        SizedBox(width: 4),
                                                        Text('CODE', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.business_rounded, size: 13, color: Color(0xFF059669)),
                                                        SizedBox(width: 4),
                                                        Text('CUSTOMER / DEBTOR NAME', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 140,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFFD97706)),
                                                        SizedBox(width: 4),
                                                        Text('GSTIN', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.map_rounded, size: 13, color: Color(0xFF0891B2)),
                                                        SizedBox(width: 4),
                                                        Text('STATE', style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 120,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.phone_iphone_rounded, size: 13, color: Color(0xFF6366F1)),
                                                        SizedBox(width: 4),
                                                        Text('MOBILE', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF7C3AED)),
                                                        SizedBox(width: 4),
                                                        Text('REGISTERED ADDRESS', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 10.5)),
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
                                                      onTap: () => _selectCustomer(item),
                                                      child: Container(
                                                        height: 42,
                                                        color: rowBg,
                                                        padding: const EdgeInsets.symmetric(horizontal: 14),
                                                        child: Row(
                                                          children: [
                                                            // Code Pill Badge
                                                            SizedBox(
                                                              width: 90,
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
                                                                    '#${item.pCode}',
                                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),

                                                            // Customer Name
                                                            Expanded(
                                                              flex: 3,
                                                              child: Text(
                                                                item.pName,
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                              ),
                                                            ),

                                                            // GSTIN
                                                            SizedBox(
                                                              width: 140,
                                                              child: Text(
                                                                item.gstIn.isNotEmpty ? item.gstIn : '—',
                                                                style: TextStyle(
                                                                  fontSize: 11.5,
                                                                  fontFamily: item.gstIn.isNotEmpty ? 'monospace' : null,
                                                                  color: item.gstIn.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                                                                  fontWeight: item.gstIn.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                                                ),
                                                              ),
                                                            ),

                                                            // State
                                                            SizedBox(
                                                              width: 90,
                                                              child: Text(
                                                                item.state.isNotEmpty ? item.state : '—',
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                                              ),
                                                            ),

                                                            // Mobile
                                                            SizedBox(
                                                              width: 120,
                                                              child: Text(
                                                                item.mobile.isNotEmpty ? item.mobile : '—',
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                                              ),
                                                            ),

                                                            // Registered Address
                                                            Expanded(
                                                              flex: 3,
                                                              child: Text(
                                                                item.address.isNotEmpty ? item.address : '—',
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                              ),
                                                            ),

                                                            // Select Action Button
                                                            SizedBox(
                                                              width: 90,
                                                              child: Center(
                                                                child: ElevatedButton(
                                                                  onPressed: () => _selectCustomer(item),
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
