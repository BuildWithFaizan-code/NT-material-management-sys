import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../purchase_order_models.dart';
import '../purchase_order_service.dart';

class PartyLookupDialog extends StatefulWidget {
  final PurchaseOrderService service;
  final ValueChanged<SupplierLookupItem>? onSelect;

  const PartyLookupDialog({
    super.key,
    required this.service,
    this.onSelect,
  });

  @override
  State<PartyLookupDialog> createState() => _PartyLookupDialogState();
}

class _PartyLookupDialogState extends State<PartyLookupDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<SupplierLookupItem> _items = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalCount = 0;
  Timer? _debounceTimer;

  int? _hoveredIndex;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _currentPage = 1;
      });
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await widget.service.fetchSuppliersLookup(
        search: _searchCtrl.text,
        page: _currentPage,
        pageSize: 50,
      );
      if (mounted) {
        setState(() {
          _items = res.items;
          _totalCount = res.totalCount;
          _isLoading = false;
          _selectedIndex = null;
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

  void _selectItem(SupplierLookupItem item) {
    widget.onSelect?.call(item);
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1080,
        height: 640,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Top Header Bar
            _buildHeader(),

            // Search Bar & Filter Strip
            _buildSearchStrip(),

            // Data Table Grid
            Expanded(child: _buildTableBody()),

            // Footer Status & Pagination Bar
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.contact_mail_outlined,
              size: 20,
              color: AppColors.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Supplier / Creditor Party',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutralDark,
                ),
              ),
              Text(
                'Double-click or press Enter to choose supplier',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.slateMuted,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_totalCount Suppliers',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.neutralDark),
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceColor,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                decoration: InputDecoration(
                  hintText: 'Search by party name, GSTIN, code... (Type to filter)',
                  hintStyle: TextStyle(fontSize: 12, color: AppColors.neutralDark.withValues(alpha: 0.45)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.primaryColor),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.slateLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) {
                  if (_items.isNotEmpty) {
                    final idx = _selectedIndex ?? 0;
                    _selectItem(_items[idx]);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text('No suppliers found matching your query.', style: TextStyle(color: AppColors.slateMuted)),
      );
    }

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 1068,
            child: Column(
              children: [
                _buildTableHeader(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    final isSelected = _selectedIndex == idx;
                    final isHovered = _hoveredIndex == idx;

                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = idx),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedIndex = idx),
                        onDoubleTap: () => _selectItem(item),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.secondaryColor.withValues(alpha: 0.18)
                                : isHovered
                                    ? AppColors.slateLight
                                    : idx.isEven
                                        ? AppColors.surfaceColor
                                        : AppColors.slateLight.withValues(alpha: 0.45),
                            border: const Border(bottom: BorderSide(color: AppColors.divider, width: 0.8)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              _cell(item.pCode.toString(), width: 70, align: Alignment.center),
                              _cell(item.pName, width: 260, isBold: true),
                              _cell(item.gstin.isEmpty ? '-' : item.gstin, width: 140),
                              _cell(item.stateCode.isEmpty ? '-' : item.stateCode, width: 60, align: Alignment.center),
                              _cell(item.address.isEmpty ? '-' : item.address, width: 220),
                              _cell(item.agent.isEmpty ? '-' : item.agent, width: 130),
                              _cell('${item.creditDays}d', width: 65, align: Alignment.center),
                              _cell(item.typeOfRegistrant, width: 95, align: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.slateLight,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _headerCell('CODE', width: 70, align: Alignment.center),
          _headerCell('SUPPLIER / PARTY NAME', width: 260),
          _headerCell('GSTIN', width: 140),
          _headerCell('STATE', width: 60, align: Alignment.center),
          _headerCell('ADDRESS', width: 220),
          _headerCell('AGENT', width: 130),
          _headerCell('CR. DAYS', width: 65, align: Alignment.center),
          _headerCell('TAX REG.', width: 95, align: Alignment.center),
        ],
      ),
    );
  }

  Widget _headerCell(String title, {required double width, Alignment align = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: align,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: AppColors.neutralDark,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {required double width, bool isBold = false, Alignment align = Alignment.centerLeft}) {
    return SizedBox(
      width: width,
      child: Align(
        alignment: align,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            color: AppColors.neutralDark,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.slateLight,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            'Showing ${_items.length} of $_totalCount suppliers',
            style: const TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.neutralDark)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _selectedIndex != null && _selectedIndex! < _items.length
                ? () => _selectItem(_items[_selectedIndex!])
                : null,
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Select Supplier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
