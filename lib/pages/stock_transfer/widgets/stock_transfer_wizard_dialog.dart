import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../design/app_colors.dart';
import '../../bom/bom_models.dart';
import '../../bom/widgets/bom_animated_success_button.dart';
import '../../../services/auth_service.dart';
import '../stock_transfer_models.dart';
import '../stock_transfer_service.dart';
import 'add_stock_transfer_row_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class StockTransferWizardDialog extends StatefulWidget {
  final StockTransferService service;
  final void Function(String code, bool isUpdate) onSaved;
  final String? editCode;
  final StockTransferDetail? initialTransfer;

  const StockTransferWizardDialog({
    super.key,
    required this.service,
    required this.onSaved,
    this.editCode,
    this.initialTransfer,
  });

  @override
  State<StockTransferWizardDialog> createState() => _StockTransferWizardDialogState();
}

class _StockTransferWizardDialogState extends State<StockTransferWizardDialog> {
  int _currentStep = 1;

  bool _isLoadingMasters = true;
  String? _masterError;
  StockTransferLookups? _lookups;

  // Step 2 Line items Horizontal Navigation & Glow State (4-second Strategy)
  final ScrollController _gridHorizCtrl = ScrollController();
  final ScrollController _gridVertCtrl = ScrollController();
  bool _gridCanScrollLeft = false;
  bool _gridCanScrollRight = true;

  int? _recentlySavedSrNo;
  int? _recentlyUpdatedSrNo;
  Timer? _lineGlowTimer;

  // Step 1 Header Fields (Exactly 11 audited fields)
  String _previewDocNo = 'STRF/000000/27'; // 1. Issue Code
  DateTime _entryDate = DateTime.now(); // 2. Date
  String _selectedIssueMode = 'Stock Transfer'; // 3. Issue Mode
  String _source = 'Direct'; // 4. Source (Direct / Requisition)
  int? _selectedSourceStore; // 5. From/Source location
  String? _selectedPlant; // 6. Plant
  int? _selectedSourceDiv; // 7. Division
  int? _selectedSourceDept; // 8. Department
  final TextEditingController _spindalCtrl = TextEditingController(); // 9. Spindal
  final TextEditingController _slipNoCtrl = TextEditingController(text: '0'); // 10. Slip No.
  final TextEditingController _jobCardCtrl = TextEditingController(); // 11. Job Card

  // Step 2 Line Items (Unlimited multi-line rows)
  final List<StockTransferLineItem> _lines = [];
  final Set<int> _selectedRowIndices = {};

  // Step 3 Totals & Logistics (6 totals & logistics fields)
  final TextEditingController _vehicleNoCtrl = TextEditingController();
  final TextEditingController _ewayBillNoCtrl = TextEditingController();
  final TextEditingController _remarkCtrl = TextEditingController();
  List<String> _remarkSuggestions = [];

  // Status & Actions
  bool _isSaving = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;
  String? _saveErrorMessage;

  bool get _isEditMode => widget.editCode != null || widget.initialTransfer != null;

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
    final newOffset = (_gridHorizCtrl.offset - 300.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
    _gridHorizCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  void _scrollGridRight() {
    if (!_gridHorizCtrl.hasClients) return;
    final newOffset = (_gridHorizCtrl.offset + 300.0).clamp(0.0, _gridHorizCtrl.position.maxScrollExtent);
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
        elevation: 4,
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
      final lookups = await widget.service.fetchLookups();

      // If initial transfer is already provided
      if (widget.initialTransfer != null) {
        _populateFromDetail(widget.initialTransfer!);
      } else if (widget.editCode != null) {
        final detail = await widget.service.fetchTransferByCode(widget.editCode!);
        _populateFromDetail(detail);
      } else {
        if (lookups.stores.isNotEmpty) {
          final suratStore = lookups.stores.firstWhere(
            (s) => s.id == 1,
            orElse: () => lookups.stores.first,
          );
          _selectedSourceStore = suratStore.id;
        }
        if (lookups.departments.isNotEmpty) {
          _selectedSourceDept = lookups.departments.first.id;
        }
        if (lookups.divisions.isNotEmpty) {
          final defaultDiv = lookups.divisions.firstWhere(
            (d) => d.id == 1,
            orElse: () => lookups.divisions.first,
          );
          _selectedSourceDiv = defaultDiv.id;
        }
        if (lookups.plants.isNotEmpty) {
          _selectedPlant = lookups.plants.first.name;
        }
        if (lookups.issueModes.isNotEmpty && !lookups.issueModes.contains(_selectedIssueMode)) {
          _selectedIssueMode = lookups.issueModes.first;
        }
        if (lookups.nextDocNo.isNotEmpty) {
          _previewDocNo = lookups.nextDocNo;
        } else {
          _derivePreviewDocNo();
        }
      }

      setState(() {
        _lookups = lookups;
        _isLoadingMasters = false;
      });
    } catch (e) {
      setState(() {
        _masterError = e.toString().replaceAll('Exception: ', '');
        _isLoadingMasters = false;
      });
    }
  }

