import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../material_return_models.dart';
import '../material_return_service.dart';
import 'material_return_item_lookup_modal.dart';

/// Modal for adding / editing a line item in Material Return.
/// STRICT REQUIREMENT: Contains EXACTLY the 21 fields matching the 21 columns of the line item grid.
class AddMaterialReturnRowDialog extends StatefulWidget {
  final MaterialReturnService service;
  final DateTime date;
  final int sourceDept;
  final int sourceStore;
  final int sourceDiv;
  final MaterialReturnLineItem? initialItem;
  final int nextSrNo;
  final ValueChanged<MaterialReturnLineItem> onSave;

  const AddMaterialReturnRowDialog({
    super.key,
    required this.service,
    required this.date,
    required this.sourceDept,
    required this.sourceStore,
    required this.sourceDiv,
    this.initialItem,
    required this.nextSrNo,
    required this.onSave,
  });

  @override
  State<AddMaterialReturnRowDialog> createState() => _AddMaterialReturnRowDialogState();
}

class _AddMaterialReturnRowDialogState extends State<AddMaterialReturnRowDialog> {
  // EXACTLY 21 CONTROLLERS CORRESPONDING TO THE 21 COLUMNS
  late final TextEditingController _srNoCtrl; // 1: srno
  final TextEditingController _itemCodeCtrl = TextEditingController(); // 2: Item Code
  final TextEditingController _itemNameCtrl = TextEditingController(); // 3: Item Name
  final TextEditingController _hsnCtrl = TextEditingController(); // 4: HSN
  final TextEditingController _mrgNoCtrl = TextEditingController(); // 5: Merge No.
  final TextEditingController _gradeCtrl = TextEditingController(); // 6: Grade
  final TextEditingController _shadeCtrl = TextEditingController(); // 7: Shade
  final TextEditingController _makerCtrl = TextEditingController(); // 8: Maker
  final TextEditingController _uqcCtrl = TextEditingController(); // 9: UQC
  final TextEditingController _qtyCtrl = TextEditingController(text: '1.00'); // 10: Qty
  final TextEditingController _rateCtrl = TextEditingController(text: '0.00'); // 11: Rate
  final TextEditingController _amountCtrl = TextEditingController(text: '0.00'); // 12: Amount
  final TextEditingController _copsCtrl = TextEditingController(text: '0'); // 13: Cops
  final TextEditingController _stockCtrl = TextEditingController(text: '0.00'); // 14: Stock
  final TextEditingController _cgstCtrl = TextEditingController(text: '0.00'); // 15: CGST (%)
  final TextEditingController _cgstAmtCtrl = TextEditingController(text: '0.00'); // 16: CGST_Amt
  final TextEditingController _sgstCtrl = TextEditingController(text: '0.00'); // 17: SGST (%)
  final TextEditingController _sgstAmtCtrl = TextEditingController(text: '0.00'); // 18: SGST_Amt
  final TextEditingController _igstCtrl = TextEditingController(text: '0.00'); // 19: IGST (%)
  final TextEditingController _igstAmtCtrl = TextEditingController(text: '0.00'); // 20: IGST_Amt
  final TextEditingController _netAmtCtrl = TextEditingController(text: '0.00'); // 21: Net_Amt

  // Additional persistence fields
  String _binNo = '';
  String _convUom = '';
  double _convQty = 0.0;
  String _rcopsType = '';
  String _retRemark = '';
  double _cut = 0.0;

  String? _validationError;

