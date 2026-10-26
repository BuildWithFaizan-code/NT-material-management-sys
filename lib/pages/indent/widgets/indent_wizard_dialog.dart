import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../../bom/bom_models.dart';
import '../../bom/widgets/bom_animated_success_button.dart';
import '../indent_models.dart';
import '../indent_service.dart';
import 'add_indent_row_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Big Box Wizard Dialog with BOM Step Progress Bar Header (1, 2, 3)
class IndentWizardDialog extends StatefulWidget {
  final IndentService service;
  final VoidCallback onSaved;
  final IndentHeader? initialIndent;

  const IndentWizardDialog({
    super.key,
    required this.service,
    required this.onSaved,
    this.initialIndent,
  });

  @override
  State<IndentWizardDialog> createState() => _IndentWizardDialogState();
}

class _IndentWizardDialogState extends State<IndentWizardDialog> {
  // Wizard Step: 1 = Header Setup, 2 = Line Items / Add Row, 3 = Summary & Calculations
  int _currentStep = 1;

  // Master Initial Data
  bool _isLoadingMasters = true;
  String? _masterError;
  IndentLookups? _lookups;

  // Header 14 Form Fields State
  String _previewIndentCode = 'INDE/000000/27'; // 1. Indent No.
  DateTime _indDate = DateTime.now(); // 2. Date
  String _source = 'Manual'; // 3. Source
  int? _selectedDeptCode; // 4. Indenting Department
  int? _selectedStoreCode; // 5. Location / Store
  int _selectedCapMode = 3; // 6. Mode (from LOCATIONMST WHERE MODE = 'CAPCONS')
  String _priority = 'Normal'; // 7. Priority
  String _minMaxThreshold = 'All Items'; // 8. Min / Max threshold
  final TextEditingController _currentStockCtrl = TextEditingController(text: '0.00'); // 9. Current Stock
  final TextEditingController _reorderOnCtrl = TextEditingController(text: '0.00'); // 10. ReOrder On
  final TextEditingController _minQtyCtrl = TextEditingController(text: '0.00'); // 11. Min Qty/Pcs
  final TextEditingController _maxQtyCtrl = TextEditingController(text: '0.00'); // 12. Max Qty/Pcs
  bool _showRate = true; // 13. Show Rate Action Control
  final TextEditingController _remarkCtrl = TextEditingController(); // 14. Remark
  List<String> _remarkSuggestions = [];

  // Step 2: Line Items (Each has 11 Columns)
  final List<IndentDetail> _lines = [];
  List<IndentCostCenterLookup> _costCenters = [];
  bool _isLoadingCostCenters = false;

