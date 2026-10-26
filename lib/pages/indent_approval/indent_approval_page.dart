import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom/bom_models.dart';
import '../bom/widgets/bom_animated_success_button.dart';
import '../bom/widgets/bom_export_modal_dialog.dart';
import 'indent_approval_models.dart';
import 'indent_approval_service.dart';
import 'widgets/indent_approval_export_modal_dialog.dart';

/// Production-ready Indent Approval Module
/// 100% Mirror of BOM Follow Up Approval Screen Layout and Design Language.
class IndentApprovalPage extends StatefulWidget {
  final IndentApprovalService? service;

  const IndentApprovalPage({super.key, this.service});

  @override
  State<IndentApprovalPage> createState() => _IndentApprovalPageState();
}

class _IndentApprovalPageState extends State<IndentApprovalPage> {
  late final IndentApprovalService _service;

  // Filter & Control State
  DateTime _approvalDate = DateTime.now();
  String _statusView = 'PENDING'; // PENDING, APPROVED, REJECTED, HOLD, ALL
  String _actionStatus = 'APPROVE'; // APPROVE, REJECT, HOLD, RESET

  String _selectedIndCode = 'ALL';
  int _selectedDeptCode = 0; // 0 = ALL
  String _selectedItemCode = 'ALL';

  // Dropdown Lookups Cache
  List<String> _indentNumbers = [];
  List<IndentApprovalDepartment> _departments = [];
  List<IndentApprovalItemLookup> _items = [];

  // Data & Table Selection
  List<IndentApprovalRecord> _records = [];
  final Set<String> _selectedRecordIds = {};
  bool _isLoading = false;
  ButtonStatus _saveButtonStatus = ButtonStatus.idle;

  // Validation feedback
  String? _buttonValidationMsg;
  Timer? _buttonValidationTimer;
  Timer? _validationClearTimer;

  // Search & Scroll
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IndentApprovalService();
    _loadInitialData();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
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

  @override
  void dispose() {
    _buttonValidationTimer?.cancel();
    _validationClearTimer?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
  }

