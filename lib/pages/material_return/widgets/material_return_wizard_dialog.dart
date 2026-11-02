import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../../bom/bom_models.dart' show ButtonStatus;
import '../../bom/widgets/bom_animated_success_button.dart';
import '../material_return_models.dart';
import '../material_return_service.dart';
import 'add_material_return_row_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class MaterialReturnWizardDialog extends StatefulWidget {
  final MaterialReturnService service;
  final void Function(String code, bool isUpdate) onSaved;
  final String? editCode;
  final MaterialReturnDetail? initialDetail;

  const MaterialReturnWizardDialog({
    super.key,
    required this.service,
    required this.onSaved,
    this.editCode,
    this.initialDetail,
  });

  @override
  State<MaterialReturnWizardDialog> createState() => _MaterialReturnWizardDialogState();
}

class _MaterialReturnWizardDialogState extends State<MaterialReturnWizardDialog> {
  int _currentStep = 1;

  bool get _isEditMode => widget.editCode != null || widget.initialDetail != null;

  bool _isLoadingMasters = true;
  String? _masterError;
  MaterialReturnLookups? _lookups;

  // Step 2 Line items Horizontal Navigation & 4-second Glow State
  final ScrollController _gridHorizCtrl = ScrollController();
  final ScrollController _gridVertCtrl = ScrollController();
  bool _gridCanScrollLeft = false;
  bool _gridCanScrollRight = true;

  int? _recentlySavedSrNo;
  Timer? _lineGlowTimer;

  // Step 1 Header Fields
  String _previewDocNo = '';
  DateTime _entryDate = DateTime.now();
  String _selectedReturnMode = 'From Department';
  String _source = 'Direct';
  String _returnToCode = '';
  String _returnToName = '';
  String _selectedCurrency = 'INR';
  final TextEditingController _creditDaysCtrl = TextEditingController(text: '0');
  String _location = 'HO';
  String _costCenter = 'DEFAULT';
  final TextEditingController _gstinCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  String? _selectedOperatorCode;
  String? _step1Error;

  // Step 2 Line Items (Exact 21 columns)
  final List<MaterialReturnLineItem> _lines = [];

  // Step 3 Totals & Save State
  bool _isSaving = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _saveErrorMessage;

  static const List<String> _returnModes = [
    'From Department',
    'To Supplier',
    'To Customer',
  ];

