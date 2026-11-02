import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import 'issue_manager_models.dart';
import 'issue_manager_service.dart';
import 'widgets/issue_manager_wizard_dialog.dart';
import 'widgets/issue_manager_export_modal_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class IssueManagerPage extends StatefulWidget {
  const IssueManagerPage({super.key});

  @override
  State<IssueManagerPage> createState() => _IssueManagerPageState();
}

class _IssueManagerPageState extends State<IssueManagerPage> {
  final IssueManagerService _service = IssueManagerService();

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedModeFilter = 'All';

  // Glowing Strategy (4-second Strategy from Project Master)
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  Timer? _glowTimer;

  // Selected row code
  String? _selectedRowCode;

  // Table Horizontal Scroll Navigation State
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  bool _isLoading = true;
  String? _errorMessage;
  List<IssueManagerGridRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 25;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _glowTimer?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
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

  void _triggerGlow(String code, bool isUpdate) {
    setState(() {
      if (isUpdate) {
        _recentlyUpdatedCode = code;
        _recentlySavedCode = null;
      } else {
        _recentlySavedCode = code;
        _recentlyUpdatedCode = null;
      }
    });

    _glowTimer?.cancel();
    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _recentlySavedCode = null;
          _recentlyUpdatedCode = null;
        });
      }
    });

    _loadRecords();
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
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.fetchIssues(
        fromDate: _fromDate,
        toDate: _toDate,
        search: _searchCtrl.text.trim(),
        issueMode: _selectedModeFilter == 'All' ? null : _selectedModeFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _records = res.records;
          _totalCount = res.totalCount;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _currentPage = 1);
      _loadRecords();
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _fromDate != null && _toDate != null
          ? DateTimeRange(start: _fromDate!, end: _toDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
        _currentPage = 1;
      });
      _loadRecords();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _currentPage = 1;
    });
    _loadRecords();
  }

  void _openNewEntryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => IssueManagerWizardDialog(
        service: _service,
        onSaved: (code, isUpdate) {
          _triggerGlow(code, isUpdate);
        },
      ),
    );
  }

  Future<void> _openEditDialog(String code) async {
    try {
      final detail = await _service.fetchIssueByCode(code);
      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => IssueManagerWizardDialog(
          service: _service,
          editCode: code,
          initialDetail: detail,
          onSaved: (savedCode, isUpdate) {
            _triggerGlow(savedCode, isUpdate);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load issue for editing: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _confirmDelete(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Issue Record?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete Issue "$code"?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will purge stock ledger entries in STOCKREGNEW and automatically restore all deducted stock in ITEMMST.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            child: const Text('Delete Issue', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final res = await _service.deleteIssue(code);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.message.isNotEmpty ? res.message : 'Issue $code deleted and inventory restored successfully.'),
              backgroundColor: const Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          _loadRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete issue: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }
    }
  }

  Future<void> _openDetailsDialog(String code) async {
    try {
      final detail = await _service.fetchIssueByCode(code);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => _IssueDetailsDialog(detail: detail),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load issue details: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openExportDialog() {
    showDialog(
      context: context,
      builder: (_) => IssueManagerExportModalDialog(records: _records),
    );
  }

  // Summary Metrics for Gauge KPI Cards
  int get _uniqueDeptCount => _records.map((r) => r.sourceDeptName).toSet().length;
  double get _totalQtySum => _records.fold(0.0, (acc, r) => acc + r.totQty);
  int get _totalItemsSum => _records.fold(0, (acc, r) => acc + r.totItm);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. TOP HEADER & KPI CARDS (DEPARTMENT MASTER STYLE WITH CIRCULAR GAUGES)
            _buildTopHeaderWithKpiCards(),
            const SizedBox(height: 14),

            // 2. MAIN DATA GRID DESK (DEPARTMENT MASTER TABLE IN CORPORATE WAY)
            Expanded(
              child: _buildMainDataGridDesk(),
            ),
            const SizedBox(height: 10),

            // 3. PAGINATION FOOTER
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER WITH GAUGE KPI CARDS & ACTION BAR (DEPARTMENT MASTER STYLE)
  // ============================================================================
  Widget _buildTopHeaderWithKpiCards() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Logo & Title (Left) + Circular Gauge KPI Cards (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C3B2E).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.outbox_rounded, color: Color(0xFF0C3B2E), size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Issue Manager',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Transaction > Issue > Issue Manager (To Department / Direct)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Modern & Fashioned Gauge KPI Cards (Department Master Parity)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildKpiCard(
                        label: 'TOTAL ISSUES',
                        value: '$_totalCount',
                        progress: _totalCount > 0 ? 0.75 : 0.0,
                        gradientColors: const [
                          Color(0xFF2563EB), // Electric Royal Blue
                          Color(0xFF06B6D4), // Vibrant Cyan Blue
                        ],
                      ),
                      const SizedBox(width: 10),
                      _buildKpiCard(
                        label: 'ACTIVE DEPTS',
                        value: '$_uniqueDeptCount',
                        progress: _uniqueDeptCount > 0 ? 0.85 : 0.0,
                        gradientColors: const [
                          Color(0xFFEC4899), // Hot Fashion Pink
                          Color(0xFFF43F5E), // Luminous Rose Pink
                        ],
                      ),
                      const SizedBox(width: 10),
                      _buildKpiCard(
                        label: 'TOTAL QTY',
                        value: _totalQtySum > 1000000
                            ? '${(_totalQtySum / 1000000).toStringAsFixed(1)}M'
                            : _totalQtySum > 1000
                                ? '${(_totalQtySum / 1000).toStringAsFixed(1)}K'
                                : _totalQtySum.toStringAsFixed(0),
                        progress: _totalQtySum > 0 ? 0.80 : 0.0,
                        gradientColors: const [
                          Color(0xFF059669), // Emerald Green
                          Color(0xFF10B981), // Mint
                        ],
                      ),
                      const SizedBox(width: 10),
                      _buildKpiCard(
                        label: 'TOTAL ITEMS',
                        value: '$_totalItemsSum',
                        progress: _totalItemsSum > 0 ? 0.70 : 0.0,
                        gradientColors: const [
                          Color(0xFFD97706), // Warm Amber
                          Color(0xFFF59E0B), // Golden Orange
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Row 2: Search Bar + Date Range + Mode Filter + Export & New Entry Buttons
              Row(
                children: [
                  // Search Field
                  SizedBox(
                    width: 260,
                    height: 38,
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
                      decoration: InputDecoration(
                        hintText: 'Search Issue Code, Dept, Remark...',
                        hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 14),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Date Range Button
                  OutlinedButton.icon(
                    onPressed: _selectDateRange,
                    icon: const Icon(Icons.date_range_rounded, size: 15, color: Color(0xFF475569)),
                    label: Text(
                      _fromDate != null && _toDate != null
                          ? '${_formatDate(_fromDate!)} - ${_formatDate(_toDate!)}'
                          : 'Date Filter',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  if (_fromDate != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                      tooltip: 'Clear Date Filter',
                      onPressed: _clearDateFilter,
                    ),
                  ],
                  const SizedBox(width: 10),

                  // Mode Filter Dropdown
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedModeFilter,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Modes')),
                          DropdownMenuItem(value: 'To Department', child: Text('To Department')),
                          DropdownMenuItem(value: 'To Store', child: Text('To Store')),
                          DropdownMenuItem(value: 'To Company', child: Text('To Company')),
                          DropdownMenuItem(value: 'To Dept (RGP)', child: Text('To Dept (RGP)')),
                          DropdownMenuItem(value: 'To WIP', child: Text('To WIP')),
                          DropdownMenuItem(value: 'To Cost Center', child: Text('To Cost Center')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedModeFilter = val;
                              _currentPage = 1;
                            });
                            _loadRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF0C3B2E)),
                    tooltip: 'Refresh Records',
                    onPressed: _loadRecords,
                  ),

                  const Spacer(),

                  // Animated Orbiting Export Button (100% Project Master Parity)
                  IssueManagerAnimatedExportButton(onPressed: _openExportDialog),
                  const SizedBox(width: 10),

                  // Primary "+ New Entry" Button (Project Master Style)
                  ElevatedButton.icon(
                    onPressed: _openNewEntryDialog,
                    icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    label: const Text(
                      'New Entry',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      elevation: 2,
                      shadowColor: AppColors.secondaryColor.withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required double progress,
    required List<Color> gradientColors,
  }) {
    return _HeaderKpiCard(
      label: label,
      value: value,
      progress: progress,
      gradientColors: gradientColors,
    );
  }

  // ============================================================================
  // 2. MAIN DATA GRID DESK (DEPARTMENT MASTER TABLE IN CORPORATE WAY)
  // ============================================================================
  Widget _buildMainDataGridDesk() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Color(0xFF0C3B2E), size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Issue Transactions Directory Desk',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_records.length} of $_totalCount Records',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Table Body Grid with Left & Right Floating Navigation Controls
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                                  const SizedBox(height: 12),
                                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                                  const SizedBox(height: 12),
                                  ElevatedButton(onPressed: _loadRecords, child: const Text('Retry')),
                                ],
                              ),
                            )
                          : _records.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 10),
                                      Text(
                                        'No issue transaction records found.',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    final tableWidth = math.max(constraints.maxWidth, 1580.0);

                                    return Scrollbar(
                                      controller: _horizontalScrollCtrl,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: _horizontalScrollCtrl,
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: tableWidth,
                                          child: Column(
                                            children: [
                                              _buildMainTableHeaderBar(),
                                              Expanded(
                                                child: Scrollbar(
                                                  controller: _verticalScrollCtrl,
                                                  thumbVisibility: true,
                                                  child: ListView.separated(
                                                    controller: _verticalScrollCtrl,
                                                    itemCount: _records.length,
                                                    separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                                    itemBuilder: (ctx, idx) {
                                                      final r = _records[idx];
                                                      final isSelected = _selectedRowCode == r.issueCode;
                                                      final isGlowingNew = _recentlySavedCode == r.issueCode;
                                                      final isGlowingUpdated = _recentlyUpdatedCode == r.issueCode;

                                                      return _AnimatedIssueRecordRow(
                                                        key: ValueKey<String>(r.issueCode),
                                                        item: r,
                                                        isSelected: isSelected,
                                                        isGlowingNew: isGlowingNew,
                                                        isGlowingUpdated: isGlowingUpdated,
                                                        onTap: () {
                                                          setState(() => _selectedRowCode = r.issueCode);
                                                        },
                                                        onDoubleTap: () => _openDetailsDialog(r.issueCode),
                                                        onViewDetails: () => _openDetailsDialog(r.issueCode),
                                                        onEdit: () => _openEditDialog(r.issueCode),
                                                        onDelete: () => _confirmDelete(r.issueCode),
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

                  // Left Floating Scroll Arrow Button
                  if (_canScrollLeft)
                    Positioned(
                      left: 12,
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

                  // Right Floating Scroll Arrow Button
                  if (_canScrollRight && _records.isNotEmpty)
                    Positioned(
                      right: 12,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTableHeaderBar() {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Icon(Icons.tag_rounded, size: 12, color: Color(0xFF6366F1)),
                SizedBox(width: 4),
                Text('ISSUE CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0D9488)),
                SizedBox(width: 4),
                Text('DATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
          SizedBox(
            width: 130,
            child: Row(
              children: [
                Icon(Icons.alt_route_rounded, size: 12, color: Color(0xFF0284C7)),
                SizedBox(width: 4),
                Text('MODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Row(
              children: [
                Icon(Icons.source_rounded, size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Text('SOURCE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
          SizedBox(
            width: 160,
            child: Row(
              children: [
                Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text('FROM DEPARTMENT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
          SizedBox(width: 110, child: Text('MACHINE NO.', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 90, child: Text('SPINDAL', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 80, child: Text('SLIP NO.', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(
            width: 100,
            child: Text('TOTAL QTY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5), textAlign: TextAlign.right),
          ),
          SizedBox(
            width: 70,
            child: Text('ITEMS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5), textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 70,
            child: Text('PCS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5), textAlign: TextAlign.center),
          ),
          SizedBox(width: 170, child: Text('REMARK', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(width: 110, child: Text('CREATED BY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5))),
          SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_outlined, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 3),
                Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. PAGINATION FOOTER
  // ============================================================================
  Widget _buildPaginationFooter() {
    final totalPages = (_totalCount / _pageSize).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing ${(_currentPage - 1) * _pageSize + (_records.isEmpty ? 0 : 1)} to '
          '${(_currentPage * _pageSize).clamp(0, _totalCount)} of $_totalCount records',
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _loadRecords();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left_rounded, size: 16),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _loadRecords();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              label: const Text('Next'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// ANIMATED ROW (DEPARTMENT MASTER STYLE WITH GLOWING STRATEGY)
// ============================================================================
class _AnimatedIssueRecordRow extends StatefulWidget {
  final IssueManagerGridRecord item;
  final bool isSelected;
  final bool isGlowingNew;
  final bool isGlowingUpdated;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onViewDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedIssueRecordRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isGlowingNew,
    required this.isGlowingUpdated,
    required this.onTap,
    required this.onDoubleTap,
    required this.onViewDetails,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedIssueRecordRow> createState() => _AnimatedIssueRecordRowState();
}

class _AnimatedIssueRecordRowState extends State<_AnimatedIssueRecordRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isGlowingNew = widget.isGlowingNew;
    final isGlowingUpdated = widget.isGlowingUpdated;
    final isGlowing = isGlowingNew || isGlowingUpdated;

    final glowColor = isGlowingUpdated ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: isGlowing
                ? glowColor.withValues(alpha: 0.12)
                : (isSelected
                    ? AppColors.secondaryColor.withValues(alpha: 0.08)
                    : (_isHovered ? const Color(0xFFF0FDF4) : Colors.white)),
            border: Border.all(
              color: isGlowing
                  ? glowColor
                  : (isSelected
                      ? AppColors.secondaryColor
                      : (_isHovered ? const Color(0xFF16A34A) : Colors.transparent)),
              width: isGlowing ? 1.8 : (_isHovered || isSelected ? 1.2 : 0.0),
            ),
            boxShadow: isGlowing
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      spreadRadius: 1.2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Issue Code
              SizedBox(
                width: 140,
                child: Text(
                  item.issueCode,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Color(0xFF0F766E)),
                ),
              ),

              // Date
              SizedBox(
                width: 100,
                child: Text(_formatDate(item.issueDate), style: const TextStyle(fontSize: 11)),
              ),

              // Mode
              SizedBox(
                width: 130,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.issueMode,
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Source
              SizedBox(
                width: 90,
                child: Text(item.issueSource, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),

              // From Department (with avatar badge)
              SizedBox(
                width: 160,
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        item.sourceDeptName.isNotEmpty ? item.sourceDeptName[0] : 'D',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.sourceDeptName,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Machine No
              SizedBox(
                width: 110,
                child: Text(item.machineNo.isEmpty ? '*' : item.machineNo, style: const TextStyle(fontSize: 11)),
              ),

              // Spindal
              SizedBox(
                width: 90,
                child: Text(item.spindal, style: const TextStyle(fontSize: 11)),
              ),

              // Slip No
              SizedBox(
                width: 80,
                child: Text('${item.slipNo}', style: const TextStyle(fontSize: 11)),
              ),

              // Total Qty
              SizedBox(
                width: 100,
                child: Text(
                  item.totQty.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1D4ED8), fontSize: 11.5),
                  textAlign: TextAlign.right,
                ),
              ),

              // Items
              SizedBox(
                width: 70,
                child: Text('${item.totItm}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
              ),

              // Pcs
              SizedBox(
                width: 70,
                child: Text(item.totPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
              ),

              // Remark
              SizedBox(
                width: 170,
                child: Text(item.remark, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
              ),

              // Created By
              SizedBox(
                width: 110,
                child: Text(item.createdBy, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
              ),

              // Actions
              SizedBox(
                width: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _TableActionButton(
                      icon: Icons.visibility_outlined,
                      color: const Color(0xFF0F766E),
                      tooltip: 'View Details',
                      onPressed: widget.onViewDetails,
                    ),
                    const SizedBox(width: 4),
                    _TableActionButton(
                      icon: Icons.edit_outlined,
                      color: const Color(0xFFD97706),
                      tooltip: 'Edit Issue',
                      onPressed: widget.onEdit,
                    ),
                    const SizedBox(width: 4),
                    _TableActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: const Color(0xFFDC2626),
                      tooltip: 'Delete Issue',
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// COMPACT INTERACTIVE ACTION BUTTON (DEPARTMENT MASTER PATTERN - NO OVERFLOW)
// ============================================================================
class _TableActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onPressed;

  const _TableActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onPressed,
  });

  @override
  State<_TableActionButton> createState() => _TableActionButtonState();
}

class _TableActionButtonState extends State<_TableActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered && isEnabled ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _isHovered && isEnabled
                  ? widget.color.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: IconButton(
              icon: Icon(
                widget.icon,
                size: 15,
                color: isEnabled
                    ? (_isHovered ? widget.color : widget.color.withValues(alpha: 0.85))
                    : const Color(0xFFCBD5E1),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: widget.onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GAUGE KPI CARD (COPIED FROM DEPARTMENT MASTER)
// ============================================================================
class _HeaderKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final double progress;
  final List<Color> gradientColors;

  const _HeaderKpiCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.gradientColors,
  });

  @override
  State<_HeaderKpiCard> createState() => _HeaderKpiCardState();
}

class _HeaderKpiCardState extends State<_HeaderKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;
    final effectiveTrackColor = primaryColor.withValues(alpha: 0.12);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 106,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? primaryColor.withValues(alpha: 0.20)
                  : primaryColor.withValues(alpha: 0.06),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 3 : 1.5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isHovered ? 0.65 : 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isHovered
                      ? primaryColor.withValues(alpha: 0.50)
                      : primaryColor.withValues(alpha: 0.18),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(34, 34),
                          painter: _CircularGaugePainter(
                            progress: widget.progress,
                            gradientColors: widget.gradientColors,
                            trackColor: effectiveTrackColor,
                            strokeWidth: 3.2,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.value,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 4.5,
                        height: 4.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.55),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4.5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475569),
                            letterSpacing: 0.45,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularGaugePainter extends CustomPainter {
  final double progress;
  final List<Color> gradientColors;
  final Color trackColor;
  final double strokeWidth;

  const _CircularGaugePainter({
    required this.progress,
    required this.gradientColors,
    required this.trackColor,
    this.strokeWidth = 3.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const startAngle = 135.0 * (math.pi / 180.0);
    const totalSweepAngle = 270.0 * (math.pi / 180.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      startAngle,
      totalSweepAngle,
      false,
      trackPaint,
    );

    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0.0) {
      final activeSweep = totalSweepAngle * clampedProgress;
      final primaryColor = gradientColors.first;

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2.0
        ..strokeCap = StrokeCap.round
        ..color = primaryColor.withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

      canvas.drawArc(
        rect,
        startAngle,
        activeSweep,
        false,
        glowPaint,
      );

      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      if (gradientColors.length > 1) {
        activePaint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ).createShader(rect);
      } else {
        activePaint.color = primaryColor;
      }

      canvas.drawArc(
        rect,
        startAngle,
        activeSweep,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gradientColors != gradientColors ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// ============================================================================
// DETAILS MODAL DIALOG
// ============================================================================
class _IssueDetailsDialog extends StatelessWidget {
  final IssueManagerDetail detail;

  const _IssueDetailsDialog({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1040,
        height: 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0C3B2E), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Issue Details: ${detail.header.issueCode}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Dated: ${_formatDate(detail.header.issueDate)} | Mode: ${detail.header.issueMode} | Dept: ${detail.header.sourceDeptName}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Detail Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header metadata pills
                      Row(
                        children: [
                          _buildDetailPill('Source', detail.header.issueSource),
                          const SizedBox(width: 10),
                          _buildDetailPill('Store', detail.header.sourceStoreName),
                          const SizedBox(width: 10),
                          _buildDetailPill('Machine', detail.header.machineNo.isEmpty ? '*' : detail.header.machineNo),
                          const SizedBox(width: 10),
                          _buildDetailPill('Spindal', detail.header.spindal.isEmpty ? 'None' : detail.header.spindal),
                          const SizedBox(width: 10),
                          _buildDetailPill('Total Qty', detail.header.totQty.toStringAsFixed(2)),
                          const SizedBox(width: 10),
                          _buildDetailPill('Total Items', '${detail.header.totItm}'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Lines Table
                      const Text(
                        'Issued Material Lines',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 8),

                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ListView.separated(
                              itemCount: detail.lines.length + 1,
                              separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, idx) {
                                if (idx == 0) {
                                  return Container(
                                    height: 36,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    color: const Color(0xFFF1F5F9),
                                    child: const Row(
                                      children: [
                                        SizedBox(width: 45, child: Text('SR #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        SizedBox(width: 110, child: Text('ITEM CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        Expanded(child: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        SizedBox(width: 70, child: Text('UQC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        SizedBox(width: 90, child: Text('MERGE NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        SizedBox(width: 70, child: Text('RATE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5))),
                                        SizedBox(width: 80, child: Text('ISSUE QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.right)),
                                        SizedBox(width: 90, child: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.right)),
                                      ],
                                    ),
                                  );
                                }
                                final l = detail.lines[idx - 1];
                                return Container(
                                  height: 36,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      SizedBox(width: 45, child: Text('${l.srNo}', style: const TextStyle(fontSize: 11))),
                                      SizedBox(width: 110, child: Text(l.itemCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)))),
                                      Expanded(child: Text(l.itemName, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      SizedBox(width: 70, child: Text(l.unitName, style: const TextStyle(fontSize: 11))),
                                      SizedBox(width: 90, child: Text(l.mrgNo, style: const TextStyle(fontSize: 11))),
                                      SizedBox(width: 70, child: Text(l.rate.toStringAsFixed(4), style: const TextStyle(fontSize: 11))),
                                      SizedBox(width: 80, child: Text(l.issueQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)), textAlign: TextAlign.right)),
                                      SizedBox(width: 90, child: Text(l.amount.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF047857)), textAlign: TextAlign.right)),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
