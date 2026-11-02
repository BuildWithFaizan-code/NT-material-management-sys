import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../stock_transfer_models.dart';
import '../stock_transfer_service.dart';
import 'stock_catalog_lookup_dialog.dart';
import 'pending_requisition_lookup_dialog.dart';

class AddStockTransferRowDialog extends StatefulWidget {
  final StockTransferService service;
  final StockTransferLookups lookups;
  final DateTime date;
  final String source; // 'Direct' or 'Requisition'
  final int sourceDept;
  final int sourceStore;
  final int sourceDiv;
  final StockTransferLineItem? initialItem;
  final int nextSrNo;

  const AddStockTransferRowDialog({
    super.key,
    required this.service,
    required this.lookups,
    required this.date,
    this.source = 'Direct',
    required this.sourceDept,
    required this.sourceStore,
    required this.sourceDiv,
    this.initialItem,
    required this.nextSrNo,
  });

  @override
  State<AddStockTransferRowDialog> createState() => _AddStockTransferRowDialogState();
}

class _AddStockTransferRowDialogState extends State<AddStockTransferRowDialog> {
  StockCatalogItem? _selectedStock;

  final TextEditingController _reqCodeCtrl = TextEditingController(text: 'None');
  double _reqQty = 0.0;
  final TextEditingController _itemCodeCtrl = TextEditingController();
  final TextEditingController _itemNameCtrl = TextEditingController();
  final TextEditingController _uqcCtrl = TextEditingController();
  final TextEditingController _mergeNoCtrl = TextEditingController();
  final TextEditingController _gradeCtrl = TextEditingController();
  final TextEditingController _makerCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController(text: '0.00');
  final TextEditingController _nosCtrl = TextEditingController(text: '0');
  final TextEditingController _issueQtyCtrl = TextEditingController(text: '0');
  final TextEditingController _remarkCtrl = TextEditingController();

  int _uom = 0;
  String _shade = '';

  int? _selectedToDept;
  int? _selectedToStore;
  int? _selectedToCost;

  List<StockTransferLookupItem> _toStores = [];
  bool _isLoadingToStores = false;
  String _validationError = '';

  @override
  void initState() {
    super.initState();
    _loadToStores();

    if (widget.initialItem != null) {
      final it = widget.initialItem!;
      _reqCodeCtrl.text = it.reqCode;
      _reqQty = it.reqQty;
      _itemCodeCtrl.text = it.itemCode;
      _itemNameCtrl.text = it.itemName;
      _uqcCtrl.text = it.unitName;
      _uom = it.uom;
      _mergeNoCtrl.text = it.mrgNo;
      _gradeCtrl.text = it.grade;
      _shade = it.shade;
      _makerCtrl.text = it.maker;
      _rateCtrl.text = it.rate.toString();
      _stockCtrl.text = it.stock.toString();
      _nosCtrl.text = it.issPcs.toString();
      _issueQtyCtrl.text = it.issueQty.toString();
      _remarkCtrl.text = it.remark;

      _selectedToDept = it.toDeptCode;
      _selectedToStore = it.toStoreId;
      _selectedToCost = it.toCostId;
    } else {
      if (widget.lookups.departments.isNotEmpty) {
        _selectedToDept = widget.lookups.departments.first.id;
      }
      if (widget.lookups.divisions.isNotEmpty) {
        _selectedToCost = widget.lookups.divisions.first.id;
      }
    }
  }

  @override
  void dispose() {
    _reqCodeCtrl.dispose();
    _itemCodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _uqcCtrl.dispose();
    _mergeNoCtrl.dispose();
    _gradeCtrl.dispose();
    _makerCtrl.dispose();
    _rateCtrl.dispose();
    _stockCtrl.dispose();
    _nosCtrl.dispose();
    _issueQtyCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToStores() async {
    setState(() => _isLoadingToStores = true);
    try {
      final stores = await widget.service.fetchToStores(widget.sourceStore);
      setState(() {
        _toStores = stores;
        if (_selectedToStore == null && _toStores.isNotEmpty) {
          _selectedToStore = _toStores.first.id;
        }
        _isLoadingToStores = false;
      });
    } catch (_) {
      setState(() {
        _toStores = widget.lookups.stores;
        if (_selectedToStore == null && _toStores.isNotEmpty) {
          _selectedToStore = _toStores.first.id;
        }
        _isLoadingToStores = false;
      });
    }
  }

  Future<void> _openStockPicker() async {
    final item = await showDialog<StockCatalogItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StockCatalogLookupDialog(
        service: widget.service,
        date: widget.date,
        sourceDept: widget.sourceDept,
        sourceStore: widget.sourceStore,
        sourceDiv: widget.sourceDiv,
        lookups: widget.lookups,
      ),
    );

    if (item != null) {
      setState(() {
        _selectedStock = item;
        _itemCodeCtrl.text = item.itemCode;
        _itemNameCtrl.text = item.itemName;
        _uqcCtrl.text = item.unitName;
        _uom = item.unitCode;
        _mergeNoCtrl.text = item.mrgNo;
        _gradeCtrl.text = item.grade;
        _shade = item.shade;
        _makerCtrl.text = item.maker;
        _rateCtrl.text = item.rate.toString();
        _stockCtrl.text = item.stock.toStringAsFixed(2);
        _validationError = '';
      });
    }
  }