  static const List<String> _currencyOptions = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'AED',
  ];

  static const List<String> _sources = [
    'Direct',
    'Issued',
    'Production',
    'Line Based',
    'Job_GRN',
    'WIP',
    'PROD_ORDER',
    'Service Order Based',
  ];

  @override
  void initState() {
    super.initState();
    _loadMasters();
    _gridHorizCtrl.addListener(_updateGridScrollButtons);
  }

  void _updateGridScrollButtons() {
    if (!_gridHorizCtrl.hasClients) return;
    final maxScroll = _gridHorizCtrl.position.maxScrollExtent;
    final offset = _gridHorizCtrl.offset;
    final canLeft = offset > 10;
    final canRight = offset < maxScroll - 10;
    if (canLeft != _gridCanScrollLeft || canRight != _gridCanScrollRight) {
      setState(() {
        _gridCanScrollLeft = canLeft;
        _gridCanScrollRight = canRight;
      });
    }
  }

  void _scrollGridLeft() {
    if (!_gridHorizCtrl.hasClients) return;
    final newOffset = (_gridHorizCtrl.offset - 350.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
    _gridHorizCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  void _scrollGridRight() {
    if (!_gridHorizCtrl.hasClients) return;
    final newOffset = (_gridHorizCtrl.offset + 350.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
    _gridHorizCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _lineGlowTimer?.cancel();
    _gridHorizCtrl.removeListener(_updateGridScrollButtons);
    _gridHorizCtrl.dispose();
    _gridVertCtrl.dispose();
    _creditDaysCtrl.dispose();
    _gstinCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _isLoadingMasters = true;
      _masterError = null;
    });

    try {
      final lookups = await widget.service.fetchLookups();
      _lookups = lookups;
      _location = lookups.defaultLocation;
      _costCenter = lookups.defaultCostCenter;

      if (_isEditMode) {
        await _loadEditDetail();
      } else {
        // Defaults for new entry
        if (lookups.departments.isNotEmpty) {
          final regDept = lookups.departments.firstWhere(
            (d) => d.name.toUpperCase().contains('REGULAR'),
            orElse: () => lookups.departments.first,
          );
          _returnToCode = regDept.code;
          _returnToName = regDept.name;
        }

        if (lookups.operators.isNotEmpty) {
          _selectedOperatorCode = lookups.operators.first.operCode;
        }

        await _updatePreviewDocNo();
      }

      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMasters = false;
          _masterError = 'Failed to load master lookups: $e';
        });
      }
    }
  }

  Future<void> _loadEditDetail() async {
    final detail = widget.initialDetail ?? await widget.service.fetchByCode(widget.editCode!);
    _previewDocNo = detail.retCode;
    _entryDate = detail.retDate;
    _selectedReturnMode = detail.retMode;
    _source = detail.source;
    _returnToCode = detail.retTo;
    _returnToName = detail.retToName;
    _selectedCurrency = detail.currency;
    _creditDaysCtrl.text = detail.creditDays.toString();
    _location = detail.location;
    _costCenter = detail.costCenter;
    _gstinCtrl.text = detail.gstin;
    _remarkCtrl.text = detail.remark;
    _selectedOperatorCode = detail.operatorCode;

    _lines.clear();
    for (final l in detail.lines) {
      _lines.add(l.clone());
    }
  }

  Future<void> _updatePreviewDocNo() async {
    if (_isEditMode) return;
    try {
      final code = await widget.service.fetchPreviewCode(
        date: _entryDate,
        returnMode: _selectedReturnMode,
        fromDeptName: _returnToName,
      );
      if (mounted) {
        setState(() => _previewDocNo = code);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _previewDocNo = 'REGU/000001/27');
      }
    }
  }

  // Live Calculations across all line items
  double get _totalQty => _lines.fold(0.0, (acc, l) => acc + l.qty);
  int get _totalItm => _lines.length;
  int get _totalCops => _lines.fold(0, (acc, l) => acc + l.cops);
  double get _grossAmount => _lines.fold(0.0, (acc, l) => acc + l.amount);
  double get _totalCgstAmt => _lines.fold(0.0, (acc, l) => acc + l.cgstAmt);
  double get _totalSgstAmt => _lines.fold(0.0, (acc, l) => acc + l.sgstAmt);
  double get _totalIgstAmt => _lines.fold(0.0, (acc, l) => acc + l.igstAmt);
  double get _totalTaxAmt => _totalCgstAmt + _totalSgstAmt + _totalIgstAmt;
  double get _netAmount => _lines.fold(0.0, (acc, l) => acc + l.netAmt);

  Future<void> _handleSave() async {
    if (_lines.isEmpty) {
      setState(() => _saveErrorMessage = 'Please add at least one line item in Step 2.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    // Check date lock
    final isLocked = await widget.service.isDateLocked(_entryDate);
    if (isLocked) {
      setState(() {
        _isSaving = false;
        _saveErrorMessage = 'Selected entry date ${_formatDate(_entryDate)} is locked in LOCKDATAMST.';
        _saveButtonStatus = ButtonStatus.error;
      });
      return;
    }

    final request = MaterialReturnCreateRequest(
      retCode: _isEditMode ? _previewDocNo : null,
      retDate: _entryDate,
      retMode: _selectedReturnMode,
      retTo: _returnToCode.isNotEmpty ? _returnToCode : _returnToName,
      source: _source,
      location: _location,
      costCenter: _costCenter,
      operatorCode: _selectedOperatorCode,
      currency: _selectedCurrency,
      creditDays: int.tryParse(_creditDaysCtrl.text.trim()) ?? 0,
      gstin: _gstinCtrl.text.trim(),
      remark: _remarkCtrl.text.trim(),
      totQty: _totalQty,
      totItm: _totalItm,
      lines: _lines,
    );

    try {
      MaterialReturnSaveResult result;
      if (_isEditMode) {
        result = await widget.service.updateReturn(_previewDocNo, request);
      } else {
        result = await widget.service.createReturn(request);
      }

      if (result.success) {
        setState(() => _saveButtonStatus = ButtonStatus.success);
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          widget.onSaved(result.docNo.isNotEmpty ? result.docNo : _previewDocNo, _isEditMode);
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _isSaving = false;
          _saveButtonStatus = ButtonStatus.error;
          _saveErrorMessage = result.message;
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveButtonStatus = ButtonStatus.error;
        _saveErrorMessage = e.toString();
      });
    }
  }

  void _openAddRowDialog({MaterialReturnLineItem? itemToEdit}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => AddMaterialReturnRowDialog(
        service: widget.service,
        date: _entryDate,
        sourceDept: int.tryParse(_returnToCode) ?? 1,
        sourceStore: 1,
        sourceDiv: 1,
        initialItem: itemToEdit,
        nextSrNo: _lines.length + 1,
        onSave: (savedLine) {
          setState(() {
            if (itemToEdit != null) {
              final idx = _lines.indexWhere((l) => l.srNo == itemToEdit.srNo);
              if (idx >= 0) {
                _lines[idx] = savedLine;
              }
            } else {
              _lines.add(savedLine);
            }

            // Glow the newly saved line
            _recentlySavedSrNo = savedLine.srNo;
            _lineGlowTimer?.cancel();
            _lineGlowTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _recentlySavedSrNo = null);
            });
          });
        },
      ),
    );
  }

  void _deleteLineItem(int srNo) {
    setState(() {
      _lines.removeWhere((l) => l.srNo == srNo);
      // Renumber
      for (var i = 0; i < _lines.length; i++) {
        _lines[i].srNo = i + 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 1320,
        height: 760,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 36,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // 1. Wizard Top Title Bar
              _buildTopTitleBar(),

              // 2. BOM-Style Step Header (1, 2, 3 with subtext)
              _buildBOMProgressHeader(),

              // 3. Step Body
              Expanded(
                child: _isLoadingMasters
                    ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor))
                    : _masterError != null
                        ? Center(child: Text(_masterError!, style: const TextStyle(color: AppColors.error)))
                        : _buildStepContent(),
              ),

              // 4. Wizard Footer Navigation Bar
              _buildFooterNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopTitleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_return_rounded, color: AppColors.secondaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditMode ? 'Edit Material Return: $_previewDocNo' : 'New Material Return (From/To)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(
                'Production-grade Dapper persistence • stockregnew positive inventory movement',
                style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
              ),
            ],
          ),
          const Spacer(),
          if (_previewDocNo.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF4338CA)),
                  const SizedBox(width: 5),
                  Text(
                    _previewDocNo,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildBOMProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          _buildStepPill(
            stepIndex: 1,
            title: 'Step 1: Header Metadata',
            subtitle: 'Doc Code, Mode, Source & Entity',
            icon: Icons.article_outlined,
          ),
          _buildStepConnector(1),
          _buildStepPill(
            stepIndex: 2,
            title: 'Step 2: Line Items Grid',
            subtitle: 'Exact 21 Columns & Catalog Lookup',
            icon: Icons.table_chart_outlined,
          ),
          _buildStepConnector(2),
          _buildStepPill(
            stepIndex: 3,
            title: 'Step 3: Totals & Save',
            subtitle: 'Tax Breakdown & Atomic Save',
            icon: Icons.verified_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStepPill({
    required int stepIndex,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return InkWell(
      onTap: () {
        if (stepIndex < _currentStep || (stepIndex == 2 && _returnToName.isNotEmpty) || (stepIndex == 3 && _lines.isNotEmpty)) {
          setState(() => _currentStep = stepIndex);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.secondaryColor.withValues(alpha: 0.08)
              : (isDone ? const Color(0xFFF0FDF4) : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.secondaryColor
                : (isDone ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981)
                    : (isActive ? AppColors.secondaryColor : const Color(0xFFCBD5E1)),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(
                        '$stepIndex',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.secondaryColor : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: AppColors.slateMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector(int beforeStep) {
    final isPassed = _currentStep > beforeStep;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        height: 2,
        color: isPassed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1Header();
      case 2:
        return _buildStep2Grid();
      case 3:
        return _buildStep3TotalsAndLogistics();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==========================================================================
  // STEP 1: HEADER METADATA & DROPDOWNS
  // ==========================================================================
  Widget _buildStep1Header() {
    final lookups = _lookups!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_step1Error != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _step1Error!,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildCardHeader('1. Sequence, Mode & Date', Icons.receipt_rounded),
          const SizedBox(height: 14),
          Row(
            children: [
              // Return Code (Auto Sequence)
              Expanded(
                child: _buildTextFieldDisplay(
                  label: 'Return Code (System Sequence)',
                  value: _previewDocNo.isNotEmpty ? _previewDocNo : 'Generating sequence...',
                  icon: Icons.tag_rounded,
                  badge: 'REGU Prefix',
                ),
              ),
              const SizedBox(width: 20),
              // Return Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transaction Date *', style: _labelStyle),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _entryDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _entryDate = picked);
                          _updatePreviewDocNo();
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.secondaryColor),
                            const SizedBox(width: 10),
                            Text(
                              _formatDate(_entryDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Return Mode
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Return Mode *', style: _labelStyle),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedReturnMode,
                          isExpanded: true,
                          items: _returnModes.map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(m, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedReturnMode = val;
                                // Reset entity selection
                                if (val == 'From Department' && lookups.departments.isNotEmpty) {
                                  _returnToCode = lookups.departments.first.code;
                                  _returnToName = lookups.departments.first.name;
                                } else if (lookups.parties.isNotEmpty) {
                                  _returnToCode = lookups.parties.first.code;
                                  _returnToName = lookups.parties.first.name;
                                  _gstinCtrl.text = lookups.parties.first.hsn ?? '';
                                }
                              });
                              _updatePreviewDocNo();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildCardHeader('2. Party, Terms & Currency', Icons.account_tree_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              // Return To / By Selector
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedReturnMode == 'From Department' ? 'From Department *' : 'Return Entity (Party) *',
                      style: _labelStyle,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _returnToCode.isNotEmpty ? _returnToCode : null,
                          isExpanded: true,
                          hint: const Text('Select Entity / Department', style: TextStyle(fontSize: 12.5)),
                          items: (_selectedReturnMode == 'From Department'
                                  ? lookups.departments
                                  : lookups.parties)
                              .map((item) {
                            return DropdownMenuItem(
                              value: item.code,
                              child: Text('${item.name} (${item.code})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              final list = _selectedReturnMode == 'From Department'
                                  ? lookups.departments
                                  : lookups.parties;
                              final match = list.firstWhere((i) => i.code == val);
                              setState(() {
                                _returnToCode = match.code;
                                _returnToName = match.name;
                                _step1Error = null;
                                if (_selectedReturnMode != 'From Department' && match.hsn != null) {
                                  _gstinCtrl.text = match.hsn!;
                                }
                              });
                              _updatePreviewDocNo();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Source Dropdown
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Source *', style: _labelStyle),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _source,
                          isExpanded: true,
                          items: _sources.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _source = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Currency & Credit Days Row
          Row(
            children: [
              // Currency Dropdown
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Currency *', style: _labelStyle),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          items: _currencyOptions.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(
                                c == 'INR' ? 'INR (₹)' : (c == 'USD' ? 'USD (\$)' : (c == 'EUR' ? 'EUR (€)' : (c == 'GBP' ? 'GBP (£)' : 'AED (د.إ)'))),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCurrency = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Credit Days
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Credit Days', style: _labelStyle),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _creditDaysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: 'e.g. 30'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // GSTIN
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GSTIN / Add', style: _labelStyle),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _gstinCtrl,
                        decoration: _inputDecoration(hint: 'GSTIN tax identifier'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildCardHeader('3. Warehouse & Cost Center', Icons.warehouse_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              // Location
              Expanded(
                child: _buildTextFieldDisplay(
                  label: 'Location / Warehouse',
                  value: _location,
                  icon: Icons.store_rounded,
                ),
              ),
              const SizedBox(width: 20),
              // Cost Center
              Expanded(
                child: _buildTextFieldDisplay(
                  label: 'Cost Center',
                  value: _costCenter,
                  icon: Icons.account_balance_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 2: LINE-ITEMS GRID (EXACT 21 COLUMNS)
  // ==========================================================================
  Widget _buildStep2Grid() {
    return Column(
      children: [
        // Action Bar (+ Add Row button & Count)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_lines.length} Line Items Added',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Total Qty: ${_totalQty.toStringAsFixed(2)} | Gross Amt: ₹${_grossAmount.toStringAsFixed(2)} | Net Amt: ₹${_netAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              const Spacer(),
              // Left / Right Scroll navigation buttons
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                color: _gridCanScrollLeft ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
                onPressed: _gridCanScrollLeft ? _scrollGridLeft : null,
                tooltip: 'Scroll Left',
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: _gridCanScrollRight ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
                onPressed: _gridCanScrollRight ? _scrollGridRight : null,
                tooltip: 'Scroll Right',
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openAddRowDialog(),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text(
                  'Add Row',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // 21 Column Data Grid
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.playlist_add_rounded, size: 36, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'No line items added yet.',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Click "+ Add Row" to select items and configure the exact 21 columns.',
                        style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openAddRowDialog(),
                        icon: const Icon(Icons.add, size: 16, color: Colors.white),
                        label: const Text('Add First Row', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                )
              : Scrollbar(
                  controller: _gridHorizCtrl,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _gridHorizCtrl,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 2450, // Accommodates all 21 columns comfortably
                      child: Column(
                        children: [
                          _buildGridHeaderRow(),
                          Expanded(
                            child: Scrollbar(
                              controller: _gridVertCtrl,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _gridVertCtrl,
                                itemCount: _lines.length,
                                itemBuilder: (context, idx) {
                                  final item = _lines[idx];
                                  final isGlowing = _recentlySavedSrNo == item.srNo;
                                  return _buildGridDataRow(item, idx, isGlowing);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildGridHeaderRow() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFF0C3B2E), // Match corporate theme
        border: Border(bottom: BorderSide(color: Color(0xFF092920))),
      ),
      child: const Row(
        children: [
          SizedBox(width: 50, child: Center(child: Text('#', style: _gridHdrStyle))),
          SizedBox(width: 105, child: Text('Item Code', style: _gridHdrStyle)),
          SizedBox(width: 230, child: Text('Item Name', style: _gridHdrStyle)),
          SizedBox(width: 90, child: Text('HSN', style: _gridHdrStyle)),
          SizedBox(width: 90, child: Text('Merge No.', style: _gridHdrStyle)),
          SizedBox(width: 80, child: Text('Grade', style: _gridHdrStyle)),
          SizedBox(width: 80, child: Text('Shade', style: _gridHdrStyle)),
          SizedBox(width: 80, child: Text('Maker', style: _gridHdrStyle)),
          SizedBox(width: 65, child: Text('UQC', style: _gridHdrStyle)),
          SizedBox(width: 90, child: Text('Qty', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 90, child: Text('Rate', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 110, child: Text('Amount', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 65, child: Text('Cops', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 90, child: Text('Stock', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 70, child: Text('CGST %', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 95, child: Text('CGST_Amt', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 70, child: Text('SGST %', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 95, child: Text('SGST_Amt', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 70, child: Text('IGST %', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 95, child: Text('IGST_Amt', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 120, child: Text('Net_Amt', textAlign: TextAlign.right, style: _gridHdrStyle)),
          SizedBox(width: 90, child: Center(child: Text('Actions', style: _gridHdrStyle))),
        ],
      ),
    );
  }

  Widget _buildGridDataRow(MaterialReturnLineItem item, int idx, bool isGlowing) {
    final isEven = idx % 2 == 0;
    Color rowBg = isEven ? Colors.white : const Color(0xFFF8FAFC);
    if (isGlowing) {
      rowBg = const Color(0xFFFEF3C7); // Amber glow from Project Master
    }

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // 1: srno
          SizedBox(width: 50, child: Center(child: Text('${item.srNo}', style: _cellStyleBold))),
          // 2: Item Code
          SizedBox(width: 105, child: Text(item.itemCode, style: _cellStyleCode)),
          // 3: Item Name
          SizedBox(width: 230, child: Text(item.itemName, style: _cellStyle, overflow: TextOverflow.ellipsis)),
          // 4: HSN
          SizedBox(width: 90, child: Text(item.hsn.isEmpty ? '-' : item.hsn, style: _cellStyle)),
          // 5: Merge No.
          SizedBox(width: 90, child: Text(item.mrgNo.isEmpty ? '-' : item.mrgNo, style: _cellStyle)),
          // 6: Grade
          SizedBox(width: 80, child: Text(item.grade.isEmpty ? '-' : item.grade, style: _cellStyle)),
          // 7: Shade
          SizedBox(width: 80, child: Text(item.shade.isEmpty ? '-' : item.shade, style: _cellStyle)),
          // 8: Maker
          SizedBox(width: 80, child: Text(item.maker.isEmpty ? '-' : item.maker, style: _cellStyle)),
          // 9: UQC
          SizedBox(width: 65, child: Text(item.uqc, style: _cellStyle)),
          // 10: Qty
          SizedBox(width: 90, child: Text(item.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyleBold)),
          // 11: Rate
          SizedBox(width: 90, child: Text(item.rate.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyle)),
          // 12: Amount
          SizedBox(width: 110, child: Text(item.amount.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyleBold)),
          // 13: Cops
          SizedBox(width: 65, child: Text('${item.cops}', textAlign: TextAlign.right, style: _cellStyle)),
          // 14: Stock
          SizedBox(width: 90, child: Text(item.stock.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyle)),
          // 15: CGST
          SizedBox(width: 70, child: Text('${item.cgst.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: _cellStyle)),
          // 16: CGST_Amt
          SizedBox(width: 95, child: Text(item.cgstAmt.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyle)),
          // 17: SGST
          SizedBox(width: 70, child: Text('${item.sgst.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: _cellStyle)),
          // 18: SGST_Amt
          SizedBox(width: 95, child: Text(item.sgstAmt.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyle)),
          // 19: IGST
          SizedBox(width: 70, child: Text('${item.igst.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: _cellStyle)),
          // 20: IGST_Amt
          SizedBox(width: 95, child: Text(item.igstAmt.toStringAsFixed(2), textAlign: TextAlign.right, style: _cellStyle)),
          // 21: Net_Amt
          SizedBox(
            width: 120,
            child: Text(
              '₹${item.netAmt.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
            ),
          ),
          // Actions
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFFD97706)),
                  tooltip: 'Edit Line',
                  onPressed: () => _openAddRowDialog(itemToEdit: item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFDC2626)),
                  tooltip: 'Delete Line',
                  onPressed: () => _deleteLineItem(item.srNo),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // STEP 3: TOTALS, CALCULATION & LOGISTICS FOOTER
  // ==========================================================================
  Widget _buildStep3TotalsAndLogistics() {
    final lookups = _lookups!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saveErrorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 18, color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _saveErrorMessage!,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          // Valuation Cards
          Row(
            children: [
              _buildMetricCard('Total Return Qty', _totalQty.toStringAsFixed(2), Icons.scale_rounded, const Color(0xFF0C3B2E)),
              const SizedBox(width: 16),
              _buildMetricCard('Gross Valuation', '₹${_grossAmount.toStringAsFixed(2)}', Icons.payments_outlined, const Color(0xFF2563EB)),
              const SizedBox(width: 16),
              _buildMetricCard('Total Taxes (GST)', '₹${_totalTaxAmt.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined, const Color(0xFFD97706)),
              const SizedBox(width: 16),
              _buildMetricCard('Net Payable / Ret', '₹${_netAmount.toStringAsFixed(2)}', Icons.check_circle_outline, const Color(0xFF10B981)),
            ],
          ),

          const SizedBox(height: 24),

          // Tax Breakdown Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.secondaryColor),
                    SizedBox(width: 8),
                    Text('Tax Dissection (CGST / SGST / IGST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTaxSubMetric('CGST Breakdown', '₹${_totalCgstAmt.toStringAsFixed(2)}'),
                    _buildTaxSubMetric('SGST Breakdown', '₹${_totalSgstAmt.toStringAsFixed(2)}'),
                    _buildTaxSubMetric('IGST Breakdown', '₹${_totalIgstAmt.toStringAsFixed(2)}'),
                    _buildTaxSubMetric('Total Cops', '$_totalCops Cops'),
                    _buildTaxSubMetric('Total Items', '$_totalItm Items'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Logistics & Operator Section
          _buildCardHeader('Logistics & Authorization', Icons.badge_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              // Operator Selector
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Operator (OPERATORMST) *', style: _labelStyle),
                    const SizedBox(height: 6),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedOperatorCode,
                          isExpanded: true,
                          hint: const Text('Select Operator', style: TextStyle(fontSize: 12.5)),
                          items: lookups.operators.map((op) {
                            return DropdownMenuItem(
                              value: op.operCode,
                              child: Text('${op.operName} (${op.operCode})', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedOperatorCode = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Remarks
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Transaction Remark', style: _labelStyle),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 42,
                      child: TextField(
                        controller: _remarkCtrl,
                        decoration: _inputDecoration(hint: 'Enter return reason or remarks...'),
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

  // ==========================================================================
  // FOOTER NAVIGATION BAR
  // ==========================================================================
  Widget _buildFooterNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (_currentStep > 1)
            OutlinedButton.icon(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Previous Step', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
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
          if (_currentStep < 3)
            ElevatedButton.icon(
              onPressed: () {
                if (_currentStep == 1 && _returnToName.isEmpty) {
                  setState(() => _step1Error = 'Please select a Party / Department to proceed.');
                  return;
                }
                setState(() {
                  _step1Error = null;
                  _currentStep++;
                });
              },
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
              label: const Text('Next Step', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            SizedBox(
              width: 175,
              child: BomAnimatedSuccessButton(
                status: _saveButtonStatus,
                onPressed: _isSaving ? null : _handleSave,
                idleText: _isEditMode ? 'Update Return' : 'Confirm & Save',
                loadingText: 'Saving to SQL...',
                successText: 'Saved!',
                idleBackgroundColor: AppColors.primaryColor,
                successBackgroundColor: const Color(0xFF10B981),
                height: 42,
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER WIDGETS
  // ==========================================================================
  Widget _buildCardHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    );
  }

  Widget _buildTextFieldDisplay({
    required String label,
    required String value,
    required IconData icon,
    String? badge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: _labelStyle),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppColors.slateMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxSubMetric(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
      ),
    );
  }
}

const TextStyle _labelStyle = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: Color(0xFF475569),
);

const TextStyle _gridHdrStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

const TextStyle _cellStyle = TextStyle(
  fontSize: 11.5,
  color: Color(0xFF334155),
);

const TextStyle _cellStyleBold = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.bold,
  color: Color(0xFF0F172A),
);

const TextStyle _cellStyleCode = TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.bold,
  color: AppColors.secondaryColor,
);

