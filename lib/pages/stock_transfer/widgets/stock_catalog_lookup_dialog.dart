import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../stock_transfer_models.dart';
import '../stock_transfer_service.dart';

/// 100% Parity with Group Master Show Record Table UI
class StockCatalogLookupDialog extends StatefulWidget {
  final StockTransferService service;
  final DateTime date;
  final int sourceDept;
  final int sourceStore;
  final int sourceDiv;
  final StockTransferLookups? lookups;

  const StockCatalogLookupDialog({
    super.key,
    required this.service,
    required this.date,
    required this.sourceDept,
    required this.sourceStore,
    required this.sourceDiv,
    this.lookups,
  });

  @override
  State<StockCatalogLookupDialog> createState() => _StockCatalogLookupDialogState();
}

class _StockCatalogLookupDialogState extends State<StockCatalogLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  String _error = '';

  late int _selectedStore;
  late int _selectedDiv;

  List<StockCatalogItem> _items = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 50;
  int _selectedIndex = -1;

  // Horizontal Scroll Navigation State
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
    _selectedStore = widget.sourceStore;
    if (_selectedStore == 0 && widget.lookups != null && widget.lookups!.stores.isNotEmpty) {
      _selectedStore = widget.lookups!.stores.firstWhere((s) => s.id == 1, orElse: () => widget.lookups!.stores.first).id;
    }
    _selectedDiv = widget.sourceDiv;
    if (_selectedDiv == 0 && widget.lookups != null && widget.lookups!.divisions.isNotEmpty) {
      _selectedDiv = widget.lookups!.divisions.firstWhere((d) => d.id == 1, orElse: () => widget.lookups!.divisions.first).id;
    }
    _loadItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _verticalScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final maxScroll = _horizontalScrollCtrl.position.maxScrollExtent;
    final offset = _horizontalScrollCtrl.offset;
    final canLeft = offset > 10;
    final canRight = offset < maxScroll - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset - 300.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 300.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFloatingArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 1;
        _selectedIndex = -1;
      });
      _loadItems();
    });
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await widget.service.fetchStockCatalog(
        date: widget.date,
        sourceDept: widget.sourceDept,
        sourceStore: _selectedStore,
        sourceDiv: _selectedDiv,
        search: _searchCtrl.text.trim(),
        page: _currentPage,
        pageSize: _pageSize,
      );

      setState(() {
        _items = res.items;
        _totalCount = res.totalCount;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _onSelect(StockCatalogItem item) {
    Navigator.of(context).pop(item);
  }

  void _handleKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_selectedIndex < _items.length - 1) {
        setState(() => _selectedIndex++);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_selectedIndex > 0) {
        setState(() => _selectedIndex--);
        _scrollToSelected();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
        _onSelect(_items[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToSelected() {
    if (_selectedIndex < 0) return;
    const rowHeight = 36.0;
    final targetOffset = _selectedIndex * rowHeight;
    if (_verticalScrollCtrl.hasClients) {
      if (targetOffset < _verticalScrollCtrl.offset ||
          targetOffset > _verticalScrollCtrl.offset + 300) {
        _verticalScrollCtrl.animateTo(
          targetOffset.clamp(0.0, _verticalScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = (_totalCount / _pageSize).ceil().clamp(1, 9999);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth > 1200 ? 1120.0 : (screenWidth * 0.95);
    final dialogHeight = screenHeight > 750 ? 660.0 : (screenHeight * 0.90);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyDown,
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Stock Item',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            'Search available items from current store and division stock register',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Search Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    if (widget.lookups != null && widget.lookups!.stores.isNotEmpty) ...[
                      // Store selector
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: widget.lookups!.stores.any((s) => s.id == _selectedStore)
                                ? _selectedStore
                                : widget.lookups!.stores.first.id,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                            items: widget.lookups!.stores.map((s) {
                              return DropdownMenuItem<int>(
                                value: s.id,
                                child: Text('Store: ${s.name}', style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedStore) {
                                setState(() {
                                  _selectedStore = val;
                                  _currentPage = 1;
                                  _selectedIndex = -1;
                                });
                                _loadItems();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (widget.lookups != null && widget.lookups!.divisions.isNotEmpty) ...[
                      // Division selector
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: widget.lookups!.divisions.any((d) => d.id == _selectedDiv)
                                ? _selectedDiv
                                : widget.lookups!.divisions.first.id,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                            items: widget.lookups!.divisions.map((d) {
                              return DropdownMenuItem<int>(
                                value: d.id,
                                child: Text('Div: ${d.name}', style: const TextStyle(fontSize: 12)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null && val != _selectedDiv) {
                                setState(() {
                                  _selectedDiv = val;
                                  _currentPage = 1;
                                  _selectedIndex = -1;
                                });
                                _loadItems();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Search by Item Code or Item Name...',
                            hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Found: $_totalCount items',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
                            tooltip: 'Scroll Table Left',
                            onPressed: _scrollLeft,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                          Container(height: 16, width: 1, color: const Color(0xFFCBD5E1)),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF475569)),
                            tooltip: 'Scroll Table Right',
                            onPressed: _scrollRight,
                            visualDensity: VisualDensity.compact,
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Table Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                    : _error.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 36),
                                const SizedBox(height: 8),
                                Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _loadItems,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _items.isEmpty
                            ? const Center(
                                child: Text('No stock items available in the selected store & division.',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                              )
                            : Stack(
                                children: [
                                  Scrollbar(
                                    controller: _horizontalScrollCtrl,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollCtrl,
                                  scrollDirection: Axis.horizontal,
                                  child: Scrollbar(
                                    controller: _verticalScrollCtrl,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _verticalScrollCtrl,
                                      scrollDirection: Axis.vertical,
                                      child: DataTable(
                                    columnSpacing: 16,
                                    horizontalMargin: 16,
                                    headingRowHeight: 38,
                                    dataRowMinHeight: 34,
                                    dataRowMaxHeight: 38,
                                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                    columns: const [
                                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Merge No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Shade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Maker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('UOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Pcs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Available Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    ],
                                    rows: List.generate(_items.length, (index) {
                                      final item = _items[index];
                                      final isSelected = index == _selectedIndex;

                                      return DataRow(
                                        color: WidgetStateProperty.resolveWith<Color>((states) {
                                          if (isSelected) return const Color(0xFFE2E8F0);
                                          return index.isEven ? Colors.white : const Color(0xFFF8FAFC);
                                        }),
                                        cells: [
                                          DataCell(
                                            Text(item.itemCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                            onTap: () => _onSelect(item),
                                          ),
                                          DataCell(
                                            Text(item.itemName, style: const TextStyle(fontSize: 12)),
                                            onTap: () => _onSelect(item),
                                          ),
                                          DataCell(Text(item.mrgNo, style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.grade, style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.shade, style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.maker, style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.unitName, style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.pcs.toStringAsFixed(0), style: const TextStyle(fontSize: 11.5))),
                                          DataCell(Text(item.rate.toStringAsFixed(3), style: const TextStyle(fontSize: 11.5))),
                                          DataCell(
                                            Text(
                                              item.stock.toStringAsFixed(2),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: item.stock > 0 ? const Color(0xFF0F766E) : Colors.red,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            ElevatedButton(
                                              onPressed: () => _onSelect(item),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.primaryColor,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                minimumSize: const Size(60, 26),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                              ),
                                              child: const Text('Select', style: TextStyle(fontSize: 11)),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_canScrollLeft)
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildFloatingArrowButton(
                                  icon: Icons.chevron_left_rounded,
                                  onTap: _scrollLeft,
                                  tooltip: 'Scroll Left',
                                ),
                              ),
                            ),
                          if (_canScrollRight)
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildFloatingArrowButton(
                                  icon: Icons.chevron_right_rounded,
                                  onTap: _scrollRight,
                                  tooltip: 'Scroll Right',
                                ),
                              ),
                            ),
                        ],
                      ),
              ),

              // Pagination Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(15),
                    bottomRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Page $_currentPage of $totalPages ($_totalCount items)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: _currentPage > 1
                              ? () {
                                  setState(() => _currentPage--);
                                  _loadItems();
                                }
                              : null,
                          splashRadius: 18,
                        ),
                        Text('$_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: _currentPage < totalPages
                              ? () {
                                  setState(() => _currentPage++);
                                  _loadItems();
                                }
                              : null,
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
