import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../../stock_transfer/stock_transfer_models.dart'
    show StockCatalogItem, StockTransferLookups, StockTransferLookupItem;
import '../../stock_transfer/stock_transfer_service.dart';
import '../../stock_transfer/widgets/stock_catalog_lookup_dialog.dart';
import '../issue_manager_models.dart';
import '../issue_manager_service.dart';

/// Add / Edit Line Item Dialog for Issue Manager.
/// Strict rule: Fields correspond 1:1 with the Line Items table columns.
/// Live calculation: Amount = IssueQty * Rate (strictly performed).
class AddIssueManagerRowDialog extends StatefulWidget {
  final IssueManagerService service;
  final IssueManagerLookups lookups;
  final DateTime date;
  final int sourceDept;
  final int sourceStore;
  final int sourceDiv;
  final IssueManagerLineItem? initialItem;
  final int nextSrNo;

  const AddIssueManagerRowDialog({
    super.key,
    required this.service,
    required this.lookups,
    required this.date,
    required this.sourceDept,
    required this.sourceStore,
    required this.sourceDiv,
    this.initialItem,
    required this.nextSrNo,
  });

  @override
  State<AddIssueManagerRowDialog> createState() => _AddIssueManagerRowDialogState();
}

class _AddIssueManagerRowDialogState extends State<AddIssueManagerRowDialog> {
  // 14 exact fields matching the 14 line item table columns
  late final TextEditingController _srNoCtrl;
  final TextEditingController _itemCodeCtrl = TextEditingController();
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _uqcCtrl = TextEditingController();
  final TextEditingController _mergeNoCtrl = TextEditingController();
  final TextEditingController _gradeCtrl = TextEditingController();
  final TextEditingController _shadeCtrl = TextEditingController();
  final TextEditingController _makerCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController(text: '0.00');
  final TextEditingController _stockCtrl = TextEditingController(text: '0.00');
  final TextEditingController _nosCtrl = TextEditingController(text: '0');
  final TextEditingController _issueQtyCtrl = TextEditingController(text: '0');
  final TextEditingController _amountCtrl = TextEditingController(text: '0.00');
  final TextEditingController _remarkCtrl = TextEditingController();

  int _uom = 0;
  String _validationError = '';
  bool _isValidatingStock = false;

  @override
  void initState() {
    super.initState();
    final srNo = widget.initialItem?.srNo ?? widget.nextSrNo;
    _srNoCtrl = TextEditingController(text: srNo.toString());

    if (widget.initialItem != null) {
      final it = widget.initialItem!;
      _itemCodeCtrl.text = it.itemCode;
      _itemNameCtrl.text = it.itemName;
      _uqcCtrl.text = it.unitName;
      _uom = it.uom;
      _mergeNoCtrl.text = it.mrgNo;
      _gradeCtrl.text = it.grade;
      _shadeCtrl.text = it.shade;
      _makerCtrl.text = it.maker;
      _rateCtrl.text = it.rate.toStringAsFixed(5).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
      _stockCtrl.text = it.stock.toStringAsFixed(2);
      _nosCtrl.text = it.issPcs.toStringAsFixed(0);
      _issueQtyCtrl.text = it.issueQty.toStringAsFixed(2);
      _amountCtrl.text = it.amount.toStringAsFixed(2);
      _remarkCtrl.text = it.remark;
    }

    _rateCtrl.addListener(_recalculateAmount);
    _issueQtyCtrl.addListener(_recalculateAmount);
  }

