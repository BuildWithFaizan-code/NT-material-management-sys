import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/app_colors.dart';
import 'so_approval_models.dart';
import 'so_approval_service.dart';
import 'widgets/so_approval_export_modal_dialog.dart';
import '../bom/bom_models.dart';
import '../bom/widgets/bom_animated_success_button.dart';
import '../bom/widgets/bom_modern_date_picker_dialog.dart';

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

/// Sales Order Release & Approval Module
/// Enterprise central control hub for reviewing, filtering, and releasing/approving sales orders.
/// 100% mirrors BOM Follow-up layout, modern filter modal dialog, high-density table, and token standards.
class SoApprovalPage extends StatefulWidget {
  final SoApprovalService? service;

  const SoApprovalPage({super.key, this.service});

  @override
  State<SoApprovalPage> createState() => _SoApprovalPageState();
}

class _SoApprovalPageState extends State<SoApprovalPage> {
  late final SoApprovalService _service;

  // View Mode: 'PENDING', 'APPROVED', 'REJECTED', 'HOLD', 'CLOSE', 'UNCLOSE'
  String _currentViewMode = 'PENDING';

  // Target Status Action: 'Approve', 'Reject', 'Hold', 'Close', 'UnClose'
  String _selectedActionType = 'Approve';
  DateTime _approvalDate = DateTime.now();
  final TextEditingController _actionRemarkCtrl = TextEditingController();

  // Filters State
  int _selectedDeptCode = 0; // 0 = ALL
  int _selectedPartyCode = 0; // 0 = ALL
  String _selectedSoNo = '';
  String _selectedItemSearch = '';
  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  // Lookups cache
  SoApprovalLookupsData _lookups = const SoApprovalLookupsData();

  // Records & Selection
  List<SoApprovalRecord> _records = [];
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

  // Column View Mode: 0: All Columns, 1: Overview, 2: Quantities & Rates, 3: Process & Audit
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
    _service = widget.service ?? SoApprovalService();
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
      _selectedPartyCode != 0 ||
      _selectedSoNo.isNotEmpty ||
      _selectedItemSearch.isNotEmpty ||
      _filterFromDate != null ||
      _filterToDate != null;

