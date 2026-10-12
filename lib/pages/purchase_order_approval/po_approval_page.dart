import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_colors.dart';
import 'po_approval_models.dart';
import 'po_approval_service.dart';
import 'widgets/po_approval_export_modal_dialog.dart';
import '../bom/bom_models.dart';
import '../bom/widgets/bom_animated_success_button.dart';
import '../bom/widgets/bom_export_modal_dialog.dart';
import '../bom/widgets/bom_modern_date_picker_dialog.dart';
import '../bom/widgets/bom_modern_dropdown.dart';

class _ViewModeStep {
  final int index;
  final String label;
  final Color color;
  final Color glowColor;
  final Color activeBorderTint;
  final Color inactiveBarColor;

  const _ViewModeStep({
    required this.index,
    required this.label,
    required this.color,
    required this.glowColor,
    required this.activeBorderTint,
    required this.inactiveBarColor,
  });
}

/// Purchase Order Release & Approval Module
/// Enterprise central control hub for reviewing, filtering, and approving purchase orders.
/// 100% mirrors BOM Follow-up layout, modern filter modal dialog, high-density table, and token standards.
class PoApprovalPage extends StatefulWidget {
  final PoApprovalService? service;

  const PoApprovalPage({super.key, this.service});

  @override
  State<PoApprovalPage> createState() => _PoApprovalPageState();
}

class _PoApprovalPageState extends State<PoApprovalPage> {
  late final PoApprovalService _service;

  // View Mode: 'PENDING', 'APPROVED', 'REJECTED', 'HOLD', 'CLOSE', 'UNCLOSE'
  String _currentViewMode = 'PENDING';

  // Target Status Action: 'Approve', 'Reject', 'Hold', 'Close', 'UnClose'
  String _selectedActionType = 'Approve';
  DateTime _approvalDate = DateTime.now();
  final TextEditingController _actionRemarkCtrl = TextEditingController();

  // Filters State
  int _selectedDeptCode = 0; // 0 = ALL
  int _selectedPlantCode = 0; // 0 = ALL
  int _selectedPartyCode = 0; // 0 = ALL
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  // Lookups cache
  PoApprovalLookupsData _lookups = const PoApprovalLookupsData();

  // Records & Selection
  List<PoApprovalRecord> _records = [];
  final Set<String> _selectedRowKeys = {};
  bool _isLoading = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;

  // Button Micro-Feedback States
  String? _buttonValidationMsg;
  Timer? _buttonValidationTimer;

