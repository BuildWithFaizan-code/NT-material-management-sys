import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../purchase_order_models.dart';
import 'po_animated_success_button.dart';

/// Auxiliary modal for editing Additional Duties, Taxes, Freight, Insurance,
/// Discounts & TCS with explicit (+ / -) ADDLESS toggles.
class PoChargesModalDialog extends StatefulWidget {
  final double orderGrossAmount;
  final List<PurchaseOrderCharge> currentCharges;
  final List<ChargesMasterLookupItem> defaultChargesMaster;

  const PoChargesModalDialog({
    super.key,
    required this.orderGrossAmount,
    required this.currentCharges,
    required this.defaultChargesMaster,
  });

  @override
  State<PoChargesModalDialog> createState() => _PoChargesModalDialogState();
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

class _PoChargesModalDialogState extends State<PoChargesModalDialog> {
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
      // Prefill from default charges if any
      for (final m in widget.defaultChargesMaster) {
        _rows.add(_EditableChargeRow(
          chgId: m.chgId,
          chgName: m.chgName,
          per: m.disc,
          amt: 0.0,
          remark: '',
          addLess: m.addLess,
          exp: m.exp,
        ));
      }
    }
  }

  void _recalcAmountFromPer(_EditableChargeRow row) {
    final per = double.tryParse(row.perCtrl.text.trim()) ?? 0.0;
    if (per != 0 && widget.orderGrossAmount > 0) {
      final calculated = widget.orderGrossAmount * (per / 100.0);
      row.amtCtrl.text = calculated.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _recalcPerFromAmount(_EditableChargeRow row) {
    final amt = double.tryParse(row.amtCtrl.text.trim()) ?? 0.0;
    if (widget.orderGrossAmount > 0) {
      final per = (amt / widget.orderGrossAmount) * 100.0;
      row.perCtrl.text = per.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _addNewCharge() {
    setState(() {
      _rows.add(_EditableChargeRow(
        chgId: 0,
        chgName: 'Other Charge',
        per: 0.0,
        amt: 0.0,
        remark: '',
        addLess: 1,
        exp: '',
      ));
    });
  }

  void _removeRow(int index) {
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  double get _totalAdditions {
    return _rows
        .where((r) => r.addLess == 1)
        .fold(0.0, (sum, r) => sum + (double.tryParse(r.amtCtrl.text.trim()) ?? 0.0));
  }

  double get _totalDeductions {
    return _rows
        .where((r) => r.addLess == -1)
        .fold(0.0, (sum, r) => sum + (double.tryParse(r.amtCtrl.text.trim()) ?? 0.0));
  }

  double get _netImpact => _totalAdditions - _totalDeductions;

  void _onApply() {
    setState(() => _buttonStatus = ButtonStatus.loading);

    final results = <PurchaseOrderCharge>[];
    for (int i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      final amt = double.tryParse(r.amtCtrl.text.trim()) ?? 0.0;
      final per = double.tryParse(r.perCtrl.text.trim()) ?? 0.0;
      if (amt != 0 || per != 0) {
        results.add(PurchaseOrderCharge(
          id: i + 1,
          chgId: r.chgId,
          chgName: r.chgName,
          per: per,
          amt: amt,
          addLess: r.addLess,
          exp: r.exp,
          remark: r.remarkCtrl.text.trim(),
        ));
      }
    }

    setState(() => _buttonStatus = ButtonStatus.success);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).pop(results);
      }
    });
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 620),
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.tableBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralDark.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildOrderGrossBanner(),
            Expanded(
              child: _rows.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(18),
                      itemCount: _rows.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _buildChargeRowCard(_rows[i], i),
                    ),
            ),
            _buildSummaryBar(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            child: const Icon(Icons.tune_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Additional Duties & Charges',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
              SizedBox(height: 2),
              Text(
                'Configure Freight, Insurance, Discount, TCS with Add/Less (+ / -) rules',
                style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _addNewCharge,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Charge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondaryColor,
              foregroundColor: AppColors.surfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderGrossBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      color: AppColors.primaryColor.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primaryColor),
          const SizedBox(width: 6),
          Text(
            'Base Order Gross Amount for % calculation: ₹ ${widget.orderGrossAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.layers_clear_rounded, size: 38, color: AppColors.slateMuted),
          const SizedBox(height: 8),
          const Text('No charges or duties added yet', style: TextStyle(fontSize: 13, color: AppColors.slateMuted)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _addNewCharge,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: AppColors.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Add First Charge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChargeRowCard(_EditableChargeRow row, int index) {
    final isAdd = row.addLess == 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tableBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Explicit ADD/LESS Toggle Button
          InkWell(
            onTap: () {
              setState(() {
                row.addLess = isAdd ? -1 : 1;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isAdd ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isAdd ? AppColors.successBorder : AppColors.errorBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isAdd ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
                      size: 14, color: isAdd ? AppColors.success : AppColors.error),
                  const SizedBox(width: 4),
                  Text(
                    isAdd ? '+ ADD' : '- LESS',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: isAdd ? AppColors.successDark : AppColors.errorDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Charge Name Selector / Text
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Charge Name', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
                const SizedBox(height: 4),
                widget.defaultChargesMaster.isNotEmpty
                    ? DropdownButtonFormField<int>(
                        isExpanded: true,
                        isDense: true,
                        initialValue: widget.defaultChargesMaster.any((m) => m.chgId == row.chgId) ? row.chgId : null,
                        decoration: InputDecoration(
                          hintText: row.chgName.isNotEmpty ? row.chgName : 'Select Charge',
                          filled: true,
                          fillColor: AppColors.tableRowHover,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        ),
                        items: widget.defaultChargesMaster.map((m) {
                          return DropdownMenuItem<int>(
                            value: m.chgId,
                            child: Text(
                              m.chgName,
                              style: const TextStyle(fontSize: 11.5),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final match = widget.defaultChargesMaster.firstWhere((m) => m.chgId == val);
                            setState(() {
                              row.chgId = match.chgId;
                              row.chgName = match.chgName;
                              row.addLess = match.addLess;
                              if (match.disc > 0) {
                                row.perCtrl.text = match.disc.toStringAsFixed(2);
                                _recalcAmountFromPer(row);
                              }
                            });
                          }
                        },
                      )
                    : SizedBox(
                        height: 36,
                        child: TextField(
                          onChanged: (val) => row.chgName = val,
                          controller: TextEditingController(text: row.chgName),
                          style: const TextStyle(fontSize: 11.5),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.tableRowHover,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Percentage %
          SizedBox(
            width: 85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Rate (%)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: row.perCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (_) => _recalcAmountFromPer(row),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.tableRowHover,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Amount
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount (₹)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: row.amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (_) => _recalcPerFromAmount(row),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: isAdd ? AppColors.successDark : AppColors.errorDark,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.tableRowHover,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Remark
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Remark', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: row.remarkCtrl,
                    style: const TextStyle(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'Notes...',
                      hintStyle: const TextStyle(fontSize: 10.5, color: AppColors.slateMuted),
                      filled: true,
                      fillColor: AppColors.tableRowHover,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Delete Action
          IconButton(
            onPressed: () => _removeRow(index),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.errorLight,
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(28, 28),
            ),
            tooltip: 'Remove Charge',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.tableRowHover,
        border: Border(top: BorderSide(color: AppColors.tableBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Additions (+): ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
              Text('₹ ${_totalAdditions.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(width: 18),
              const Text('Deductions (-): ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slateMuted)),
              Text('₹ ${_totalDeductions.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
            ],
          ),
          Row(
            children: [
              const Text('Net Impact on PO: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark)),
              Text(
                '${_netImpact >= 0 ? "+" : ""} ₹ ${_netImpact.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _netImpact >= 0 ? AppColors.primaryColor : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
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
            onPressed: _onApply,
            idleText: 'Apply Charges',
            loadingText: 'Applying...',
            successText: 'Applied!',
            idleIcon: Icons.check_circle_outline_rounded,
            height: 38,
            fontSize: 12,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }
}