  Future<void> _openRequisitionPicker() async {
    final req = await showDialog<PendingRequisitionItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PendingRequisitionLookupDialog(service: widget.service),
    );

    if (req != null) {
      setState(() {
        _reqCodeCtrl.text = req.reqCode;
        _reqQty = req.reqQty;
        _itemCodeCtrl.text = req.itemCode;
        _itemNameCtrl.text = req.itemName;
        _uqcCtrl.text = req.unitName;
        _uom = req.uom;
        _mergeNoCtrl.text = req.mrgNo;
        _gradeCtrl.text = req.grade;
        _shade = req.shade;
        _rateCtrl.text = req.rate > 0 ? req.rate.toString() : '0.00';
        _issueQtyCtrl.text = req.balQty.toString();
        _validationError = '';
      });

      // Fetch live stock for this item
      try {
        final available = await widget.service.checkStock(
          date: widget.date,
          itemCode: req.itemCode,
          mrgNo: req.mrgNo,
          grade: req.grade,
          shade: req.shade,
          sourceDept: widget.sourceDept,
          sourceStore: widget.sourceStore,
          sourceDiv: widget.sourceDiv,
          uom: req.uom,
        );
        if (mounted) {
          setState(() => _stockCtrl.text = available.toStringAsFixed(2));
        }
      } catch (_) {}
    }
  }

  void _onConfirm() {
    final itemCode = _itemCodeCtrl.text.trim();
    if (itemCode.isEmpty) {
      setState(() => _validationError = 'Please select an item.');
      return;
    }

    final qty = double.tryParse(_issueQtyCtrl.text.trim()) ?? 0.0;
    if (qty <= 0) {
      setState(() => _validationError = 'Issue Quantity must be greater than 0.');
      return;
    }

    final stock = double.tryParse(_stockCtrl.text.trim()) ?? 0.0;
    if (stock > 0 && qty > stock) {
      setState(() => _validationError = 'Issue Quantity ($qty) cannot exceed available stock ($stock).');
      return;
    }

    final pcs = double.tryParse(_nosCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    final toDeptName = widget.lookups.departments.firstWhere(
      (d) => d.id == _selectedToDept,
      orElse: () => StockTransferLookupItem(id: 0, code: '', name: ''),
    ).name;

    final toStoreName = _toStores.firstWhere(
      (s) => s.id == _selectedToStore,
      orElse: () => StockTransferLookupItem(id: 0, code: '', name: ''),
    ).name;

    final toCostName = widget.lookups.divisions.firstWhere(
      (c) => c.id == _selectedToCost,
      orElse: () => StockTransferLookupItem(id: 0, code: '', name: ''),
    ).name;

    final result = StockTransferLineItem(
      srNo: widget.initialItem?.srNo ?? widget.nextSrNo,
      reqCode: _reqCodeCtrl.text.trim().isEmpty ? 'None' : _reqCodeCtrl.text.trim(),
      reqQty: _reqQty,
      itemCode: itemCode,
      itemName: _itemNameCtrl.text.trim(),
      toDeptCode: _selectedToDept ?? 0,
      toDeptName: toDeptName,
      toStoreId: _selectedToStore ?? 0,
      toStoreName: toStoreName,
      toCostId: _selectedToCost ?? 0,
      toCostName: toCostName,
      uom: _uom > 0 ? _uom : (_selectedStock?.unitCode ?? widget.initialItem?.uom ?? 0),
      unitName: _uqcCtrl.text.trim(),
      mrgNo: _mergeNoCtrl.text.trim(),
      grade: _gradeCtrl.text.trim(),
      shade: _shade.isNotEmpty ? _shade : (_selectedStock?.shade ?? widget.initialItem?.shade ?? ''),
      maker: _makerCtrl.text.trim(),
      rate: rate,
      stock: stock,
      issPcs: pcs,
      issueQty: qty,
      binNo: _selectedStock?.simBin ?? widget.initialItem?.binNo ?? 'REPACK',
      remark: _remarkCtrl.text.trim(),
    );

    Navigator.of(context).pop(result);
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool readOnly = false, bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            readOnly: readOnly,
            keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: readOnly ? FontWeight.w500 : FontWeight.w600,
              color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: AppColors.primaryColor)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRequisition = widget.source == 'Requisition';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 880,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
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
                    child: const Icon(Icons.playlist_add_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialItem == null
                              ? (isRequisition ? 'Add Requisition Transfer Row' : 'Add Direct Transfer Row')
                              : 'Edit Transfer Row',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRequisition
                              ? '15 Columns: Select pending requisition line, destination location, and transfer quantity.'
                              : '14 Columns: Select stock catalog item, destination location, and transfer quantity.',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_validationError.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationError,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Row 1: Requisition Code (if Requisition mode) / Item Code + Name
                    if (isRequisition) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Requisition Code', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 38,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _reqCodeCtrl,
                                          readOnly: true,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFFF1F5F9),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: _openRequisitionPicker,
                                        icon: const Icon(Icons.search, size: 16),
                                        label: const Text('Browse', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _buildTextField('Item Code', _itemCodeCtrl, readOnly: true),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 4,
                            child: _buildTextField('Item Name', _itemNameCtrl, readOnly: true),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Item Code', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                const SizedBox(height: 5),
                                SizedBox(
                                  height: 38,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _itemCodeCtrl,
                                          readOnly: true,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: const Color(0xFFF1F5F9),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: _openStockPicker,
                                        icon: const Icon(Icons.search, size: 16),
                                        label: const Text('Lookup', style: TextStyle(fontSize: 11)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 5,
                            child: _buildTextField('Item Name', _itemNameCtrl, readOnly: true),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Row 2: Destination Dropdowns
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To Department', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              const SizedBox(height: 5),
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedToDept,
                                    isExpanded: true,
                                    items: widget.lookups.departments.map((d) {
                                      return DropdownMenuItem<int>(
                                        value: d.id,
                                        child: Text(d.name, style: const TextStyle(fontSize: 12.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedToDept = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To Location (Store)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              const SizedBox(height: 5),
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: _isLoadingToStores
                                    ? const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                                    : DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _toStores.any((s) => s.id == _selectedToStore) ? _selectedToStore : null,
                                          isExpanded: true,
                                          items: _toStores.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s.id,
                                              child: Text(s.name, style: const TextStyle(fontSize: 12.5)),
                                            );
                                          }).toList(),
                                          onChanged: (val) => setState(() => _selectedToStore = val),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('To Cost Center', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                              const SizedBox(height: 5),
                              Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedToCost,
                                    isExpanded: true,
                                    items: widget.lookups.divisions.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(c.name, style: const TextStyle(fontSize: 12.5)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedToCost = val),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Row 3: Specifications: UQC, Merge No., Grade, Maker
                    Row(
                      children: [
                        Expanded(child: _buildTextField('UQC', _uqcCtrl, readOnly: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Merge No.', _mergeNoCtrl)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Grade', _gradeCtrl)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Maker', _makerCtrl)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Row 4: Rate, Stock, Nos, Issue Qty
                    Row(
                      children: [
                        Expanded(child: _buildTextField('Rate', _rateCtrl, isNumeric: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Current Stock', _stockCtrl, readOnly: true, isNumeric: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Nos (Pcs)', _nosCtrl, isNumeric: true)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildTextField('Iss. Qty *', _issueQtyCtrl, isNumeric: true)),
                      ],
                    ),

                    // Row 5: Remark / Party Name (only in Direct mode)
                    if (!isRequisition) ...[
                      const SizedBox(height: 14),
                      _buildTextField('Remark / Party Name', _remarkCtrl),
                    ],
                  ],
                ),
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(widget.initialItem == null ? 'Add Row' : 'Update Row'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