  void _populateFromDetail(StockTransferDetail detail) {
    final h = detail.header;
    _previewDocNo = h.issueCode;
    _entryDate = h.issueDate;
    _selectedIssueMode = h.issueMode.isNotEmpty ? h.issueMode : 'Stock Transfer';
    _source = h.issueSource.isNotEmpty ? h.issueSource : 'Direct';
    _selectedSourceStore = h.sourceStoreId > 0 ? h.sourceStoreId : _selectedSourceStore;
    _selectedSourceDept = h.sourceDeptCode > 0 ? h.sourceDeptCode : _selectedSourceDept;
    _selectedSourceDiv = h.sourceDivId > 0 ? h.sourceDivId : _selectedSourceDiv;
    _selectedPlant = h.plantName.isNotEmpty ? h.plantName : _selectedPlant;
    _spindalCtrl.text = h.spindal;
    _slipNoCtrl.text = h.slipNo.toString();
    _jobCardCtrl.text = h.jobCard;
    _vehicleNoCtrl.text = h.vehicleNo;
    _ewayBillNoCtrl.text = h.ewayBillNo;
    _remarkCtrl.text = h.remark;

    _lines.clear();
    _lines.addAll(detail.lines);
    for (int i = 0; i < _lines.length; i++) {
      _lines[i].srNo = i + 1;
    }
  }

  Future<void> _updatePreviewDocNo() async {
    if (_isEditMode) return;
    try {
      final code = await widget.service.fetchPreviewCode(
        date: _entryDate,
        issueMode: _selectedIssueMode,
      );
      if (code.isNotEmpty && mounted) {
        setState(() {
          _previewDocNo = code;
        });
      } else {
        _derivePreviewDocNo();
      }
    } catch (_) {
      _derivePreviewDocNo();
    }
  }

