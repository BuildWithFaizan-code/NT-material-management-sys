import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';
import 'so_animated_success_button.dart';

class SoTermsModalDialog extends StatefulWidget {
  final List<SalesOrderCondition> initialConditions;

  const SoTermsModalDialog({
    super.key,
    required this.initialConditions,
  });

  @override
  State<SoTermsModalDialog> createState() => _SoTermsModalDialogState();
}

class _EditableConditionClause {
  int conNo;
  TextEditingController textCtrl;

  _EditableConditionClause({required this.conNo, required String text})
      : textCtrl = TextEditingController(text: text);

  void dispose() {
    textCtrl.dispose();
  }
}

class _SoTermsModalDialogState extends State<SoTermsModalDialog> {
  final List<_EditableConditionClause> _clauses = [];
  ButtonStatus _buttonStatus = ButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    if (widget.initialConditions.isNotEmpty) {
      for (final c in widget.initialConditions) {
        _clauses.add(_EditableConditionClause(
          conNo: c.conNo,
          text: c.conditionText,
        ));
      }
    } else {
      // Default common terms
      _clauses.add(_EditableConditionClause(conNo: 1, text: 'Goods once sold will not be taken back or exchanged.'));
      _clauses.add(_EditableConditionClause(conNo: 2, text: 'Payment is due within agreed credit days from invoice date.'));
      _clauses.add(_EditableConditionClause(conNo: 3, text: 'Interest @ 18% p.a. will be charged on overdue payments.'));
      _clauses.add(_EditableConditionClause(conNo: 4, text: 'All disputes subject to local jurisdiction only.'));
    }
  }

  @override
  void dispose() {
    for (final c in _clauses) {
      c.dispose();
    }
    super.dispose();
  }

  void _addClause() {
    setState(() {
      final nextNo = _clauses.isEmpty ? 1 : (_clauses.map((e) => e.conNo).reduce((a, b) => a > b ? a : b) + 1);
      _clauses.add(_EditableConditionClause(conNo: nextNo, text: ''));
    });
  }

  void _removeClause(int index) {
    setState(() {
      final removed = _clauses.removeAt(index);
      removed.dispose();
      // Re-number
      for (int i = 0; i < _clauses.length; i++) {
        _clauses[i].conNo = i + 1;
      }
    });
  }

  void _saveAndClose() {
    setState(() => _buttonStatus = ButtonStatus.loading);

    final List<SalesOrderCondition> result = [];
    for (int i = 0; i < _clauses.length; i++) {
      final text = _clauses[i].textCtrl.text.trim();
      if (text.isNotEmpty) {
        result.add(SalesOrderCondition(
          conNo: i + 1,
          conditionText: text,
        ));
      }
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
    final dialogWidth = (size.width * 0.75).clamp(650.0, 850.0);
    final dialogHeight = (size.height * 0.8).clamp(450.0, 650.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildClausesList()),
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
        color: AppColors.sidebarBackground.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.gavel_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Clauses and commercial conditions saved to ConditionDet',
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

  Widget _buildClausesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Commercial Clauses (${_clauses.length})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              ElevatedButton.icon(
                onPressed: _addClause,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Clause'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: _clauses.isEmpty
              ? const Center(
                  child: Text('No terms added. Click "Add Clause" above.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _clauses.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _clauses[index];

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Text(
                            '#${item.conNo}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: item.textCtrl,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Enter condition clause...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          onPressed: () => _removeClause(index),
                          tooltip: 'Remove Clause',
                          splashRadius: 18,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
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
          SoAnimatedSuccessButton(
            status: _buttonStatus,
            onPressed: _saveAndClose,
            idleText: 'Save Terms',
            successText: 'Saved!',
            idleIcon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}
