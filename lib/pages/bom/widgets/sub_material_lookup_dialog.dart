import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';
import '../bom_service.dart';

/// Modal dialog allowing users to search and pick Sub-Materials / Components
/// to populate the Line Items Grid (matches SQL Trace Query 6).
class SubMaterialLookupDialog extends StatefulWidget {
  final String parentItemCode;
  final String? initialQuery;
  final BomService? bomService;

  const SubMaterialLookupDialog({
    super.key,
    required this.parentItemCode,
    this.initialQuery,
    this.bomService,
  });

  @override
  State<SubMaterialLookupDialog> createState() => _SubMaterialLookupDialogState();
}

class _SubMaterialLookupDialogState extends State<SubMaterialLookupDialog> {
  late final BomService _bomService;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  List<ComponentLookupItem> _items = [];
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
    final results = await _bomService.fetchComponents(
      parentItemCode: widget.parentItemCode,
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

  void _handleSelect(ComponentLookupItem item) {
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
    const primaryColor = Color(0xFF0C3B2E);
    const primaryBg = Color(0xFFE6F4EA);
    const primaryBorder = Color(0xFFA7F3D0);

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
              width: 800,
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
                            color: primaryBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: primaryBorder),
                          ),
                          child: const Icon(Icons.category_rounded, size: 20, color: primaryColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  const Text(
                                    'Select Sub-Material / Component',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (widget.parentItemCode.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        'Parent: ${widget.parentItemCode}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1D4ED8),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Raw materials, accessories, and components from ITEMMST (Query 6)',
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
                            borderSide: const BorderSide(color: primaryColor, width: 1.5),
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
                          width: 95,
                          child: Text(
                            'TYPE',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 160,
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
                          width: 60,
                          child: Text(
                            'UQC',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 65,
                          child: Text(
                            'CONV QTY',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                          ),
                        ),
                        SizedBox(
                          width: 65,
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
                        ? const Center(child: CircularProgressIndicator(color: primaryColor))
                        : _items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 38, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No sub-materials found for "${_searchCtrl.text}"',
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

                                  return MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    onEnter: (_) => setState(() => _selectedIndex = index),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? primaryBg : (index.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? primaryBorder : const Color(0xFFE2E8F0),
                                          width: isSelected ? 1.4 : 1.0,
                                        ),
                                      ),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _handleSelect(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                          child: Row(
                                            children: [
                                              // TYPE BADGE
                                              SizedBox(
                                                width: 95,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                                    ),
                                                    child: Text(
                                                      item.materialType.isNotEmpty ? item.materialType : 'GENERAL',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF334155),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // MATERIAL CODE
                                              SizedBox(
                                                width: 160,
                                                child: Text(
                                                  item.iCode,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: isSelected ? primaryColor : const Color(0xFF0F172A),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),

                                              // DESCRIPTION
                                              Expanded(
                                                child: Text(
                                                  item.itName,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF334155),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),

                                              // UQC / UNIT
                                              SizedBox(
                                                width: 60,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      item.unitName,
                                                      style: const TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              // CONV QTY
                                              SizedBox(
                                                width: 65,
                                                child: Text(
                                                  item.convQty.toStringAsFixed(2),
                                                  textAlign: TextAlign.right,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF0F172A),
                                                  ),
                                                ),
                                              ),

                                              // SELECT ACTION BUTTON
                                              SizedBox(
                                                width: 65,
                                                child: Align(
                                                  alignment: Alignment.centerRight,
                                                  child: ElevatedButton(
                                                    onPressed: () => _handleSelect(item),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: primaryColor,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text('Select', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
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

                  // FOOTER HINT
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Use ↑ ↓ to navigate  •  Enter to select  •  Esc to close',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Showing ${_items.length} sub-materials',
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
