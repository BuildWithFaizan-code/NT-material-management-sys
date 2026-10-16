import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';
import '../sales_order_service.dart';
import 'item_lookup_dialog.dart';

class AddSoRowDialog extends StatefulWidget {
  final SalesOrderService service;
  final List<LookupCodeName> costCenters;
  final SalesOrderItem? initialItem;
  final int nextSrNo;
  final ValueChanged<SalesOrderItem> onSave;

  const AddSoRowDialog({
    super.key,
    required this.service,
    required this.costCenters,
    this.initialItem,
    required this.nextSrNo,
    required this.onSave,
  });

  @override
  State<AddSoRowDialog> createState() => _AddSoRowDialogState();
}

class _AddSoRowDialogState extends State<AddSoRowDialog> {
  final _formKey = GlobalKey<FormState>();

  String _iCode = '';
  String _itemName = '';
  int _uom = 0;
  String _unitName = '';
  int _khCode = 0;
  String _divisionName = '';

  final TextEditingController _qtyCtrl = TextEditingController(text: '1.0');
  final TextEditingController _rateCtrl = TextEditingController(text: '0.0');
  final TextEditingController _discCtrl = TextEditingController(text: '0.0');
  final TextEditingController _specCtrl = TextEditingController();

  double _calculatedAmount = 0.0;
  String? _itemError;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      final it = widget.initialItem!;
      _iCode = it.iCode;
      _itemName = it.itemName;
      _uom = it.uom;
      _unitName = it.unitName;
      _khCode = it.khCode;
      _divisionName = it.divisionName;
      _qtyCtrl.text = it.qty.toString();
      _rateCtrl.text = it.rate.toString();
      _discCtrl.text = it.disc.toString();
      _specCtrl.text = it.specification;
      _calculatedAmount = it.amount;
    } else {
      if (widget.costCenters.isNotEmpty) {
        _khCode = widget.costCenters.first.code;
        _divisionName = widget.costCenters.first.name;
      }
      _recalculate();
    }

    _qtyCtrl.addListener(_recalculate);
    _rateCtrl.addListener(_recalculate);
    _discCtrl.addListener(_recalculate);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _discCtrl.dispose();
    _specCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final disc = double.tryParse(_discCtrl.text.trim()) ?? 0.0;

    final gross = qty * rate;
    final net = (gross - disc).clamp(0.0, double.infinity);

    setState(() {
      _calculatedAmount = net;
    });
  }

  void _openItemLookup() async {
    final selected = await showDialog<SalesOrderItemLookup>(
      context: context,
      builder: (_) => ItemLookupDialog(service: widget.service),
    );

    if (selected != null) {
      setState(() {
        _iCode = selected.iCode;
        _itemName = selected.iName;
        _uom = selected.unitCode;
        _unitName = selected.unitName;
        _itemError = null;
      });
    }
  }

  void _submit() {
    if (_iCode.isEmpty) {
      setState(() {
        _itemError = 'Please select an item from the catalog';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
    final disc = double.tryParse(_discCtrl.text.trim()) ?? 0.0;

    final rowItem = SalesOrderItem(
      soNo: widget.initialItem?.soNo ?? '',
      srNo: widget.initialItem?.srNo ?? widget.nextSrNo,
      iCode: _iCode,
      itemName: _itemName,
      uom: _uom,
      unitName: _unitName,
      qty: qty,
      accQty: widget.initialItem?.accQty ?? 0.0,
      rate: rate,
      disc: disc,
      amount: _calculatedAmount,
      isAppro: widget.initialItem?.isAppro ?? false,
      isRec: widget.initialItem?.isRec ?? false,
      isReject: widget.initialItem?.isReject ?? false,
      isHold: widget.initialItem?.isHold ?? false,
      khCode: _khCode,
      divisionName: _divisionName,
      depCode: widget.initialItem?.depCode ?? 0,
      deptName: widget.initialItem?.deptName ?? '',
      mrgNo: widget.initialItem?.mrgNo ?? '',
      specification: _specCtrl.text.trim(),
      closeSo: widget.initialItem?.closeSo ?? false,
    );

    widget.onSave(rowItem);
    Navigator.of(context).pop(rowItem);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialItem != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 600,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isEditing),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildItemSelector(),
                    if (_itemError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _itemError!,
                        style: const TextStyle(color: AppColors.error, fontSize: 11.5),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildDivisionDropdown(),
                    const SizedBox(height: 16),
                    _buildQtyRateDiscRow(),
                    const SizedBox(height: 16),
                    _buildCalculatedAmountCard(),
                    const SizedBox(height: 16),
                    _buildSpecificationField(),
                  ],
                ),
              ),
              _buildFooter(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sidebarBackground.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            isEditing ? 'Edit Line Item #${widget.initialItem!.srNo}' : 'Add Sales Order Line Item',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelector() {
    final hasItem = _iCode.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _itemError != null ? AppColors.error : AppColors.divider.withOpacity(0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasItem ? _itemName : 'Select Item from Catalog *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: hasItem ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                if (hasItem) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Code: $_iCode',
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryColor, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Unit: ${_unitName.isNotEmpty ? _unitName : 'N/A'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _openItemLookup,
            icon: const Icon(Icons.search_rounded, size: 16),
            label: Text(hasItem ? 'Change' : 'Browse'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisionDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Division / Cost Center',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _khCode > 0 ? _khCode : (widget.costCenters.isNotEmpty ? widget.costCenters.first.code : null),
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              items: widget.costCenters.map((cc) {
                return DropdownMenuItem<int>(
                  value: cc.code,
                  child: Text(cc.name),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  final found = widget.costCenters.firstWhere((e) => e.code == val);
                  setState(() {
                    _khCode = found.code;
                    _divisionName = found.name;
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQtyRateDiscRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quantity *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                  suffixText: _unitName.isNotEmpty ? _unitName : null,
                ),
                validator: (val) {
                  final v = double.tryParse(val?.trim() ?? '');
                  if (v == null || v <= 0) return 'Required > 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rate (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                ),
                validator: (val) {
                  final v = double.tryParse(val?.trim() ?? '');
                  if (v == null || v < 0) return 'Required >= 0';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Discount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _discCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
                ),
                validator: (val) {
                  final v = double.tryParse(val?.trim() ?? '');
                  if (v == null || v < 0) return 'Invalid';
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatedAmountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Line Amount (Net = Qty × Rate − Disc):',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          Text(
            '₹ ${_calculatedAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Specification / Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _specCtrl,
          maxLines: 2,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter technical specifications, batch criteria, or notes...',
            hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.divider)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isEditing) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: Icon(isEditing ? Icons.save_rounded : Icons.add_rounded, size: 16),
            label: Text(isEditing ? 'Update Item' : 'Add to Order'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}
