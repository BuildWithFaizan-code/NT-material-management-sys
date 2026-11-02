import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../material_return_models.dart';
import '../material_return_service.dart';

/// Item Lookup Modal styled 100% after the Group Master Show Record table
class MaterialReturnItemLookupModal extends StatefulWidget {
  final MaterialReturnService service;
  final DateTime date;
  final int sourceDept;
  final int sourceStore;
  final int sourceDiv;
  final ValueChanged<MaterialReturnStockCatalogItem> onSelect;

  const MaterialReturnItemLookupModal({
    super.key,
    required this.service,
    required this.date,
    required this.sourceDept,
    required this.sourceStore,
    required this.sourceDiv,
    required this.onSelect,
  });

  @override
  State<MaterialReturnItemLookupModal> createState() => _MaterialReturnItemLookupModalState();
}

class _MaterialReturnItemLookupModalState extends State<MaterialReturnItemLookupModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<MaterialReturnStockCatalogItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedAlphabet = 'ALL';
  String _searchQuery = '';
  Timer? _debounce;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _fetchItems();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchCtrl.text.trim();
        });
        _fetchItems();
      }
    });
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final query = _searchQuery.isNotEmpty
          ? _searchQuery
          : (_selectedAlphabet != 'ALL' && _selectedAlphabet != '#' ? _selectedAlphabet : null);

      final res = await widget.service.fetchStockCatalog(
        date: widget.date,
        sourceDept: widget.sourceDept,
        sourceStore: widget.sourceStore,
        sourceDiv: widget.sourceDiv,
        search: query,
        page: 1,
        pageSize: 60,
      );

      if (mounted) {
        setState(() {
          _items = res.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  List<MaterialReturnStockCatalogItem> get _filteredItems {
    if (_selectedAlphabet == 'ALL') {
      return _items;
    }
    if (_selectedAlphabet == '#') {
      final reg = RegExp(r'^[0-9]');
      return _items.where((i) => reg.hasMatch(i.itemName.trim()) || reg.hasMatch(i.itemCode.trim())).toList();
    }
    return _items.where((i) {
      final n = i.itemName.trim().toUpperCase();
      final c = i.itemCode.trim().toUpperCase();
      return n.startsWith(_selectedAlphabet) || c.startsWith(_selectedAlphabet);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredItems;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1200,
        height: 680,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              // Top Header Bar
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
                        color: AppColors.secondaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.secondaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Material / Item Catalog',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        '${list.length} Items available',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF64748B)),
                          SizedBox(width: 6),
                          Text(
                            'Click row to select | Esc to close',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Search Bar & Alphabet Strip
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _fetchItems();
                                        },
                                      )
                                    : null,
                                hintText: 'Search by item code, item name, HSN, shade, grade...',
                                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppColors.secondaryColor, size: 20),
                          tooltip: 'Refresh Catalog',
                          onPressed: _fetchItems,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Alphabet strip
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _alphabets.map((alpha) {
                          final isSelected = _selectedAlphabet == alpha;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: InkWell(
                              onTap: () {
                                setState(() => _selectedAlphabet = alpha);
                                _fetchItems();
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.secondaryColor : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  alpha,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Catalog Table
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.secondaryColor),
                      )
                    : _errorMessage != null
                        ? Center(
                            child: Text(
                              'Error loading catalog: $_errorMessage',
                              style: const TextStyle(color: AppColors.error),
                            ),
                          )
                        : list.isEmpty
                            ? const Center(
                                child: Text(
                                  'No items found matching the criteria.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                ),
                              )
                            : Scrollbar(
                                controller: _scrollCtrl,
                                thumbVisibility: true,
                                child: ListView.builder(
                                  controller: _scrollCtrl,
                                  itemCount: list.length + 1,
                                  itemBuilder: (context, idx) {
                                    if (idx == 0) {
                                      // Table Header
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        color: const Color(0xFFF8FAFC),
                                        child: const Row(
                                          children: [
                                            SizedBox(
                                              width: 110,
                                              child: Text('Item Code', style: _hdrStyle),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text('Item Name', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: Text('UOM', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text('HSN', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 85,
                                              child: Text('Stock', textAlign: TextAlign.right, style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 85,
                                              child: Text('Rate', textAlign: TextAlign.right, style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text('Grade', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text('Shade', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text('Maker', style: _hdrStyle),
                                            ),
                                            SizedBox(
                                              width: 75,
                                              child: Text('Tax %', textAlign: TextAlign.right, style: _hdrStyle),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    final item = list[idx - 1];
                                    final isEven = idx % 2 == 0;
                                    final totalTax = item.cgper + item.sgper + item.igper;

                                    return InkWell(
                                      onTap: () {
                                        widget.onSelect(item);
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8.5),
                                        decoration: BoxDecoration(
                                          color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
                                          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                item.itemCode,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: AppColors.secondaryColor,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                item.itemName,
                                                style: const TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 70,
                                              child: Text(
                                                item.uom,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 90,
                                              child: Text(
                                                item.hsnCode.isEmpty ? '-' : item.hsnCode,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 85,
                                              child: Text(
                                                item.balanceQty.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 85,
                                              child: Text(
                                                item.avgRate.toStringAsFixed(2),
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                item.matGrade.isEmpty ? '-' : item.matGrade,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                item.matShade.isEmpty ? '-' : item.matShade,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                item.matMaker.isEmpty ? '-' : item.matMaker,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 75,
                                              child: Text(
                                                totalTax > 0 ? '${totalTax.toStringAsFixed(1)}%' : '0%',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
              ),

              // Modal Bottom Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    const Text(
                      'Returning materials will increment stock balances upon confirmation.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
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

const TextStyle _hdrStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.bold,
  color: Color(0xFF475569),
);
