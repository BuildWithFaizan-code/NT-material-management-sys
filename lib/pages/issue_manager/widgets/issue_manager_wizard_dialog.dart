import 'dart:async';
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../../bom/bom_models.dart';
import '../../bom/widgets/bom_animated_success_button.dart';
import '../../../services/auth_service.dart';
import '../issue_manager_models.dart';
import '../issue_manager_service.dart';
import 'add_issue_manager_row_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class IssueManagerWizardDialog extends StatefulWidget {
  final IssueManagerService service;
  final void Function(String code, bool isUpdate) onSaved;
  final String? editCode;
  final IssueManagerDetail? initialDetail;

  const IssueManagerWizardDialog({
    super.key,
    required this.service,
    required this.onSaved,
    this.editCode,
    this.initialDetail,
  });

  @override
  State<IssueManagerWizardDialog> createState() => _IssueManagerWizardDialogState();
}

class _IssueManagerWizardDialogState extends State<IssueManagerWizardDialog> {
  int _currentStep = 1;

  bool get _isEditMode => widget.editCode != null || widget.initialDetail != null;

  bool _isLoadingMasters = true;
  String? _masterError;
  IssueManagerLookups? _lookups;

  // Step 2 Line items Horizontal Navigation & 4-second Glow State
  final ScrollController _gridHorizCtrl = ScrollController();
  final ScrollController _gridVertCtrl = ScrollController();
  bool _gridCanScrollLeft = false;
  bool _gridCanScrollRight = true;

  int? _recentlySavedSrNo;
  int? _recentlyUpdatedSrNo;
  Timer? _lineGlowTimer;

  // Step 1 Header Fields
  String _previewDocNo = '';
  DateTime _entryDate = DateTime.now();
  String _selectedIssueMode = 'To Department';
  String _source = 'Direct';
  int? _selectedSourceDept;
  String _selectedSourceDeptName = '';
  int? _selectedPlant;
  int? _selectedSourceDiv;
  String? _selectedMachine;
  final TextEditingController _spindalCtrl = TextEditingController();
  final TextEditingController _slipNoCtrl = TextEditingController(text: '0');
  final TextEditingController _jobCardCtrl = TextEditingController();

  // Step 2 Line Items
  final List<IssueManagerLineItem> _lines = [];

  // Step 3 Totals & Logistics
  final TextEditingController _vehicleNoCtrl = TextEditingController();
  final TextEditingController _ewayBillNoCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();

  // Save State
  bool _isSaving = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _saveErrorMessage;