  void _derivePreviewDocNo() {
    if (_isEditMode) return;
    final y = _entryDate.year;
    final m = _entryDate.month;
    final fy = m >= 4 ? (y + 1) % 100 : y % 100;
    final prefix = _selectedIssueMode.toLowerCase().contains('department') ||
            _selectedIssueMode.toLowerCase().contains('wip')
        ? 'REGU'
        : 'STRF';
    setState(() {
      _previewDocNo = '$prefix/000000/${fy.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _entryDate) {
      final isLocked = await widget.service.isDateLocked(picked);
      if (isLocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Date ${_formatDate(picked)} is locked against financial changes.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      setState(() {
        _entryDate = picked;
      });
      _updatePreviewDocNo();
    }
  }

  void _showSourceChangeWarning(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Location / Source?'),
        content: const Text(
          'Changing warehouse location or source parameters will reset currently added line items to maintain stock integrity.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirm & Reset Lines'),
          ),
        ],
      ),
    );
  }

  void _onRemarkChanged(String val) async {
    if (val.trim().isNotEmpty) {
      final suggestions = await widget.service.fetchRemarkSuggestions(val.trim());
      setState(() => _remarkSuggestions = suggestions);
    } else {
      setState(() => _remarkSuggestions = []);
    }
  }

  Future<void> _openAddRowDialog({StockTransferLineItem? item}) async {
    if (_lookups == null) return;

    final result = await showDialog<StockTransferLineItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddStockTransferRowDialog(
        service: widget.service,
        lookups: _lookups!,
        date: _entryDate,
        source: _source,
        sourceDept: _selectedSourceDept ?? 0,
        sourceStore: _selectedSourceStore ?? 0,
        sourceDiv: _selectedSourceDiv ?? 0,
        initialItem: item,
        nextSrNo: _lines.length + 1,
      ),
    );

    if (result != null) {
      setState(() {
        if (item != null) {
          final index = _lines.indexOf(item);
          if (index != -1) _lines[index] = result;
          _recentlyUpdatedSrNo = result.srNo;
          _recentlySavedSrNo = null;
        } else {
          _lines.add(result);
          _recentlySavedSrNo = _lines.length;
          _recentlyUpdatedSrNo = null;
        }
        // Ensure sequential numbering across multi-row operations
        for (int i = 0; i < _lines.length; i++) {
          _lines[i].srNo = i + 1;
        }
        if (item != null) {
          final updatedIdx = _lines.indexOf(result);
          if (updatedIdx != -1) _recentlyUpdatedSrNo = updatedIdx + 1;
        } else {
          _recentlySavedSrNo = _lines.length;
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
  }

  void _removeRow(int index) {
    setState(() {
      _lines.removeAt(index);
      _selectedRowIndices.remove(index);
      for (int i = 0; i < _lines.length; i++) {
        _lines[i].srNo = i + 1;
      }
    });
  }

  Future<void> _handleSave() async {
    if (_lines.isEmpty) {
      setState(() {
        _saveErrorMessage = 'Please add at least one line item before saving.';
        _currentStep = 2;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _saveButtonStatus = ButtonStatus.loading;
      _saveErrorMessage = null;
    });

    try {
      final req = StockTransferCreateRequest(
        issueDate: _entryDate,
        issueMode: _selectedIssueMode,
        issueSource: _source,
        sourceStoreId: _selectedSourceStore ?? 0,
        sourceDeptCode: _selectedSourceDept ?? 0,
        sourceDivId: _selectedSourceDiv ?? 0,
        plantName: _selectedPlant ?? '',
        spindal: _spindalCtrl.text.trim(),
        slipNo: int.tryParse(_slipNoCtrl.text.trim()) ?? 0,
        jobCard: _jobCardCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
        vehicleNo: _vehicleNoCtrl.text.trim(),
        ewayBillNo: _ewayBillNoCtrl.text.trim(),
        lines: _lines,
      );

      String code;
      if (_isEditMode) {
        final targetCode = widget.editCode ?? widget.initialTransfer!.header.issueCode;
        code = await widget.service.updateTransfer(targetCode, req);
      } else {
        code = await widget.service.createTransfer(req);
      }

      setState(() {
        _saveButtonStatus = ButtonStatus.success;
        _isSaving = false;
      });

      await Future.delayed(const Duration(milliseconds: 900));

      if (mounted) {
        widget.onSaved(code, _isEditMode);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stock Transfer $code ${_isEditMode ? "updated" : "saved"} successfully!'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _saveErrorMessage = e.toString().replaceAll('Exception: ', '');
        _saveButtonStatus = ButtonStatus.error;
        _isSaving = false;
      });
    }
  }

  // Calculation helpers (Strictly audited totals)
  double get _totStock => _lines.fold(0.0, (acc, l) => acc + l.stock);
  int get _totItm => _lines.length;
  double get _totPcs => _lines.fold(0.0, (acc, l) => acc + l.issPcs);
  double get _totQty => _lines.fold(0.0, (acc, l) => acc + l.issueQty);
  double get _totVal => _lines.fold(0.0, (acc, l) => acc + (l.issueQty * l.rate));

  // Step Header Progress Indicator
  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        children: [
          Text(
            _isEditMode ? 'Edit Stock Transfer ($_previewDocNo)' : 'New Stock Transfer Entry',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _buildStepPill(1, 'Header Setup', Icons.tune_outlined),
          _buildStepDivider(1),
          _buildStepPill(2, 'Line Items Grid', Icons.list_alt_outlined),
          _buildStepDivider(2),
          _buildStepPill(3, 'Totals & Logistics', Icons.local_shipping_outlined),
        ],
      ),
    );
  }

  Widget _buildStepPill(int step, String title, IconData icon) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;

    return InkWell(
      onTap: () {
        if (step == 2 && _lines.isEmpty && _currentStep == 1) {
          setState(() => _currentStep = 2);
        } else if (step < _currentStep || (step == 2 && _currentStep == 1)) {
          setState(() => _currentStep = step);
        } else if (step == 3 && _lines.isNotEmpty) {
          setState(() => _currentStep = 3);
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryColor
              : isDone
                  ? const Color(0xFF10B981)
                  : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDone ? Icons.check : icon,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              '$step. $title',
              style: TextStyle(
                color: Colors.white,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final isDone = _currentStep > step;
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDone ? const Color(0xFF10B981) : const Color(0xFF475569),
    );
  }

  // Step 1 View: Header Configuration (Exactly 11 Fields)
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 1: Header Configuration (11 Master Fields)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Define the issuing warehouse, source department, source mode, and transfer operational metadata.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          // Row 1: Issue Code, Date, Mode, Source
          Row(
            children: [
              Expanded(
                child: _buildStaticField('1. Issue Code (Auto)', _previewDocNo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDatePickerField('2. Transfer Date *', _entryDate, _selectDate),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<String>(
                  '3. Issue Mode *',
                  (_lookups?.issueModes ?? const ['Stock Transfer', 'To Department', 'To WIP'])
                          .contains(_selectedIssueMode)
                      ? _selectedIssueMode
                      : ((_lookups?.issueModes.isNotEmpty ?? false)
                          ? _lookups!.issueModes.first
                          : _selectedIssueMode),
                  (_lookups?.issueModes ?? const ['Stock Transfer', 'To Department', 'To WIP']).map((mode) {
                    return DropdownMenuItem<String>(
                      value: mode,
                      child: Text(mode, style: const TextStyle(fontSize: 12.5)),
                    );
                  }).toList(),
                  _isEditMode
                      ? null
                      : (val) {
                          if (val != null && val != _selectedIssueMode) {
                            setState(() {
                              _selectedIssueMode = val;
                            });
                            _updatePreviewDocNo();
                          }
                        },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<String>(
                  '4. Source *',
                  _source,
                  const [
                    DropdownMenuItem(value: 'Direct', child: Text('Direct')),
                    DropdownMenuItem(value: 'Requisition', child: Text('Requisition')),
                  ],
                  (val) {
                    if (val != null && val != _source) {
                      setState(() => _source = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 2: From/Source Location, Plant, Division, Department
          Row(
            children: [
              Expanded(
                child: _buildDropdownField<int>(
                  '5. From / Source Location *',
                  _selectedSourceStore,
                  _lookups?.stores.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList() ?? [],
                  (val) {
                    if (_lines.isNotEmpty) {
                      _showSourceChangeWarning(() => setState(() {
                            _selectedSourceStore = val;
                            _lines.clear();
                          }));
                    } else {
                      setState(() => _selectedSourceStore = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<String>(
                  '6. Plant / Packing Unit *',
                  _selectedPlant,
                  _lookups?.plants.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList() ?? [],
                  (val) => setState(() => _selectedPlant = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<int>(
                  '7. Division / Cost Center *',
                  _selectedSourceDiv,
                  _lookups?.divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList() ?? [],
                  (val) {
                    if (_lines.isNotEmpty) {
                      _showSourceChangeWarning(() => setState(() {
                            _selectedSourceDiv = val;
                            _lines.clear();
                          }));
                    } else {
                      setState(() => _selectedSourceDiv = val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDropdownField<int>(
                  '8. Department (LABOURMST) *',
                  _selectedSourceDept,
                  _lookups?.departments.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList() ?? [],
                  (val) {
                    if (_lines.isNotEmpty) {
                      _showSourceChangeWarning(() => setState(() {
                            _selectedSourceDept = val;
                            _lines.clear();
                          }));
                    } else {
                      setState(() => _selectedSourceDept = val);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Row 3: Spindal, Slip No., Job Card
          Row(
            children: [
              Expanded(
                child: _buildInputField('9. Spindal', _spindalCtrl),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField('10. Slip No.', _slipNoCtrl, isNumeric: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputField('11. Job Card', _jobCardCtrl),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2 View: Line Items Grid (Dynamic 15 or 14 Columns based on Source)
  Widget _buildStep2() {
    final isRequisition = _source == 'Requisition';

    return Column(
      children: [
        // Grid Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Text(
                'Line Items (${_lines.length} Rows Added) — Source Mode: $_source (${isRequisition ? "15 Columns" : "14 Columns"})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155)),
              ),
              const Spacer(),
              // Left / Right Navigation Scroll Buttons for Grid
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
                      tooltip: 'Scroll Table Left',
                      onPressed: _scrollGridLeft,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                    Container(height: 16, width: 1, color: const Color(0xFFCBD5E1)),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF475569)),
                      tooltip: 'Scroll Table Right',
                      onPressed: _scrollGridRight,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => _openAddRowDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(isRequisition ? 'Add Row (Requisition)' : 'Add Row (Direct)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),

        // Grid Content
        Expanded(
          child: _lines.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text('No transfer line items added yet.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                        isRequisition
                            ? 'Click "Add Row (Requisition)" to select pending requisition lines.'
                            : 'Click "Add Row (Direct)" to pick stock items from the issuing warehouse.',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Scrollbar(
                      controller: _gridHorizCtrl,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _gridHorizCtrl,
                        scrollDirection: Axis.horizontal,
                        child: Scrollbar(
                          controller: _gridVertCtrl,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _gridVertCtrl,
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                              headingRowHeight: 38,
                              dataRowMinHeight: 36,
                              dataRowMaxHeight: 40,
                              columns: isRequisition
                                  ? const [
                                      // 15 Columns when Source = "Requisition"
                                      DataColumn(label: Text('Select', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Req. Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Item Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Cost Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('UQC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Merge No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Maker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Nos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Iss. Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                    ]
                                  : const [
                                      // 14 Columns when Source = "Direct"
                                      DataColumn(label: Text('Item Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('To Cost Center', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('UQC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Merge No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Grade', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Maker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Nos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(numeric: true, label: Text('Iss. Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Remark / Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                    ],
                              rows: List.generate(_lines.length, (idx) {
                                final l = _lines[idx];
                                final isChecked = _selectedRowIndices.contains(idx);
                                final isNewGlow = l.srNo == _recentlySavedSrNo;
                                final isUpdateGlow = l.srNo == _recentlyUpdatedSrNo;
                                final isGlowing = isNewGlow || isUpdateGlow;
                                final glowColor = isUpdateGlow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

                                return DataRow(
                                  selected: isChecked,
                                  color: WidgetStateProperty.resolveWith<Color>((states) {
                                    if (isGlowing) return glowColor.withValues(alpha: 0.14);
                                    if (isChecked) return const Color(0xFFEFF6FF);
                                    return idx.isEven ? Colors.white : const Color(0xFFFAFAFA);
                                  }),
                                  cells: isRequisition
                                      ? [
                                          // 15 Cells
                                          DataCell(
                                            Checkbox(
                                              value: isChecked,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedRowIndices.add(idx);
                                                  } else {
                                                    _selectedRowIndices.remove(idx);
                                                  }
                                                });
                                              },
                                            ),
                                          ),
                                          DataCell(Text(l.reqCode, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5))),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(l.itemCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isGlowing ? glowColor : null)),
                                                if (isNewGlow) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                ] else if (isUpdateGlow) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
                                                    child: const Text('UPDATED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                  DataCell(Text(l.itemName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toDeptName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toStoreName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toCostName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.unitName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.mrgNo, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.grade, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.maker, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.rate.toStringAsFixed(3), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.stock.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.issPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.issueQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0F766E)),
                                          onPressed: () => _openAddRowDialog(item: l),
                                          splashRadius: 16,
                                          tooltip: 'Edit Line',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          onPressed: () => _removeRow(idx),
                                          splashRadius: 16,
                                          tooltip: 'Delete Line',
                                        ),
                                      ],
                                    ),
                                  ),
                                ]
                              : [
                                  // 14 Cells
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(l.itemCode, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: isGlowing ? glowColor : null)),
                                        if (isNewGlow) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ] else if (isUpdateGlow) ...[
                                          const SizedBox(width: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('UPDATED', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(l.itemName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toDeptName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toStoreName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.toCostName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.unitName, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.mrgNo, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.grade, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.maker, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.rate.toStringAsFixed(3), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.stock.toStringAsFixed(2), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.issPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 11.5))),
                                  DataCell(Text(l.issueQty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                                  DataCell(Text(l.remark, style: const TextStyle(fontSize: 11.5))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 16, color: Color(0xFF0F766E)),
                                          onPressed: () => _openAddRowDialog(item: l),
                                          splashRadius: 16,
                                          tooltip: 'Edit Line',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          onPressed: () => _removeRow(idx),
                                          splashRadius: 16,
                                          tooltip: 'Delete Line',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            if (_gridCanScrollLeft)
              Positioned(
                left: 8,
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
            if (_gridCanScrollRight)
              Positioned(
                right: 8,
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
      ],
    );
  }

  // Step 3 View: Totals & Logistics (6 Total Fields)
  Widget _buildStep3() {
    final issuer = AuthService.instance.currentUser?.username ?? 'ADMIN';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Step 3: Audited Totals & Logistics (6 Mandatory Summary Fields)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          const Text('Review verified stock and ledger totals before executing atomic database persistence.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          // 5 Summary Metric Cards (Stock, Total Item, Total Pcs/Box, Total Qty, Total Value)
          Row(
            children: [
              Expanded(child: _buildMetricCard('1. Current Stock', _totStock.toStringAsFixed(2), Icons.inventory_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('2. Total Item', '$_totItm', Icons.inventory_2_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('3. Total Pcs/Box', _totPcs.toStringAsFixed(0), Icons.all_inbox_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('4. Total Qty', _totQty.toStringAsFixed(2), Icons.scale_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('5. Total Value', '₹ ${_totVal.toStringAsFixed(2)}', Icons.account_balance_wallet_outlined)),
            ],
          ),
          const SizedBox(height: 24),

          // 6. Logistics & User Tracking Inputs
          const Text('6. Logistics & Operational Audit Inputs',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInputField('Vehicle No.', _vehicleNoCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildInputField('E-Way Bill No.', _ewayBillNoCtrl)),
              const SizedBox(width: 16),
              Expanded(child: _buildStaticField('Issuer (User Context)', issuer)),
            ],
          ),
          const SizedBox(height: 16),

          // Remark Field with Suggestions
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Remark', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 5),
              TextField(
                controller: _remarkCtrl,
                onChanged: _onRemarkChanged,
                maxLines: 2,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Enter transfer remark or transport comments...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
              if (_remarkSuggestions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: _remarkSuggestions.map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _remarkCtrl.text = s;
                          _remarkSuggestions = [];
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Common UI Builders
  Widget _buildStaticField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ),
      ],
    );
  }

  Widget _buildDatePickerField(String label, DateTime date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Text(_formatDate(date), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?>? onChanged,
  ) {
    final bool isDisabled = onChanged == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDisabled ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.any((i) => i.value == value) ? value : null,
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl, {bool isNumeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        const SizedBox(height: 5),
        SizedBox(
          height: 38,
          child: TextField(
            controller: ctrl,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String val, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(
                  val,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.f1): () {
            if (!_isSaving) _handleSave();
          },
        },
        child: Focus(
          autofocus: true,
          child: Container(
            width: 1100,
            height: 700,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step Indicator Header
                _buildStepIndicator(),

                // Error Banner if save failed
                if (_saveErrorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    color: const Color(0xFFFEE2E2),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _saveErrorMessage!,
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                          onPressed: () => setState(() => _saveErrorMessage = null),
                          splashRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ],

                // Body content per step
                Expanded(
                  child: _isLoadingMasters
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                      : _masterError != null
                          ? Center(child: Text(_masterError!, style: const TextStyle(color: Colors.red)))
                          : _currentStep == 1
                              ? _buildStep1()
                              : _currentStep == 2
                                  ? _buildStep2()
                                  : _buildStep3(),
                ),

                // Wizard Bottom Navigation Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(15),
                      bottomRight: Radius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      if (_currentStep > 1) ...[
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _currentStep--),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Previous'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (_currentStep < 3) ...[
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_currentStep == 1 && _lines.isEmpty) {
                              setState(() => _currentStep = 2);
                            } else {
                              setState(() => _currentStep++);
                            }
                          },
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('Next Step'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ] else ...[
                        BomAnimatedSuccessButton(
                          status: _saveButtonStatus,
                          onPressed: _saveButtonStatus == ButtonStatus.loading ? null : _handleSave,
                          idleText: _isEditMode ? 'Update Transfer (F1)' : 'Save Transfer (F1)',
                          idleBackgroundColor: const Color(0xFF0F766E),
                          height: 38,
                          width: 190,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
