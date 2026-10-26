import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../indent_models.dart';
import '../indent_service.dart';
import 'indent_item_lookup_dialog.dart';

/// Medium-Size Add Row Dialog with EXACTLY 11 Fields Corresponding to 11 Columns
class AddIndentRowDialog extends StatefulWidget {
  final IndentService service;
  final int nextSrno;
  final int defaultDeptCode;
  final List<IndentDepartmentLookup> departments;
  final List<IndentCostCenterLookup> costCenters;
  final DateTime defaultReqDate;
  final IndentDetail? initialRow;
  final bool showRate;

  const AddIndentRowDialog({
    super.key,
    required this.service,
    required this.nextSrno,
    required this.defaultDeptCode,
    required this.departments,
    required this.costCenters,
    required this.defaultReqDate,
    this.initialRow,
    this.showRate = true,
  });

  @override
  State<AddIndentRowDialog> createState() => _AddIndentRowDialogState();
}

class _AddIndentRowDialogState extends State<AddIndentRowDialog> {
  final _formKey = GlobalKey<FormState>();

  // 11 Exact Fields Matching 11 Table Columns
  late int _srno; // 1. SrNo
  final String _reqNo = 'None'; // 2. Req No
  String _code = ''; // 3. Code
  String _itemName = ''; // 4. Item Name
  int _selectedKhCode = 0; // 5. Cost Center
  int _uom = 0; // 6. UQC
  String _uomName = ''; // 6. UQC Name
  final TextEditingController _qtyCtrl = TextEditingController(text: '1'); // 7. Qty/Pcs
  final TextEditingController _rateCtrl = TextEditingController(text: '0'); // 8. Rate
  double _totalValue = 0.0; // 9. Total Value
  int _selectedDeptCode = 0; // 10. Department
  late DateTime _reqDate; // 11. Req. Date

  // Stock Threshold Auxiliaries
  double _stock = 0.0;
  double _minQty = 0.0;
  double _maxQty = 0.0;
  double _orderOn = 0.0;
  String? _validationError;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    if (widget.initialRow != null) {
      final r = widget.initialRow!;
      _srno = r.srno;
      _code = r.code;
      _itemName = r.itemName;
      _uom = r.uom;
      _uomName = r.uomName;
      _selectedKhCode = r.khCode;
      _selectedDeptCode = r.deptCode;
      _reqDate = r.reqDate;
      _qtyCtrl.text = r.qty.toString();
      _rateCtrl.text = r.rate.toString();
      _totalValue = r.totalValue;
      _stock = r.stock;
      _minQty = r.minQty;
      _maxQty = r.maxQty;
      _orderOn = r.orderOn;
    } else {
      _srno = widget.nextSrno;
      _selectedDeptCode = widget.defaultDeptCode > 0
          ? widget.defaultDeptCode
          : (widget.departments.isNotEmpty ? widget.departments.first.labCode : 0);
      _selectedKhCode = widget.costCenters.isNotEmpty ? widget.costCenters.first.khCode : 0;
      _reqDate = widget.defaultReqDate;
      _calculateTotal();
    }