  // Save / Button Success State
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _saveErrorMessage;
  String? _savedIndentCode;
  String? _validationBannerMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialIndent != null) {
      final i = widget.initialIndent!;
      _previewIndentCode = i.indCode;
      _indDate = i.indDate;
      _source = i.source.isNotEmpty ? i.source : 'Manual';
      _selectedDeptCode = i.deptCode;
      _selectedStoreCode = i.storeCode;
      _selectedCapMode = i.indCapMode > 0 ? i.indCapMode : 3;
      _priority = i.priority.isNotEmpty ? i.priority : 'Normal';
      _remarkCtrl.text = i.remark;
      _lines.addAll(i.items);
      _updateHeaderFromLines();
    }
    _loadMasters();
  }

  @override
  void dispose() {
    _currentStockCtrl.dispose();
    _reorderOnCtrl.dispose();
    _minQtyCtrl.dispose();
    _maxQtyCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _isLoadingMasters = true;
      _masterError = null;
    });

    try {
      final data = await widget.service.fetchLookups();
      if (!mounted) return;

      setState(() {
        _lookups = data;
        if (widget.initialIndent == null) {
          _previewIndentCode = data.nextIndNo.isNotEmpty ? data.nextIndNo : 'INDE/000000/27';
          if (data.departments.isNotEmpty) {
            _selectedDeptCode = data.departments.first.labCode;
          }
          if (data.stores.isNotEmpty) {
            _selectedStoreCode = data.stores.first.strCode;
          }
          if (data.capModes.isNotEmpty) {
            _selectedCapMode = data.capModes.first.locCode;
          }
        }
        _isLoadingMasters = false;
      });

      _loadCostCenters();
    } catch (e) {
      if (mounted) {
        setState(() {
          _masterError = e.toString().replaceAll('ApiException: ', '');
          _isLoadingMasters = false;
        });
      }
    }
  }

  Future<void> _loadCostCenters() async {
    setState(() => _isLoadingCostCenters = true);
    try {
      final list = await widget.service.fetchCostCenters(_selectedStoreCode ?? 0);
      if (mounted) {
        setState(() {
          _costCenters = list;
          _isLoadingCostCenters = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCostCenters = false);
    }
  }

  // Aggregate Calculations for Step 3
  double get _totQty => _lines.fold(0.0, (acc, line) => acc + line.qty);
  double get _totAmt => _lines.fold(0.0, (acc, line) => acc + line.totalValue);
  double get _avgRate => _lines.isEmpty || _totQty == 0 ? 0.0 : (_totAmt / _totQty);

  void _openAddRowDialog({IndentDetail? editRow}) {
    showDialog<IndentDetail>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddIndentRowDialog(
        service: widget.service,
        nextSrno: editRow?.srno ?? (_lines.length + 1),
        defaultDeptCode: _selectedDeptCode ?? 0,
        departments: _lookups?.departments ?? [],
        costCenters: _costCenters,
        defaultReqDate: _indDate,
        initialRow: editRow,
        showRate: _showRate,
      ),
    ).then((newRow) {
      if (newRow != null) {
        setState(() {
          if (editRow != null) {
            final idx = _lines.indexWhere((l) => l.srno == editRow.srno);
            if (idx != -1) _lines[idx] = newRow;
          } else {
            _lines.add(newRow);
          }
          _updateHeaderFromLines();
        });
      }
    });
  }

  void _updateHeaderFromLines() {
    if (_lines.isNotEmpty) {
      final last = _lines.last;
      _currentStockCtrl.text = last.stock.toStringAsFixed(2);
      _reorderOnCtrl.text = last.orderOn.toStringAsFixed(2);
      _minQtyCtrl.text = last.minQty.toStringAsFixed(2);
      _maxQtyCtrl.text = last.maxQty.toStringAsFixed(2);
    }
  }

  void _deleteRow(int index) {
    setState(() {
      _lines.removeAt(index);
      for (int i = 0; i < _lines.length; i++) {
        _lines[i] = _lines[i].copyWith(srno: i + 1);
      }
      _updateHeaderFromLines();
    });
  }

  void _validateAndProceedToStep2() {
    if (_selectedDeptCode == null || _selectedDeptCode == 0) {
      setState(() => _validationBannerMessage = 'Please select an Indenting Department (Field 4).');
      return;
    }
    if (_selectedStoreCode == null || _selectedStoreCode == 0) {
      setState(() => _validationBannerMessage = 'Please select a Location / Store (Field 5).');
      return;
    }
    setState(() {
      _validationBannerMessage = null;
      _currentStep = 2;
    });
  }

  void _validateAndProceedToStep3() {
    if (_lines.isEmpty) {
      setState(() => _validationBannerMessage = 'Please add at least one line item (Step 2) to continue.');
      return;
    }
    setState(() {
      _validationBannerMessage = null;
      _currentStep = 3;
    });
  }

  Future<void> _saveIndent() async {
    if (_lines.isEmpty) {
      setState(() => _validationBannerMessage = 'Please add at least one line item before saving.');
      return;
    }

    setState(() {
      _saveButtonStatus = ButtonStatus.loading;
      _saveErrorMessage = null;
      _validationBannerMessage = null;
    });

    try {
      final payload = IndentSavePayload(
        indDate: _indDate,
        deptCode: _selectedDeptCode ?? 0,
        storeCode: _selectedStoreCode ?? 0,
        priority: _priority,
        source: _source,
        remark: _remarkCtrl.text.trim().isEmpty ? 'Direct Indent Entry' : _remarkCtrl.text.trim(),
        capMode: _selectedCapMode,
        items: _lines.map((l) => IndentLineItemPayload(
          srno: l.srno,
          reqNo: l.reqNo,
          code: l.code,
          description: l.itemName,
          uom: l.uom,
          qty: l.qty,
          rate: l.rate,
          totalValue: l.totalValue,
          khCode: l.khCode,
          deptCode: l.deptCode,
          reqDate: l.reqDate,
        )).toList(),
      );

      final String result;
      if (widget.initialIndent != null) {
        result = await widget.service.updateIndent(widget.initialIndent!.indCode, payload);
      } else {
        result = await widget.service.saveIndent(payload);
      }
      if (!mounted) return;

      setState(() {
        _saveButtonStatus = ButtonStatus.success;
        _savedIndentCode = result.isNotEmpty ? result : _previewIndentCode;
      });

      widget.onSaved();

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveButtonStatus = ButtonStatus.idle;
          _saveErrorMessage = e.toString().replaceAll('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f1): () {
          if (_currentStep == 3 && _saveButtonStatus != ButtonStatus.loading) {
            _saveIndent();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            width: 1300,
            height: 790,
            constraints: const BoxConstraints(maxWidth: 1360, maxHeight: 860),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  // 1. TOP HEADER WITH BOM PROGRESS BAR (STEP 1, 2, 3)
                  _buildWizardHeaderBar(),

                  // 2. INLINE VALIDATION BANNER (ZERO SNACKBARS)
                  if (_validationBannerMessage != null)
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFEF2F2),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _validationBannerMessage!,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                            onPressed: () => setState(() => _validationBannerMessage = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                  // 3. STEP VIEW CONTENT
                  Expanded(
                    child: _isLoadingMasters
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(width: 36, height: 36, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0C3B2E))),
                                SizedBox(height: 14),
                                Text('Loading Indent Setup Masters...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              ],
                            ),
                          )
                        : _masterError != null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                    const SizedBox(height: 10),
                                    Text('Error: $_masterError', style: const TextStyle(color: Colors.redAccent)),
                                    const SizedBox(height: 14),
                                    ElevatedButton(onPressed: _loadMasters, child: const Text('Retry')),
                                  ],
                                ),
                              )
                            : _buildActiveStepBody(),
                  ),

                  // 4. STEP ACTION FOOTER
                  _buildWizardFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // BOM STEP PROGRESS BAR (COMPACT 3-STEP MATCHING BOM SCREEN)
  // ============================================================================
  Widget _buildWizardHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Title on left
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.note_alt_outlined, color: Color(0xFF0C3B2E), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialIndent != null ? 'Edit Indent Voucher' : 'Create Indent Voucher',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    _savedIndentCode != null ? 'Voucher Generated: $_savedIndentCode' : 'Sequence: $_previewIndentCode',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // CENTER: BOM PROGRESS STEP BAR (1, 2, 3)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepNode(
                stepNumber: '1',
                title: 'HEADER SETUP',
                subtitle: 'Voucher & store',
                isActive: _currentStep == 1,
                isCompleted: _currentStep > 1,
                onTap: () => setState(() => _currentStep = 1),
              ),
              _buildConnectorLine(isActive: _currentStep >= 2),
              _buildStepNode(
                stepNumber: '2',
                title: 'LINE ITEMS',
                subtitle: 'Add row & catalog',
                isActive: _currentStep == 2,
                isCompleted: _currentStep > 2,
                onTap: () {
                  if (_selectedDeptCode != null && _selectedStoreCode != null) {
                    setState(() => _currentStep = 2);
                  }
                },
              ),
              _buildConnectorLine(isActive: _currentStep >= 3),
              _buildStepNode(
                stepNumber: '3',
                title: 'SUMMARY & CALC',
                subtitle: 'Calculations & save',
                isActive: _currentStep == 3,
                isCompleted: _saveButtonStatus == ButtonStatus.success,
                onTap: () {
                  if (_lines.isNotEmpty) {
                    setState(() => _currentStep = 3);
                  }
                },
              ),
            ],
          ),

          const Spacer(),

          // Close button
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorLine({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 8, right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 2.2,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0C3B2E) : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildStepNode({
    required String stepNumber,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    final Color barColor = isActive
        ? const Color(0xFF0C3B2E)
        : (isCompleted ? const Color(0xFF10B981) : const Color(0xFFCBD5E1));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Step Indicator with Halo Glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? const Color(0xFF0C3B2E)
                    : (isCompleted ? const Color(0xFF10B981) : Colors.white),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFF86EFAC)
                      : (isCompleted ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                  width: 1.6,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0C3B2E).withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: isCompleted
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text(
                      stepNumber,
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF475569),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 3),

            // Indicator pill bars (Image 2 BOM style)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 2.4,
              decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(1.5)),
            ),
            const SizedBox(height: 2),

            // Step Title & Subtext
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? const Color(0xFF0C3B2E) : const Color(0xFF64748B),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // STEP ROUTER
  // ============================================================================
  Widget _buildActiveStepBody() {
    switch (_currentStep) {
      case 1:
        return _buildStep1HeaderForm();
      case 2:
        return _buildStep2LineItems();
      case 3:
      default:
        return _buildStep3SummaryCalculations();
    }
  }

  // ============================================================================
  // STEP 1: HEADER FORM (EXACT 14 FIELDS)
  // ============================================================================
  Widget _buildStep1HeaderForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CARD 1: Basic Identifiers & Logistics
          _buildFormSectionCard(
            title: '1. Identification & Logistics Details',
            icon: Icons.badge_outlined,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Indent No.
                  Expanded(
                    flex: 3,
                    child: _buildReadOnlyHeaderField('1. Indent No. (Auto Sequence)', _previewIndentCode, Icons.receipt_long_outlined),
                  ),
                  const SizedBox(width: 14),

                  // 2. Date
                  Expanded(
                    flex: 3,
                    child: _buildDatePickerField('2. Indent Date *', _indDate, (picked) {
                      setState(() => _indDate = picked);
                    }),
                  ),
                  const SizedBox(width: 14),

                  // 3. Source
                  Expanded(
                    flex: 3,
                    child: _buildDropdownField<String>(
                      label: '3. Source',
                      value: _source,
                      items: const ['Manual', 'Requisition', 'Direct', 'MRP'],
                      itemLabel: (s) => s,
                      onChanged: (val) => setState(() => _source = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4. Indenting Department
                  Expanded(
                    flex: 4,
                    child: _buildDropdownField<int>(
                      label: '4. Indenting Department (LABOURMST) *',
                      value: _selectedDeptCode,
                      items: _lookups?.departments.map((d) => d.labCode).toList() ?? [],
                      itemLabel: (code) {
                        final m = _lookups?.departments.where((d) => d.labCode == code);
                        return m != null && m.isNotEmpty ? m.first.labName : '$code';
                      },
                      onChanged: (val) => setState(() => _selectedDeptCode = val),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 5. Location / Store
                  Expanded(
                    flex: 4,
                    child: _buildDropdownField<int>(
                      label: '5. Location / Store (STOREMST) *',
                      value: _selectedStoreCode,
                      items: _lookups?.stores.map((s) => s.strCode).toList() ?? [],
                      itemLabel: (code) {
                        final m = _lookups?.stores.where((s) => s.strCode == code);
                        return m != null && m.isNotEmpty ? m.first.strName : '$code';
                      },
                      onChanged: (val) => setState(() => _selectedStoreCode = val),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // CARD 2: Classification, Mode & Priority
          _buildFormSectionCard(
            title: '2. Classification, Mode & Priority',
            icon: Icons.tune_rounded,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 6. Mode
                  Expanded(
                    flex: 3,
                    child: _buildDropdownField<int>(
                      label: '6. Mode (LOCATIONMST CAPCONS)',
                      value: _selectedCapMode,
                      items: _lookups?.capModes.map((c) => c.locCode).toList() ?? [3],
                      itemLabel: (code) {
                        final m = _lookups?.capModes.where((c) => c.locCode == code);
                        return m != null && m.isNotEmpty ? m.first.location : 'CAPCONS ($code)';
                      },
                      onChanged: (val) => setState(() => _selectedCapMode = val ?? 3),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 7. Priority
                  Expanded(
                    flex: 3,
                    child: _buildDropdownField<String>(
                      label: '7. Priority',
                      value: _priority,
                      items: const ['Normal', 'High', 'Urgent', 'Low'],
                      itemLabel: (s) => s,
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 8. Min / Max
                  Expanded(
                    flex: 3,
                    child: _buildDropdownField<String>(
                      label: '8. Min / Max Stock Filter',
                      value: _minMaxThreshold,
                      items: const [
                        'All Items',
                        'Below Minimum Level',
                        'At Reorder Level',
                        'Above Maximum Level',
                      ],
                      itemLabel: (s) => s,
                      onChanged: (val) => setState(() => _minMaxThreshold = val!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // CARD 3: Stock Thresholds & Privacy Controls (9 to 13)
          _buildFormSectionCard(
            title: '3. Stock Thresholds & Privacy Controls',
            icon: Icons.analytics_outlined,
            children: [
              Row(
                children: [
                  // 9. Current Stock
                  Expanded(child: _buildNumericBox('9. Current Stock', _currentStockCtrl)),
                  const SizedBox(width: 12),

                  // 10. ReOrder On
                  Expanded(child: _buildNumericBox('10. ReOrder On', _reorderOnCtrl)),
                  const SizedBox(width: 12),

                  // 11. Min Qty/Pcs
                  Expanded(child: _buildNumericBox('11. Min Qty/Pcs', _minQtyCtrl)),
                  const SizedBox(width: 12),

                  // 12. Max Qty/Pcs
                  Expanded(child: _buildNumericBox('12. Max Qty/Pcs', _maxQtyCtrl)),
                  const SizedBox(width: 14),

                  // 13. Show Rate Action Control
                  Container(
                    width: 185,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _showRate ? const Color(0xFFEAF5EE) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _showRate ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('13. Show Rate',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                              Text(_showRate ? 'Visible' : 'Hidden',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _showRate ? const Color(0xFF0C3B2E) : const Color(0xFF64748B))),
                            ],
                          ),
                        ),
                        Transform.scale(
                          scale: 0.75,
                          child: Switch(
                            value: _showRate,
                            activeTrackColor: const Color(0xFFBBF7D0),
                            activeThumbColor: const Color(0xFF0C3B2E),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setState(() => _showRate = val),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // CARD 4: (14) Remark Notes Footer
          _buildFormSectionCard(
            title: '4. Historical Remark & Context Notes',
            icon: Icons.history_edu_outlined,
            children: [
              _buildRemarkFooter(),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STEP 2: LINE ITEMS & ADD ROW (EXACT 11 COLUMNS)
  // ============================================================================
  Widget _buildStep2LineItems() {
    return Column(
      children: [
        // TOOLBAR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5EE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Text(
                  '${_lines.length} Line Items Added',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                ),
              ),
              const SizedBox(width: 14),
              if (_isLoadingCostCenters)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0C3B2E))),
              const Spacer(),

              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Row', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                onPressed: () => _openAddRowDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C3B2E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        // MASTER GRID TABLE OF 11 COLUMNS
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_add_check_circle_outlined, size: 52, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No line items added yet.',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 6),
                      const Text('Click "+ Add Row" above to select items from catalog and add columns.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add First Line Item'),
                        onPressed: () => _openAddRowDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0C3B2E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                )
              : Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1250),
                        child: DataTable(
                          headingRowHeight: 38,
                          dataRowMinHeight: 36,
                          dataRowMaxHeight: 38,
                          columnSpacing: 14,
                          horizontalMargin: 16,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFF0C3B2E)),
                          columns: [
                            const DataColumn(label: Text('1. SrNo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('2. Req No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('3. Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('4. Item Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('5. Cost Center', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('6. UQC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(numeric: true, label: Text('7. Qty/Pcs', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            DataColumn(numeric: true, label: Text(_showRate ? '8. Rate (₹)' : '8. Rate', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            DataColumn(numeric: true, label: Text(_showRate ? '9. Total Value' : '9. Value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('10. Department', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('11. Req. Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            const DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                          ],
                          rows: _lines.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final line = entry.value;
                            final isEven = idx.isEven;

                            return DataRow(
                              color: WidgetStateProperty.all(isEven ? Colors.white : const Color(0xFFF8FAFC)),
                              cells: [
                                DataCell(Text('${line.srno}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                DataCell(Text(line.reqNo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                DataCell(Text(line.code, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)))),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(line.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                                  ),
                                ),
                                DataCell(Text(line.costCenterName.isEmpty ? '-' : line.costCenterName, style: const TextStyle(fontSize: 11))),
                                DataCell(Text(line.uomName.isEmpty ? '${line.uom}' : line.uomName, style: const TextStyle(fontSize: 11))),
                                DataCell(Text(line.qty.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
                                DataCell(Text(_showRate ? line.rate.toStringAsFixed(2) : '••••', style: const TextStyle(fontSize: 11.5))),
                                DataCell(
                                  Text(
                                    _showRate ? '₹ ${line.totalValue.toStringAsFixed(2)}' : '••••',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                                  ),
                                ),
                                DataCell(Text(line.deptName.isEmpty ? '${line.deptCode}' : line.deptName, style: const TextStyle(fontSize: 11))),
                                DataCell(Text(_formatDate(line.reqDate), style: const TextStyle(fontSize: 11))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF0C3B2E)),
                                        tooltip: 'Edit Row',
                                        onPressed: () => _openAddRowDialog(editRow: line),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        tooltip: 'Delete Row',
                                        onPressed: () => _deleteRow(idx),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================================
  // STEP 3: SUMMARY & CALCULATIONS REVIEW
  // ============================================================================
  Widget _buildStep3SummaryCalculations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PROMINENT KPI CALCULATION CARDS
          Row(
            children: [
              Expanded(
                child: _buildCalculationKpiCard(
                  title: 'TOTAL ITEMS',
                  value: '${_lines.length}',
                  subtitle: 'Distinct catalog lines',
                  icon: Icons.inventory_2_outlined,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCalculationKpiCard(
                  title: 'TOTAL QUANTITY',
                  value: _totQty.toStringAsFixed(2),
                  subtitle: 'Aggregated units / pcs',
                  icon: Icons.scale_outlined,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCalculationKpiCard(
                  title: 'TOTAL INDENT VALUE',
                  value: _showRate ? '₹ ${_totAmt.toStringAsFixed(2)}' : '••••••',
                  subtitle: _showRate ? 'Net transaction amount' : 'Rate masked by toggle',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCalculationKpiCard(
                  title: 'AVG RATE / UNIT',
                  value: _showRate ? '₹ ${_avgRate.toStringAsFixed(2)}' : '••••',
                  subtitle: 'Weighted line average',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // VOUCHER HEADER RECAP CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF0C3B2E)),
                    SizedBox(width: 8),
                    Text('Voucher Details & Audit Recap',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _buildRecapItem('Indent No.', _previewIndentCode)),
                    Expanded(child: _buildRecapItem('Date', _formatDate(_indDate))),
                    Expanded(child: _buildRecapItem('Source', _source)),
                    Expanded(child: _buildRecapItem('Priority', _priority)),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  children: [
                    Expanded(
                      child: _buildRecapItem(
                        'Department',
                        _lookups?.departments.firstWhere((d) => d.labCode == _selectedDeptCode,
                                orElse: () => const IndentDepartmentLookup(labCode: 0, labName: '-')).labName ?? '-',
                      ),
                    ),
                    Expanded(
                      child: _buildRecapItem(
                        'Location / Store',
                        _lookups?.stores.firstWhere((s) => s.strCode == _selectedStoreCode,
                                orElse: () => const IndentStoreLookup(strCode: 0, strName: '-')).strName ?? '-',
                      ),
                    ),
                    Expanded(child: _buildRecapItem('Capital Mode', 'CAPCONS ($_selectedCapMode)')),
                    Expanded(child: _buildRecapItem('Lock Status', 'Open & Valid')),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                _buildRecapItem('Remark Notes', _remarkCtrl.text.trim().isEmpty ? 'Direct Indent Entry' : _remarkCtrl.text.trim()),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ERROR ALERT BANNER IF SAVE FAILED
          if (_saveErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Save Indent Error: $_saveErrorMessage',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // FOOTER ACTIONS
  // ============================================================================
  Widget _buildWizardFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep == 1)
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12.5)),
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(_currentStep == 2 ? 'Back to Header (Step 1)' : 'Back to Line Items (Step 2)',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0C3B2E),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

          const Spacer(),

          if (_currentStep == 1)
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Proceed to Line Items (Step 2)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              onPressed: _validateAndProceedToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C3B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            )
          else if (_currentStep == 2)
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Proceed to Summary & Calculations (Step 3)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
              onPressed: _validateAndProceedToStep3,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C3B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            )
          else
            BomAnimatedSuccessButton(
              status: _saveButtonStatus,
              onPressed: _saveButtonStatus == ButtonStatus.loading ? null : _saveIndent,
              idleText: widget.initialIndent != null ? 'Update Indent (F1)' : 'Save Indent (F1)',
              loadingText: widget.initialIndent != null ? 'Updating Indent...' : 'Saving Indent...',
              successText: 'Saved! ($_savedIndentCode)',
              idleIcon: Icons.save_rounded,
              idleBackgroundColor: const Color(0xFF0C3B2E),
              successBackgroundColor: const Color(0xFF10B981),
              height: 44,
              fontSize: 13,
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // FORM COMPONENT HELPERS
  // ============================================================================
  Widget _buildFormSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0C3B2E)),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReadOnlyHeaderField(String label, String value, IconData icon) {
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
          child: Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(String label, DateTime value, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (picked != null) onPicked(picked);
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
                Text(_formatDate(value),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
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
            child: DropdownButton<T>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
              items: items.map((item) {
                return DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item), style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumericBox(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemarkFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _remarkCtrl,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              hintText: 'Type or choose historical remark note...',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_remarkSuggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _remarkSuggestions.take(6).map((s) {
              return ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFFF1F5F9),
                onPressed: () {
                  _remarkCtrl.text = s;
                  setState(() => _remarkSuggestions = []);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildCalculationKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecapItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