  void _showButtonValidation(String msg) {
    setState(() {
      _buttonValidationMsg = msg;
      _saveButtonStatus = ButtonStatus.error;
    });
    _buttonValidationTimer?.cancel();
    _buttonValidationTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted && _saveButtonStatus == ButtonStatus.error) {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
      }
    });
    _validationClearTimer?.cancel();
    _validationClearTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final lookups = await _service.fetchLookups();
      _indentNumbers = lookups.indentNumbers;
      _departments = lookups.departments;
      _items = lookups.items;

      await _fetchGridRecords();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        _showSnack('Failed to load lookups: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchGridRecords() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.fetchRecords(
        asOnDate: _approvalDate,
        statusFilter: _statusView,
        indCode: _selectedIndCode != 'ALL' ? _selectedIndCode : null,
        deptCode: _selectedDeptCode > 0 ? _selectedDeptCode : null,
        itemCode: _selectedItemCode != 'ALL' ? _selectedItemCode : null,
      );
      if (mounted) {
        setState(() {
          _records = list;
          _selectedRecordIds.removeWhere((id) => !_records.any((r) => r.uniqueId == id));
        });
      }
    } catch (e) {
      debugPrint('Error fetching indent approval records: $e');
      if (mounted) {
        _showSnack('Failed to load indent records: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<IndentApprovalRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return _records;
    return _records.where((r) {
      final idMatch = r.indCode.toLowerCase().contains(_searchQuery);
      final codeMatch = r.code.toLowerCase().contains(_searchQuery);
      final descMatch = r.itName.toLowerCase().contains(_searchQuery);
      final depMatch = r.labName.toLowerCase().contains(_searchQuery);
      final reqMatch = r.reqNo.toLowerCase().contains(_searchQuery);
      final poMatch = r.processDo.toLowerCase().contains(_searchQuery);
      final statusMatch = r.status.toLowerCase().contains(_searchQuery);
      return idMatch || codeMatch || descMatch || depMatch || reqMatch || poMatch || statusMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final list = _filteredRecords;
    if (list.isEmpty) return false;
    return list.every((r) => _selectedRecordIds.contains(r.uniqueId));
  }

  void _toggleSelectAllFiltered() {
    final list = _filteredRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in list) {
          _selectedRecordIds.remove(r.uniqueId);
        }
      } else {
        for (final r in list) {
          _selectedRecordIds.add(r.uniqueId);
        }
      }
    });
  }

  void _toggleRecordSelection(String uniqueId) {
    setState(() {
      if (_selectedRecordIds.contains(uniqueId)) {
        _selectedRecordIds.remove(uniqueId);
      } else {
        _selectedRecordIds.add(uniqueId);
      }
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _handleSaveAction() async {
    if (_saveButtonStatus == ButtonStatus.loading) return;

    if (_selectedRecordIds.isEmpty) {
      _showButtonValidation('Select at least 1 record');
      _showSnack('Please select at least one indent item to process.', isError: true);
      return;
    }

    setState(() {
      _buttonValidationMsg = null;
      _saveButtonStatus = ButtonStatus.loading;
    });

    try {
      // 1. Date Lock Check
      final isLocked = await _service.checkDateLock(_approvalDate);
      if (isLocked) {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
        _showLockWarningDialog();
        return;
      }

      // 2. Prepare payload
      final selectedItems = _records
          .where((r) => _selectedRecordIds.contains(r.uniqueId))
          .map((r) => IndentApprovalItemSelection(
                indCode: r.indCode,
                code: r.code,
                inddetCode: r.inddetCode,
                departmentName: r.labName,
              ))
          .toList();

      final payload = IndentApprovalActionPayload(
        action: _actionStatus,
        approvalDate: _approvalDate,
        items: selectedItems,
      );

      final result = await _service.processApprovalBatch(payload);

      if (result.success) {
        setState(() {
          _saveButtonStatus = ButtonStatus.success;
          _selectedRecordIds.clear();
        });

        _showSnack(result.message, isError: false);

        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) {
          setState(() => _saveButtonStatus = ButtonStatus.idle);
        }
      } else {
        setState(() => _saveButtonStatus = ButtonStatus.idle);
        _showSnack(result.message, isError: true);
      }
    } catch (e) {
      debugPrint('Indent approval action failed: $e');
      setState(() => _saveButtonStatus = ButtonStatus.idle);
      _showSnack('Action failed: $e', isError: true);
    } finally {
      if (mounted) {
        await _fetchGridRecords();
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isError ? 'Notice' : 'Success',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0C3B2E),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? const Color(0xFFF87171) : const Color(0xFF34D399),
            width: 1.2,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showLockWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_clock_outlined, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 10),
            Text('Date Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Transactions for date ${_formatDate(_approvalDate)} are locked in LOCKDATAMST. Indent approvals cannot be posted on this date.',
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF334155)),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C3B2E),
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
    final list = _filteredRecords;
    if (list.isEmpty) {
      _showSnack('No records available to export.', isError: true);
      return;
    }
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => IndentApprovalExportModalDialog(records: list),
    );
  }

  // Header Summary Calculations
  double get _selectedTotalQty {
    return _records
        .where((r) => _selectedRecordIds.contains(r.uniqueId))
        .fold(0.0, (acc, r) => acc + r.qty);
  }

  double get _selectedTotalValue {
    return _records
        .where((r) => _selectedRecordIds.contains(r.uniqueId))
        .fold(0.0, (acc, r) => acc + r.totalValue);
  }

  String get _actionButtonText {
    switch (_actionStatus) {
      case 'REJECT':
        return 'Reject (F1)';
      case 'HOLD':
        return 'Hold (F1)';
      case 'RESET':
        return 'Reset (F1)';
      case 'APPROVE':
      default:
        return 'Approve (F1)';
    }
  }

  Color get _actionButtonColor {
    switch (_actionStatus) {
      case 'REJECT':
        return const Color(0xFFDC2626);
      case 'HOLD':
        return const Color(0xFFD97706);
      case 'RESET':
        return const Color(0xFF475569);
      case 'APPROVE':
      default:
        return const Color(0xFF0C3B2E);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;

    return Focus(
      autofocus: true,
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f1) {
          _handleSaveAction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER & ACTION BAR (MIRRORING BOM FOLLOW UP)
              _buildTopHeader(),

              // 2. FILTER CONTROLS & KPI CARDS
              _buildFilterToolbar(),

              // 3. MAIN TABLE CONTAINER (Department Master parity)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
                          // 3.1 Table Subheader with Count & Quick Toggles
                          _buildTableSubHeader(filtered.length),

                          // 3.2 Main Grid Content
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

  // ============================================================================
  // 1. TOP HEADER (MIRRORING BOM FOLLOW UP)
  // ============================================================================
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
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
            // Left: Title & Logo
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/bom_close_screen_logo.png',
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.approval_rounded, color: Color(0xFF0C3B2E), size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Indent Approval Screen',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Review, approve, reject, or hold plant material indents',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // Right: Export & Save/Approve Action Button
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                BomAnimatedExportButton(onPressed: _openExportModal),
                const SizedBox(height: 8),
                if (_buttonValidationMsg != null) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          _buttonValidationMsg!,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                BomAnimatedSuccessButton(
                  status: _saveButtonStatus,
                  onPressed: _handleSaveAction,
                  idleText: _actionButtonText,
                  loadingText: 'Processing...',
                  successText: 'Saved!',
                  errorText: 'Select Records',
                  idleIcon: Icons.check_circle_outline_rounded,
                  idleBackgroundColor: _actionButtonColor,
                  successBackgroundColor: const Color(0xFF10B981),
                  height: 36,
                  width: 145,
                  borderRadius: BorderRadius.circular(18),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 2. FILTER CONTROLS & STATUS TOGGLE TOOLBAR
  // ============================================================================
  Widget _buildFilterToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Row 1: Status View Toggles & Set Action Selector
            Row(
              children: [
                // STATUS VIEW TOGGLES
                const Text('View Mode:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                const SizedBox(width: 10),
                _buildStatusPill(
                  label: 'Pending',
                  value: 'PENDING',
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Approved',
                  value: 'APPROVED',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Rejected',
                  value: 'REJECTED',
                  icon: Icons.cancel_outlined,
                  color: const Color(0xFFDC2626),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'Hold',
                  value: 'HOLD',
                  icon: Icons.pause_circle_outline_rounded,
                  color: const Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                _buildStatusPill(
                  label: 'All Entries',
                  value: 'ALL',
                  icon: Icons.list_alt_rounded,
                  color: const Color(0xFF475569),
                ),

                const Spacer(),

                // ACTION SELECTOR (Set Status for Selected Rows)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Action:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(width: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _actionStatus,
                          isDense: true,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          items: const [
                            DropdownMenuItem(value: 'APPROVE', child: Text('Approve Selected', style: TextStyle(color: Color(0xFF0C3B2E)))),
                            DropdownMenuItem(value: 'REJECT', child: Text('Reject Selected', style: TextStyle(color: Color(0xFFDC2626)))),
                            DropdownMenuItem(value: 'HOLD', child: Text('Put on Hold', style: TextStyle(color: Color(0xFFD97706)))),
                            DropdownMenuItem(value: 'RESET', child: Text('Reset to Pending', style: TextStyle(color: Color(0xFF475569)))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _actionStatus = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 16, color: Color(0xFFF1F5F9)),

            // Row 2: Date Picker, Dropdowns & Search Box
            Row(
              children: [
                // Approval Date Picker
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF0C3B2E)),
                  label: Text('As On: ${_formatDate(_approvalDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E))),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _approvalDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _approvalDate = picked);
                      _fetchGridRecords();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 10),

                // Indent No Dropdown
                _buildCompactDropdown<String>(
                  width: 155,
                  label: 'Indent No',
                  value: _selectedIndCode,
                  items: ['ALL', ..._indentNumbers],
                  itemLabel: (v) => v,
                  onChanged: (v) {
                    setState(() => _selectedIndCode = v ?? 'ALL');
                    _fetchGridRecords();
                  },
                ),
                const SizedBox(width: 8),

                // Department Dropdown
                _buildCompactDropdown<int>(
                  width: 165,
                  label: 'Department',
                  value: _selectedDeptCode,
                  items: [0, ..._departments.map((d) => d.labCode)],
                  itemLabel: (code) {
                    if (code == 0) return 'All Departments';
                    final dept = _departments.firstWhere((d) => d.labCode == code, orElse: () => IndentApprovalDepartment(labCode: code, labName: '$code'));
                    return dept.labName;
                  },
                  onChanged: (code) {
                    setState(() => _selectedDeptCode = code ?? 0);
                    _fetchGridRecords();
                  },
                ),
                const SizedBox(width: 8),

                // Item Dropdown
                _buildCompactDropdown<String>(
                  width: 175,
                  label: 'Item Filter',
                  value: _selectedItemCode,
                  items: ['ALL', ..._items.map((i) => i.code)],
                  itemLabel: (code) {
                    if (code == 'ALL') return 'All Items';
                    final item = _items.firstWhere((i) => i.code == code, orElse: () => IndentApprovalItemLookup(code: code, itemName: code));
                    return item.itemName.length > 20 ? '${item.itemName.substring(0, 18)}...' : item.itemName;
                  },
                  onChanged: (code) {
                    setState(() => _selectedItemCode = code ?? 'ALL');
                    _fetchGridRecords();
                  },
                ),
                const SizedBox(width: 8),

                // Reset Filters Button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                  tooltip: 'Reset Filters & Refresh',
                  onPressed: () {
                    setState(() {
                      _selectedIndCode = 'ALL';
                      _selectedDeptCode = 0;
                      _selectedItemCode = 'ALL';
                      _searchCtrl.clear();
                    });
                    _fetchGridRecords();
                  },
                ),
                const SizedBox(width: 8),

                // Search Input Field
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: 'Search by Indent, Code, Item, Dept, Req...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_searchCtrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: const Icon(Icons.clear, size: 15, color: Color(0xFF64748B)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _statusView == value;
    return InkWell(
      onTap: () {
        setState(() {
          _statusView = value;
          _selectedRecordIds.clear();
        });
        _fetchGridRecords();
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.25),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDropdown<T>({
    required double width,
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: width,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : items.first,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                itemLabel(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============================================================================
  // 3. TABLE SUBHEADER WITH SELECTION & METRIC GAUGES
  // ============================================================================
  Widget _buildTableSubHeader(int displayedCount) {
    final selectedCount = _selectedRecordIds.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isAllFilteredSelected,
            activeColor: const Color(0xFF0C3B2E),
            onChanged: (val) => _toggleSelectAllFiltered(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Text(
            'Select All ($displayedCount displayed)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          const SizedBox(width: 16),

          // Selection Counter Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF0C3B2E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0C3B2E).withValues(alpha: 0.2)),
            ),
            child: Text(
              'Selected: $selectedCount',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
            ),
          ),

          if (selectedCount > 0) ...[
            const SizedBox(width: 12),
            Text(
              'Selected Qty: ${_selectedTotalQty.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(width: 12),
            Text(
              'Selected Value: ₹ ${_selectedTotalValue.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0F766E)),
            ),
          ],

          const Spacer(),

          // Horizontal Scroll Navigation Controls (Exact BOM Follow Up parity)
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: _canScrollLeft ? const Color(0xFF0C3B2E) : const Color(0xFFCBD5E1), size: 20),
            tooltip: 'Scroll Left',
            onPressed: _canScrollLeft ? _scrollLeft : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.chevron_right_rounded, color: _canScrollRight ? const Color(0xFF0C3B2E) : const Color(0xFFCBD5E1), size: 20),
            tooltip: 'Scroll Right',
            onPressed: _canScrollRight ? _scrollRight : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. MAIN TABLE CONTENT
  // ============================================================================
  Widget _buildTableContent(List<IndentApprovalRecord> list) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.8, color: Color(0xFF0C3B2E)),
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text(
              'No indent entries found.',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              _statusView == 'PENDING'
                  ? 'There are currently no pending indent vouchers for this filter.'
                  : 'No records found matching status "$_statusView".',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      controller: _horizontalScrollCtrl,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollCtrl,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 1420,
          child: Column(
            children: [
              // TABLE HEADER (FOREST GREEN THEME)
              Container(
                height: 36,
                color: const Color(0xFF0C3B2E),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Row(
                  children: [
                    SizedBox(width: 35, child: Text('', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 45, child: Text('SRNO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 135, child: Text('INDENT NO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 95, child: Text('DATE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 150, child: Text('DEPARTMENT', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 110, child: Text('ITEM CODE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('ITEM DESCRIPTION', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 85, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 95, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 110, child: Text('TOTAL VALUE', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 105, child: Text('STATUS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 110, child: Text('REQ NO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                    SizedBox(width: 120, child: Text('PO / PROCESS DO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

              // ROWS LIST
              Expanded(
                child: ListView.builder(
                  controller: _verticalScrollCtrl,
                  itemCount: list.length,
                  itemBuilder: (ctx, idx) {
                    final item = list[idx];
                    final isChecked = _selectedRecordIds.contains(item.uniqueId);
                    final isEven = idx.isEven;

                    Color getStatusColor() {
                      if (item.isAppro) return const Color(0xFF10B981);
                      if (item.isReject) return const Color(0xFFDC2626);
                      if (item.isHold) return const Color(0xFFD97706);
                      return const Color(0xFF2563EB);
                    }

                    final statusColor = getStatusColor();

                    return InkWell(
                      onTap: () => _toggleRecordSelection(item.uniqueId),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? const Color(0xFFF0FDF4)
                              : (isEven ? Colors.white : const Color(0xFFF8FAFC)),
                          border: Border(
                            bottom: BorderSide(
                              color: isChecked ? const Color(0xFF86EFAC) : const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // CHECKBOX
                            SizedBox(
                              width: 35,
                              child: Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF0C3B2E),
                                onChanged: (val) => _toggleRecordSelection(item.uniqueId),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),

                            // SRNO
                            SizedBox(
                              width: 45,
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ),

                            // INDENT NO
                            SizedBox(
                              width: 135,
                              child: Text(
                                item.indCode,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                              ),
                            ),

                            // DATE
                            SizedBox(
                              width: 95,
                              child: Text(_formatDate(item.indDate), style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                            ),

                            // DEPARTMENT
                            SizedBox(
                              width: 150,
                              child: Text(
                                item.labName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              ),
                            ),

                            // ITEM CODE
                            SizedBox(
                              width: 110,
                              child: Text(
                                item.code,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                              ),
                            ),

                            // ITEM DESCRIPTION
                            Expanded(
                              child: Text(
                                item.itName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155)),
                              ),
                            ),

                            // QTY
                            SizedBox(
                              width: 85,
                              child: Text(
                                item.qty.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),

                            // RATE
                            SizedBox(
                              width: 95,
                              child: Text(
                                item.rate.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),

                            // TOTAL VALUE
                            SizedBox(
                              width: 110,
                              child: Text(
                                '₹ ${item.totalValue.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                              ),
                            ),

                            // STATUS
                            SizedBox(
                              width: 105,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  item.status,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ),

                            // REQ NO
                            SizedBox(
                              width: 110,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  item.reqNo.isEmpty ? '-' : item.reqNo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ),
                            ),

                            // PO / PROCESS DO
                            SizedBox(
                              width: 120,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  item.processDo.isEmpty ? '-' : item.processDo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