  bool get _isModeSupported => _selectedIssueMode == 'To Department';
  bool get _isSourceSupported => _source == 'Direct';

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
    final newOffset = (_gridHorizCtrl.offset - 320.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
    _gridHorizCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  void _scrollGridRight() {
    if (!_gridHorizCtrl.hasClients) return;
    final newOffset = (_gridHorizCtrl.offset + 320.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
    _gridHorizCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  Widget _buildFloatingArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  void _triggerLineGlow(int srNo, bool isUpdate) {
    setState(() {
      if (isUpdate) {
        _recentlyUpdatedSrNo = srNo;
        _recentlySavedSrNo = null;
      } else {
        _recentlySavedSrNo = srNo;
        _recentlyUpdatedSrNo = null;
      }
    });

    _lineGlowTimer?.cancel();
    _lineGlowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _recentlySavedSrNo = null;
          _recentlyUpdatedSrNo = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _lineGlowTimer?.cancel();
    _gridHorizCtrl.removeListener(_updateGridScrollButtons);
    _gridHorizCtrl.dispose();
    _gridVertCtrl.dispose();
    _spindalCtrl.dispose();
    _slipNoCtrl.dispose();
    _jobCardCtrl.dispose();
    _vehicleNoCtrl.dispose();
    _ewayBillNoCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    setState(() {
      _isLoadingMasters = true;
      _masterError = null;
    });

    try {
      final res = await widget.service.fetchLookups();
      _lookups = res;

      if (widget.initialDetail != null) {
        _populateFromDetail(widget.initialDetail!);
      } else if (widget.editCode != null) {
        final detail = await widget.service.fetchIssueByCode(widget.editCode!);
        _populateFromDetail(detail);
      } else {
        if (res.departments.isNotEmpty) {
          final regDept = res.departments.firstWhere(
            (d) => d.name.toUpperCase() == 'REGULAR',
            orElse: () => res.departments.first,
          );
          _selectedSourceDept = regDept.id;
          _selectedSourceDeptName = regDept.name;
          _selectedPlant = regDept.id;
        }

        if (res.divisions.isNotEmpty) {
          _selectedSourceDiv = res.divisions.first.id;
        }

        // Default Machine No is '*' (None) per legacy trace A5
        _selectedMachine = '*';

        await _refreshPreviewCode();
      }

      if (mounted) {
        setState(() => _isLoadingMasters = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _masterError = e.toString().replaceAll('Exception: ', '');
          _isLoadingMasters = false;
        });
      }
    }
  }

  void _populateFromDetail(IssueManagerDetail detail) {
    final h = detail.header;
    _previewDocNo = h.issueCode;
    _entryDate = h.issueDate;
    _selectedIssueMode = h.issueMode.isNotEmpty ? h.issueMode : 'To Department';
    _source = h.issueSource.isNotEmpty ? h.issueSource : 'Direct';
    _selectedSourceDept = h.sourceDeptCode > 0 ? h.sourceDeptCode : _selectedSourceDept;
    _selectedSourceDeptName = h.sourceDeptName.isNotEmpty ? h.sourceDeptName : _selectedSourceDeptName;
    _selectedPlant = h.sourceDeptCode > 0 ? h.sourceDeptCode : _selectedPlant;
    _selectedSourceDiv = h.sourceDivId > 0 ? h.sourceDivId : _selectedSourceDiv;
    _selectedMachine = h.machineNo.isNotEmpty ? h.machineNo : '*';
    _spindalCtrl.text = h.spindal;
    _slipNoCtrl.text = h.slipNo.toString();
    _remarkCtrl.text = h.remark;

    _lines.clear();
    _lines.addAll(detail.lines);
    for (int i = 0; i < _lines.length; i++) {
      _lines[i].srNo = i + 1;
    }
  }

  Future<void> _refreshPreviewCode() async {
    if (_isEditMode) return;
    if (!_isModeSupported || _selectedSourceDeptName.isEmpty) {
      setState(() => _previewDocNo = '');
      return;
    }

    try {
      final code = await widget.service.fetchPreviewCode(
        date: _entryDate,
        issueMode: _selectedIssueMode,
        fromDeptName: _selectedSourceDeptName,
      );
      if (mounted) {
        setState(() => _previewDocNo = code);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _previewDocNo = '');
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _entryDate) {
      final isLocked = await widget.service.isDateLocked(picked);
      if (isLocked) {
        setState(() {
          _saveErrorMessage = 'Date ${_formatDate(picked)} is locked in LOCKDATAMST.';
        });
        return;
      }

      setState(() => _entryDate = picked);
      if (!_isEditMode) {
        await _refreshPreviewCode();
      }
    }
  }

  void _openAddRowDialog() async {
    if (_lookups == null) return;

    final result = await showDialog<IssueManagerLineItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddIssueManagerRowDialog(
        service: widget.service,
        lookups: _lookups!,
        date: _entryDate,
        sourceDept: _selectedSourceDept ?? 0,
        sourceStore: 1,
        sourceDiv: _selectedSourceDiv ?? 1,
        nextSrNo: _lines.length + 1,
      ),
    );

    if (result != null) {
      setState(() {
        _lines.add(result);
      });
      _triggerLineGlow(result.srNo, false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateGridScrollButtons());
    }
  }

  void _openEditRowDialog(int index) async {
    if (_lookups == null) return;
    final item = _lines[index];

    final result = await showDialog<IssueManagerLineItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddIssueManagerRowDialog(
        service: widget.service,
        lookups: _lookups!,
        date: _entryDate,
        sourceDept: _selectedSourceDept ?? 0,
        sourceStore: 1,
        sourceDiv: _selectedSourceDiv ?? 1,
        initialItem: item,
        nextSrNo: item.srNo,
      ),
    );

    if (result != null) {
      setState(() {
        _lines[index] = result;
      });
      _triggerLineGlow(result.srNo, true);
    }
  }