    _qtyCtrl.addListener(_calculateTotal);
    _rateCtrl.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    setState(() {
      _totalValue = (qty * rate);
    });
  }

  Future<void> _openItemSearch() async {
    final item = await showDialog<IndentItemLookup>(
      context: context,
      barrierDismissible: true,
      builder: (_) => IndentItemLookupDialog(service: widget.service),
    );

    if (item != null) {
      setState(() {
        _code = item.iCode;
        _itemName = item.itName;
        _uom = item.unitCode;
        _uomName = item.unitName;
        _stock = item.stk;
        _minQty = item.minQty;
        _maxQty = item.maxQty;
        _orderOn = item.orderOn;
        _validationError = null;
      });
    }
  }

  void _submit() {
    if (_code.isEmpty) {
      setState(() => _validationError = 'Please select an item from catalog (Column 3).');
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    if (qty <= 0) {
      setState(() => _validationError = 'Quantity must be greater than zero (Column 7).');
      return;
    }

    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    String deptName = '';
    final deptMatch = widget.departments.where((d) => d.labCode == _selectedDeptCode);
    if (deptMatch.isNotEmpty) {
      deptName = deptMatch.first.labName;
    }

    String khName = '';
    final khMatch = widget.costCenters.where((k) => k.khCode == _selectedKhCode);
    if (khMatch.isNotEmpty) {
      khName = khMatch.first.khName;
    }

    final detail = IndentDetail(
      indCode: '',
      srno: _srno,
      reqNo: _reqNo,
      code: _code,
      itemName: _itemName,
      khCode: _selectedKhCode,
      costCenterName: khName,
      uom: _uom,
      uomName: _uomName,
      qty: qty,
      rate: rate,
      totalValue: _totalValue,
      deptCode: _selectedDeptCode,
      deptName: deptName,
      reqDate: _reqDate,
      stock: _stock,
      minQty: _minQty,
      maxQty: _maxQty,
      orderOn: _orderOn,
    );

    Navigator.of(context).pop(detail);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 920,
        constraints: const BoxConstraints(maxWidth: 960),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // MODAL HEADER
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_add_rounded, color: Color(0xFF0C3B2E), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialRow != null ? 'Edit Indent Line Item' : 'Add Indent Line Item',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text('Enter exact line item columns for material requisition',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0C3B2E).withValues(alpha: 0.2)),
                      ),
                      child: Text('Row #$_srno',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E))),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // INLINE VALIDATION BANNER (ZERO SNACKBARS)
              if (_validationError != null)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_validationError!,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Color(0xFFDC2626)),
                        onPressed: () => setState(() => _validationError = null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

              // STOCK THRESHOLD SUMMARY CARD
              if (_code.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStockMetric('CURRENT STOCK', _stock.toStringAsFixed(2), _stock <= _minQty ? Colors.redAccent : const Color(0xFF166534)),
                      _buildStockMetric('REORDER LEVEL', _orderOn.toStringAsFixed(2), const Color(0xFF0F766E)),
                      _buildStockMetric('MIN QTY', _minQty.toStringAsFixed(2), const Color(0xFF475569)),
                      _buildStockMetric('MAX QTY', _maxQty.toStringAsFixed(2), const Color(0xFF475569)),
                    ],
                  ),
                ),

              // FORM CONTENT (EXACT 11 COLUMNS)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // ROW 1: (1) SrNo, (2) Req No, (3) Item Code, (4) Item Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. SrNo
                          SizedBox(
                            width: 75,
                            child: _buildReadOnlyBox('1. SrNo', '$_srno'),
                          ),
                          const SizedBox(width: 12),

                          // 2. Req No
                          SizedBox(
                            width: 110,
                            child: _buildReadOnlyBox('2. Req No', _reqNo),
                          ),
                          const SizedBox(width: 12),

                          // 3. Item Code *
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('3. Item Code *',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _openItemSearch,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _code.isEmpty ? Colors.red.shade300 : AppColors.divider),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _code.isEmpty ? 'Click to select...' : _code,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: _code.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF0C3B2E),
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 4. Item Name *
                          Expanded(
                            flex: 5,
                            child: _buildReadOnlyBox('4. Item Name', _itemName.isEmpty ? 'Select item above' : _itemName),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ROW 2: (5) Cost Center, (6) UQC, (10) Department, (11) Req. Date
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 5. Cost Center
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('5. Cost Center (KHATAMST)',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: widget.costCenters.any((k) => k.khCode == _selectedKhCode) ? _selectedKhCode : null,
                                      isExpanded: true,
                                      hint: const Text('None (General)', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                      items: [
                                        const DropdownMenuItem<int>(
                                          value: 0,
                                          child: Text('0 - None (General Plant)', style: TextStyle(fontSize: 12)),
                                        ),
                                        ...widget.costCenters.map((k) {
                                          return DropdownMenuItem<int>(
                                            value: k.khCode,
                                            child: Text('${k.khCode} - ${k.khName}',
                                                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                          );
                                        }),
                                      ],
                                      onChanged: (val) => setState(() => _selectedKhCode = val ?? 0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 6. UQC
                          SizedBox(
                            width: 110,
                            child: _buildReadOnlyBox('6. UQC', _uomName.isEmpty ? '-' : '$_uom ($_uomName)'),
                          ),
                          const SizedBox(width: 12),

                          // 10. Department
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('10. Department',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.divider),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: widget.departments.any((d) => d.labCode == _selectedDeptCode) ? _selectedDeptCode : null,
                                      isExpanded: true,
                                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
                                      items: widget.departments.map((d) {
                                        return DropdownMenuItem<int>(
                                          value: d.labCode,
                                          child: Text(d.labName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setState(() => _selectedDeptCode = val);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 11. Req. Date
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('11. Req. Date',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _reqDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2035),
                                    );
                                    if (picked != null) {
                                      setState(() => _reqDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 40,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 14, color: Color(0xFF64748B)),
                                        const SizedBox(width: 8),
                                        Text(_formatDate(_reqDate),
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ROW 3: (7) Qty/Pcs, (8) Rate, (9) Total Value (Strict Real-Time Calculation)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 7. Qty/Pcs *
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('7. Qty / Pcs *',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: TextField(
                                      controller: _qtyCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // 8. Rate
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.showRate ? '8. Unit Rate (₹)' : '8. Unit Rate (Hidden)',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: widget.showRate ? Colors.white : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: TextField(
                                      controller: _rateCtrl,
                                      enabled: widget.showRate,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: widget.showRate ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        hintText: widget.showRate ? '0.00' : '••••',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // 9. Total Value (Strict Real-Time Calculated: Qty * Rate)
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('9. Total Value (Real-Time)',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF5EE),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      widget.showRate ? '₹ ${_totalValue.toStringAsFixed(2)}' : '••••',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0C3B2E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ACTION BUTTONS FOOTER
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: Text(
                        widget.initialRow != null ? 'Update Row' : 'Add Row to Indent',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
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

  Widget _buildReadOnlyBox(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  Widget _buildStockMetric(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
