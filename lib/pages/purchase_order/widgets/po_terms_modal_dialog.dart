import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../purchase_order_models.dart';
import 'po_animated_success_button.dart';

class PoTermsResult {
  final String dTerms;
  final String pTerms;
  final String dispIns;
  final String spNote;
  final String remark;
  final List<PurchaseOrderCondition> conditions;

  const PoTermsResult({
    required this.dTerms,
    required this.pTerms,
    required this.dispIns,
    required this.spNote,
    required this.remark,
    required this.conditions,
  });
}

/// Modal dialog for managing Terms & Conditions, Contractual Clauses,
/// Delivery/Payment Terms, and Dispatch Instructions.
class PoTermsModalDialog extends StatefulWidget {
  final String initialDTerms;
  final String initialPTerms;
  final String initialDispIns;
  final String initialSpNote;
  final String initialRemark;
  final List<PurchaseOrderCondition> initialConditions;
  final PurchaseOrderLookupsData lookups;

  const PoTermsModalDialog({
    super.key,
    required this.initialDTerms,
    required this.initialPTerms,
    required this.initialDispIns,
    required this.initialSpNote,
    required this.initialRemark,
    required this.initialConditions,
    required this.lookups,
  });

  @override
  State<PoTermsModalDialog> createState() => _PoTermsModalDialogState();
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

class _PoTermsModalDialogState extends State<PoTermsModalDialog> {
  late final TextEditingController _dTermsCtrl;
  late final TextEditingController _pTermsCtrl;
  late final TextEditingController _dispInsCtrl;
  late final TextEditingController _spNoteCtrl;
  late final TextEditingController _remarkCtrl;
  final List<_EditableConditionClause> _clauses = [];
  ButtonStatus _buttonStatus = ButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    _dTermsCtrl = TextEditingController(text: widget.initialDTerms);
    _pTermsCtrl = TextEditingController(text: widget.initialPTerms);
    _dispInsCtrl = TextEditingController(text: widget.initialDispIns);
    _spNoteCtrl = TextEditingController(text: widget.initialSpNote);
    _remarkCtrl = TextEditingController(text: widget.initialRemark);

    if (widget.initialConditions.isNotEmpty) {
      for (final c in widget.initialConditions) {
        _clauses.add(_EditableConditionClause(conNo: c.conNo, text: c.conditionText));
      }
    } else {
      // Default common contractual terms
      _clauses.add(_EditableConditionClause(conNo: 1, text: 'Goods must strictly conform to specifications and inspection criteria.'));
      _clauses.add(_EditableConditionClause(conNo: 2, text: 'Payment will be released strictly as per credit terms upon accepted delivery.'));
      _clauses.add(_EditableConditionClause(conNo: 3, text: 'Dispatch must be accompanied with valid E-way bill and original tax invoice.'));
    }
  }

  void _addClause() {
    setState(() {
      _clauses.add(_EditableConditionClause(
        conNo: _clauses.length + 1,
        text: '',
      ));
    });
  }

  void _removeClause(int index) {
    setState(() {
      final removed = _clauses.removeAt(index);
      removed.dispose();
      // Re-index remaining
      for (int i = 0; i < _clauses.length; i++) {
        _clauses[i].conNo = i + 1;
      }
    });
  }

  void _onApply() {
    setState(() => _buttonStatus = ButtonStatus.loading);

    final conditions = <PurchaseOrderCondition>[];
    for (int i = 0; i < _clauses.length; i++) {
      final text = _clauses[i].textCtrl.text.trim();
      if (text.isNotEmpty) {
        conditions.add(PurchaseOrderCondition(
          conNo: i + 1,
          conditionText: text,
        ));
      }
    }

    final result = PoTermsResult(
      dTerms: _dTermsCtrl.text.trim(),
      pTerms: _pTermsCtrl.text.trim(),
      dispIns: _dispInsCtrl.text.trim(),
      spNote: _spNoteCtrl.text.trim(),
      remark: _remarkCtrl.text.trim(),
      conditions: conditions,
    );

    setState(() => _buttonStatus = ButtonStatus.success);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  void dispose() {
    _dTermsCtrl.dispose();
    _pTermsCtrl.dispose();
    _dispInsCtrl.dispose();
    _spNoteCtrl.dispose();
    _remarkCtrl.dispose();
    for (final c in _clauses) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 680),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSuggestedField(
                      title: 'Delivery Terms (DTerms)',
                      controller: _dTermsCtrl,
                      hint: 'e.g. Door delivery within 7 working days',
                      suggestions: widget.lookups.deliveryTermsSuggestions,
                      icon: Icons.local_shipping_outlined,
                    ),
                    const SizedBox(height: 14),
                    _buildSuggestedField(
                      title: 'Payment Terms (PTerms)',
                      controller: _pTermsCtrl,
                      hint: 'e.g. 30 days credit from invoice date',
                      suggestions: widget.lookups.paymentTermsSuggestions,
                      icon: Icons.credit_card_outlined,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSuggestedField(
                            title: 'Dispatch Instructions',
                            controller: _dispInsCtrl,
                            hint: 'e.g. Send via BlueDart Express',
                            suggestions: widget.lookups.dispatchInstructionsSuggestions,
                            icon: Icons.send_outlined,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSuggestedField(
                            title: 'Special Notes',
                            controller: _spNoteCtrl,
                            hint: 'e.g. Handle with fragile tags',
                            suggestions: widget.lookups.specialNotesSuggestions,
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildSuggestedField(
                      title: 'General Header Remark',
                      controller: _remarkCtrl,
                      hint: 'e.g. Urgent plant requirement',
                      suggestions: widget.lookups.remarksSuggestions,
                      icon: Icons.notes_rounded,
                    ),
                    const SizedBox(height: 20),
                    _buildConditionClausesSection(),
                  ],
                ),
              ),
            ),
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
            child: const Icon(Icons.gavel_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms & Conditions & Contractual Clauses',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
              SizedBox(height: 2),
              Text(
                'Configure delivery & payment terms, dispatch guidelines, and custom condition list',
                style: TextStyle(fontSize: 11, color: AppColors.slateMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
            tooltip: 'Close Modal',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedField({
    required String title,
    required TextEditingController controller,
    required String hint,
    required List<String> suggestions,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.primaryColor),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
            filled: true,
            fillColor: AppColors.tableRowHover,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: suggestions.take(4).map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 10, color: AppColors.primaryColor)),
                backgroundColor: AppColors.secondaryColor.withValues(alpha: 0.1),
                side: BorderSide(color: AppColors.secondaryColor.withValues(alpha: 0.2)),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                onPressed: () {
                  controller.text = s;
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildConditionClausesSection() {
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
              const Icon(Icons.format_list_numbered_rounded, size: 16, color: AppColors.glowGold),
              const SizedBox(width: 6),
              const Text(
                'CONTRACTUAL CONDITIONS LIST (ConditionDet)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _addClause,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: const Text('Add Clause', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryColor,
                  foregroundColor: AppColors.surfaceColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _clauses.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final clause = _clauses[i];
              return Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${clause.conNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: clause.textCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Enter contractual clause #${clause.conNo}...',
                        hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                        filled: true,
                        fillColor: AppColors.surfaceColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.tableBorder)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _removeClause(i),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                    tooltip: 'Remove Clause',
                  ),
                ],
              );
            },
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
            idleText: 'Save Terms',
            loadingText: 'Saving...',
            successText: 'Terms Saved!',
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