  void _deleteRow(int index) {
    setState(() {
      _lines.removeAt(index);
      for (int i = 0; i < _lines.length; i++) {
        _lines[i].srNo = i + 1;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateGridScrollButtons());
  }

  double get _totQty => _lines.fold(0.0, (acc, l) => acc + l.issueQty);
  double get _totPcs => _lines.fold(0.0, (acc, l) => acc + l.issPcs);
  double get _totVal => _lines.fold(0.0, (acc, l) => acc + l.amount);
  int get _totItm => _lines.length;

  Future<void> _handleSave() async {
    if (_lines.isEmpty) {
      setState(() => _saveErrorMessage = 'At least one line item is required.');
      return;
    }

    if (!_isModeSupported) {
      setState(() => _saveErrorMessage = 'Issue Mode "$_selectedIssueMode" is not available yet.');
      return;
    }

    if (!_isSourceSupported) {
      setState(() => _saveErrorMessage = 'Source "$_source" is not available yet.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveErrorMessage = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    try {
      final req = IssueManagerCreateRequest(
        issueDate: _entryDate,
        issueMode: _selectedIssueMode,
        issueSource: _source,
        sourceDeptCode: _selectedSourceDept ?? 0,
        sourceDeptName: _selectedSourceDeptName,
        sourceStoreId: 1,
        sourceDivId: _selectedSourceDiv ?? 1,
        machineNo: _selectedMachine ?? '*',
        spindal: _spindalCtrl.text.trim(),
        slipNo: int.tryParse(_slipNoCtrl.text.trim()) ?? 0,
        jobCard: _jobCardCtrl.text.trim(),
        vehicleNo: _vehicleNoCtrl.text.trim(),
        ewayBillNo: _ewayBillNoCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
        lines: _lines,
      );

      IssueManagerSaveResult res;
      if (_isEditMode) {
        final targetCode = widget.editCode ?? widget.initialDetail!.header.issueCode;
        res = await widget.service.updateIssue(targetCode, req);
      } else {
        res = await widget.service.createIssue(req);
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveButtonStatus = ButtonStatus.success;
        });

        // Exact button success strategy: allow animation to run for 800ms, then close and trigger main table glow
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          widget.onSaved(res.issueCode, _isEditMode);
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveButtonStatus = ButtonStatus.idle;
          _saveErrorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Container(
        width: 1180,
        height: 720,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Top Wizard Header with Stepper Progress Bar (100% BOM Parity)
              _buildWizardTopHeader(),

              // Body Content (Steps 1, 2, or 3)
              Expanded(
                child: _isLoadingMasters
                    ? const Center(child: CircularProgressIndicator())
                    : _masterError != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                                const SizedBox(height: 12),
                                Text(_masterError!, style: const TextStyle(color: Colors.red)),
                                const SizedBox(height: 12),
                                ElevatedButton(onPressed: _loadMasters, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _buildStepContent(),
              ),

              // Bottom Navigation & Action Bar
              _buildBottomActionBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // STEPPER PROGRESS BAR HEADER (SAME AS BOM SCREEN WITH SUBTEXT)
  // ============================================================================
  Widget _buildWizardTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0C3B2E), size: 22),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditMode ? 'Edit Material Issue' : 'Create New Material Issue',
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _previewDocNo.isNotEmpty ? 'Document Code: $_previewDocNo' : 'Assigning sequence code...',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          // Stepper Progress Cluster with Small Subtext
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepItem(
                stepIndex: 1,
                title: 'Header Details',
                subtext: 'Dept, Date, Mode',
                color: const Color(0xFF059669),
                glowColor: const Color(0xFF10B981),
              ),
              _buildStepConnector(isPassed: _currentStep > 1),
              _buildStepItem(
                stepIndex: 2,
                title: 'Line Items',
                subtext: 'Add Items & Quantities',
                color: const Color(0xFF0091FF),
                glowColor: const Color(0xFF00A3FF),
              ),
              _buildStepConnector(isPassed: _currentStep > 2),
              _buildStepItem(
                stepIndex: 3,
                title: 'Logistics & Summary',
                subtext: 'Vehicle & Save',
                color: const Color(0xFF7C3AED),
                glowColor: const Color(0xFF8B5CF6),
              ),
            ],
          ),

          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
            tooltip: 'Close Wizard',
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int stepIndex,
    required String title,
    required String subtext,
    required Color color,
    required Color glowColor,
  }) {
    final isActive = _currentStep == stepIndex;
    final isPassed = _currentStep > stepIndex;

    return InkWell(
      onTap: () {
        if (!_isSaving) {
          setState(() => _currentStep = stepIndex);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Badge with Glow
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed
                    ? const Color(0xFF10B981)
                    : (isActive ? color : Colors.white),
                border: Border.all(
                  color: isPassed
                      ? const Color(0xFF10B981)
                      : (isActive ? color : const Color(0xFFCBD5E1)),
                  width: isActive ? 1.8 : 1.2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: isPassed
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : Text(
                      '$stepIndex',
                      style: TextStyle(
                        color: isActive ? Colors.white : const Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 8),

            // Title & Small Subtext
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                    color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 10,
                    color: isActive ? color : const Color(0xFF94A3B8),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepConnector({required bool isPassed}) {
    return Container(
      width: 28,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isPassed ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
    );
  }

  // ============================================================================
  // STEP CONTENT DISPATCHER
  // ============================================================================
  Widget _buildStepContent() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_saveErrorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _saveErrorMessage!,
                      style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: _currentStep == 1
                ? _buildStep1HeaderForm()
                : _currentStep == 2
                    ? _buildStep2LineItemsGrid()
                    : _buildStep3SummaryAndLogistics(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STEP 1: HEADER FORM
  // ============================================================================
  Widget _buildStep1HeaderForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Informational Warning Banner if unsupported Mode/Source is selected
          if (!_isModeSupported || !_isSourceSupported) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SCOPE NOTICE: Currently verified combination is Issue Mode "To Department" + Source "Direct". '
                      'Selecting any other mode or source will disable saving until respective legacy trace specification arrives.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Grid of Fields (Clean 3-column corporate layout)
          Builder(
            builder: (context) {
              final modeOptions = (_lookups?.issueModes ?? ['To Department']).toSet().toList();
              final effectiveMode = modeOptions.contains(_selectedIssueMode) ? _selectedIssueMode : modeOptions.first;

              final deptOptions = _lookups?.departments ?? [];
              final effectiveDept = deptOptions.any((d) => d.id == _selectedSourceDept)
                  ? _selectedSourceDept
                  : (deptOptions.isNotEmpty ? deptOptions.first.id : null);

              final storeOptions = _lookups?.stores ?? [];
              final effectivePlant = storeOptions.any((s) => s.id == _selectedPlant)
                  ? _selectedPlant
                  : (storeOptions.isNotEmpty ? storeOptions.first.id : null);

              final divOptions = _lookups?.divisions ?? [];
              final effectiveDiv = divOptions.any((v) => v.id == _selectedSourceDiv)
                  ? _selectedSourceDiv
                  : (divOptions.isNotEmpty ? divOptions.first.id : null);

              // Unique non-empty machine options, ensuring '*' is exclusively added once
              final machineOptions = <String>['*'];
              if (_lookups != null) {
                for (final m in _lookups!.machines) {
                  final trimmed = m.trim();
                  if (trimmed.isNotEmpty && trimmed != '*' && !machineOptions.contains(trimmed)) {
                    machineOptions.add(trimmed);
                  }
                }
              }
              final effectiveMachine = machineOptions.contains(_selectedMachine) ? _selectedMachine : '*';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Issue Code (Preview)
                      Expanded(
                        child: _buildFormField(
                          label: '1. Issue Code (Auto Sequenced)',
                          controller: TextEditingController(text: _previewDocNo.isEmpty ? 'Auto Assigned' : _previewDocNo),
                          readOnly: true,
                          textColor: const Color(0xFF0F766E),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 2. Entry Date
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('2. Issue Date *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDate(_entryDate), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0C3B2E)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 3. Issue Mode
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('3. Issue Mode *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: effectiveMode,
                                  isExpanded: true,
                                  items: modeOptions.map((m) {
                                    return DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedIssueMode = val);
                                      _refreshPreviewCode();
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
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 4. Source
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('4. Source (Direct / Requisition) *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _source,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'Direct', child: Text('Direct (Verified)', style: TextStyle(fontSize: 12.5))),
                                    DropdownMenuItem(value: 'Requisition', child: Text('Requisition', style: TextStyle(fontSize: 12.5))),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _source = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 5. From / Source Department
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('5. From / Source Department *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: effectiveDept,
                                  isExpanded: true,
                                  items: deptOptions.map((d) {
                                    return DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontSize: 12.5)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final d = deptOptions.firstWhere((x) => x.id == val);
                                      setState(() {
                                        _selectedSourceDept = val;
                                        _selectedSourceDeptName = d.name;
                                      });
                                      _refreshPreviewCode();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 6. Plant (Store)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('6. Plant (Store) *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: effectivePlant,
                                  isExpanded: true,
                                  items: storeOptions.map((s) {
                                    return DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12.5)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedPlant = val);
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
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 7. Division (Cost Center)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('7. Division (Cost Center) *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: effectiveDiv,
                                  isExpanded: true,
                                  items: divOptions.map((v) {
                                    return DropdownMenuItem(value: v.id, child: Text(v.name, style: const TextStyle(fontSize: 12.5)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedSourceDiv = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 8. Machine No.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('8. Machine No. (Optional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            const SizedBox(height: 5),
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: effectiveMachine,
                                  isExpanded: true,
                                  items: machineOptions.map((m) {
                                    return DropdownMenuItem<String>(
                                      value: m,
                                      child: Text(m == '*' ? '* (None)' : m, style: const TextStyle(fontSize: 12.5)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMachine = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 9. Spindal
                      Expanded(
                        child: _buildFormField(
                          label: '9. Spindal',
                          controller: _spindalCtrl,
                          hintText: 'Spindal identifier',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 10. Slip No.
                      Expanded(
                        child: _buildFormField(
                          label: '10. Slip No.',
                          controller: _slipNoCtrl,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 11. Job Card
                      Expanded(
                        child: _buildFormField(
                          label: '11. Job Card',
                          controller: _jobCardCtrl,
                          hintText: 'Job card code',
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Spacer(),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STEP 2: LINE ITEMS GRID WITH HORIZONTAL NAVIGATION & 4-SEC GLOW
  // ============================================================================
  Widget _buildStep2LineItemsGrid() {
    return Column(
      children: [
        // Table Subheader with Add Row button & Count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_lines.length} Line Item${_lines.length == 1 ? '' : 's'} Added',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Scroll horizontally to inspect all 14 line columns',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),

            // "+ Add Row" Button (Project Master Style)
            ElevatedButton.icon(
              onPressed: _openAddRowDialog,
              icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              label: const Text('+ Add Row', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C3B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Scrollable Table Grid with Left & Right Navigation Arrows
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  _lines.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.playlist_add_rounded, size: 44, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text(
                                'No line items added yet.',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Click "+ Add Row" to browse stock catalog and issue items.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
                              width: 1540,
                              child: Column(
                                children: [
                                  _buildLineItemsHeaderBar(),
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _gridVertCtrl,
                                      thumbVisibility: true,
                                      child: ListView.separated(
                                        controller: _gridVertCtrl,
                                        itemCount: _lines.length,
                                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (ctx, idx) {
                                          final item = _lines[idx];
                                          final isGlowingNew = _recentlySavedSrNo == item.srNo;
                                          final isGlowingEdit = _recentlyUpdatedSrNo == item.srNo;

                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            height: 38,
                                            color: isGlowingNew
                                                ? const Color(0xFFDCFCE7)
                                                : isGlowingEdit
                                                    ? const Color(0xFFFEF3C7)
                                                    : (idx % 2 == 0 ? const Color(0xFFF8FAFC) : Colors.white),
                                            child: _buildLineItemRow(item, idx),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                  // Left Floating Scroll Arrow Button
                  if (_gridCanScrollLeft)
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildFloatingArrowButton(
                          icon: Icons.chevron_left_rounded,
                          onTap: _scrollGridLeft,
                          tooltip: 'Scroll Left',
                        ),
                      ),
                    ),

                  // Right Floating Scroll Arrow Button
                  if (_gridCanScrollRight && _lines.isNotEmpty)
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _buildFloatingArrowButton(
                          icon: Icons.chevron_right_rounded,
                          onTap: _scrollGridRight,
                          tooltip: 'Scroll Right',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsHeaderBar() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 55, child: Text('SR #', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 120, child: Text('ITEM CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 180, child: Text('ITEM NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 75, child: Text('UQC', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 95, child: Text('MERGE NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 70, child: Text('GRADE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 70, child: Text('SHADE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 130, child: Text('MAKER', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 80, child: Text('RATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 90, child: Text('STOCK', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 75, child: Text('NOS (PCS)', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 95, child: Text('ISSUE QTY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 105, child: Text('AMOUNT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 160, child: Text('REMARK / PARTY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 90, child: Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
        ],
      ),
    );
  }

  Widget _buildLineItemRow(IssueManagerLineItem item, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text('${item.srNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
          SizedBox(
            width: 120,
            child: Text(item.itemCode, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
          ),
          SizedBox(
            width: 180,
            child: Text(item.itemName, style: const TextStyle(fontSize: 11.5), overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: 75, child: Text(item.unitName, style: const TextStyle(fontSize: 11))),
          SizedBox(width: 95, child: Text(item.mrgNo, style: const TextStyle(fontSize: 11))),
          SizedBox(width: 70, child: Text(item.grade, style: const TextStyle(fontSize: 11))),
          SizedBox(width: 70, child: Text(item.shade, style: const TextStyle(fontSize: 11))),
          SizedBox(width: 130, child: Text(item.maker, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          SizedBox(width: 80, child: Text(item.rate.toStringAsFixed(4), style: const TextStyle(fontSize: 11))),
          SizedBox(
            width: 90,
            child: Text(item.stock.toStringAsFixed(2), style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600)),
          ),
          SizedBox(width: 75, child: Text(item.issPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 11))),
          SizedBox(
            width: 95,
            child: Text(item.issueQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
          ),
          SizedBox(
            width: 105,
            child: Text(item.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF047857))),
          ),
          SizedBox(width: 160, child: Text(item.remark, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          SizedBox(
            width: 90,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _WizardLineActionButton(
                  icon: Icons.edit_outlined,
                  color: const Color(0xFF0F766E),
                  tooltip: 'Edit Line Item',
                  onPressed: () => _openEditRowDialog(index),
                ),
                const SizedBox(width: 6),
                _WizardLineActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFDC2626),
                  tooltip: 'Remove Line Item',
                  onPressed: () => _deleteRow(index),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STEP 3: SUMMARY TOTALS & LOGISTICS FORM
  // ============================================================================
  Widget _buildStep3SummaryAndLogistics() {
    final actingUser = AuthService.instance.currentUser?.username ?? 'ADMIN';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Top Metric KPI Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetricCard(
                  title: 'TOTAL ITEMS',
                  value: '$_totItm',
                  sub: 'Unique lines',
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetricCard(
                  title: 'TOTAL ISSUED QTY',
                  value: _totQty.toStringAsFixed(2),
                  sub: 'Material units',
                  icon: Icons.scale_rounded,
                  color: const Color(0xFF0D9488),
                  bgColor: const Color(0xFFF0FDFA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetricCard(
                  title: 'TOTAL PIECES (PCS)',
                  value: _totPcs.toStringAsFixed(0),
                  sub: 'Physical units',
                  icon: Icons.layers_rounded,
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetricCard(
                  title: 'TOTAL AMOUNT',
                  value: '₹ ${_totVal.toStringAsFixed(2)}',
                  sub: 'Calculated value',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF059669),
                  bgColor: const Color(0xFFECFDF5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Logistics & Remarks Group
          const Text(
            'Dispatch Logistics & Audit Details',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Vehicle No.',
                  controller: _vehicleNoCtrl,
                  hintText: 'e.g. MH-12-AB-1234',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'E-Way Bill No.',
                  controller: _ewayBillNoCtrl,
                  hintText: '12-digit e-way bill',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Created By / Issuer',
                  controller: TextEditingController(text: actingUser),
                  readOnly: true,
                  textColor: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildFormField(
            label: 'General Remark / Gate Pass Notes',
            controller: _remarkCtrl,
            hintText: 'Enter any remarks, purpose, or reference numbers for this issue transaction',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetricCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(sub, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // BOTTOM ACTION BAR
  // ============================================================================
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Step Back or Cancel Button
          if (_currentStep > 1)
            OutlinedButton.icon(
              onPressed: _isSaving ? null : () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(_currentStep == 2 ? 'Back to Header' : 'Back to Line Items'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            OutlinedButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),

          // Right: Next Step or Animated Success Save Button
          if (_currentStep < 3)
            ElevatedButton.icon(
              onPressed: () {
                if (_currentStep == 1) {
                  if (!_isModeSupported) {
                    setState(() => _saveErrorMessage = 'Issue Mode "$_selectedIssueMode" is not available yet.');
                    return;
                  }
                  if (!_isSourceSupported) {
                    setState(() => _saveErrorMessage = 'Source "$_source" is not available yet.');
                    return;
                  }
                }
                setState(() {
                  _saveErrorMessage = null;
                  _currentStep++;
                });
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              label: Text(
                _currentStep == 1 ? 'Next: Line Items' : 'Next: Logistics & Summary',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0C3B2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )
          else
            BomAnimatedSuccessButton(
              status: _saveButtonStatus,
              onPressed: _handleSave,
              idleText: _isEditMode ? 'Confirm & Update Issue' : 'Confirm & Save Issue',
              loadingText: _isEditMode ? 'Updating Issue...' : 'Saving Issue...',
              successText: _isEditMode ? 'Updated Successfully!' : 'Saved Successfully!',
              idleIcon: Icons.check_circle_outline_rounded,
              idleBackgroundColor: _isEditMode ? const Color(0xFFD97706) : const Color(0xFF0C3B2E),
              successBackgroundColor: const Color(0xFF10B981),
              height: 42,
              borderRadius: BorderRadius.circular(10),
            ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    TextInputType? keyboardType,
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 12.5,
            color: textColor ?? const Color(0xFF1E293B),
            fontWeight: fontWeight ?? FontWeight.normal,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0C3B2E), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _WizardLineActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _WizardLineActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_WizardLineActionButton> createState() => _WizardLineActionButtonState();
}

class _WizardLineActionButtonState extends State<_WizardLineActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _isHovered ? widget.color.withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: IconButton(
              icon: Icon(
                widget.icon,
                size: 14,
                color: _isHovered ? widget.color : widget.color.withValues(alpha: 0.85),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: widget.onPressed,
            ),
          ),
        ),
      ),
    );
  }
}