  @override
  void initState() {
    super.initState();
    final sr = widget.initialItem?.srNo ?? widget.nextSrNo;
    _srNoCtrl = TextEditingController(text: sr.toString());

    if (widget.initialItem != null) {
      final it = widget.initialItem!;
      _itemCodeCtrl.text = it.itemCode;
      _itemNameCtrl.text = it.itemName;
      _hsnCtrl.text = it.hsn;
      _mrgNoCtrl.text = it.mrgNo;
      _gradeCtrl.text = it.grade;
      _shadeCtrl.text = it.shade;
      _makerCtrl.text = it.maker;
      _uqcCtrl.text = it.uqc;
      _qtyCtrl.text = it.qty.toStringAsFixed(2);
      _rateCtrl.text = it.rate.toStringAsFixed(2);
      _amountCtrl.text = it.amount.toStringAsFixed(2);
      _copsCtrl.text = it.cops.toString();
      _stockCtrl.text = it.stock.toStringAsFixed(2);
      _cgstCtrl.text = it.cgst.toStringAsFixed(2);
      _cgstAmtCtrl.text = it.cgstAmt.toStringAsFixed(2);
      _sgstCtrl.text = it.sgst.toStringAsFixed(2);
      _sgstAmtCtrl.text = it.sgstAmt.toStringAsFixed(2);
      _igstCtrl.text = it.igst.toStringAsFixed(2);
      _igstAmtCtrl.text = it.igstAmt.toStringAsFixed(2);
      _netAmtCtrl.text = it.netAmt.toStringAsFixed(2);

      _binNo = it.binNo;
      _convUom = it.convUom;
      _convQty = it.convQty;
      _rcopsType = it.rcopsType;
      _retRemark = it.retRemark;
      _cut = it.cut;
    }

    _qtyCtrl.addListener(_recalculateAll);
    _rateCtrl.addListener(_recalculateAll);
    _cgstCtrl.addListener(_recalculateAll);
    _sgstCtrl.addListener(_recalculateAll);
    _igstCtrl.addListener(_recalculateAll);
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_recalculateAll);
    _rateCtrl.removeListener(_recalculateAll);
    _cgstCtrl.removeListener(_recalculateAll);
    _sgstCtrl.removeListener(_recalculateAll);
    _igstCtrl.removeListener(_recalculateAll);