  @override
  void dispose() {
    _srNoCtrl.dispose();
    _itemCodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _uqcCtrl.dispose();
    _mergeNoCtrl.dispose();
    _gradeCtrl.dispose();
    _shadeCtrl.dispose();
    _makerCtrl.dispose();
    _rateCtrl.removeListener(_recalculateAmount);
    _rateCtrl.dispose();
    _stockCtrl.dispose();
    _nosCtrl.dispose();
    _issueQtyCtrl.removeListener(_recalculateAmount);
    _issueQtyCtrl.dispose();
    _amountCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _recalculateAmount() {
    final qty = double.tryParse(_issueQtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final amount = qty * rate;
    final formatted = amount.toStringAsFixed(2);
    if (_amountCtrl.text != formatted) {
      _amountCtrl.text = formatted;
    }
  }

  Future<void> _openStockCatalogLookup() async {
    final adaptedLookups = StockTransferLookups(
      departments: widget.lookups.departments
          .map((d) => StockTransferLookupItem(id: d.id, code: d.code, name: d.name))
          .toList(),
      stores: widget.lookups.stores
          .map((s) => StockTransferLookupItem(id: s.id, code: s.code, name: s.name))
          .toList(),
      divisions: widget.lookups.divisions
          .map((v) => StockTransferLookupItem(id: v.id, code: v.code, name: v.name))
          .toList(),
      plants: const [],
      issueModes: widget.lookups.issueModes,
    );

    final selected = await showDialog<StockCatalogItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockCatalogLookupDialog(
        service: StockTransferService(),
        date: widget.date,
        sourceDept: widget.sourceDept,
        sourceStore: widget.sourceStore,
        sourceDiv: widget.sourceDiv,
        lookups: adaptedLookups,
      ),
    );

    if (selected != null) {
      setState(() {
        _itemCodeCtrl.text = selected.itemCode;
        _itemNameCtrl.text = selected.itemName;
        _uqcCtrl.text = selected.unitName;
        _uom = selected.unitCode;
        _mergeNoCtrl.text = selected.mrgNo;
        _gradeCtrl.text = selected.grade;
        _shadeCtrl.text = selected.shade;
        _makerCtrl.text = selected.maker;
        _rateCtrl.text = selected.rate.toString();
        _stockCtrl.text = selected.stock.toStringAsFixed(2);
        _nosCtrl.text = selected.pcs > 0 ? selected.pcs.toStringAsFixed(0) : '1';
        _issueQtyCtrl.text = '';
        _validationError = '';
      });
      _recalculateAmount();
    }
  }

  Future<void> _submit() async {
    setState(() => _validationError = '');

    final itemCode = _itemCodeCtrl.text.trim();
    if (itemCode.isEmpty) {
      setState(() => _validationError = 'Please select or browse an Item from the catalog.');
      return;
    }

    final issueQty = double.tryParse(_issueQtyCtrl.text.trim()) ?? 0.0;
    if (issueQty <= 0) {
      setState(() => _validationError = 'Issue Quantity must be strictly greater than zero.');
      return;
    }

    final availableStock = double.tryParse(_stockCtrl.text.trim()) ?? 0.0;
    if (issueQty > availableStock) {
      setState(() => _validationError =
          'Issue quantity ($issueQty) exceeds available stock ($availableStock).');
      return;
    }

    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final nos = double.tryParse(_nosCtrl.text.trim()) ?? 0.0;

    // Real-time stock verification against DB
    setState(() => _isValidatingStock = true);
    try {
      final liveStock = await widget.service.checkStock(
        date: widget.date,
        itemCode: itemCode,
        mrgNo: _mergeNoCtrl.text.trim(),
        grade: _gradeCtrl.text.trim(),
        shade: _shadeCtrl.text.trim(),
        sourceDept: widget.sourceDept,
        sourceStore: widget.sourceStore,
        sourceDiv: widget.sourceDiv,
        uom: _uom,
      );

      if (issueQty > liveStock) {
        setState(() {
          _isValidatingStock = false;
          _validationError = 'Insufficient stock. Live DB stock is $liveStock.';
        });
        return;
      }
    } catch (_) {
      // Allow local catalog stock fallback if network or endpoint has momentary fluctuation
    } finally {
      if (mounted) setState(() => _isValidatingStock = false);
    }

    final rowItem = IssueManagerLineItem(
      srNo: widget.initialItem?.srNo ?? widget.nextSrNo,
      itemCode: itemCode,
      itemName: _itemNameCtrl.text.trim(),
      uom: _uom,
      unitName: _uqcCtrl.text.trim(),
      mrgNo: _mergeNoCtrl.text.trim(),
      grade: _gradeCtrl.text.trim(),
      shade: _shadeCtrl.text.trim(),
      maker: _makerCtrl.text.trim(),
      rate: rate,
      stock: availableStock,
      issPcs: nos,
      issueQty: issueQty,
      remark: _remarkCtrl.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop(rowItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialItem != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 780,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C3B2E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF0C3B2E), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Line Item (Sr #${widget.initialItem!.srNo})' : 'Add Line Item (Direct Mode)',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Strict 1:1 table columns with live real-time amount calculation',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                    ),
                  ],
                ),
              ),

              // Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_validationError.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _validationError,
                                  style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Row 1: Sr No (1), Item Code (2), Item Name (3)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 80,
                            child: _buildFormField(
                              label: '1. Sr No',
                              controller: _srNoCtrl,
                              readOnly: true,
                              textColor: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: _buildFormField(
                              label: '2. Item Code *',
                              controller: _itemCodeCtrl,
                              readOnly: true,
                              hintText: 'Click browse',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.manage_search_rounded, color: Color(0xFF0C3B2E), size: 20),
                                tooltip: 'Browse Item Catalog (Stock Picker)',
                                onPressed: _openStockCatalogLookup,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: _buildFormField(
                              label: '3. Item Name',
                              controller: _itemNameCtrl,
                              readOnly: true,
                              hintText: 'Auto-populated from catalog',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: UQC (4), Merge No (5), Grade (6), Shade (7)
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: '4. UQC / Unit',
                              controller: _uqcCtrl,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '5. Merge No.',
                              controller: _mergeNoCtrl,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '6. Grade',
                              controller: _gradeCtrl,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '7. Shade',
                              controller: _shadeCtrl,
                              readOnly: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 3: Maker (8), Rate (9), Stock (10), Nos (11)
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildFormField(
                              label: '8. Maker',
                              controller: _makerCtrl,
                              readOnly: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '9. Rate',
                              controller: _rateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '10. Stock',
                              controller: _stockCtrl,
                              readOnly: true,
                              textColor: const Color(0xFF0F766E),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '11. Nos (Pcs)',
                              controller: _nosCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 4: Issue Qty (12), Amount (13) [STRICT LIVE CALCULATION]
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: '12. Issue Qty *',
                              controller: _issueQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textColor: const Color(0xFF1D4ED8),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildFormField(
                              label: '13. Amount (Qty × Rate)',
                              controller: _amountCtrl,
                              readOnly: true,
                              textColor: const Color(0xFF047857),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 5: Remark / Party Name (14)
                      _buildFormField(
                        label: '14. Remark / Party Name',
                        controller: _remarkCtrl,
                        hintText: 'Optional remark for this line item',
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isValidatingStock ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isValidatingStock
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEdit ? 'Update Row' : 'Add to List',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
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

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 12.5,
            color: textColor ?? const Color(0xFF1E293B),
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C3B2E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
