import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../stock_transfer_models.dart';
import '../stock_transfer_service.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class PendingRequisitionLookupDialog extends StatefulWidget {
  final StockTransferService service;

  const PendingRequisitionLookupDialog({super.key, required this.service});

  @override
  State<PendingRequisitionLookupDialog> createState() => _PendingRequisitionLookupDialogState();
}

class _PendingRequisitionLookupDialogState extends State<PendingRequisitionLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  Timer? _debounce;
  bool _isLoading = false;
  String _error = '';
  List<PendingRequisitionItem> _items = [];
  int _selectedIndex = -1;

  // Horizontal Scroll Navigation State
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
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

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final res = await widget.service.fetchPendingRequisitions(search: _searchCtrl.text.trim());
      if (mounted) {
        setState(() {
          _items = res;
          _isLoading = false;
          _selectedIndex = res.isNotEmpty ? 0 : -1;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadItems();
    });
  }

  void _onSelect(PendingRequisitionItem item) {
    Navigator.of(context).pop(item);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_items.isNotEmpty && _selectedIndex < _items.length - 1) {
        setState(() => _selectedIndex++);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_items.isNotEmpty && _selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
        _onSelect(_items[_selectedIndex]);
      }
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth > 1150 ? 1040.0 : (screenWidth * 0.94);
    final dialogHeight = screenHeight > 750 ? 660.0 : (screenHeight * 0.90);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Pending Requisition',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Browse unfulfilled department requisition lines to transfer stock against.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close (Esc)',
                    ),
                  ],
                ),
              ),

              // Filter toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
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
                          style: const TextStyle(fontSize: 12.5),
                          decoration: const InputDecoration(
                            hintText: 'Search by Requisition Code, Item Code or Item Name...',
                            prefixIcon: Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadItems,
                      tooltip: 'Refresh Requisitions',
                    ),
                  ],
                ),
              ),

              // Table Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error.isNotEmpty
                        ? Center(
                            child: Text(
                              _error,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          )
                        : _items.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending requisitions found matching criteria.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                ),
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
                                        columnSpacing: 18,
                                        horizontalMargin: 16,
                                        headingRowHeight: 38,
                                        dataRowMinHeight: 38,
                                        dataRowMaxHeight: 38,
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                        columns: const [
                                          DataColumn(label: Text('Req. Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(label: Text('Req. Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(label: Text('Item Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(numeric: true, label: Text('Req Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(numeric: true, label: Text('Bal Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(label: Text('UOM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(numeric: true, label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                        ],
                                        rows: _items.asMap().entries.map((entry) {
                                          final idx = entry.key;
                                          final item = entry.value;
                                          final isSelected = idx == _selectedIndex;

                                          return DataRow(
                                            selected: isSelected,
                                            onSelectChanged: (_) => _onSelect(item),
                                            cells: [
                                              DataCell(Text(item.reqCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                                              DataCell(Text(_formatDate(item.reqDate), style: const TextStyle(fontSize: 11.5))),
                                              DataCell(Text(item.itemCode, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5))),
                                              DataCell(
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 220),
                                                  child: Text(
                                                    item.itemName,
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: const TextStyle(fontSize: 11.5),
                                                  ),
                                                ),
                                              ),
                                              DataCell(Text(item.reqQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5))),
                                              DataCell(
                                                Text(
                                                  item.balQty.toStringAsFixed(2),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F766E), fontSize: 11.5),
                                                ),
                                              ),
                                              DataCell(Text(item.unitName, style: const TextStyle(fontSize: 11.5))),
                                              DataCell(Text(item.rate.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5))),
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
                                        }).toList(),
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

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                      'Total Records: ${_items.length}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel (Esc)', style: TextStyle(fontSize: 12)),
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
