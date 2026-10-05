import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';
import '../bom_service.dart';

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
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  List<FinishedGoodItem> _items = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _bomService = widget.bomService ?? BomService();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery!;
    }
    _loadItems();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  void _handleSelect(FinishedGoodItem item) {
    Navigator.of(context).pop(item);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_items.isNotEmpty && _selectedIndex < _items.length - 1) {
        setState(() => _selectedIndex++);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_items.isNotEmpty && _selectedIndex > 0) {
        setState(() => _selectedIndex--);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_items.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _items.length) {
        _handleSelect(_items[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = widget.mode == BomMode.job ? const Color(0xFF2563EB) : const Color(0xFF059669);
    final modeBg = widget.mode == BomMode.job ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final modeBorder = widget.mode == BomMode.job ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 780,
              height: 560,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // DIALOG HEADER
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: modeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: modeBorder),
                          ),
                          child: Icon(Icons.inventory_2_rounded, size: 20, color: modeColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Select Finished Good Item',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: modeBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: modeBorder),
                                    ),
                                    child: Text(
                                      '${widget.mode.label} (SKU Cross: ${widget.mode.skuCross})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: modeColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Only active finished goods matching production mode are displayed',
                                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          splashRadius: 18,
                          tooltip: 'Close (Esc)',
                        ),
                      ],
                    ),
                  ),

                  // SEARCH INPUT BAR
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        onChanged: (_) => _loadItems(),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _loadItems();
                                  },
                                )
                              : null,
                          hintText: 'Search by Material Code or Description...',
                          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: modeColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // TABLE HEADER
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: Text(
                            'MATERIAL CODE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'DESCRIPTION',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'UOM',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'STATUS',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            'ACTION',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  // LIST OF ITEMS
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: modeColor))
                        : _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 38, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No finished goods found for "${_searchCtrl.text}"',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                itemCount: _items.length,
                                itemBuilder: (context, index) {
                                  final item = _items[index];
                                  final isSelected = index == _selectedIndex;
                                  final isBlocked = item.status == 'BLOCKED';

                                  return MouseRegion(
                                    cursor: isBlocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _selectedIndex = index),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? modeBg : (index.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? modeBorder : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: isBlocked ? null : () => _handleSelect(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 220,
                                                child: Text(
                                                  item.iCode,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected ? modeColor : const Color(0xFF0F172A),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  item.itName,
                                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 70,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                                    ),
                                                    child: Text(
                                                      item.unitName,
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 80,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isBlocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: isBlocked ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0)),
                                                    ),
                                                    child: Text(
                                                      item.status,
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: isBlocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                width: 70,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isSelected ? modeColor : const Color(0xFF0F172A),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'Select',
                                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  // FOOTER TIP
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_outlined, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Use ↑ ↓ arrow keys to navigate, Enter to select, Esc to dismiss',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_items.length} item(s) found',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