    _srNoCtrl.dispose();
    _itemCodeCtrl.dispose();
    _itemNameCtrl.dispose();
    _hsnCtrl.dispose();
    _mrgNoCtrl.dispose();
    _gradeCtrl.dispose();
    _shadeCtrl.dispose();
    _makerCtrl.dispose();
    _uqcCtrl.dispose();
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _amountCtrl.dispose();
    _copsCtrl.dispose();
    _stockCtrl.dispose();
    _cgstCtrl.dispose();
    _cgstAmtCtrl.dispose();
    _sgstCtrl.dispose();
    _sgstAmtCtrl.dispose();
    _igstCtrl.dispose();
    _igstAmtCtrl.dispose();
    _netAmtCtrl.dispose();
    super.dispose();
  }

  void _recalculateAll() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final cgstRate = double.tryParse(_cgstCtrl.text.trim()) ?? 0.0;
    final sgstRate = double.tryParse(_sgstCtrl.text.trim()) ?? 0.0;
    final igstRate = double.tryParse(_igstCtrl.text.trim()) ?? 0.0;

    final amount = (qty * rate * 100).round() / 100.0;
    final cgstAmt = (amount * cgstRate / 100.0 * 100).round() / 100.0;
    final sgstAmt = (amount * sgstRate / 100.0 * 100).round() / 100.0;
    final igstAmt = (amount * igstRate / 100.0 * 100).round() / 100.0;
    final netAmt = ((amount + cgstAmt + sgstAmt + igstAmt) * 100).round() / 100.0;

    _amountCtrl.text = amount.toStringAsFixed(2);
    _cgstAmtCtrl.text = cgstAmt.toStringAsFixed(2);
    _sgstAmtCtrl.text = sgstAmt.toStringAsFixed(2);
    _igstAmtCtrl.text = igstAmt.toStringAsFixed(2);
    _netAmtCtrl.text = netAmt.toStringAsFixed(2);
  }

  void _openItemLookup() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => MaterialReturnItemLookupModal(
        service: widget.service,
        date: widget.date,
        sourceDept: widget.sourceDept,
        sourceStore: widget.sourceStore,
        sourceDiv: widget.sourceDiv,
        onSelect: (item) {
          setState(() {
            _itemCodeCtrl.text = item.itemCode;
            _itemNameCtrl.text = item.itemName;
            _hsnCtrl.text = item.hsnCode;
            _mrgNoCtrl.text = item.mrgNo;
            _gradeCtrl.text = item.matGrade;
            _shadeCtrl.text = item.matShade;
            _makerCtrl.text = item.matMaker;
            _uqcCtrl.text = item.uom;
            _rateCtrl.text = item.avgRate > 0 ? item.avgRate.toStringAsFixed(2) : '0.00';
            _stockCtrl.text = item.balanceQty.toStringAsFixed(2);
            _copsCtrl.text = item.cops.toString();
            _cgstCtrl.text = item.cgper.toStringAsFixed(2);
            _sgstCtrl.text = item.sgper.toStringAsFixed(2);
            _igstCtrl.text = item.igper.toStringAsFixed(2);

            _binNo = item.binNo;
            _convUom = item.convUom;
            _convQty = item.convQty;
            _validationError = null;
          });
          _recalculateAll();
        },
      ),
    );
  }

  void _handleSubmit() {
    final itemCode = _itemCodeCtrl.text.trim();
    final itemName = _itemNameCtrl.text.trim();
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    if (itemCode.isEmpty) {
      setState(() => _validationError = 'Please select an item from the catalog.');
      return;
    }
    if (qty <= 0) {
      setState(() => _validationError = 'Return Quantity must be greater than 0.');
      return;
    }

    final srNo = int.tryParse(_srNoCtrl.text.trim()) ?? widget.nextSrNo;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? (qty * rate);
    final cops = int.tryParse(_copsCtrl.text.trim()) ?? 0;
    final stock = double.tryParse(_stockCtrl.text.trim()) ?? 0.0;
    final cgst = double.tryParse(_cgstCtrl.text.trim()) ?? 0.0;
    final cgstAmt = double.tryParse(_cgstAmtCtrl.text.trim()) ?? 0.0;
    final sgst = double.tryParse(_sgstCtrl.text.trim()) ?? 0.0;
    final sgstAmt = double.tryParse(_sgstAmtCtrl.text.trim()) ?? 0.0;
    final igst = double.tryParse(_igstCtrl.text.trim()) ?? 0.0;
    final igstAmt = double.tryParse(_igstAmtCtrl.text.trim()) ?? 0.0;
    final netAmt = double.tryParse(_netAmtCtrl.text.trim()) ?? (amount + cgstAmt + sgstAmt + igstAmt);

    final line = MaterialReturnLineItem(
      srNo: srNo,
      itemCode: itemCode,
      itemName: itemName,
      hsn: _hsnCtrl.text.trim(),
      mrgNo: _mrgNoCtrl.text.trim(),
      grade: _gradeCtrl.text.trim(),
      shade: _shadeCtrl.text.trim(),
      maker: _makerCtrl.text.trim(),
      uqc: _uqcCtrl.text.trim(),
      qty: qty,
      rate: rate,
      amount: amount,
      cops: cops,
      stock: stock,
      cgst: cgst,
      cgstAmt: cgstAmt,
      sgst: sgst,
      sgstAmt: sgstAmt,
      igst: igst,
      igstAmt: igstAmt,
      netAmt: netAmt,
      binNo: _binNo,
      convUom: _convUom,
      convQty: _convQty,
      rcopsType: _rcopsType,
      retRemark: _retRemark,
      cut: _cut,
    );

    widget.onSave(line);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        width: 1040,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.playlist_add_rounded, color: AppColors.secondaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.initialItem != null ? 'Edit Line Item' : 'Add Return Line Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: const Text(
                      'Exact 21 Grid Columns',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Form Body (Exactly 21 Columns with live math)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_validationError != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _validationError!,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Section 1: Item Identification (Columns 1 to 5)
                    _buildSectionHeader('1. Identification & Attributes', Icons.tag_rounded),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Column 1: srno
                        SizedBox(
                          width: 80,
                          child: _buildFormField('1. Sr No', _srNoCtrl, readOnly: true),
                        ),
                        const SizedBox(width: 12),
                        // Column 2: Item Code with Search action
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('2. Item Code *', style: _labelStyle),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: _itemCodeCtrl,
                                  readOnly: true,
                                  onTap: _openItemLookup,
                                  decoration: _inputDecoration(
                                    hint: 'Tap to select item',
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search, size: 18, color: AppColors.secondaryColor),
                                      onPressed: _openItemLookup,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Column 3: Item Name
                        Expanded(
                          flex: 5,
                          child: _buildFormField('3. Item Name', _itemNameCtrl, readOnly: true, hint: 'Select item code above'),
                        ),
                        const SizedBox(width: 12),
                        // Column 4: HSN
                        Expanded(
                          flex: 2,
                          child: _buildFormField('4. HSN', _hsnCtrl, hint: 'HSN code'),
                        ),
                        const SizedBox(width: 12),
                        // Column 5: Merge No.
                        Expanded(
                          flex: 2,
                          child: _buildFormField('5. Merge No.', _mrgNoCtrl, hint: 'Merge No'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Section 2: Quality & Specifications (Columns 6 to 9)
                    _buildSectionHeader('2. Item Specifications & UQC', Icons.tune_rounded),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Column 6: Grade
                        Expanded(child: _buildFormField('6. Grade', _gradeCtrl, hint: 'Grade')),
                        const SizedBox(width: 12),
                        // Column 7: Shade
                        Expanded(child: _buildFormField('7. Shade', _shadeCtrl, hint: 'Shade')),
                        const SizedBox(width: 12),
                        // Column 8: Maker
                        Expanded(child: _buildFormField('8. Maker', _makerCtrl, hint: 'Maker')),
                        const SizedBox(width: 12),
                        // Column 9: UQC
                        Expanded(child: _buildFormField('9. UQC', _uqcCtrl, hint: 'Unit (KGS/PCS)')),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Section 3: Quantity, Valuation & Stock (Columns 10 to 14)
                    _buildSectionHeader('3. Quantity, Valuation & Stock', Icons.calculate_outlined),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Column 10: Qty
                        Expanded(
                          child: _buildFormField(
                            '10. Return Qty *',
                            _qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0.00',
                            isHighlighted: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Column 11: Rate
                        Expanded(
                          child: _buildFormField(
                            '11. Rate *',
                            _rateCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0.00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Column 12: Amount (Calculated)
                        Expanded(
                          child: _buildFormField(
                            '12. Amount (Gross)',
                            _amountCtrl,
                            readOnly: true,
                            hint: '0.00',
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Column 13: Cops
                        Expanded(
                          child: _buildFormField(
                            '13. Cops',
                            _copsCtrl,
                            keyboardType: TextInputType.number,
                            hint: '0',
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Column 14: Stock
                        Expanded(
                          child: _buildFormField(
                            '14. Current Stock',
                            _stockCtrl,
                            readOnly: true,
                            hint: '0.00',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Section 4: Taxes & Net Amount (Columns 15 to 21)
                    _buildSectionHeader('4. Taxes & Net Calculation', Icons.receipt_long_outlined),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Column 15: CGST %
                        Expanded(
                          child: _buildFormField(
                            '15. CGST %',
                            _cgstCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0.00',
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Column 16: CGST_Amt
                        Expanded(
                          child: _buildFormField('16. CGST Amt', _cgstAmtCtrl, readOnly: true, hint: '0.00'),
                        ),
                        const SizedBox(width: 10),
                        // Column 17: SGST %
                        Expanded(
                          child: _buildFormField(
                            '17. SGST %',
                            _sgstCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0.00',
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Column 18: SGST_Amt
                        Expanded(
                          child: _buildFormField('18. SGST Amt', _sgstAmtCtrl, readOnly: true, hint: '0.00'),
                        ),
                        const SizedBox(width: 10),
                        // Column 19: IGST %
                        Expanded(
                          child: _buildFormField(
                            '19. IGST %',
                            _igstCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            hint: '0.00',
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Column 20: IGST_Amt
                        Expanded(
                          child: _buildFormField('20. IGST Amt', _igstAmtCtrl, readOnly: true, hint: '0.00'),
                        ),
                        const SizedBox(width: 12),
                        // Column 21: Net_Amt
                        Expanded(
                          flex: 2,
                          child: _buildFormField(
                            '21. Net Amount (₹)',
                            _netAmtCtrl,
                            readOnly: true,
                            isHighlighted: true,
                            hint: '0.00',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  const Text(
                    'All 21 columns configured with live tax & valuation math.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _handleSubmit,
                    icon: const Icon(Icons.check, size: 17, color: Colors.white),
                    label: Text(
                      widget.initialItem != null ? 'Update Row' : 'Add Row to Grid',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.secondaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    );
  }

  Widget _buildFormField(
    String label,
    TextEditingController controller, {
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    bool isHighlighted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 4),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted ? AppColors.secondaryColor : const Color(0xFF0F172A),
            ),
            decoration: _inputDecoration(
              hint: hint,
              fillColor: readOnly ? const Color(0xFFF1F5F9) : (isHighlighted ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC)),
              borderColor: isHighlighted ? const Color(0xFF86EFAC) : null,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    String? hint,
    Widget? suffixIcon,
    Color? fillColor,
    Color? borderColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: fillColor ?? const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor ?? const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
      ),
    );
  }
}

const TextStyle _labelStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: Color(0xFF475569),
);