  int get _activeFilterCount =>
      (_currentViewMode != 'PENDING' ? 1 : 0) +
      (_selectedDeptCode != 0 ? 1 : 0) +
      (_selectedPartyCode != 0 ? 1 : 0) +
      (_selectedSoNo.isNotEmpty ? 1 : 0) +
      (_selectedItemSearch.isNotEmpty ? 1 : 0) +
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
        partyCode: _selectedPartyCode > 0 ? _selectedPartyCode : null,
        soNo: _selectedSoNo.isNotEmpty ? _selectedSoNo : null,
        itemSearch: _selectedItemSearch.isNotEmpty ? _selectedItemSearch : null,
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
      debugPrint('Error fetching SO approval records: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<SoApprovalRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    return _records.where((r) {
      final soMatch = r.salOrdNo.toLowerCase().contains(_searchQuery);
      final itemMatch = r.itCode.toLowerCase().contains(_searchQuery) ||
          r.itemName.toLowerCase().contains(_searchQuery);
      final partyMatch = r.partyName.toLowerCase().contains(_searchQuery);
      final deptMatch = r.labName.toLowerCase().contains(_searchQuery);
      final cellMatch = r.cellNo.toLowerCase().contains(_searchQuery);
      final statusMatch = r.status.toLowerCase().contains(_searchQuery);
      return soMatch || itemMatch || partyMatch || deptMatch || cellMatch || statusMatch;
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

      final itemsToProcess = <SoApprovalActionItemPayload>[];
      for (final r in _records) {
        if (_selectedRowKeys.contains(r.rowKey)) {
          itemsToProcess.add(SoApprovalActionItemPayload(
            soNo: r.salOrdNo,
            sId: r.sId,
            itemCode: r.itCode,
            departmentName: r.labName,
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
          'Transactions for date ${_formatDate(_approvalDate)} are locked in LOCKDATAMST. Cannot update sales orders on this date.',
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
      builder: (ctx) => SoApprovalExportModalDialog(records: _filteredRecords),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER MODAL DIALOG (BOM Follow-Up Parity)
  // ---------------------------------------------------------------------------
  void _openFilterDialog() {
    String tempViewMode = _currentViewMode;
    int tempDeptCode = _selectedDeptCode;
    int tempPartyCode = _selectedPartyCode;
    String tempSoNo = _selectedSoNo;
    String tempItemSearch = _selectedItemSearch;
    DateTime? tempFromDate = _filterFromDate;
    DateTime? tempToDate = _filterToDate;
    ButtonStatus filterBtnStatus = ButtonStatus.idle;

    final viewModeOptions = [
      {'key': 'PENDING', 'label': 'Filter View Only (Pending)', 'icon': Icons.content_paste_search_rounded},
      {'key': 'APPROVED', 'label': 'Approved SO Entries', 'icon': Icons.check_circle_rounded},
      {'key': 'REJECTED', 'label': 'Rejected SO Entries', 'icon': Icons.cancel_rounded},
      {'key': 'HOLD', 'label': 'Hold SO Entries', 'icon': Icons.pause_circle_rounded},
      {'key': 'CLOSE', 'label': 'Close SO Entries', 'icon': Icons.lock_rounded},
      {'key': 'UNCLOSE', 'label': 'UnClose SO Entries', 'icon': Icons.lock_open_rounded},
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeCount = (tempViewMode != 'PENDING' ? 1 : 0) +
                (tempDeptCode != 0 ? 1 : 0) +
                (tempPartyCode != 0 ? 1 : 0) +
                (tempSoNo.isNotEmpty ? 1 : 0) +
                (tempItemSearch.isNotEmpty ? 1 : 0) +
                (tempFromDate != null || tempToDate != null ? 1 : 0);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Center(
                child: Container(
                  width: 900,
                  height: 640,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // Modal Header
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tune_rounded, color: Color(0xFF059669), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Filter Sales Order Directory',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (activeCount > 0) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$activeCount Active',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Text(
                                    'Toggle status views, filter by customer, department, order no, item, or date period',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),

                        // Modal Body Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. View Mode Toggles
                                const Text(
                                  'VIEW MODE / STATUS TOGGLE',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: viewModeOptions.map((opt) {
                                    final isSelected = tempViewMode == opt['key'];
                                    return InkWell(
                                      onTap: () => setModalState(() => tempViewMode = opt['key'] as String),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1),
                                            width: isSelected ? 1.5 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              opt['icon'] as IconData,
                                              size: 15,
                                              color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              opt['label'] as String,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),

                                const SizedBox(height: 24),
                                const Divider(color: Color(0xFFE2E8F0)),
                                const SizedBox(height: 16),

                                // 2. Dropdowns: Order No, Department, Customer, Item
                                const Text(
                                  'SPECIFIC MASTER FILTERS',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    // Order No Filter
                                    Expanded(
                                      child: _buildModalDropdown<String>(
                                        label: 'Order No',
                                        icon: Icons.sell_outlined,
                                        value: tempSoNo.isEmpty ? null : tempSoNo,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('ALL Sales Orders')),
                                          ..._lookups.orderNumbers.map((so) => DropdownMenuItem(value: so, child: Text(so))),
                                        ],
                                        onChanged: (val) => setModalState(() => tempSoNo = val ?? ''),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Department Filter
                                    Expanded(
                                      child: _buildModalDropdown<int>(
                                        label: 'Department',
                                        icon: Icons.account_tree_outlined,
                                        value: tempDeptCode == 0 ? null : tempDeptCode,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('ALL Departments')),
                                          ..._lookups.departments.map((d) => DropdownMenuItem(value: d.labCode, child: Text(d.labName))),
                                        ],
                                        onChanged: (val) => setModalState(() => tempDeptCode = val ?? 0),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    // Customer / Party Filter
                                    Expanded(
                                      child: _buildModalDropdown<int>(
                                        label: 'Customer / Party',
                                        icon: Icons.business_rounded,
                                        value: tempPartyCode == 0 ? null : tempPartyCode,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('ALL Customers')),
                                          ..._lookups.customers.map((c) => DropdownMenuItem(value: c.pCode, child: Text(c.pName))),
                                        ],
                                        onChanged: (val) => setModalState(() => tempPartyCode = val ?? 0),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Item Filter
                                    Expanded(
                                      child: _buildModalDropdown<String>(
                                        label: 'Item Filter',
                                        icon: Icons.inventory_2_outlined,
                                        value: tempItemSearch.isEmpty ? null : tempItemSearch,
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('ALL Items')),
                                          ..._lookups.items.map((i) => DropdownMenuItem(value: i.itCode, child: Text('${i.itCode} - ${i.itemName}'))),
                                        ],
                                        onChanged: (val) => setModalState(() => tempItemSearch = val ?? ''),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),
                                const Divider(color: Color(0xFFE2E8F0)),
                                const SizedBox(height: 16),

                                // 3. Date Range Filter
                                const Text(
                                  'TRANSACTION DATE PERIOD',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDateBox(
                                        label: 'From Date',
                                        date: tempFromDate,
                                        onSelect: () async {
                                          final picked = await showModernDatePicker(
                                            context: context,
                                            initialDate: tempFromDate ?? DateTime.now(),
                                          );
                                          if (picked != null) {
                                            setModalState(() => tempFromDate = picked);
                                          }
                                        },
                                        onClear: () => setModalState(() => tempFromDate = null),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: _buildDateBox(
                                        label: 'To Date',
                                        date: tempToDate,
                                        onSelect: () async {
                                          final picked = await showModernDatePicker(
                                            context: context,
                                            initialDate: tempToDate ?? DateTime.now(),
                                          );
                                          if (picked != null) {
                                            setModalState(() => tempToDate = picked);
                                          }
                                        },
                                        onClear: () => setModalState(() => tempToDate = null),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Modal Footer
                        Container(
                          height: 64,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                          ),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    tempViewMode = 'PENDING';
                                    tempDeptCode = 0;
                                    tempPartyCode = 0;
                                    tempSoNo = '';
                                    tempItemSearch = '';
                                    tempFromDate = null;
                                    tempToDate = null;
                                  });
                                },
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Reset All Filters'),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF64748B),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              BomAnimatedSuccessButton(
                                status: filterBtnStatus,
                                onPressed: () {
                                  setState(() {
                                    _currentViewMode = tempViewMode;
                                    _selectedDeptCode = tempDeptCode;
                                    _selectedPartyCode = tempPartyCode;
                                    _selectedSoNo = tempSoNo;
                                    _selectedItemSearch = tempItemSearch;
                                    _filterFromDate = tempFromDate;
                                    _filterToDate = tempToDate;
                                  });
                                  Navigator.of(ctx).pop();
                                  _fetchGridRecords();
                                },
                                idleText: 'Apply Filter',
                                loadingText: 'Applying...',
                                successText: 'Filter Applied!',
                                errorText: 'Error',
                                idleBackgroundColor: const Color(0xFF059669),
                                successBackgroundColor: const Color(0xFF10B981),
                                height: 36,
                                width: 140,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalDropdown<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox({
    required String label,
    required DateTime? date,
    required VoidCallback onSelect,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelect,
                  child: Text(
                    date != null ? _formatDate(date) : 'Select date...',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                      color: date != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              if (date != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                  onPressed: onClear,
                  splashRadius: 12,
                  padding: EdgeInsets.zero,
                )
              else
                IconButton(
                  icon: const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF64748B)),
                  onPressed: onSelect,
                  splashRadius: 12,
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // MAIN SCAFFOLD & VIEW BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.f1) {
            _handleExecuteAction();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.f5) {
            _fetchGridRecords();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 1. Top Enterprise Control Bar (Mirrors BOM Follow Up / PO Approval Header)
              _buildTopControlBar(),

              const SizedBox(height: 12),

              // 2. High Density Directory Table Card
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      children: [
                        // SubHeader: Counter, Filter, Search, View Mode Stepper Cluster
                        _buildTableSubHeader(_filteredRecords.length),

                        // Table Grid Body
                        Expanded(
                          child: _isLoading
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryColor),
                                      SizedBox(height: 12),
                                      Text('Loading sales order records...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                )
                              : _filteredRecords.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'No sales order records match your criteria',
                                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _hasActiveFilters
                                                ? 'Try clearing some filters or changing your view mode'
                                                : 'All orders in this view are processed',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        final tableWidth = constraints.maxWidth > 1780.0 ? constraints.maxWidth : 1780.0;
                                        return Scrollbar(
                                          controller: _horizontalScrollCtrl,
                                          thumbVisibility: true,
                                          trackVisibility: true,
                                          scrollbarOrientation: ScrollbarOrientation.bottom,
                                          child: SingleChildScrollView(
                                            controller: _horizontalScrollCtrl,
                                            scrollDirection: Axis.horizontal,
                                            physics: const ClampingScrollPhysics(),
                                            child: SizedBox(
                                              width: tableWidth,
                                              child: Column(
                                                children: [
                                                  // Column Header Bar
                                                  _buildTableHeaderBar(),

                                                  // Table Row List
                                                  Expanded(
                                                    child: Scrollbar(
                                                      controller: _verticalScrollCtrl,
                                                      thumbVisibility: true,
                                                      child: ListView.separated(
                                                        controller: _verticalScrollCtrl,
                                                        itemCount: _filteredRecords.length,
                                                        separatorBuilder: (ctx, idx) => const Divider(
                                                          height: 1,
                                                          thickness: 1,
                                                          color: Color(0xFFF1F5F9),
                                                        ),
                                                        itemBuilder: (context, index) {
                                                          final record = _filteredRecords[index];
                                                          final isSelected = _selectedRowKeys.contains(record.rowKey);
                                                          final isZebra = index % 2 == 1;

                                                          return InkWell(
                                                            onTap: () => _toggleRecordSelection(record.rowKey),
                                                            child: Container(
                                                              height: 38,
                                                              color: isSelected
                                                                  ? const Color(0xFFECFDF5)
                                                                  : (isZebra ? const Color(0xFFF8FAFC) : Colors.white),
                                                              padding: const EdgeInsets.symmetric(horizontal: 14),
                                                              child: _buildDataRow(record, index + 1, isSelected),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
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
  // 1. TOP CONTROL BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopControlBar() {
    Color actionColor = const Color(0xFF10B981);
    if (_selectedActionType == 'Reject') {
      actionColor = AppColors.error;
    } else if (_selectedActionType == 'Hold') {
      actionColor = const Color(0xFFF59E0B);
    } else if (_selectedActionType == 'Close') {
      actionColor = const Color(0xFF64748B);
    } else if (_selectedActionType == 'UnClose') {
      actionColor = AppColors.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Module Identity & View Mode Quick Pills
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_cart_checkout_outlined, color: AppColors.brandBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Release Sales Order',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'Executive Customer Order Approval & Release Hub',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                  const SizedBox(width: 16),
                  // Quick View Mode Pills
                  _buildQuickPill('PENDING', 'Pending', Icons.schedule_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                  const SizedBox(width: 6),
                  _buildQuickPill('APPROVED', 'Approved', Icons.check_circle_rounded, const Color(0xFF059669), const Color(0xFFDCFCE7)),
                  const SizedBox(width: 6),
                  _buildQuickPill('REJECTED', 'Rejected', Icons.cancel_rounded, const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                  const SizedBox(width: 6),
                  _buildQuickPill('HOLD', 'Hold', Icons.pause_circle_rounded, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                  const SizedBox(width: 6),
                  _buildQuickPill('CLOSE', 'Closed', Icons.lock_rounded, const Color(0xFF475569), const Color(0xFFE2E8F0)),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right: Action Control Cluster (Date Picker, Set Status, Remark, Export, Save)
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
                    width: 140,
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
                  ElevatedButton.icon(
                    onPressed: _openExportModal,
                    icon: const Icon(Icons.file_download_outlined, size: 14, color: Colors.white),
                    label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      elevation: 0,
                    ),
                  ),

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
    );
  }

  Widget _buildQuickPill(String mode, String label, IconData icon, Color activeColor, Color activeBg) {
    final isSelected = _currentViewMode == mode;

    return InkWell(
      onTap: () {
        setState(() {
          _currentViewMode = mode;
        });
        _fetchGridRecords();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? activeColor : const Color(0xFF64748B)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF475569),
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
          // Left: Count Badge & Selection Info + Filter + Search
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
      message: 'Filter records by View Mode, Department, Customer, Order No, Date',
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
              if (activeCount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$activeCount',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
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
    return Container(
      width: 180,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _focusNode,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 13, color: Color(0xFF64748B)),
                  onPressed: () => _searchCtrl.clear(),
                  splashRadius: 10,
                  padding: EdgeInsets.zero,
                )
              : null,
          hintText: 'Search table...',
          hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildStepperProgressNavigationCluster() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Previous View Mode
        Tooltip(
          message: 'Previous View Mode',
          child: InkWell(
            onTap: _previousViewMode,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 16, color: Color(0xFF2563EB)),
            ),
          ),
        ),
        const SizedBox(width: 4),

        // View Mode Stepper Dots
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _stepperSteps.map((step) {
              final isCurrent = _columnViewMode == step.index;
              return Tooltip(
                message: 'View: ${step.label}',
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _columnViewMode = step.index;
                      if (_horizontalScrollCtrl.hasClients) {
                        _horizontalScrollCtrl.jumpTo(0.0);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isCurrent ? step.color : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      step.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        color: isCurrent ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 4),

        // Next View Mode
        Tooltip(
          message: 'Next View Mode',
          child: InkWell(
            onTap: _nextViewMode,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Left / Right Scroll Navigation
        Container(
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _scrollLeft,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: Color(0xFF2563EB)),
                ),
              ),
              Container(width: 1, height: 16, color: const Color(0xFFCBD5E1)),
              InkWell(
                onTap: _scrollRight,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3. TABLE HEADER BAR
  // ---------------------------------------------------------------------------
  Widget _buildTableHeaderBar() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Select All Checkbox
          SizedBox(
            width: 44,
            child: Checkbox(
              value: _isAllFilteredSelected,
              onChanged: (_) => _toggleSelectAllFiltered(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeColor: AppColors.brandBlue,
            ),
          ),

          // Sr No
          const SizedBox(
            width: 45,
            child: Text('#', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
          ),

          // Sales Order No
          const SizedBox(
            width: 135,
            child: Row(
              children: [
                Icon(Icons.sell_outlined, size: 12, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Text('SO NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),

          // Date
          const SizedBox(
            width: 95,
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0891B2)),
                SizedBox(width: 4),
                Text('DATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),

          // Department
          const SizedBox(
            width: 140,
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 12, color: Color(0xFF8B5CF6)),
                SizedBox(width: 4),
                Text('DEPARTMENT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),

          // Customer Name
          const SizedBox(
            width: 220,
            child: Row(
              children: [
                Icon(Icons.business_rounded, size: 12, color: Color(0xFF059669)),
                SizedBox(width: 4),
                Text('CUSTOMER NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),

          // Item Code
          const SizedBox(
            width: 140,
            child: Text('ITEM CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
          ),

          // Item Name
          const SizedBox(
            width: 220,
            child: Text('ITEM NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
          ),

          // Qty
          const SizedBox(
            width: 85,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('QTY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ),

          // Rate
          const SizedBox(
            width: 95,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('RATE (₹)', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ),

          // Amount
          const SizedBox(
            width: 110,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('AMOUNT (₹)', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ),

          // Cell No
          const SizedBox(
            width: 110,
            child: Text('CELL NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
          ),

          // Status Badge
          const SizedBox(
            width: 95,
            child: Center(
              child: Text('STATUS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
            ),
          ),

          // Remark
          const SizedBox(
            width: 180,
            child: Row(
              children: [
                Icon(Icons.comment_outlined, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Text('REMARK', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. DATA ROW BUILDER
  // ---------------------------------------------------------------------------
  Widget _buildDataRow(SoApprovalRecord record, int srNo, bool isSelected) {
    Color statusBg = const Color(0xFFFEF3C7);
    Color statusText = const Color(0xFFB45309);
    if (record.isApproved) {
      statusBg = const Color(0xFFDCFCE7);
      statusText = const Color(0xFF15803D);
    } else if (record.isRejected) {
      statusBg = const Color(0xFFFEE2E2);
      statusText = const Color(0xFFDC2626);
    } else if (record.isOnHold) {
      statusBg = const Color(0xFFFEF3C7);
      statusText = const Color(0xFFB45309);
    } else if (record.isClosed) {
      statusBg = const Color(0xFFE2E8F0);
      statusText = const Color(0xFF475569);
    }

    return Row(
      children: [
        // Checkbox
        SizedBox(
          width: 44,
          child: Checkbox(
            value: isSelected,
            onChanged: (_) => _toggleRecordSelection(record.rowKey),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeColor: AppColors.brandBlue,
          ),
        ),

        // Sr No
        SizedBox(
          width: 45,
          child: Text(
            '$srNo',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),

        // SO No Badge
        SizedBox(
          width: 135,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFC7D2FE)),
              ),
              child: Text(
                record.salOrdNo,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
            ),
          ),
        ),

        // Date
        SizedBox(
          width: 95,
          child: Text(
            record.soDate.toIso8601String().split('T').first,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
        ),

        // Department
        SizedBox(
          width: 140,
          child: Text(
            record.labName.isNotEmpty ? record.labName : 'GENERAL',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
          ),
        ),

        // Customer Name
        SizedBox(
          width: 220,
          child: Text(
            record.partyName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
          ),
        ),

        // Item Code
        SizedBox(
          width: 140,
          child: Text(
            record.itCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFD97706)),
          ),
        ),

        // Item Name
        SizedBox(
          width: 220,
          child: Text(
            record.itemName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
          ),
        ),

        // Qty
        SizedBox(
          width: 85,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              record.qty.toStringAsFixed(1),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ),

        // Rate
        SizedBox(
          width: 95,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              record.rate.toStringAsFixed(2),
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ),
        ),

        // Amount
        SizedBox(
          width: 110,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              '₹ ${record.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
            ),
          ),
        ),

        // Cell No
        SizedBox(
          width: 110,
          child: Text(
            record.cellNo.isNotEmpty ? record.cellNo : '—',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),

        // Status Badge
        SizedBox(
          width: 95,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                record.status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: statusText,
                ),
              ),
            ),
          ),
        ),

        // Remark
        SizedBox(
          width: 180,
          child: Text(
            record.sodClosRem.isNotEmpty ? record.sodClosRem : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}