  // Search & Focus
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  // Scroll controllers
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  // Column View Mode: 0: All Columns, 1: Overview, 2: Quantities & Rates, 3: Tracking & Metadata
  int _columnViewMode = 0;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  static const List<_ViewModeStep> _stepperSteps = [
    _ViewModeStep(
      index: 0,
      label: 'All Columns',
      color: Color(0xFF059669),
      glowColor: Color(0xFF10B981),
      activeBorderTint: Color(0xFFA7F3D0),
      inactiveBarColor: Color(0xFFA7F3D0),
    ),
    _ViewModeStep(
      index: 1,
      label: 'Overview',
      color: Color(0xFF0091FF),
      glowColor: Color(0xFF00A3FF),
      activeBorderTint: Color(0xFFBAE6FD),
      inactiveBarColor: Color(0xFFBAE6FD),
    ),
    _ViewModeStep(
      index: 2,
      label: 'Quantities',
      color: Color(0xFF7C3AED),
      glowColor: Color(0xFF8B5CF6),
      activeBorderTint: Color(0xFFDDD6FE),
      inactiveBarColor: Color(0xFFDDD6FE),
    ),
    _ViewModeStep(
      index: 3,
      label: 'Process',
      color: Color(0xFFEA580C),
      glowColor: Color(0xFFF97316),
      activeBorderTint: Color(0xFFFFEDD5),
      inactiveBarColor: Color(0xFFFFEDD5),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? PoApprovalService();
    _loadInitialData();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _buttonValidationTimer?.cancel();
    _searchCtrl.dispose();
    _actionRemarkCtrl.dispose();
    _focusNode.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final maxScroll = _horizontalScrollCtrl.position.maxScrollExtent;
    final offset = _horizontalScrollCtrl.offset;
    final canLeft = offset > 10;
    final canRight = offset < maxScroll - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset - 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousViewMode() {
    setState(() {
      _columnViewMode = (_columnViewMode - 1 + 4) % 4;
      if (_horizontalScrollCtrl.hasClients) {
        _horizontalScrollCtrl.jumpTo(0.0);
      }
    });
  }

  void _nextViewMode() {
    setState(() {
      _columnViewMode = (_columnViewMode + 1) % 4;
      if (_horizontalScrollCtrl.hasClients) {
        _horizontalScrollCtrl.jumpTo(0.0);
      }
    });
  }

  bool get _hasActiveFilters =>
      _currentViewMode != 'PENDING' ||
      _selectedDeptCode != 0 ||
      _selectedPlantCode != 0 ||
      _selectedPartyCode != 0 ||
      _filterFromDate != null ||
      _filterToDate != null;

  int get _activeFilterCount =>
      (_currentViewMode != 'PENDING' ? 1 : 0) +
      (_selectedDeptCode != 0 ? 1 : 0) +
      (_selectedPlantCode != 0 ? 1 : 0) +
      (_selectedPartyCode != 0 ? 1 : 0) +
      (_filterFromDate != null || _filterToDate != null ? 1 : 0);

  void _showButtonValidation(String msg) {
    setState(() {
      _buttonValidationMsg = msg;
      _saveButtonStatus = ButtonStatus.error;
    });
    _buttonValidationTimer?.cancel();
    _buttonValidationTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _saveButtonStatus = ButtonStatus.idle;
          _buttonValidationMsg = null;
        });
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final lookups = await _service.fetchLookups();
      _lookups = lookups;
      await _fetchGridRecords();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGridRecords() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchRecords(
        viewMode: _currentViewMode,
        deptCode: _selectedDeptCode > 0 ? _selectedDeptCode : null,
        plantCode: _selectedPlantCode > 0 ? _selectedPlantCode : null,
        partyCode: _selectedPartyCode > 0 ? _selectedPartyCode : null,
        fromDate: _filterFromDate,
        toDate: _filterToDate,
      );
      if (mounted) {
        setState(() {
          _records = list;
          _selectedRowKeys.removeWhere((key) => !_records.any((r) => r.rowKey == key));
        });
      }
    } catch (e) {
      debugPrint('Error fetching PO approval records: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<PoApprovalRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    return _records.where((r) {
      final poMatch = r.purOrdNo.toLowerCase().contains(_searchQuery);
      final itemMatch = r.itCode.toLowerCase().contains(_searchQuery) ||
          r.itemName.toLowerCase().contains(_searchQuery);
      final partyMatch = r.partyName.toLowerCase().contains(_searchQuery);
      final deptMatch = r.department.toLowerCase().contains(_searchQuery);
      final plantMatch = r.plant.toLowerCase().contains(_searchQuery);
      final refMatch = r.refNo.toLowerCase().contains(_searchQuery);
      final shadeMatch = r.shade.toLowerCase().contains(_searchQuery);
      return poMatch || itemMatch || partyMatch || deptMatch || plantMatch || refMatch || shadeMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final list = _filteredRecords;
    if (list.isEmpty) return false;
    return list.every((r) => _selectedRowKeys.contains(r.rowKey));
  }

  void _toggleSelectAllFiltered() {
    final list = _filteredRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in list) {
          _selectedRowKeys.remove(r.rowKey);
        }
      } else {
        for (final r in list) {
          _selectedRowKeys.add(r.rowKey);
        }
      }
    });
  }

  void _toggleRecordSelection(String rowKey) {
    setState(() {
      if (_selectedRowKeys.contains(rowKey)) {
        _selectedRowKeys.remove(rowKey);
      } else {
        _selectedRowKeys.add(rowKey);
      }
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _handleExecuteAction() async {
    if (_saveButtonStatus == ButtonStatus.loading) return;

    if (_selectedRowKeys.isEmpty) {
      _showButtonValidation('Select at least 1 record');
      return;
    }

    setState(() {
      _buttonValidationMsg = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    try {
      // 1. Check Date Lock
      final isLocked = await _service.checkLockDate(_approvalDate);
      if (isLocked) {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
        _showLockWarningDialog();
        return;
      }

      final itemsToProcess = <PoApprovalActionItemPayload>[];
      for (final r in _records) {
        if (_selectedRowKeys.contains(r.rowKey)) {
          itemsToProcess.add(PoApprovalActionItemPayload(
            poNo: r.purOrdNo,
            pId: r.pId,
            departmentName: r.department,
          ));
        }
      }

      await _service.processStatusAction(
        actionType: _selectedActionType,
        approvalDate: _approvalDate,
        remark: _actionRemarkCtrl.text.trim(),
        items: itemsToProcess,
      );

      setState(() => _saveButtonStatus = ButtonStatus.success);

      Future.delayed(const Duration(milliseconds: 600), () async {
        if (!mounted) return;
        _selectedRowKeys.clear();
        await _fetchGridRecords();
      });

      Timer(const Duration(milliseconds: 2000), () {
        if (mounted && _saveButtonStatus == ButtonStatus.success) {
          setState(() => _saveButtonStatus = ButtonStatus.idle);
        }
      });
    } catch (e) {
      debugPrint('Error executing status action: $e');
      setState(() => _saveButtonStatus = ButtonStatus.error);
      _showButtonValidation(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showLockWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: AppColors.error, size: 26),
            SizedBox(width: 10),
            Text('Date Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Transactions for date ${_formatDate(_approvalDate)} are locked in LOCKDATAMST. Cannot update purchase orders on this date.',
          style: const TextStyle(fontSize: 13.5, color: AppColors.neutralDark),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openExportModal() {
    if (_records.isEmpty) {
      _showButtonValidation('No records to export');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PoApprovalExportModalDialog(records: _filteredRecords),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER MODAL DIALOG (BOM Follow-Up Parity)
  // ---------------------------------------------------------------------------
  void _openFilterDialog() {
    String tempViewMode = _currentViewMode;
    int tempDeptCode = _selectedDeptCode;
    int tempPlantCode = _selectedPlantCode;
    int tempPartyCode = _selectedPartyCode;
    DateTime? tempFromDate = _filterFromDate;
    DateTime? tempToDate = _filterToDate;
    String localSearchQuery = '';
    ButtonStatus filterBtnStatus = ButtonStatus.idle;

    final viewModeOptions = [
      {'key': 'PENDING', 'label': 'Filter View Only (Pending)', 'icon': Icons.content_paste_search_rounded},
      {'key': 'APPROVED', 'label': 'Approved PO Entries', 'icon': Icons.check_circle_rounded},
      {'key': 'REJECTED', 'label': 'Rejected PO Entries', 'icon': Icons.cancel_rounded},
      {'key': 'HOLD', 'label': 'Hold PO Entries', 'icon': Icons.pause_circle_rounded},
      {'key': 'CLOSE', 'label': 'Close PO Entries', 'icon': Icons.lock_rounded},
      {'key': 'UNCLOSE', 'label': 'UnClose PO Entries', 'icon': Icons.lock_open_rounded},
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.40),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 680,
                constraints: const BoxConstraints(maxHeight: 740),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            size: 19,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Purchase Orders',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Refine view mode, department, supplier, plant, and date range',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => Navigator.of(ctx).pop(),
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Search Pill Input inside Modal
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              style: const TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w600),
                              decoration: const InputDecoration(
                                hintText: 'Quick filter department or supplier list...',
                                hintStyle: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (val) {
                                setDialogState(() => localSearchQuery = val.trim().toLowerCase());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Scrollable Filter Sections
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // SECTION 1: VIEW MODE (Entry Status)
                            _buildFilterSectionTitle('ENTRY VIEW MODE / STATUS'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: viewModeOptions.map((opt) {
                                final isSelected = tempViewMode == opt['key'];
                                return InkWell(
                                  onTap: () => setDialogState(() => tempViewMode = opt['key'] as String),
                                  borderRadius: BorderRadius.circular(20),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppColors.primaryColor : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryColor : const Color(0xFFCBD5E1),
                                        width: 1.1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primaryColor.withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          opt['icon'] as IconData,
                                          size: 14,
                                          color: isSelected ? Colors.white : const Color(0xFF475569),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          opt['label'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? Colors.white : const Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            // SECTION 2: DATE RANGE / PERIOD
                            _buildFilterSectionTitle('PERIOD / DATE RANGE'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('From Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showModernDatePicker(
                                            context: ctx,
                                            initialDate: tempFromDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => tempFromDate = picked);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          height: 38,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryColor),
                                              const SizedBox(width: 8),
                                              Text(
                                                tempFromDate != null ? _formatDate(tempFromDate!) : 'Select From Date',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: tempFromDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (tempFromDate != null)
                                                InkWell(
                                                  onTap: () => setDialogState(() => tempFromDate = null),
                                                  child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('To Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showModernDatePicker(
                                            context: ctx,
                                            initialDate: tempToDate ?? DateTime.now(),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => tempToDate = picked);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          height: 38,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primaryColor),
                                              const SizedBox(width: 8),
                                              Text(
                                                tempToDate != null ? _formatDate(tempToDate!) : 'Select To Date',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: tempToDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              const Spacer(),
                                              if (tempToDate != null)
                                                InkWell(
                                                  onTap: () => setDialogState(() => tempToDate = null),
                                                  child: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                                                ),
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

                            // SECTION 3: DEPARTMENT
                            _buildFilterSectionTitle('DEPARTMENT'),
                            const SizedBox(height: 5),
                            BomModernDropdown<int>(
                              value: tempDeptCode,
                              hintText: 'Select Department',
                              dropdownTitle: 'DEPARTMENT LIST',
                              items: [
                                const BomDropdownItem<int>(
                                  value: 0,
                                  label: 'ALL DEPARTMENTS',
                                  subtitle: 'Show all purchase order departments',
                                  icon: Icons.apartment_rounded,
                                ),
                                ..._lookups.departments
                                    .where((d) => localSearchQuery.isEmpty || d.labName.toLowerCase().contains(localSearchQuery))
                                    .map(
                                      (d) => BomDropdownItem<int>(
                                        value: d.labCode,
                                        label: d.labName,
                                        subtitle: 'Code: ${d.labCode}',
                                        icon: Icons.apartment_rounded,
                                      ),
                                    ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => tempDeptCode = val);
                                }
                              },
                            ),

                            const SizedBox(height: 14),

                            // SECTION 4: PLANT / STORE
                            _buildFilterSectionTitle('PLANT / STORE'),
                            const SizedBox(height: 5),
                            BomModernDropdown<int>(
                              value: tempPlantCode,
                              hintText: 'Select Plant / Store',
                              dropdownTitle: 'PLANTS & WAREHOUSES',
                              items: [
                                const BomDropdownItem<int>(
                                  value: 0,
                                  label: 'ALL PLANTS',
                                  subtitle: 'Show all warehouses and plants',
                                  icon: Icons.store_mall_directory_rounded,
                                ),
                                ..._lookups.plants
                                    .where((p) => localSearchQuery.isEmpty || p.strName.toLowerCase().contains(localSearchQuery))
                                    .map(
                                      (p) => BomDropdownItem<int>(
                                        value: p.strCode,
                                        label: p.strName,
                                        subtitle: 'Code: ${p.strCode}',
                                        icon: Icons.store_mall_directory_rounded,
                                      ),
                                    ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => tempPlantCode = val);
                                }
                              },
                            ),

                            const SizedBox(height: 14),

                            // SECTION 5: SUPPLIER / PARTY
                            _buildFilterSectionTitle('SUPPLIER / PARTY'),
                            const SizedBox(height: 5),
                            BomModernDropdown<int>(
                              value: tempPartyCode,
                              hintText: 'Select Supplier / Party',
                              dropdownTitle: 'SUPPLIERS LIST',
                              items: [
                                const BomDropdownItem<int>(
                                  value: 0,
                                  label: 'ALL SUPPLIERS',
                                  subtitle: 'Show all suppliers and creditors',
                                  icon: Icons.business_rounded,
                                ),
                                ..._lookups.suppliers
                                    .where((s) => localSearchQuery.isEmpty || s.pName.toLowerCase().contains(localSearchQuery))
                                    .map(
                                      (s) => BomDropdownItem<int>(
                                        value: s.pCode,
                                        label: s.pName,
                                        subtitle: 'Code: ${s.pCode}',
                                        icon: Icons.business_rounded,
                                      ),
                                    ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => tempPartyCode = val);
                                }
                              },
                            ),

                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Dialog Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              tempViewMode = 'PENDING';
                              tempDeptCode = 0;
                              tempPlantCode = 0;
                              tempPartyCode = 0;
                              tempFromDate = null;
                              tempToDate = null;
                              localSearchQuery = '';
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF64748B)),
                          label: const Text(
                            'Reset All',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 10),
                            BomAnimatedSuccessButton(
                              status: filterBtnStatus,
                              onPressed: () async {
                                setDialogState(() => filterBtnStatus = ButtonStatus.loading);
                                await Future.delayed(const Duration(milliseconds: 250));
                                if (!ctx.mounted) return;
                                setDialogState(() => filterBtnStatus = ButtonStatus.success);
                                await Future.delayed(const Duration(milliseconds: 450));
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _currentViewMode = tempViewMode;
                                  _selectedDeptCode = tempDeptCode;
                                  _selectedPlantCode = tempPlantCode;
                                  _selectedPartyCode = tempPartyCode;
                                  _filterFromDate = tempFromDate;
                                  _filterToDate = tempToDate;
                                });
                                await _fetchGridRecords();
                              },
                              idleText: 'Apply Filters',
                              loadingText: 'Applying...',
                              successText: 'Filters Applied!',
                              idleIcon: Icons.check_rounded,
                              idleBackgroundColor: AppColors.secondaryColor,
                              successBackgroundColor: const Color(0xFF10B981),
                              height: 36,
                              width: 140,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF475569),
        letterSpacing: 0.4,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
          _handleExecuteAction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER & ACTION CONTROLS (Mirrors BOM Follow Up)
              _buildTopHeader(),

              // 2. MAIN TABLE CONTAINER (Department Master Parity)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.tableBorder, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 2.1 Table Subheader with Filter Button, Search Bar, & Stepper Presets
                          _buildTableSubHeader(filtered.length),

                          // 2.2 Master High-Density Grid
                          Expanded(
                            child: _buildTableContent(filtered),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader() {
    final actionColor = _selectedActionType == 'Reject'
        ? AppColors.error
        : (_selectedActionType == 'Hold'
            ? const Color(0xFFF59E0B)
            : (_selectedActionType == 'Close'
                ? const Color(0xFF64748B)
                : AppColors.secondaryColor));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.tableBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Icon & Module Title (Responsive)
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.2)),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.assignment_turned_in_rounded,
                        color: AppColors.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Purchase Order Release & Approval',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Review, filter, and approve purchase orders in real-time',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right Action Controls Strip (wrapped in SingleChildScrollView to guarantee zero overflow)
            Flexible(
              flex: 0,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Approval Date Picker
                    Tooltip(
                      message: 'Click to select transaction date',
                      child: InkWell(
                        onTap: () async {
                          final picked = await showModernDatePicker(
                            context: context,
                            initialDate: _approvalDate,
                          );
                          if (picked != null) {
                            setState(() => _approvalDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primaryColor),
                              const SizedBox(width: 5),
                              Text(
                                _formatDate(_approvalDate),
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Set Status Dropdown
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedActionType,
                          isDense: true,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(
                              value: 'Approve',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                  SizedBox(width: 5),
                                  Text('Approve'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Reject',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cancel_rounded, size: 13, color: AppColors.error),
                                  SizedBox(width: 5),
                                  Text('Reject'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Hold',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pause_circle_rounded, size: 13, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 5),
                                  Text('Hold'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'Close',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_rounded, size: 13, color: Color(0xFF64748B)),
                                  SizedBox(width: 5),
                                  Text('Close'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'UnClose',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_open_rounded, size: 13, color: AppColors.primaryColor),
                                  SizedBox(width: 5),
                                  Text('UnClose'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _selectedActionType = val ?? 'Approve'),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Action Remark Field
                    SizedBox(
                      width: 130,
                      height: 34,
                      child: TextField(
                        controller: _actionRemarkCtrl,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Action remark...',
                          hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Export Button
                    BomAnimatedExportButton(onPressed: _openExportModal),

                    const SizedBox(width: 6),

                    // Save Animated Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (_buttonValidationMsg != null) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  _buttonValidationMsg!,
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        BomAnimatedSuccessButton(
                          status: _saveButtonStatus,
                          onPressed: _handleExecuteAction,
                          idleText: '$_selectedActionType (F1)',
                          loadingText: 'Processing...',
                          successText: '$_selectedActionType Done!',
                          errorText: 'Select Records',
                          idleIcon: _selectedActionType == 'Reject'
                              ? Icons.cancel_outlined
                              : (_selectedActionType == 'Hold'
                                  ? Icons.pause_circle_outline
                                  : (_selectedActionType == 'Close'
                                      ? Icons.lock_outline
                                      : Icons.check_circle_outline_rounded)),
                          idleBackgroundColor: actionColor,
                          successBackgroundColor: const Color(0xFF10B981),
                          height: 34,
                          width: 125,
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TABLE SUBHEADER
  // ---------------------------------------------------------------------------
  Widget _buildTableSubHeader(int count) {
    final selectedCount = _selectedRowKeys.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0)),
      ),
      child: Row(
        children: [
          // Left: Count Badge & Selection Info + Filter + Search (Horizontal scrollable if constrained)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.table_chart_outlined, size: 12, color: AppColors.primaryColor),
                        const SizedBox(width: 5),
                        Text(
                          _currentViewMode == 'PENDING'
                              ? '$count PENDING'
                              : '$count ($_currentViewMode)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF059669)),
                          const SizedBox(width: 4),
                          Text(
                            '$selectedCount sel.',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Filter Button
                  _buildFilterButton(),
                  const SizedBox(width: 6),
                  // Compact Search Bar
                  _buildCompactGlassmorphicSearchBar(),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Right: Stepper Progress Bar Navigation Cluster
          _buildStepperProgressNavigationCluster(),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasActive = _hasActiveFilters;
    final activeCount = _activeFilterCount;

    return Tooltip(
      message: 'Filter records by View Mode, Department, Plant, Supplier, Date',
      child: InkWell(
        onTap: _openFilterDialog,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: hasActive ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 14,
                color: hasActive ? const Color(0xFF065F46) : const Color(0xFF334155),
              ),
              const SizedBox(width: 5),
              Text(
                'Filter',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: hasActive ? const Color(0xFF065F46) : const Color(0xFF334155),
                ),
              ),
              if (hasActive) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactGlassmorphicSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 165,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _searchQuery.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Search PO, item...',
              hintStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 15, color: AppColors.primaryColor),
              prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 32),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 13, color: Color(0xFF64748B)),
                      onPressed: () => _searchCtrl.clear(),
                      splashRadius: 10,
                      padding: EdgeInsets.zero,
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 22, minHeight: 32),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              isDense: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperProgressNavigationCluster() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepperArrowButton(
          icon: Icons.chevron_left_rounded,
          onTap: _previousViewMode,
          tooltip: 'Previous View Mode',
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepNode(_stepperSteps[0], isActive: _columnViewMode == 0),
            _buildConnectorLine(precedingIndex: 0),
            _buildStepNode(_stepperSteps[1], isActive: _columnViewMode == 1),
            _buildConnectorLine(precedingIndex: 1),
            _buildStepNode(_stepperSteps[2], isActive: _columnViewMode == 2),
            _buildConnectorLine(precedingIndex: 2),
            _buildStepNode(_stepperSteps[3], isActive: _columnViewMode == 3),
          ],
        ),
        const SizedBox(width: 8),
        _buildStepperArrowButton(
          icon: Icons.chevron_right_rounded,
          onTap: _nextViewMode,
          tooltip: 'Next View Mode',
        ),
      ],
    );
  }

  Widget _buildStepperArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildStepNode(_ViewModeStep step, {required bool isActive}) {
    final Color barColor = isActive ? step.color : step.inactiveBarColor;

    return Tooltip(
      message: 'Switch to ${step.label}',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            setState(() => _columnViewMode = step.index);
            if (_horizontalScrollCtrl.hasClients) {
              _horizontalScrollCtrl.jumpTo(0.0);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? step.color : Colors.white,
                  border: isActive
                      ? Border.all(color: step.activeBorderTint.withValues(alpha: 0.9), width: 1.3)
                      : Border.all(color: step.color, width: 1.6),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: step.glowColor.withValues(alpha: 0.50),
                            blurRadius: 8,
                            spreadRadius: 2.5,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${step.index + 1}',
                  style: TextStyle(
                    color: isActive ? Colors.white : step.color,
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 3.5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 1.8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 12,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 3.5),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? step.color : const Color(0xFF64748B),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectorLine({required int precedingIndex}) {
    final bool isCompleted = _columnViewMode > precedingIndex;
    final step = _stepperSteps[precedingIndex];

    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 14,
        height: 2,
        color: isCompleted ? step.color : const Color(0xFFE2E8F0),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TABLE BODY & HEADER CELLS
  // ---------------------------------------------------------------------------
  static const double _colWidthIndex = 42.0;
  static const double _colWidthCheckbox = 44.0;
  static const double _colWidthPoNo = 130.0;
  static const double _colWidthPoDate = 95.0;
  static const double _colWidthRefNo = 110.0;
  static const double _colWidthRefDate = 95.0;
  static const double _colWidthDept = 130.0;
  static const double _colWidthPlant = 110.0;
  static const double _colWidthSupplier = 180.0;
  static const double _colWidthItemCode = 150.0;
  static const double _colWidthItemDesc = 240.0;
  static const double _colWidthShade = 90.0;
  static const double _colWidthPoQty = 90.0;
  static const double _colWidthInwardQty = 90.0;
  static const double _colWidthBalQty = 90.0;
  static const double _colWidthRate = 85.0;
  static const double _colWidthAmount = 95.0;
  static const double _colWidthFreight = 75.0;
  static const double _colWidthStatus = 95.0;
  static const double _colWidthProcessDo = 100.0;
  static const double _colWidthIndentNo = 100.0;
  static const double _colWidthCloseRemark = 140.0;

  // Base table widths per mode (Mathematically exact sum of column widths)
  static const double _mode0BaseWidth = _colWidthIndex +
      _colWidthCheckbox +
      _colWidthPoNo +
      _colWidthPoDate +
      _colWidthRefNo +
      _colWidthRefDate +
      _colWidthDept +
      _colWidthPlant +
      _colWidthSupplier +
      _colWidthItemCode +
      _colWidthItemDesc +
      _colWidthShade +
      _colWidthPoQty +
      _colWidthInwardQty +
      _colWidthBalQty +
      _colWidthRate +
      _colWidthAmount +
      _colWidthFreight +
      _colWidthStatus +
      _colWidthProcessDo +
      _colWidthIndentNo +
      _colWidthCloseRemark; // 2376.0

  static const double _mode1BaseWidth = _colWidthIndex +
      _colWidthCheckbox +
      _colWidthPoNo +
      _colWidthPoDate +
      _colWidthDept +
      _colWidthPlant +
      _colWidthSupplier +
      _colWidthItemDesc +
      _colWidthPoQty +
      _colWidthBalQty +
      _colWidthStatus; // 1246.0

  static const double _mode2BaseWidth = _colWidthIndex +
      _colWidthCheckbox +
      _colWidthPoNo +
      _colWidthSupplier +
      _colWidthItemDesc +
      _colWidthPoQty +
      _colWidthInwardQty +
      _colWidthBalQty +
      _colWidthRate +
      _colWidthAmount +
      _colWidthFreight +
      _colWidthStatus; // 1256.0

  static const double _mode3BaseWidth = _colWidthIndex +
      _colWidthCheckbox +
      _colWidthPoNo +
      _colWidthSupplier +
      _colWidthItemCode +
      _colWidthRefNo +
      _colWidthRefDate +
      _colWidthProcessDo +
      _colWidthIndentNo +
      _colWidthCloseRemark +
      _colWidthStatus; // 1186.0

  double _calculateTotalTableWidth(double availableWidth) {
    switch (_columnViewMode) {
      case 1: // Overview
        return availableWidth > _mode1BaseWidth ? availableWidth : _mode1BaseWidth;
      case 2: // Quantities & Rates
        return availableWidth > _mode2BaseWidth ? availableWidth : _mode2BaseWidth;
      case 3: // Tracking & Process
        return availableWidth > _mode3BaseWidth ? availableWidth : _mode3BaseWidth;
      case 0: // All Columns
      default:
        return _mode0BaseWidth;
    }
  }

  double _calculateExtraWidth(double availableWidth) {
    switch (_columnViewMode) {
      case 1:
        return (availableWidth - _mode1BaseWidth).clamp(0.0, 1000.0);
      case 2:
        return (availableWidth - _mode2BaseWidth).clamp(0.0, 1000.0);
      case 3:
        return (availableWidth - _mode3BaseWidth).clamp(0.0, 1000.0);
      case 0:
      default:
        return 0.0;
    }
  }

  Widget _buildTableContent(List<PoApprovalRecord> list) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.slateMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No purchase order records found for $_currentViewMode mode',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Adjust the filter parameters or search query to find open records.',
              style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = _calculateTotalTableWidth(constraints.maxWidth);
        final extraWidth = _calculateExtraWidth(constraints.maxWidth);
        final needsHorizontalScroll = tableWidth > constraints.maxWidth;

        return Stack(
          children: [
            Scrollbar(
              controller: _horizontalScrollCtrl,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollCtrl,
                scrollDirection: Axis.horizontal,
                physics: needsHorizontalScroll
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      // Table Headers
                      _buildTableHeader(extraWidth),

                      // Table Body Rows
                      Expanded(
                        child: Scrollbar(
                          controller: _verticalScrollCtrl,
                          thumbVisibility: true,
                          child: ListView.separated(
                            controller: _verticalScrollCtrl,
                            itemCount: list.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (ctx, index) {
                              final r = list[index];
                              final isSelected = _selectedRowKeys.contains(r.rowKey);
                              final isEven = index % 2 == 0;
                              return _buildTableRow(index + 1, r, isSelected, isEven, extraWidth);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Left Floating Navigation Arrow
            if (needsHorizontalScroll && _canScrollLeft)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildFloatingArrowButton(
                    icon: Icons.chevron_left_rounded,
                    onTap: _scrollLeft,
                    tooltip: 'Scroll Left',
                  ),
                ),
              ),

            // Right Floating Navigation Arrow
            if (needsHorizontalScroll && _canScrollRight)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _buildFloatingArrowButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _scrollRight,
                    tooltip: 'Scroll Right',
                  ),
                ),
              ),
          ],
        );
      },
    );
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
        shadowColor: Colors.black.withValues(alpha: 0.15),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader([double extraWidth = 0.0]) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      child: Row(
        children: [
          // Row SrNo
          const SizedBox(
            width: _colWidthIndex,
            child: Center(
              child: Text(
                '#',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
              ),
            ),
          ),

          // Select All Checkbox
          SizedBox(
            width: _colWidthCheckbox,
            child: Center(
              child: Checkbox(
                value: _isAllFilteredSelected,
                activeColor: AppColors.primaryColor,
                onChanged: (_) => _toggleSelectAllFiltered(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          ..._buildHeaderCellsForMode(extraWidth),
        ],
      ),
    );
  }

  List<Widget> _buildHeaderCellsForMode([double extraWidth = 0.0]) {
    switch (_columnViewMode) {
      case 1: // Overview
        final supplierW = _colWidthSupplier + (extraWidth * 0.4);
        final itemW = _colWidthItemDesc + (extraWidth * 0.6);
        return [
          _buildHeaderCell(_colWidthPoNo, 'PO NO', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthPoDate, 'DATE', Icons.calendar_today_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(_colWidthDept, 'DEPARTMENT', Icons.apartment_rounded, const Color(0xFF10B981)),
          _buildHeaderCell(_colWidthPlant, 'PLANT', Icons.store_mall_directory_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(supplierW, 'SUPPLIER', Icons.business_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(itemW, 'ITEM DESCRIPTION', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(_colWidthPoQty, 'PO QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(_colWidthBalQty, 'BAL QTY', Icons.timelapse_rounded, const Color(0xFFEF4444), alignRight: true),
          _buildHeaderCell(_colWidthStatus, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
        ];

      case 2: // Quantities & Rates
        final itemW = _colWidthItemDesc + extraWidth;
        return [
          _buildHeaderCell(_colWidthPoNo, 'PO NO', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthSupplier, 'SUPPLIER', Icons.business_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(itemW, 'ITEM DESCRIPTION', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(_colWidthPoQty, 'PO QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(_colWidthInwardQty, 'INWARD QTY', Icons.move_to_inbox_rounded, const Color(0xFF06B6D4), alignRight: true),
          _buildHeaderCell(_colWidthBalQty, 'BAL QTY', Icons.timelapse_rounded, const Color(0xFFEF4444), alignRight: true),
          _buildHeaderCell(_colWidthRate, 'RATE', Icons.currency_rupee_rounded, AppColors.primaryColor, alignRight: true),
          _buildHeaderCell(_colWidthAmount, 'AMOUNT', Icons.account_balance_wallet_outlined, const Color(0xFF059669), alignRight: true),
          _buildHeaderCell(_colWidthFreight, 'FREIGHT', Icons.local_shipping_outlined, const Color(0xFF64748B), alignRight: true),
          _buildHeaderCell(_colWidthStatus, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
        ];

      case 3: // Tracking & Process
        final remarkW = _colWidthCloseRemark + extraWidth;
        return [
          _buildHeaderCell(_colWidthPoNo, 'PO NO', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthSupplier, 'SUPPLIER', Icons.business_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(_colWidthItemCode, 'ITEM CODE', Icons.qr_code_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(_colWidthRefNo, 'REF NO', Icons.receipt_long_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(_colWidthRefDate, 'REF DATE', Icons.event_note_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(_colWidthProcessDo, 'PROCESS DO', Icons.alt_route_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(_colWidthIndentNo, 'INDENT NO', Icons.numbers_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(remarkW, 'CLOSE REMARK', Icons.notes_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(_colWidthStatus, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
        ];

      case 0: // All Columns
      default:
        return [
          _buildHeaderCell(_colWidthPoNo, 'PO NO', Icons.tag_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthPoDate, 'PO DATE', Icons.calendar_today_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(_colWidthRefNo, 'REF NO', Icons.receipt_long_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(_colWidthRefDate, 'REF DATE', Icons.event_note_rounded, const Color(0xFFF59E0B)),
          _buildHeaderCell(_colWidthDept, 'DEPARTMENT', Icons.apartment_rounded, const Color(0xFF10B981)),
          _buildHeaderCell(_colWidthPlant, 'PLANT', Icons.store_mall_directory_rounded, const Color(0xFF06B6D4)),
          _buildHeaderCell(_colWidthSupplier, 'SUPPLIER', Icons.business_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(_colWidthItemCode, 'ITEM CODE', Icons.qr_code_rounded, const Color(0xFF64748B)),
          _buildHeaderCell(_colWidthItemDesc, 'ITEM DESCRIPTION', Icons.inventory_2_outlined, const Color(0xFFEC4899)),
          _buildHeaderCell(_colWidthShade, 'SHADE', Icons.palette_outlined, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthPoQty, 'PO QTY', Icons.calculate_outlined, const Color(0xFFF97316), alignRight: true),
          _buildHeaderCell(_colWidthInwardQty, 'INWARD QTY', Icons.move_to_inbox_rounded, const Color(0xFF06B6D4), alignRight: true),
          _buildHeaderCell(_colWidthBalQty, 'BAL QTY', Icons.timelapse_rounded, const Color(0xFFEF4444), alignRight: true),
          _buildHeaderCell(_colWidthRate, 'RATE', Icons.currency_rupee_rounded, AppColors.primaryColor, alignRight: true),
          _buildHeaderCell(_colWidthAmount, 'AMOUNT', Icons.account_balance_wallet_outlined, const Color(0xFF059669), alignRight: true),
          _buildHeaderCell(_colWidthFreight, 'FREIGHT', Icons.local_shipping_outlined, const Color(0xFF64748B), alignRight: true),
          _buildHeaderCell(_colWidthStatus, 'STATUS', Icons.verified_rounded, const Color(0xFF10B981), center: true),
          _buildHeaderCell(_colWidthProcessDo, 'PROCESS DO', Icons.alt_route_rounded, const Color(0xFF8B5CF6)),
          _buildHeaderCell(_colWidthIndentNo, 'INDENT NO', Icons.numbers_rounded, const Color(0xFF6366F1)),
          _buildHeaderCell(_colWidthCloseRemark, 'CLOSE REMARK', Icons.notes_rounded, const Color(0xFF64748B)),
        ];
    }
  }

  Widget _buildHeaderCell(
    double width,
    String label,
    IconData icon,
    Color iconColor, {
    bool alignRight = false,
    bool center = false,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: center
              ? MainAxisAlignment.center
              : (alignRight ? MainAxisAlignment.end : MainAxisAlignment.start),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: iconColor),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(int index, PoApprovalRecord r, bool isSelected, bool isEven, [double extraWidth = 0.0]) {
    return InkWell(
      onTap: () => _toggleRecordSelection(r.rowKey),
      hoverColor: const Color(0xFFF1F5F9),
      child: Container(
        height: 42,
        color: isSelected
            ? const Color(0xFFF0FDF4)
            : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
        child: Row(
          children: [
            // Sr No
            SizedBox(
              width: _colWidthIndex,
              child: Center(
                child: Text(
                  '$index',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Checkbox
            SizedBox(
              width: _colWidthCheckbox,
              child: Center(
                child: Checkbox(
                  value: isSelected,
                  activeColor: AppColors.primaryColor,
                  onChanged: (_) => _toggleRecordSelection(r.rowKey),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

            ..._buildRowCellsForMode(r, extraWidth),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRowCellsForMode(PoApprovalRecord r, [double extraWidth = 0.0]) {
    switch (_columnViewMode) {
      case 1: // Overview
        final supplierW = _colWidthSupplier + (extraWidth * 0.4);
        final itemW = _colWidthItemDesc + (extraWidth * 0.6);
        return [
          _buildCell(_colWidthPoNo, r.purOrdNo, isBold: true, textColor: AppColors.primaryColor),
          _buildCell(_colWidthPoDate, _formatDate(r.poDate)),
          _buildCell(_colWidthDept, r.department),
          _buildCell(_colWidthPlant, r.plant),
          _buildCell(supplierW, r.partyName, isBold: true),
          _buildCell(itemW, r.itemName),
          _buildCell(_colWidthPoQty, r.poQty.toStringAsFixed(2), alignRight: true, isBold: true),
          _buildCell(_colWidthBalQty, r.balanceQty.toStringAsFixed(2), alignRight: true, isBold: true, textColor: r.balanceQty > 0 ? const Color(0xFFDC2626) : null),
          _buildStatusCell(_colWidthStatus, r),
        ];

      case 2: // Quantities & Rates
        final itemW = _colWidthItemDesc + extraWidth;
        return [
          _buildCell(_colWidthPoNo, r.purOrdNo, isBold: true, textColor: AppColors.primaryColor),
          _buildCell(_colWidthSupplier, r.partyName, isBold: true),
          _buildCell(itemW, r.itemName),
          _buildCell(_colWidthPoQty, r.poQty.toStringAsFixed(2), alignRight: true, isBold: true),
          _buildCell(_colWidthInwardQty, r.inwardQty.toStringAsFixed(2), alignRight: true),
          _buildCell(_colWidthBalQty, r.balanceQty.toStringAsFixed(2), alignRight: true, isBold: true, textColor: r.balanceQty > 0 ? const Color(0xFFDC2626) : null),
          _buildCell(_colWidthRate, r.rate.toStringAsFixed(2), alignRight: true),
          _buildCell(_colWidthAmount, r.amount.toStringAsFixed(2), alignRight: true, isBold: true),
          _buildCell(_colWidthFreight, r.freight.toStringAsFixed(2), alignRight: true, textColor: const Color(0xFF94A3B8)),
          _buildStatusCell(_colWidthStatus, r),
        ];

      case 3: // Tracking & Process
        final remarkW = _colWidthCloseRemark + extraWidth;
        return [
          _buildCell(_colWidthPoNo, r.purOrdNo, isBold: true, textColor: AppColors.primaryColor),
          _buildCell(_colWidthSupplier, r.partyName, isBold: true),
          _buildCell(_colWidthItemCode, r.itCode, textColor: const Color(0xFF475569)),
          _buildCell(_colWidthRefNo, r.refNo.isNotEmpty ? r.refNo : '-'),
          _buildCell(_colWidthRefDate, r.refDate != null ? _formatDate(r.refDate!) : '-'),
          _buildCell(_colWidthProcessDo, r.processDo ?? '-'),
          _buildCell(_colWidthIndentNo, r.indCode.isNotEmpty ? r.indCode : '-'),
          _buildCell(remarkW, r.podClosRem.isNotEmpty ? r.podClosRem : '-'),
          _buildStatusCell(_colWidthStatus, r),
        ];

      case 0: // All Columns
      default:
        return [
          _buildCell(_colWidthPoNo, r.purOrdNo, isBold: true, textColor: AppColors.primaryColor),
          _buildCell(_colWidthPoDate, _formatDate(r.poDate)),
          _buildCell(_colWidthRefNo, r.refNo.isNotEmpty ? r.refNo : '-'),
          _buildCell(_colWidthRefDate, r.refDate != null ? _formatDate(r.refDate!) : '-'),
          _buildCell(_colWidthDept, r.department),
          _buildCell(_colWidthPlant, r.plant),
          _buildCell(_colWidthSupplier, r.partyName, isBold: true),
          _buildCell(_colWidthItemCode, r.itCode, textColor: const Color(0xFF475569)),
          _buildCell(_colWidthItemDesc, r.itemName),
          _buildCell(_colWidthShade, r.shade.isNotEmpty ? r.shade : '-'),
          _buildCell(_colWidthPoQty, r.poQty.toStringAsFixed(2), alignRight: true, isBold: true),
          _buildCell(_colWidthInwardQty, r.inwardQty.toStringAsFixed(2), alignRight: true),
          _buildCell(_colWidthBalQty, r.balanceQty.toStringAsFixed(2), alignRight: true, isBold: true, textColor: r.balanceQty > 0 ? const Color(0xFFDC2626) : null),
          _buildCell(_colWidthRate, r.rate.toStringAsFixed(2), alignRight: true),
          _buildCell(_colWidthAmount, r.amount.toStringAsFixed(2), alignRight: true, isBold: true),
          _buildCell(_colWidthFreight, r.freight.toStringAsFixed(2), alignRight: true, textColor: const Color(0xFF94A3B8)),
          _buildStatusCell(_colWidthStatus, r),
          _buildCell(_colWidthProcessDo, r.processDo ?? '-'),
          _buildCell(_colWidthIndentNo, r.indCode.isNotEmpty ? r.indCode : '-'),
          _buildCell(_colWidthCloseRemark, r.podClosRem.isNotEmpty ? r.podClosRem : '-'),
        ];
    }
  }

  Widget _buildCell(
    double width,
    String text, {
    bool alignRight = false,
    bool isBold = false,
    Color? textColor,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCell(double width, PoApprovalRecord r) {
    Color badgeBg;
    Color badgeFg;

    if (r.isApproved) {
      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.12);
      badgeFg = const Color(0xFF047857);
    } else if (r.isClosed) {
      badgeBg = const Color(0xFF64748B).withValues(alpha: 0.12);
      badgeFg = const Color(0xFF334155);
    } else if (r.isRejected) {
      badgeBg = AppColors.error.withValues(alpha: 0.12);
      badgeFg = AppColors.error;
    } else if (r.isHeld) {
      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      badgeFg = const Color(0xFFB45309);
    } else {
      badgeBg = AppColors.secondaryColor.withValues(alpha: 0.14);
      badgeFg = AppColors.primaryColor;
    }

    return SizedBox(
      width: width,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            r.status,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg),
          ),
        ),
      ),
    );
  }
}
