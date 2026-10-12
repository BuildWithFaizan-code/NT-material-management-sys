import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../purchase_order_models.dart';
import '../purchase_order_service.dart';
import 'item_lookup_dialog.dart';
import 'po_animated_success_button.dart';

/// Modal dialog for adding or editing a Purchase Order line item with all
/// 24 legacy columns and real-time tax & conversion calculations.
class AddPoRowDialog extends StatefulWidget {
  final int srNo;
  final String supplierStateCode;
  final String companyStateCode;
  final List<DepartmentLookupItem> departments;
  final List<DivisionLookupItem> divisions;
  final PurchaseOrderService service;
  final PurchaseOrderItem? existingItem;

  const AddPoRowDialog({
    super.key,
    required this.srNo,
    required this.supplierStateCode,
    this.companyStateCode = '27',
    required this.departments,
    required this.divisions,
    required this.service,
    this.existingItem,
  });

  @override
  State<AddPoRowDialog> createState() => _AddPoRowDialogState();
}

class _AddPoRowDialogState extends State<AddPoRowDialog> {
  // 1. Item Code & Description
  final TextEditingController _iCodeCtrl = TextEditingController();
  final TextEditingController _itemNameCtrl = TextEditingController();

  // 2. Merge No / Style & Shade
  final TextEditingController _mrgNoCtrl = TextEditingController();
  final TextEditingController _shadeCtrl = TextEditingController(text: '*');

  // 3. Remark & Department / Cost Center
  final TextEditingController _pRemarkCtrl = TextEditingController();
  int _selectedDepCode = 0;
  String _selectedDeptName = '';
  int _selectedKhCode = 0;
  String _selectedDivisionName = '';

  // 4. Quantities & Units
  int _uom = 0;
  String _unitName = '';
  final TextEditingController _qtyCtrl = TextEditingController(text: '1.00');
  final TextEditingController _accQtyCtrl = TextEditingController(text: '0.00'); // GRN Qty
  final TextEditingController _pendQtyCtrl = TextEditingController(text: '0.00');
  int _convUom = 0;
  String _convUnitName = '';
  double _conversionFactor = 1.0;
  final TextEditingController _convQtyCtrl = TextEditingController(text: '1.00');

  // 5. Rate, Disc, Amount, Freight
  final TextEditingController _rateCtrl = TextEditingController(text: '0.00');
  final TextEditingController _discCtrl = TextEditingController(text: '0.00');
  final TextEditingController _amountCtrl = TextEditingController(text: '0.00');
  final TextEditingController _freightCtrl = TextEditingController(text: '0.00');

  // 6. Taxes (CGST, SGST, IGST)
  double _taxSlab = 0.0;
  final TextEditingController _cgPerCtrl = TextEditingController(text: '0.00');
  final TextEditingController _cgAmtCtrl = TextEditingController(text: '0.00');
  final TextEditingController _sgPerCtrl = TextEditingController(text: '0.00');
  final TextEditingController _sgAmtCtrl = TextEditingController(text: '0.00');
  final TextEditingController _igPerCtrl = TextEditingController(text: '0.00');
  final TextEditingController _igAmtCtrl = TextEditingController(text: '0.00');

  // 7. Net Amount & Auxiliary Info
  final TextEditingController _netAmtCtrl = TextEditingController(text: '0.00');
  String _hsn = '';
  double _podStock = 0.0;
  double _podLastRate = 0.0;
  int _podMakeId = 0;
  String _makerName = '';

