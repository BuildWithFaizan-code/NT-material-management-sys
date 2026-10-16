import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';
import 'so_animated_success_button.dart';

class SoChargesModalDialog extends StatefulWidget {
  final double orderGrossAmount;
  final List<SalesOrderCharge> currentCharges;
  final List<SalesOrderCharge> defaultChargesMaster;

  const SoChargesModalDialog({
    super.key,
    required this.orderGrossAmount,
    required this.currentCharges,
    required this.defaultChargesMaster,
  });

  @override
  State<SoChargesModalDialog> createState() => _SoChargesModalDialogState();
}

class _EditableChargeRow {
  int chgId;
  String chgName;
  TextEditingController perCtrl;
  TextEditingController amtCtrl;
  TextEditingController remarkCtrl;
  int addLess; // 1 = Add, -1 = Less
  String exp;

  _EditableChargeRow({
    required this.chgId,
    required this.chgName,
    required double per,
    required double amt,
    required String remark,
    required this.addLess,
    required this.exp,
  })  : perCtrl = TextEditingController(text: per.toStringAsFixed(2)),
        amtCtrl = TextEditingController(text: amt.toStringAsFixed(2)),
        remarkCtrl = TextEditingController(text: remark);

  void dispose() {
    perCtrl.dispose();
    amtCtrl.dispose();
    remarkCtrl.dispose();
  }
}

class _SoChargesModalDialogState extends State<SoChargesModalDialog> {
  final List<_EditableChargeRow> _rows = [];
  ButtonStatus _buttonStatus = ButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    _initializeRows();
  }

  void _initializeRows() {
    if (widget.currentCharges.isNotEmpty) {
      for (final c in widget.currentCharges) {
        _rows.add(_EditableChargeRow(
          chgId: c.chgId,
          chgName: c.chgName,
          per: c.per,
          amt: c.amt,
          remark: c.remark,
          addLess: c.addLess != 0 ? c.addLess : 1,
          exp: c.exp,
        ));
      }
    } else {
      for (final m in widget.defaultChargesMaster) {
        _rows.add(_EditableChargeRow(
          chgId: m.chgId,
          chgName: m.chgName,
          per: m.per,
          amt: m.amt,
          remark: m.remark,
          addLess: m.addLess,
          exp: m.exp,
        ));
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _onPerChanged(_EditableChargeRow row) {
    final per = double.tryParse(row.perCtrl.text.trim()) ?? 0.0;
    if (per != 0.0) {
      final calculatedAmt = (widget.orderGrossAmount * per) / 100.0;
      row.amtCtrl.text = calculatedAmt.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onAmtChanged(_EditableChargeRow row) {
    final amt = double.tryParse(row.amtCtrl.text.trim()) ?? 0.0;
    if (widget.orderGrossAmount > 0.0 && amt != 0.0) {
      final calculatedPer = (amt / widget.orderGrossAmount) * 100.0;
      row.perCtrl.text = calculatedPer.toStringAsFixed(2);
    }
    setState(() {});
  }

  double get _totalChargesEffect {
    double total = 0.0;
    for (final r in _rows) {
      final amt = double.tryParse(r.amtCtrl.text.trim()) ?? 0.0;
      total += (amt * r.addLess);
    }
    return total;
  }

  void _saveAndClose() {
    setState(() => _buttonStatus = ButtonStatus.loading);

    final List<SalesOrderCharge> result = [];
    for (final r in _rows) {
      final per = double.tryParse(r.perCtrl.text.trim()) ?? 0.0;
      final amt = double.tryParse(r.amtCtrl.text.trim()) ?? 0.0;

      result.add(SalesOrderCharge(
        chgId: r.chgId,
        chgName: r.chgName,
        per: per,
        amt: amt,
        remark: r.remarkCtrl.text.trim(),
        addLess: r.addLess,
        exp: r.exp,
      ));
    }

    setState(() => _buttonStatus = ButtonStatus.success);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.75).clamp(650.0, 900.0);
    final dialogHeight = (size.height * 0.8).clamp(480.0, 680.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
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
        child: Column(
          children: [
            _buildHeader(),
            _buildGrossBanner(),
            Expanded(child: _buildChargesTable()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.calculate_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales Order Duties & Additional Charges',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Configure standard and itemized duties, taxes, freight, and additions/deductions',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildGrossBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Items Gross Amount: ', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              Text(
                '₹ ${widget.orderGrossAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          Row(
            children: [
              const Text('Net Additional Effect: ', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              Text(
                '${_totalChargesEffect >= 0 ? '+' : ''} ₹ ${_totalChargesEffect.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _totalChargesEffect >= 0 ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChargesTable() {
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No charges configured in system master', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.3)),
      itemBuilder: (context, index) {
        final r = _rows[index];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              // Add / Less Toggle
              InkWell(
                onTap: () {
                  setState(() {
                    r.addLess = r.addLess == 1 ? -1 : 1;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: r.addLess == 1
                        ? AppColors.success.withOpacity(0.12)
                        : AppColors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: r.addLess == 1 ? AppColors.success : AppColors.error,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      r.addLess == 1 ? '+' : '−',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: r.addLess == 1 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Charge Name
              Expanded(
                flex: 4,
                child: Text(
                  r.chgName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              // Percentage
              SizedBox(
                width: 90,
                child: TextField(
                  controller: r.perCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    suffixText: '%',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
                  ),
                  onChanged: (_) => _onPerChanged(r),
                ),
              ),
              const SizedBox(width: 12),
              // Amount
              SizedBox(
                width: 120,
                child: TextField(
                  controller: r.amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
                  ),
                  onChanged: (_) => _onAmtChanged(r),
                ),
              ),
              const SizedBox(width: 12),
              // Remark
              Expanded(
                flex: 3,
                child: TextField(
                  controller: r.remarkCtrl,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Notes...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Final Net Total: ₹ ${(widget.orderGrossAmount + _totalChargesEffect).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
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
              SoAnimatedSuccessButton(
                status: _buttonStatus,
                onPressed: _saveAndClose,
                idleText: 'Apply Charges',
                successText: 'Applied!',
                idleIcon: Icons.check_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