  // Lookups and lists
  List<ItemMergeLookupItem> _availableMerges = [];
  List<String> _availableShades = [];
  bool _isLoadingMerges = false;
  String? _errorMessage;
  ButtonStatus _buttonStatus = ButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    _initDefaultsAndExisting();
    _loadShades();
  }

  void _initDefaultsAndExisting() {
    if (widget.departments.isNotEmpty) {
      _selectedDepCode = widget.departments.first.labCode;
      _selectedDeptName = widget.departments.first.labName;
    }
    if (widget.divisions.isNotEmpty) {
      _selectedKhCode = widget.divisions.first.khCode;
      _selectedDivisionName = widget.divisions.first.khName;
    }

    final item = widget.existingItem;
    if (item != null) {
      _iCodeCtrl.text = item.iCode;
      _itemNameCtrl.text = item.itemName;
      _mrgNoCtrl.text = item.mrgNo;
      _shadeCtrl.text = item.shade.isNotEmpty ? item.shade : '*';
      _pRemarkCtrl.text = item.pRemark;
      _selectedDepCode = item.depCode;
      _selectedDeptName = item.deptName;
      _selectedKhCode = item.khCode;
      _selectedDivisionName = item.divisionName;
      _uom = item.uom;
      _unitName = item.unitName;
      _qtyCtrl.text = item.qty.toStringAsFixed(2);
      _accQtyCtrl.text = item.accQty.toStringAsFixed(2);
      _convUom = item.podConvUom;
      _convUnitName = item.convUnitName;
      _convQtyCtrl.text = item.podConvQty.toStringAsFixed(2);
      _rateCtrl.text = item.rate.toStringAsFixed(2);
      _discCtrl.text = item.disc.toStringAsFixed(2);
      _amountCtrl.text = item.amount.toStringAsFixed(2);
      _freightCtrl.text = item.freight.toStringAsFixed(2);
      _cgPerCtrl.text = item.cgPer.toStringAsFixed(2);
      _cgAmtCtrl.text = item.cgAmt.toStringAsFixed(2);
      _sgPerCtrl.text = item.sgPer.toStringAsFixed(2);
      _sgAmtCtrl.text = item.sgAmt.toStringAsFixed(2);
      _igPerCtrl.text = item.igPer.toStringAsFixed(2);
      _igAmtCtrl.text = item.igAmt.toStringAsFixed(2);
      _netAmtCtrl.text = item.netAmt.toStringAsFixed(2);
      _hsn = item.hsn;
      _podStock = item.podStock;
      _podLastRate = item.podLastRate;
      _podMakeId = item.podMakeId;
      _makerName = item.makerName;

      if (item.iCode.isNotEmpty) {
        _loadMergesForItem(item.iCode);
      }
    }
  }

  Future<void> _loadShades() async {
    try {
      final shades = await widget.service.fetchShades();
      if (mounted) {
        setState(() {
          _availableShades = shades;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMergesForItem(String itemCode) async {
    setState(() => _isLoadingMerges = true);
    try {
      final list = await widget.service.fetchItemMerges(itemCode);
      if (mounted) {
        setState(() {
          _availableMerges = list;
          _isLoadingMerges = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMerges = false);
    }
  }

  Future<void> _openItemLookup() async {
    final selected = await showDialog<ItemLookupItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ItemLookupDialog(service: widget.service),
    );

    if (selected != null && mounted) {
      setState(() {
        _iCodeCtrl.text = selected.iCode;
        _itemNameCtrl.text = selected.itName;
        _hsn = selected.hsn;
        _uom = selected.unitCode;
        _unitName = selected.unitName;
        _podStock = selected.stock;
        _convUom = selected.secUcode;
        _convUnitName = selected.secUnit;
        _conversionFactor = selected.conversion > 0 ? selected.conversion : 1.0;
        _taxSlab = selected.taxSlab;
        _shadeCtrl.text = selected.shade.isNotEmpty ? selected.shade : '*';
        _mrgNoCtrl.text = selected.style;

        _recalculateTaxesFromSlab();
        _recalculateAll();
      });

      _loadMergesForItem(selected.iCode);
    }
  }

  void _recalculateTaxesFromSlab() {
    final isIntraState = widget.supplierStateCode.trim() == widget.companyStateCode.trim();
    if (isIntraState) {
      final half = _taxSlab / 2.0;
      _cgPerCtrl.text = half.toStringAsFixed(2);
      _sgPerCtrl.text = half.toStringAsFixed(2);
      _igPerCtrl.text = '0.00';
    } else {
      _cgPerCtrl.text = '0.00';
      _sgPerCtrl.text = '0.00';
      _igPerCtrl.text = _taxSlab.toStringAsFixed(2);
    }
  }

  void _recalculateAll() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final disc = double.tryParse(_discCtrl.text.trim()) ?? 0.0;
    final freight = double.tryParse(_freightCtrl.text.trim()) ?? 0.0;
    final cgPer = double.tryParse(_cgPerCtrl.text.trim()) ?? 0.0;
    final sgPer = double.tryParse(_sgPerCtrl.text.trim()) ?? 0.0;
    final igPer = double.tryParse(_igPerCtrl.text.trim()) ?? 0.0;

    final gross = qty * rate;
    final discountAmount = gross * (disc / 100.0);
    final taxableAmount = (gross - discountAmount).clamp(0.0, double.infinity);

    final cgAmt = taxableAmount * (cgPer / 100.0);
    final sgAmt = taxableAmount * (sgPer / 100.0);
    final igAmt = taxableAmount * (igPer / 100.0);
    final netAmt = taxableAmount + freight + cgAmt + sgAmt + igAmt;
    final convQty = qty * (_conversionFactor > 0 ? _conversionFactor : 1.0);

    _amountCtrl.text = taxableAmount.toStringAsFixed(2);
    _cgAmtCtrl.text = cgAmt.toStringAsFixed(2);
    _sgAmtCtrl.text = sgAmt.toStringAsFixed(2);
    _igAmtCtrl.text = igAmt.toStringAsFixed(2);
    _netAmtCtrl.text = netAmt.toStringAsFixed(2);
    _convQtyCtrl.text = convQty.toStringAsFixed(2);
  }

  void _onSaveRow() {
    final iCode = _iCodeCtrl.text.trim();
    if (iCode.isEmpty) {
      setState(() => _errorMessage = 'Please select a catalog item');
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    if (qty <= 0) {
      setState(() => _errorMessage = 'Quantity must be greater than zero');
      return;
    }

    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    if (rate < 0) {
      setState(() => _errorMessage = 'Rate cannot be negative');
      return;
    }

    setState(() {
      _errorMessage = null;
      _buttonStatus = ButtonStatus.loading;
    });

    final row = PurchaseOrderItem(
      pId: widget.existingItem?.pId ?? 0,
      poNo: widget.existingItem?.poNo ?? '',
      srNo: widget.srNo,
      iCode: iCode,
      itemName: _itemNameCtrl.text.trim(),
      hsn: _hsn,
      uom: _uom,
      unitName: _unitName,
      qty: qty,
      accQty: double.tryParse(_accQtyCtrl.text.trim()) ?? 0.0,
      rate: rate,
      disc: double.tryParse(_discCtrl.text.trim()) ?? 0.0,
      amount: double.tryParse(_amountCtrl.text.trim()) ?? 0.0,
      khCode: _selectedKhCode,
      divisionName: _selectedDivisionName,
      depCode: _selectedDepCode,
      deptName: _selectedDeptName,
      mrgNo: _mrgNoCtrl.text.trim(),
      shade: _shadeCtrl.text.trim().isNotEmpty ? _shadeCtrl.text.trim() : '*',
      pRemark: _pRemarkCtrl.text.trim(),
      freight: double.tryParse(_freightCtrl.text.trim()) ?? 0.0,
      podIsFreight: (double.tryParse(_freightCtrl.text.trim()) ?? 0.0) > 0 ? 1 : 0,
      cgPer: double.tryParse(_cgPerCtrl.text.trim()) ?? 0.0,
      cgAmt: double.tryParse(_cgAmtCtrl.text.trim()) ?? 0.0,
      sgPer: double.tryParse(_sgPerCtrl.text.trim()) ?? 0.0,
      sgAmt: double.tryParse(_sgAmtCtrl.text.trim()) ?? 0.0,
      igPer: double.tryParse(_igPerCtrl.text.trim()) ?? 0.0,
      igAmt: double.tryParse(_igAmtCtrl.text.trim()) ?? 0.0,
      netAmt: double.tryParse(_netAmtCtrl.text.trim()) ?? 0.0,
      podStock: _podStock,
      podLastRate: _podLastRate,
      podMakeId: _podMakeId,
      makerName: _makerName,
      podConvUom: _convUom,
      convUnitName: _convUnitName,
      podConvQty: double.tryParse(_convQtyCtrl.text.trim()) ?? qty,
      closePO: widget.existingItem?.closePO ?? false,
    );

    setState(() => _buttonStatus = ButtonStatus.success);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        Navigator.of(context).pop(row);
      }
    });
  }

  @override
  void dispose() {
    _iCodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _mrgNoCtrl.dispose();
    _shadeCtrl.dispose();
    _pRemarkCtrl.dispose();
    _qtyCtrl.dispose();
    _accQtyCtrl.dispose();
    _pendQtyCtrl.dispose();
    _convQtyCtrl.dispose();
    _rateCtrl.dispose();
    _discCtrl.dispose();
    _amountCtrl.dispose();
    _freightCtrl.dispose();
    _cgPerCtrl.dispose();
    _cgAmtCtrl.dispose();
    _sgPerCtrl.dispose();
    _sgAmtCtrl.dispose();
    _igPerCtrl.dispose();
    _igAmtCtrl.dispose();
    _netAmtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1040,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.tableBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralDark.withValues(alpha: 0.15),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDialogHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null) _buildErrorMessageBanner(),
                    _buildCatalogLookupSection(),
                    const SizedBox(height: 16),
                    _buildMergeAndShadeSection(),
                    const SizedBox(height: 16),
                    _buildDepartmentAndCostCenterSection(),
                    const SizedBox(height: 16),
                    _buildQuantityAndPricingSection(),
                    const SizedBox(height: 16),
                    _buildTaxesAndTotalSection(),
                  ],
                ),
              ),
            ),
            _buildDialogFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    final isEdit = widget.existingItem != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.tableHeaderBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryColor, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? 'Edit PO Line Item #${widget.srNo}' : 'Add PO Line Item #${widget.srNo}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.neutralDark,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Complete all 24 legacy columns with real-time tax and conversion calculation',
                style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.tableBorder.withValues(alpha: 0.5),
              hoverColor: AppColors.tableBorder,
            ),
            tooltip: 'Close Modal (Esc)',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessageBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.errorDark),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 14, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogLookupSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tableRowHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 16, color: AppColors.primaryColor),
              const SizedBox(width: 6),
              const Text(
                '1. ITEM CATALOG LOOKUP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryColor),
              ),
              const Spacer(),
              if (_podStock > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.successBorder),
                  ),
                  child: Text(
                    'Available Stock: ${_podStock.toStringAsFixed(2)} $_unitName',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.successDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item Code with Lookup trigger
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Item Code *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _iCodeCtrl,
                              readOnly: true,
                              onTap: _openItemLookup,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
                              decoration: InputDecoration(
                                hintText: 'Press Enter or Search',
                                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: _openItemLookup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.surfaceColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(38, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Icon(Icons.search_rounded, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Description
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Item Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _itemNameCtrl,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          hintText: 'Item name & specifications',
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // HSN & Primary Unit
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HSN Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    Container(
                      height: 38,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.tableBorder),
                      ),
                      child: Text(_hsn.isNotEmpty ? _hsn : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              SizedBox(
                width: 90,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UQC (Unit)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(_unitName.isNotEmpty ? _unitName : '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryColor)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMergeAndShadeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tableRowHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.palette_rounded, size: 16, color: AppColors.glowGold),
              SizedBox(width: 6),
              Text(
                '2. MERGE / STYLE, SHADE & REMARK',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Merge No / Style
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Merge / Lot No / Style', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                        if (_isLoadingMerges) ...[
                          const SizedBox(width: 6),
                          const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    _availableMerges.isNotEmpty
                        ? DropdownButtonFormField<String>(
                            isExpanded: true,
                            isDense: true,
                            initialValue: _availableMerges.any((m) => m.mergeLotNo == _mrgNoCtrl.text) ? _mrgNoCtrl.text : null,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.surfaceColor,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                            ),
                            items: _availableMerges.map((m) {
                              return DropdownMenuItem<String>(
                                value: m.mergeLotNo,
                                child: Text(
                                  '${m.mergeLotNo} ${m.maker.isNotEmpty ? "(${m.maker})" : ""}',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final matched = _availableMerges.firstWhere((m) => m.mergeLotNo == val);
                                setState(() {
                                  _mrgNoCtrl.text = val;
                                  if (matched.shade.isNotEmpty) _shadeCtrl.text = matched.shade;
                                  _makerName = matched.maker;
                                  _podMakeId = matched.makerCode;
                                });
                              }
                            },
                          )
                        : SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _mrgNoCtrl,
                              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                              decoration: InputDecoration(
                                hintText: 'Merge / Lot / Style number',
                                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Shade
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Shade / Color', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    _availableShades.isNotEmpty
                        ? Autocomplete<String>(
                            initialValue: TextEditingValue(text: _shadeCtrl.text),
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) return _availableShades;
                              return _availableShades.where((s) => s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                            },
                            onSelected: (selection) => _shadeCtrl.text = selection,
                            fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                              ctrl.text = _shadeCtrl.text;
                              ctrl.addListener(() => _shadeCtrl.text = ctrl.text);
                              return SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: ctrl,
                                  focusNode: focus,
                                  style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                                  decoration: InputDecoration(
                                    hintText: 'Shade code or *',
                                    hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                                    filled: true,
                                    fillColor: AppColors.surfaceColor,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                  ),
                                ),
                              );
                            },
                          )
                        : SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _shadeCtrl,
                              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                              decoration: InputDecoration(
                                hintText: 'Shade code (* default)',
                                hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Line Item Remark
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Item Remark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _pRemarkCtrl,
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          hintText: 'Line specific notes, instructions...',
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentAndCostCenterSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tableRowHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.apartment_rounded, size: 16, color: AppColors.glowCyan),
              SizedBox(width: 6),
              Text(
                '3. DEPARTMENT & COST CENTER / DIVISION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Department Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Department *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: widget.departments.any((d) => d.labCode == _selectedDepCode) ? _selectedDepCode : (widget.departments.isNotEmpty ? widget.departments.first.labCode : null),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: widget.departments.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.labCode,
                          child: Text(
                            d.labName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = widget.departments.firstWhere((d) => d.labCode == val);
                          setState(() {
                            _selectedDepCode = val;
                            _selectedDeptName = match.labName;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Cost Center / Division Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cost Center / Division *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      isDense: true,
                      initialValue: widget.divisions.any((d) => d.khCode == _selectedKhCode) ? _selectedKhCode : (widget.divisions.isNotEmpty ? widget.divisions.first.khCode : null),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                      items: widget.divisions.map((d) {
                        return DropdownMenuItem<int>(
                          value: d.khCode,
                          child: Text(
                            d.khName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          final match = widget.divisions.firstWhere((d) => d.khCode == val);
                          setState(() {
                            _selectedKhCode = val;
                            _selectedDivisionName = match.khName;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityAndPricingSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tableRowHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_rounded, size: 16, color: AppColors.primaryColor),
              SizedBox(width: 6),
              Text(
                '4. QUANTITY, CONVERSION & PRICING',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Qty
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Qty *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _qtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}'))],
                        onChanged: (_) => _recalculateAll(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Secondary Unit & Conv Qty
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conv. Unit (${_convUnitName.isNotEmpty ? _convUnitName : "Sec"})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _convQtyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}'))],
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Rate
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unit Rate *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _rateCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}'))],
                        onChanged: (_) => _recalculateAll(),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Disc %
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disc (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _discCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        onChanged: (_) => _recalculateAll(),
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Taxable Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _amountCtrl,
                        readOnly: true,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.tableBorder.withValues(alpha: 0.4),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Freight
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Line Freight', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _freightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                        onChanged: (_) => _recalculateAll(),
                        style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxesAndTotalSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tableRowHover,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 16, color: AppColors.tagIndigo),
              const SizedBox(width: 6),
              const Text(
                '5. TAXES (CGST, SGST, IGST) & NET AMOUNT',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
              const Spacer(),
              Text(
                widget.supplierStateCode == widget.companyStateCode ? 'Intrastate (CGST + SGST)' : 'Interstate (IGST)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.tagIndigo),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // CGST % and Amt
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CG (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _cgPerCtrl,
                              onChanged: (_) => _recalculateAll(),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CG Amt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _cgAmtCtrl,
                              readOnly: true,
                              style: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.tableBorder.withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // SGST % and Amt
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SG (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _sgPerCtrl,
                              onChanged: (_) => _recalculateAll(),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SG Amt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _sgAmtCtrl,
                              readOnly: true,
                              style: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.tableBorder.withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // IGST % and Amt
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IG (%)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _igPerCtrl,
                              onChanged: (_) => _recalculateAll(),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceColor,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('IG Amt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                          const SizedBox(height: 5),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _igAmtCtrl,
                              readOnly: true,
                              style: const TextStyle(fontSize: 12, color: AppColors.slateMuted),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.tableBorder.withValues(alpha: 0.3),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Net Amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net Line Amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryColor)),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _netAmtCtrl,
                        readOnly: true,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.primaryColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.primaryColor.withValues(alpha: 0.08),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryColor)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.tableHeaderBg,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border(top: BorderSide(color: AppColors.tableBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: const BorderSide(color: AppColors.tableBorder),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          PoAnimatedSuccessButton(
            status: _buttonStatus,
            onPressed: _onSaveRow,
            idleText: widget.existingItem != null ? 'Update Row' : 'Add Line Row',
            loadingText: 'Saving...',
            successText: widget.existingItem != null ? 'Row Updated!' : 'Row Added!',
            idleIcon: Icons.add_task_rounded,
            height: 40,
            fontSize: 12,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
