import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/department_service.dart';

// ============================================================================
// ENUM DEFINITIONS
// ============================================================================
enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success, error }

// ============================================================================
// MAIN DEPARTMENT MASTER PAGE
// ============================================================================
class DepartmentMasterPage extends StatefulWidget {
  const DepartmentMasterPage({super.key});

  @override
  State<DepartmentMasterPage> createState() => _DepartmentMasterPageState();
}

class _DepartmentMasterPageState extends State<DepartmentMasterPage> {
  // Persistent Page Key Focus Node (Fixes Focus Loss Glitch)
  final FocusNode _pageKeyFocusNode = FocusNode();

  // State lists
  List<DepartmentMasterItem> _departments = [];
  List<DepartmentMasterItem> _filteredDepartments = [];
  List<PartyAccountItem> _partyAccounts = [];

  // Controllers & FocusNodes (Persistent State Members)
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();

  // Form Field Controllers (Persistent State Members)
  int _formLabCode = 0;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _seriesCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  bool _isActiveStatus = true;
  int? _selectedPCode;
  String _selectedPName = '';

  // UI state
  bool _isLoading = true;
  String? _errorMessage;
  bool _isModalOpen = false;
  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  int? _selectedRowCode;
  String? _buttonValidationMsg;
  Timer? _validationTimer;

  // Glowing Entry Strategy State
  int? _highlightedDeptCode;
  bool _isHighlightedEdit = false;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _highlightTimer?.cancel();
    _pageKeyFocusNode.dispose();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _tableScrollCtrl.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _seriesCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _triggerGlowingHighlight(int code, bool isEdit) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedDeptCode = code;
      _isHighlightedEdit = isEdit;
      _selectedRowCode = code;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tableScrollCtrl.hasClients) {
        final idx = _filteredDepartments.indexWhere((d) => d.labCode == code);
        if (idx != -1) {
          final targetOffset = (idx * 44.0) - 80.0;
          _tableScrollCtrl.animateTo(
            targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    _highlightTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _highlightedDeptCode = null;
        });
      }
    });
  }

  void _showButtonValidation(String msg) {
    _validationTimer?.cancel();
    setState(() {
      _buttonValidationMsg = msg;
    });
    _validationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _buttonValidationMsg = null;
        });
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        DepartmentService.fetchDepartments(),
        DepartmentService.fetchPartyAccounts(),
        DepartmentService.fetchPartyAccountsLookup(), // Pre-cache 479 accounts for instant 0ms lookup modal opening
      ]);

      if (mounted) {
        setState(() {
          _departments = results[0] as List<DepartmentMasterItem>;
          _filteredDepartments = List.from(_departments);
          _partyAccounts = results[1] as List<PartyAccountItem>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to connect to Department API: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final updatedList = await DepartmentService.fetchDepartments();
      if (mounted) {
        setState(() {
          _departments = updatedList;
          _applySearchFilter();
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged() {
    _applySearchFilter();
  }

  void _applySearchFilter() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDepartments = List.from(_departments);
      } else {
        _filteredDepartments = _departments.where((d) {
          return d.labCode.toString().contains(query) ||
              d.labName.toLowerCase().contains(query) ||
              d.labSeries.toLowerCase().contains(query) ||
              d.pName.toLowerCase().contains(query) ||
              d.labAdd.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  // Open modal for "+ New Department"
  Future<void> _openNewDepartmentModal() async {
    final nextCode = await DepartmentService.fetchNextCode();
    setState(() {
      _isEditing = false;
      _formLabCode = nextCode;
      _nameCtrl.clear();
      _seriesCtrl.clear();
      _addressCtrl.clear();
      _isActiveStatus = true;
      // Fixed Bug: Do NOT pre-select any account by default
      _selectedPCode = null;
      _selectedPName = '';
      _isModalOpen = true;
      _isSaveSuccess = false;
      _isSubmitting = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _nameFocusNode.requestFocus();
    });
  }

  // Open modal for "Edit Department"
  void _openEditDepartmentModal(DepartmentMasterItem item) {
    final rawPCode = (item.labPCode == null || item.labPCode == 0) ? null : item.labPCode;
    final validPCode = (rawPCode != null && _partyAccounts.any((p) => p.pCode == rawPCode)) ? rawPCode : null;

    setState(() {
      _isEditing = true;
      _selectedRowCode = item.labCode;
      _formLabCode = item.labCode;
      _nameCtrl.text = item.labName;
      _seriesCtrl.text = item.labSeries;
      _addressCtrl.text = item.labAdd;
      _isActiveStatus = item.labStatus.toUpperCase() != 'NO';
      _selectedPCode = validPCode;
      _selectedPName = item.pName;
      _isModalOpen = true;
      _isSaveSuccess = false;
      _isSubmitting = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      _nameFocusNode.requestFocus();
    });
  }

  void _closeModal() {
    setState(() {
      _isModalOpen = false;
      _isSaveSuccess = false;
      _isSubmitting = false;
    });
  }

  // Interactive Account Lookup Modal Trigger (3-dot button / F2)
  Future<void> _openAccountLookupModal() async {
    final selectedAccount = await showDialog<PartyAccountLookupItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AccountLookupModalDialog(
        currentPCode: _selectedPCode,
      ),
    );

    if (selectedAccount != null) {
      setState(() {
        if (selectedAccount.pCode == 0 || selectedAccount.account.isEmpty || selectedAccount.account.toLowerCase().startsWith('none')) {
          _selectedPCode = null;
          _selectedPName = '';
        } else {
          _selectedPCode = selectedAccount.pCode;
          _selectedPName = selectedAccount.account;
        }
      });
    }
  }

  // Form Submit Handler (Save / Update)
  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showButtonValidation('Department Name is required!');
      _nameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final savedCode = _formLabCode;
    final isEdit = _isEditing;

    bool success = false;
    if (_isEditing) {
      success = await DepartmentService.updateDepartment(
        labCode: _formLabCode,
        labName: name,
        labSeries: _seriesCtrl.text.trim(),
        labStatus: _isActiveStatus ? 'YES' : 'NO',
        labAdd: _addressCtrl.text.trim(),
        labPCode: _selectedPCode,
      );
    } else {
      success = await DepartmentService.saveDepartment(
        labCode: _formLabCode,
        labName: name,
        labSeries: _seriesCtrl.text.trim(),
        labStatus: _isActiveStatus ? 'YES' : 'NO',
        labAdd: _addressCtrl.text.trim(),
        labPCode: _selectedPCode,
      );
    }

    if (mounted) {
      if (success) {
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });
        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) {
          _closeModal();
          await _refreshDataSilently();
          setState(() {
            _isSaveSuccess = false;
          });
          var highlightCode = savedCode;
          if (highlightCode == 0 || !_departments.any((d) => d.labCode == highlightCode)) {
            final found = _departments.firstWhere(
              (d) => d.labName.toLowerCase() == name.toLowerCase(),
              orElse: () => _departments.isNotEmpty ? _departments.last : const DepartmentMasterItem(labCode: 0, labName: ''),
            );
            if (found.labCode != 0) highlightCode = found.labCode;
          }
          _triggerGlowingHighlight(highlightCode, isEdit);
        }
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save Department record.');
      }
    }
  }

  Future<void> _deleteDepartment(DepartmentMasterItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        itemCode: item.labCode,
        itemName: item.labName,
        onDelete: () async {
          return await DepartmentService.deleteDepartment(item.labCode);
        },
      ),
    );

    if (confirmed == true) {
      await _refreshDataSilently();
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _DepartmentExportModalDialog(departments: _departments),
    );
  }

  // Keyboard Shortcuts Handler
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

      // Ctrl + K -> Focus Search
      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
        _searchFocusNode.requestFocus();
      }

      // F2 -> Open Account Lookup Modal
      if (event.logicalKey == LogicalKeyboardKey.f2 && _isModalOpen) {
        _openAccountLookupModal();
      }

      // Esc -> Close Modal
      if (event.logicalKey == LogicalKeyboardKey.escape && _isModalOpen) {
        _closeModal();
      }

      // Ctrl + S or F1 -> Save Form when Modal is Open
      if (_isModalOpen &&
          ((isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyS) ||
              event.logicalKey == LogicalKeyboardKey.f1)) {
        _submitForm();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSeriesCount = _departments
        .map((e) => e.labSeries.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .length;

    return KeyboardListener(
      focusNode: _pageKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // 1. TOP HEADER BAR
                        _buildTopHeaderBar(activeSeriesCount),
                        const SizedBox(height: 16),

                        // 2. MAIN DATA GRID DESK
                        Expanded(
                          child: _isLoading
                              ? _buildShimmerLoadingState()
                              : _errorMessage != null
                                  ? _buildErrorState()
                                  : _buildMainDataGridDesk(),
                        ),
                      ],
                    ),
                  ),

                  // 3. CENTER FLOATING ENTRY PANEL (POPUP MODAL)
                  if (_isModalOpen) _buildCenterFloatingEntryModal(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER BAR
  // ============================================================================
  Widget _buildTopHeaderBar(int activeSeriesCount) {
    final totalDepts = _departments.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
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
                  // Row 1: Title & Subtitle (Left) + KPI Pills (Right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/department_master_logo.png',
                            width: 62,
                            height: 62,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Department Master',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF000000),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage plant departments, series tags & account mappings',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Modern & Fashioned Gauge KPI Cards (Electric Blue & Fashion Pink)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildKpiCard(
                            label: 'TOTAL DEPTS',
                            value: totalDepts.toString(),
                            progress: totalDepts > 0 ? 0.75 : 0.0,
                            gradientColors: const [
                              Color(0xFF2563EB), // Electric Royal Blue
                              Color(0xFF06B6D4), // Vibrant Cyan Blue
                            ],
                          ),
                          const SizedBox(width: 10),
                          _buildKpiCard(
                            label: 'ACTIVE SERIES',
                            value: '$activeSeriesCount',
                            progress: totalDepts > 0
                                ? (activeSeriesCount / totalDepts).clamp(0.1, 1.0) * 0.85
                                : (activeSeriesCount > 0 ? 0.85 : 0.0),
                            gradientColors: const [
                              Color(0xFFEC4899), // Hot Fashion Pink
                              Color(0xFFF43F5E), // Luminous Rose Pink
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Row 2: Search Bar (Left) + Export & New Dept Buttons (Right)
                  Row(
                    children: [
                      // Search Field
                      SizedBox(
                        width: 240,
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocusNode,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark),
                          decoration: InputDecoration(
                            hintText: 'Search depts... (Ctrl+K)',
                            hintStyle: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 15, color: AppColors.primaryColor),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 13),
                                    onPressed: () => _searchCtrl.clear(),
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

                      const Spacer(),

                      // Animated Export Button (Circulating Light Edge Orbit)
                      _AnimatedExportButton(onPressed: _openExportModal),

                      const SizedBox(width: 8),

                      // Primary "+ New Department" Button (Single Plus Icon)
                      ElevatedButton.icon(
                        onPressed: _openNewDepartmentModal,
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'New Department',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
    Color? trackColor,
  }) {
    return _HeaderKpiCard(
      label: label,
      value: value,
      progress: progress,
      gradientColors: gradientColors,
      trackColor: trackColor,
    );
  }

  // ============================================================================
  // 2. MAIN DATA GRID DESK (FULL-WIDTH DATA TABLE)
  // ============================================================================
  Widget _buildMainDataGridDesk() {
    final displayList = _filteredDepartments;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/department_directory_sheet_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Department Directory Sheet',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${displayList.length} Records',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                  ),
                ),
              ],
            ),
          ),

          // Responsive Table Body Grid (Fixes 2.0px Overflow & Adds Spacing between Active Status & Address)
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = math.max(constraints.maxWidth, 960.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          // Column Header Bar
                          Container(
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 75,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.tag_rounded, size: 12, color: Color(0xFF6366F1)),
                                      SizedBox(width: 3),
                                      Text('CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF10B981)),
                                      SizedBox(width: 5),
                                      Text('DEPARTMENT NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Icon(Icons.bookmark_rounded, size: 12, color: Color(0xFFF59E0B)),
                                      SizedBox(width: 5),
                                      Text('SERIES', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF06B6D4)),
                                      SizedBox(width: 5),
                                      Text('ACTIVE STATUS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 24),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(Icons.location_on_rounded, size: 12, color: Color(0xFFF43F5E)),
                                      SizedBox(width: 5),
                                      Text('ADDRESS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Icon(Icons.account_balance_rounded, size: 12, color: Color(0xFF8B5CF6)),
                                      SizedBox(width: 5),
                                      Text('LINKED ACCOUNT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 75,
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
                          ),

                          // Data Rows List
                          Expanded(
                            child: displayList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
                                        const SizedBox(height: 6),
                                        Text(
                                          'No department records found matching search criteria',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    controller: _tableScrollCtrl,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    cacheExtent: 400,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: displayList.length,
                                    separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                                    itemBuilder: (ctx, idx) {
                                      final item = displayList[idx];
                                      final isSelected = _selectedRowCode == item.labCode;
                                      final isGlowing = _highlightedDeptCode == item.labCode;
                                      final isGlowingEdit = isGlowing && _isHighlightedEdit;
                                      final isGlowingNew = isGlowing && !_isHighlightedEdit;
                                      final avatarGradient = _getAvatarGradient(item.labName, item.labCode);

                                      return _AnimatedDepartmentRow(
                                        key: ValueKey<int>(item.labCode),
                                        item: item,
                                        isSelected: isSelected,
                                        isGlowing: isGlowing,
                                        isGlowingEdit: isGlowingEdit,
                                        isGlowingNew: isGlowingNew,
                                        avatarGradient: avatarGradient,
                                        onTap: () {
                                          setState(() {
                                            _selectedRowCode = item.labCode;
                                          });
                                        },
                                        onDoubleTap: () => _openEditDepartmentModal(item),
                                        onEdit: () => _openEditDepartmentModal(item),
                                        onDelete: () => _deleteDepartment(item),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. CENTER FLOATING ENTRY PANEL (POPUP MODAL)
  // ============================================================================
  Widget _buildCenterFloatingEntryModal() {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Container(
        width: 720,
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Header Bar (Clean Modern Aesthetic - Request 3)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.divider, width: 1.0)),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/add_department_logo.png',
                      width: 58,
                      height: 58,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Department #$_formLabCode' : 'Add Department',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Enter department details & linked account details',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: _closeModal,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Modal Form Fields Body (Spacious Layout, Natural-Colored Icons, & 3D Sliding Switch)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Code + Department Name + Series Tag (3 Harmonious Columns)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Department Code
                          SizedBox(
                            width: 145,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.lock_rounded, size: 13, color: Color(0xFF6366F1)),
                                    SizedBox(width: 5),
                                    Text('Department Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF6366F1)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CODE: #$_formLabCode',
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          // 2. Department Name (Required, Expanded Hero Field)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.apartment_rounded, size: 13, color: Color(0xFF10B981)),
                                    SizedBox(width: 5),
                                    Text('Department Name', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                    Text(' *', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _nameCtrl,
                                    focusNode: _nameFocusNode,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'Enter department name...',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.apartment_rounded, size: 15, color: Color(0xFF10B981)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          // 3. Series Tag
                          SizedBox(
                            width: 175,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.sell_rounded, size: 13, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 5),
                                    Text('Series Tag', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 38,
                                  child: TextField(
                                    controller: _seriesCtrl,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      hintText: 'e.g. CNC-01',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.bookmark_outline_rounded, size: 15, color: Color(0xFFF59E0B)),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Row 2: Linked Account (Expanded Left) + Active Status (Aligned Right with Series Tag)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 4. Linked Account Field with Embedded 3-Dot Browse Button (...)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.account_balance_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                    SizedBox(width: 5),
                                    Text('Linked Account (F2 / ...)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: _openAccountLookupModal,
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.only(left: 10, right: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.account_balance_outlined, size: 15, color: Color(0xFF8B5CF6)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _selectedPName.isNotEmpty
                                                ? _selectedPName
                                                : '-- Select Account (F2 / Click ...) --',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: _selectedPName.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                                              color: _selectedPName.isNotEmpty ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (_selectedPName.isNotEmpty) ...[
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                _selectedPCode = null;
                                                _selectedPName = '';
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(6),
                                            child: Container(
                                              height: 28,
                                              padding: const EdgeInsets.symmetric(horizontal: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                                  SizedBox(width: 2),
                                                  Text('Clear', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        // Embedded 3-Dot Browse Button
                                        Container(
                                          height: 28,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.2)),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.more_horiz_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 14),

                          // 5. Active Status (Aligned with Series Tag)
                          SizedBox(
                            width: 175,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.toggle_on_rounded, size: 14, color: Color(0xFF06B6D4)),
                                    SizedBox(width: 5),
                                    Text('Active Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _FluidActiveStatusSwitch(
                                  value: _isActiveStatus,
                                  onChanged: (val) => setState(() => _isActiveStatus = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Field 6: Address (Multi-line text field)
                      const Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFF43F5E)),
                          SizedBox(width: 5),
                          Text('Address / Location Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Enter department physical address...',
                          hintStyle: TextStyle(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Task 3: Plain White Screen Shortcuts Banner with Realistic Glowing Light Bulb (Silver, Golden, Black)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.65),
                                    blurRadius: 14,
                                    spreadRadius: 3,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFFBBF24).withValues(alpha: 0.40),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: const CustomPaint(
                                size: Size(22, 22),
                                painter: _RealisticGlowingBulbPainter(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Shortcuts: F2 / Click ... for Account Lookup | Ctrl+S / F1 to Save | Esc to Cancel',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Modal Footer Actions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _closeModal,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel (Esc)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_buttonValidationMsg != null) ...[
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline_rounded, size: 13, color: Colors.white),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      _buttonValidationMsg!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          AnimatedSuccessButton(
                            status: _isSubmitting
                                ? ButtonStatus.loading
                                : (_isSaveSuccess ? ButtonStatus.success : ButtonStatus.idle),
                            onPressed: _submitForm,
                            idleText: _isEditing ? 'Update Dept' : 'Save Department',
                            loadingText: 'Saving...',
                            successText: _isEditing ? 'Updated!' : 'Saved!',
                            idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                            idleBackgroundColor: AppColors.secondaryColor,
                            successBackgroundColor: const Color(0xFF10B981),
                            height: 38,
                          ),
                        ],
                      ),
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

  // Shimmer & Error Loading States
  Widget _buildShimmerLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.secondaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading Department Master records...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.neutralDark.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Failed to Load Data', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(_errorMessage ?? 'Unknown error occurred.', style: TextStyle(fontSize: 12, color: AppColors.neutralDark.withValues(alpha: 0.7))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. INTERACTIVE ACCOUNT LOOKUP SEARCH MODAL DIALOG (F2 / ... TRIGGER)
// ============================================================================
class _AccountLookupModalDialog extends StatefulWidget {
  final int? currentPCode;

  const _AccountLookupModalDialog({
    this.currentPCode,
  });

  @override
  State<_AccountLookupModalDialog> createState() => _AccountLookupModalDialogState();
}

class _AccountLookupModalDialogState extends State<_AccountLookupModalDialog> {
  // Persistent Dialog Key Focus Node (Fixes Focus Loss Glitch)
  final FocusNode _dialogKeyFocusNode = FocusNode();

  // Persistent Search Controllers
  final TextEditingController _lookupSearchCtrl = TextEditingController();
  final FocusNode _lookupSearchFocusNode = FocusNode();
  final ScrollController _lookupScrollCtrl = ScrollController();
  List<PartyAccountLookupItem> _allAccounts = [];
  List<PartyAccountLookupItem> _filteredAccounts = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  String _selectedLetterFilter = 'ALL';

  static const _noneAccountItem = PartyAccountLookupItem(
    pCode: 0,
    account: 'None (Unlink / Clear Account)',
    mobileNo: '-',
    gstin: 'UNLINKED',
    stateCode: '-',
    address: 'Remove linked account association',
  );

  final List<String> _alphabetList = const [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _fetchFullAccountsLookup();
    _lookupSearchCtrl.addListener(_applyCombinedFilters);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _lookupSearchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _dialogKeyFocusNode.dispose();
    _lookupSearchCtrl.removeListener(_applyCombinedFilters);
    _lookupSearchCtrl.dispose();
    _lookupSearchFocusNode.dispose();
    _lookupScrollCtrl.dispose();
    super.dispose();
  }

  /// On open, immediately use cached list of accounts for 0ms instant loading
  Future<void> _fetchFullAccountsLookup() async {
    // 0ms Cache Hit: If pre-cached, open instantly without network delay
    if (DepartmentService.hasCachedLookupAccounts) {
      final cached = DepartmentService.getCachedLookupAccounts();
      final selIdx = widget.currentPCode != null
          ? cached.indexWhere((a) => a.pCode == widget.currentPCode)
          : 0;

      setState(() {
        _allAccounts = cached;
        _filteredAccounts = List.from(cached);
        _isLoading = false;
        _selectedIndex = selIdx >= 0 ? selIdx : 0;
      });
      return;
    }

    setState(() => _isLoading = true);
    final results = await DepartmentService.fetchPartyAccountsLookup(search: '');
    if (mounted) {
      final selIdx = widget.currentPCode != null
          ? results.indexWhere((a) => a.pCode == widget.currentPCode)
          : 0;

      setState(() {
        _allAccounts = results;
        _filteredAccounts = List.from(results);
        _isLoading = false;
        _selectedIndex = selIdx >= 0 ? selIdx : 0;
      });
    }
  }

  /// Instant local filter combining Text Query & A-Z Alphabet Selection
  void _applyCombinedFilters() {
    final query = _lookupSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredAccounts = _allAccounts.where((a) {
        // Alphabet filter check
        if (_selectedLetterFilter != 'ALL') {
          final firstChar = a.account.trim().toUpperCase();
          if (_selectedLetterFilter == '#') {
            if (firstChar.isEmpty || RegExp(r'^[A-Z]').hasMatch(firstChar[0])) {
              return false;
            }
          } else {
            if (firstChar.isEmpty || !firstChar.startsWith(_selectedLetterFilter)) {
              return false;
            }
          }
        }

        // Text query check
        if (query.isNotEmpty) {
          return a.account.toLowerCase().contains(query) ||
              a.gstin.toLowerCase().contains(query) ||
              a.mobileNo.toLowerCase().contains(query) ||
              a.address.toLowerCase().contains(query) ||
              a.stateCode.toLowerCase().contains(query);
        }
        return true;
      }).toList();

      _selectedIndex = 0;
    });
  }

  void _selectCurrentItem(PartyAccountLookupItem item) {
    Navigator.of(context).pop(item);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_filteredAccounts.isNotEmpty && _selectedIndex < _filteredAccounts.length - 1) {
          setState(() {
            _selectedIndex++;
          });
          _scrollToIndex(_selectedIndex);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_filteredAccounts.isNotEmpty && _selectedIndex > 0) {
          setState(() {
            _selectedIndex--;
          });
          _scrollToIndex(_selectedIndex);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredAccounts.isNotEmpty && _selectedIndex >= 0 && _selectedIndex < _filteredAccounts.length) {
          _selectCurrentItem(_filteredAccounts[_selectedIndex]);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context).pop();
      }
    }
  }

  void _scrollToIndex(int index) {
    if (_lookupScrollCtrl.hasClients) {
      final double targetOffset = index * 42.0;
      _lookupScrollCtrl.animateTo(
        targetOffset.clamp(0.0, _lookupScrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      );
    }
  }

  void _openExportModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AccountDirectoryExportModalDialog(accounts: _filteredAccounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = (screenSize.width * 0.88).clamp(950.0, 1400.0);
    final modalHeight = (screenSize.height * 0.86).clamp(520.0, 880.0);

    return KeyboardListener(
      focusNode: _dialogKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: modalWidth,
          height: modalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 35,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                // Modal Header Bar (Clean Modern Styling)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Account Directory Lookup',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          '${_filteredAccounts.length} / ${_allAccounts.length} Accounts',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '↑/↓ to navigate | Enter to select | Esc to close',
                          style: TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Search Input Toolbar & Export Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _lookupSearchCtrl,
                            focusNode: _lookupSearchFocusNode,
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Type to live filter by Account Name, GSTIN, Mobile, or Address...',
                              hintStyle: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF10B981)),
                              suffixIcon: _lookupSearchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16),
                                      onPressed: () {
                                        _lookupSearchCtrl.clear();
                                        _lookupSearchFocusNode.requestFocus();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Dedicated "None / Deselect" Button
                      OutlinedButton.icon(
                        onPressed: () => _selectCurrentItem(_noneAccountItem),
                        icon: const Icon(Icons.link_off_rounded, size: 16, color: Color(0xFFE11D48)),
                        label: const Text(
                          'None (Clear Choice)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF1F2),
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFFECDD3), width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _AnimatedExportButton(onPressed: () => _openExportModal(context)),
                    ],
                  ),
                ),

                // A-Z Alphabet Quick Jump Filter Strip (User Request 1)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(top: BorderSide(color: AppColors.divider), bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _alphabetList.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(width: 3),
                    itemBuilder: (ctx, idx) {
                      final letter = _alphabetList[idx];
                      final isSelected = _selectedLetterFilter == letter;

                      return InkWell(
                        onTap: () {
                          _selectedLetterFilter = letter;
                          _applyCombinedFilters();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.25),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            letter,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Data Table Body (Redesigned Clean Layout - User Request 2)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor))
                            : _filteredAccounts.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 40, color: const Color(0xFF94A3B8)),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No party accounts found starting with "$_selectedLetterFilter"',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  )
                                : LayoutBuilder(builder: (context, constraints) {
                                    final double containerWidth = constraints.maxWidth;
                                    const double minTableWidth = 1010.0;
                                    final double tableWidth = containerWidth > minTableWidth ? containerWidth : minTableWidth;

                                    return Scrollbar(
                                      controller: _lookupScrollCtrl,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: tableWidth,
                                          child: Column(
                                            children: [
                                              // Structured Table Header Bar
                                              Container(
                                                height: 36,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFF1F5F9),
                                                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
                                                ),
                                                padding: const EdgeInsets.only(left: 18, right: 14),
                                                child: Row(
                                                  children: [
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(minWidth: 230),
                                                      child: SizedBox(
                                                        width: (tableWidth - 100) * 0.23,
                                                        child: const Row(
                                                          children: [
                                                            Icon(Icons.account_balance_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                                            SizedBox(width: 5),
                                                            Text('ACCOUNT NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(minWidth: 130),
                                                      child: SizedBox(
                                                        width: (tableWidth - 100) * 0.13,
                                                        child: const Row(
                                                          children: [
                                                            Icon(Icons.phone_iphone_rounded, size: 13, color: Color(0xFF06B6D4)),
                                                            SizedBox(width: 5),
                                                            Text('MOBILE NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(minWidth: 170),
                                                      child: SizedBox(
                                                        width: (tableWidth - 100) * 0.17,
                                                        child: const Row(
                                                          children: [
                                                            Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                                                            SizedBox(width: 5),
                                                            Text('GSTIN', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    ConstrainedBox(
                                                      constraints: const BoxConstraints(minWidth: 110),
                                                      child: SizedBox(
                                                        width: (tableWidth - 100) * 0.11,
                                                        child: const Align(
                                                          alignment: Alignment.center,
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(Icons.bookmark_rounded, size: 13, color: Color(0xFFF59E0B)),
                                                              SizedBox(width: 5),
                                                              Text('STATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const Expanded(
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.location_on_rounded, size: 13, color: Color(0xFFF43F5E)),
                                                          SizedBox(width: 5),
                                                          Text('ADDRESS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.5)),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Scrollable Translucent Data Rows
                                              Expanded(
                                                child: ListView.separated(
                                                  controller: _lookupScrollCtrl,
                                                  itemCount: _filteredAccounts.length,
                                                  separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                                  itemBuilder: (ctx, idx) {
                                                    final item = _filteredAccounts[idx];
                                                    final isSelected = _selectedIndex == idx;

                                                    return _AnimatedAccountLookupRow(
                                                      item: item,
                                                      isSelected: isSelected,
                                                      index: idx,
                                                      tableWidth: tableWidth,
                                                      onTap: () => _selectCurrentItem(item),
                                                    );
                                                  },
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
                            ),
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

// ============================================================================
// ANIMATED DELETE CONFIRMATION DIALOG (In-Button Success Feedback)
// ============================================================================
// ============================================================================
// CONFIRM DELETE DIALOG (100% COPIED FROM PROJECT MASTER SCREEN)
// ============================================================================
class _ConfirmDeleteDialog extends StatefulWidget {
  final Future<bool> Function() onDelete;
  final String? itemName;
  final int? itemCode;

  const _ConfirmDeleteDialog({
    required this.onDelete,
    this.itemName,
    this.itemCode,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  ButtonStatus _status = ButtonStatus.idle;

  Future<void> _handleDelete() async {
    setState(() => _status = ButtonStatus.loading);
    try {
      final success = await widget.onDelete();
      if (!mounted) return;
      if (success) {
        setState(() => _status = ButtonStatus.success);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _status = ButtonStatus.idle);
      }
    } catch (_) {
      if (mounted) setState(() => _status = ButtonStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 350,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Right Close X Button
            Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 100% IDENTICAL IMAGE 2 VECTOR ILLUSTRATION (Person throwing red files into trash)
            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

            // Red Small Single Message Title matching exact user request
            const Text(
              'Are you sure you want to delete this',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEF4444),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons Row matching Image 2 (Delete on Left, Cancel on Right)
            Row(
              children: [
                // Red Delete Button (Left)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: AnimatedSuccessButton(
                      status: _status,
                      onPressed: _handleDelete,
                      idleText: 'Delete',
                      loadingText: 'Deleting...',
                      successText: 'Deleted!',
                      idleIcon: Icons.delete_rounded,
                      idleBackgroundColor: const Color(0xFFEF4444),
                      successBackgroundColor: const Color(0xFFDC2626),
                      height: 40,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Soft Pink Cancel Button (Right)
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF0F2),
                        foregroundColor: const Color(0xFFEF4444),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _status == ButtonStatus.loading ? null : () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFEF4444),
                        ),
                      ),
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
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WIDGET
// ============================================================================
class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const AnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Processing...',
    this.successText = 'Success!',
    this.idleIcon = Icons.save_rounded,
    this.idleBackgroundColor = const Color(0xFF0C3B2E),
    this.successBackgroundColor = const Color(0xFF10B981),
    this.height = 44,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeOut));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeInOut));

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));

    if (widget.status == ButtonStatus.success) {
      _triggerSuccess();
    }
  }

  void _triggerSuccess() {
    _checkController.forward(from: 0.0);
    _rippleController.forward(from: 0.0);
    _glowController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant AnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.success && oldWidget.status != ButtonStatus.success) {
      _triggerSuccess();
    } else if (widget.status == ButtonStatus.idle) {
      _checkController.reset();
      _rippleController.reset();
      _glowController.reset();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == ButtonStatus.success;
    final isLoading = widget.status == ButtonStatus.loading;

    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _rippleController, _glowController]),
      builder: (context, child) {
        return Transform.scale(
          scale: isSuccess ? _bounceAnimation.value : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Ripple burst ring
              if (isSuccess)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                      duration: const Duration(milliseconds: 100),
                      child: Transform.scale(
                        scale: 1.0 + (_rippleAnimation.value * 0.25),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: widget.successBackgroundColor.withValues(alpha: 0.6),
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Main button body
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: isSuccess
                      ? LinearGradient(
                          colors: [
                            widget.successBackgroundColor,
                            widget.successBackgroundColor.withValues(alpha: 0.85),
                            const Color(0xFF059669),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSuccess
                      ? null
                      : (widget.onPressed == null
                          ? widget.idleBackgroundColor.withValues(alpha: 0.6)
                          : widget.idleBackgroundColor),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    if (isSuccess)
                      BoxShadow(
                        color: widget.successBackgroundColor
                            .withValues(alpha: 0.3 + (_glowAnimation.value * 0.35)),
                        blurRadius: 8 + (_glowAnimation.value * 16),
                        spreadRadius: _glowAnimation.value * 3,
                        offset: const Offset(0, 2),
                      )
                    else
                      BoxShadow(
                        color: widget.idleBackgroundColor.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (isLoading || isSuccess) ? null : widget.onPressed,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          else if (isSuccess)
                            ScaleTransition(
                              scale: _scaleAnimation,
                              child: const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                            )
                          else
                            Icon(widget.idleIcon, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.3),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: Text(
                              isLoading
                                  ? widget.loadingText
                                  : (isSuccess ? widget.successText : widget.idleText),
                              key: ValueKey<String>(
                                isLoading
                                    ? 'loading'
                                    : (isSuccess ? 'success' : widget.idleText),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Sparkle particles
              if (isSuccess) ...List.generate(6, (i) {
                final angle = (i * 60.0) * (3.14159 / 180.0);
                final distance = 18.0 + (_rippleAnimation.value * 22.0);
                return Positioned(
                  left: (widget.height / 2) - 3 + (distance * math.cos(angle)),
                  top: (widget.height / 2) - 3 + (distance * math.sin(angle)),
                  child: AnimatedOpacity(
                    opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                    duration: const Duration(milliseconds: 100),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: i.isEven
                            ? Colors.white
                            : widget.successBackgroundColor.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: widget.successBackgroundColor.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}


// ============================================================================
// STANDARDIZED ANIMATED EXPORT BUTTON (WITH 1-LAP ORBIT ROTATION BEAM)
// ============================================================================
class StandardizedMasterExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const StandardizedMasterExportButton({super.key, required this.onPressed});

  @override
  State<StandardizedMasterExportButton> createState() => _StandardizedMasterExportButtonState();
}

class _StandardizedMasterExportButtonState extends State<StandardizedMasterExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrl.reset();
        if (mounted) {
          setState(() => _isAnimating = false);
        }
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerClickOrbit() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _triggerClickOrbit,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = _ctrl.value;

            return CustomPaint(
              painter: _OrbitButtonBorderPainter(
                progress: progress,
                isHovered: _isHovered,
                isAnimating: _isAnimating,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isAnimating ? AppColors.secondaryColor : AppColors.divider,
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? AppColors.secondaryColor.withValues(alpha: 0.3)
                          : AppColors.secondaryColor.withValues(alpha: _isHovered ? 0.18 : 0.05),
                      blurRadius: _isAnimating || _isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 16,
                      color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;
  final bool isAnimating;

  _OrbitButtonBorderPainter({
    required this.progress,
    required this.isHovered,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isAnimating || progress <= 0.0 || progress >= 1.0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics().first;
    final totalLen = metrics.length;
    final beamLen = totalLen * 0.35;

    final start = progress * totalLen;
    final end = (start + beamLen) % totalLen;

    Path extractPath;
    if (start + beamLen <= totalLen) {
      extractPath = metrics.extractPath(start, start + beamLen);
    } else {
      extractPath = metrics.extractPath(start, totalLen);
      extractPath.addPath(metrics.extractPath(0, end), Offset.zero);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF25D366).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF0C3B2E).withValues(alpha: 0.2),
          const Color(0xFF25D366),
          const Color(0xFF10B981),
          Colors.white,
        ],
        stops: const [0.0, 0.25, 0.6, 0.85, 1.0],
        transform: GradientRotation(progress * 2 * math.pi),
      ).createShader(rect);

    canvas.drawPath(extractPath, glowPaint);
    canvas.drawPath(extractPath, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitButtonBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.isAnimating != isAnimating;
  }
}

// ============================================================================
// STANDARDIZED DUAL-PANE EXPORT MODAL DIALOG
// ============================================================================
class _DepartmentExportModalDialog extends StatefulWidget {
  final List<DepartmentMasterItem> departments;
  const _DepartmentExportModalDialog({required this.departments});

  @override
  State<_DepartmentExportModalDialog> createState() => _DepartmentExportModalDialogState();
}

class _DepartmentExportModalDialogState extends State<_DepartmentExportModalDialog> {
  ExportFormat _selectedFormat = ExportFormat.excel;
  late Set<int> _selectedCodes;
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _searchFilter = '';

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.departments.map((e) => e.labCode).toSet();
    _modalSearchCtrl.addListener(() {
      setState(() {
        _searchFilter = _modalSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _modalSearchCtrl.dispose();
    _exportTimer?.cancel();
    super.dispose();
  }

  List<DepartmentMasterItem> get _previewItems {
    if (_searchFilter.isEmpty) return widget.departments;
    return widget.departments.where((d) {
      return d.labCode.toString().contains(_searchFilter) ||
          d.labName.toLowerCase().contains(_searchFilter) ||
          d.labSeries.toLowerCase().contains(_searchFilter);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _previewItems;
    if (preview.isEmpty) return false;
    return preview.every((d) => _selectedCodes.contains(d.labCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _previewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final d in preview) {
          _selectedCodes.remove(d.labCode);
        }
      } else {
        for (final d in preview) {
          _selectedCodes.add(d.labCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double progress = (currentStep / 20.0).clamp(0.0, 1.0);

      setState(() {
        _exportProgress = progress;
      });

      if (progress >= 1.0) {
        timer.cancel();
        _finalizeFileAndComplete();
      }
    });
  }

  Future<void> _finalizeFileAndComplete() async {
    try {
      final selectedList = widget.departments
          .where((d) => _selectedCodes.contains(d.labCode))
          .toList();

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      String filePath = '';

      if (_selectedFormat == ExportFormat.excel) {
        filePath = '$downloadsPath\\Department_Master_Export_$timeStamp.xlsx';
        await _generateExcelFile(filePath, selectedList);
      } else {
        filePath = '$downloadsPath\\Department_Master_Export_$timeStamp.pdf';
        await _generatePdfFile(filePath, selectedList);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();

        try {
          await Process.run('explorer.exe', ['/select,', filePath]);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _generateExcelFile(String filePath, List<DepartmentMasterItem> records) async {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Department Master');
    final excel_pkg.Sheet sheet = excel['Department Master'];

    sheet.setColumnWidth(0, 16.0); // CODE
    sheet.setColumnWidth(1, 32.0); // DEPARTMENT NAME
    sheet.setColumnWidth(2, 20.0); // SERIES
    sheet.setColumnWidth(3, 18.0); // ACTIVE STATUS
    sheet.setColumnWidth(4, 32.0); // ADDRESS
    sheet.setColumnWidth(5, 30.0); // LINKED ACCOUNT NAME

    final cellBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
      borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
    );

    final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0C3B2E'),
      fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('DEPT CODE'),
      excel_pkg.TextCellValue('DEPARTMENT NAME'),
      excel_pkg.TextCellValue('SERIES'),
      excel_pkg.TextCellValue('ACTIVE STATUS'),
      excel_pkg.TextCellValue('ADDRESS'),
      excel_pkg.TextCellValue('LINKED ACCOUNT'),
    ]);

    for (int col = 0; col < 6; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.IntCellValue(item.labCode),
        excel_pkg.TextCellValue(item.labName),
        excel_pkg.TextCellValue(item.labSeries),
        excel_pkg.TextCellValue(item.labStatus),
        excel_pkg.TextCellValue(item.labAdd.isNotEmpty ? item.labAdd : '-'),
        excel_pkg.TextCellValue(item.pName.isNotEmpty ? item.pName : '-'),
      ]);

      for (int col = 0; col < 6; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final File file = File(filePath);
      await file.writeAsBytes(fileBytes);
    }
  }

  Future<void> _generatePdfFile(String filePath, List<DepartmentMasterItem> records) async {
    final pdfDoc = pw.Document();

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DEPARTMENT MASTER REGISTER REPORT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF0C3B2E),
                  ),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Records: ${records.length}',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'Exported on: ${DateTime.now().toString().split('.')[0]}',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF0C3B2E)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by New Tech MMS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['SR NO', 'CODE', 'DEPARTMENT NAME', 'SERIES', 'ACTIVE', 'ADDRESS', 'LINKED ACCOUNT'],
            data: records.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return [
                '${idx + 1}',
                '${item.labCode}',
                item.labName,
                item.labSeries.isNotEmpty ? item.labSeries : '-',
                item.labStatus.isNotEmpty ? item.labStatus : '-',
                item.labAdd.isNotEmpty ? item.labAdd : '-',
                item.pName.isNotEmpty ? item.pName : '-',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.centerLeft,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(3.0),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(3.0),
              6: const pw.FlexColumnWidth(3.0),
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4.5),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      ),
    );

    final pdfBytes = await pdfDoc.save();
    final File file = File(filePath);
    await file.writeAsBytes(pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 920,
            height: 610,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.98), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT COLUMN: Format Selector & Options (440px)
                    SizedBox(
                      width: 440,
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF5EE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Department Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSideBySideCard(
                                    format: ExportFormat.excel,
                                    title: 'Excel (.xlsx)',
                                    subtitle: 'Structured sheet with zebra rows',
                                    logoWidget: const Excel3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFF2E7D32),
                                    bgColor: const Color(0xFFEAF5EE),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSideBySideCard(
                                    format: ExportFormat.pdf,
                                    title: 'PDF (.pdf)',
                                    subtitle: 'Clean printable report document',
                                    logoWidget: const Pdf3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFFC62828),
                                    bgColor: const Color(0xFFFFEBEE),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            if (_isExporting) ...[
                              LinearProgressIndicator(
                                value: _exportProgress,
                                backgroundColor: AppColors.divider,
                                color: const Color(0xFF0C3B2E),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Generating Export File... ${(_exportProgress * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSuccessButton(
                                    status: _isExporting
                                        ? ButtonStatus.loading
                                        : (_isExportSuccess ? ButtonStatus.success : ButtonStatus.idle),
                                    onPressed: _startExportProcess,
                                    idleText: 'Download File',
                                    loadingText: 'Exporting...',
                                    successText: 'Exported!',
                                    idleIcon: Icons.file_download_outlined,
                                    idleBackgroundColor: const Color(0xFF0C3B2E),
                                    successBackgroundColor: const Color(0xFF10B981),
                                    height: 44,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            _buildPreviewTableToolbar(),
                            const SizedBox(height: 14),
                            Expanded(child: _buildPreviewDataTable()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      hoverColor: Colors.black.withValues(alpha: 0.12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
                    tooltip: 'Close Modal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewTableToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.secondaryColor),
                suffixIcon: _modalSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => _modalSearchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Checkbox(
              value: _isAllFilteredSelected,
              onChanged: (val) => _toggleSelectAllFiltered(),
              activeColor: AppColors.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const Text(
              'Select All',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedCodes.length} of ${widget.departments.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _previewItems;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No department records found',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 40,
              color: const Color(0xFF0C3B2E),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('DEPARTMENT NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('SERIES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final d = previewList[idx];
                  final isSelected = _selectedCodes.contains(d.labCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(d.labCode);
                        } else {
                          _selectedCodes.add(d.labCode);
                        }
                      });
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.white,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.secondaryColor,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedCodes.add(d.labCode);
                                  } else {
                                    _selectedCodes.remove(d.labCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '${d.labCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d.labName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              d.labSeries.isEmpty ? '-' : d.labSeries,
                              style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
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
    );
  }

  Widget _buildSideBySideCard({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required Widget logoWidget,
    required Color brandColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: isSelected ? brandColor : const Color(0xFF94A3B8),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? brandColor : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// AUTHENTIC VECTOR BRAND LOGO WIDGETS (100% IDENTICAL TO PROJECT MASTER)
// ============================================================================

/// Authentic 3D Microsoft Excel Brand Badge Logo
class Excel3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Excel3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF107C41).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Excel3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Excel3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Dark to medium Excel green)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Right side 3D Grid Panel (Lighter green sheet with white grid cells)
    final sheetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      ).createShader(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h), Radius.circular(w * 0.08)),
      sheetPaint,
    );

    // Grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    // Horizontal grid lines
    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);

    // Vertical grid line
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    // 3D Elevated Left Block (Dark Green Front Plate)
    final platePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)));

    // Shadow under left plate
    canvas.drawPath(
      platePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final plateGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF185ABD), Color(0xFF107C41), Color(0xFF0E5C2F)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)),
      plateGradient,
    );

    // Gloss highlight on top of plate
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4), Radius.circular(w * 0.18)),
      glossPaint,
    );

    // Bold Embossed White 'X'
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.62,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(1, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.09, h * 0.08));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic 3D Adobe PDF Brand Badge Logo
class Pdf3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Pdf3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Pdf3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Pdf3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Deep Red Adobe gradient)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF3B30), Color(0xFFD32F2F), Color(0xFF8E0000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 3D Folded Top Right Corner
    final foldPath = Path()
      ..moveTo(w * 0.70, 0)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.30)
      ..close();

    final foldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)],
      ).createShader(Rect.fromLTWH(w * 0.70, 0, w * 0.30, h * 0.30));

    canvas.drawPath(foldPath, foldPaint);

    // Fold Shadow
    final foldShadow = Path()
      ..moveTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.40)
      ..close();
    canvas.drawPath(foldShadow, Paint()..color = Colors.black.withValues(alpha: 0.25));

    // Gloss Highlight Header
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), glossPaint);

    // Authentic Adobe Ribbon Curve
    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final ribbonPath = Path();
    ribbonPath.moveTo(w * 0.22, h * 0.72);
    ribbonPath.cubicTo(w * 0.22, h * 0.38, w * 0.48, h * 0.35, w * 0.50, h * 0.55);
    ribbonPath.cubicTo(w * 0.52, h * 0.75, w * 0.78, h * 0.72, w * 0.78, h * 0.42);

    canvas.drawPath(
      ribbonPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawPath(ribbonPath, ribbonPaint);

    // PDF text at top
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0.8, 0.8),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.22, h * 0.15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL DUAL-PANE ACCOUNT DIRECTORY EXPORT MODAL DIALOG
// ============================================================================
class _AccountDirectoryExportModalDialog extends StatefulWidget {
  final List<PartyAccountLookupItem> accounts;
  const _AccountDirectoryExportModalDialog({required this.accounts});

  @override
  State<_AccountDirectoryExportModalDialog> createState() => _AccountDirectoryExportModalDialogState();
}

class _AccountDirectoryExportModalDialogState extends State<_AccountDirectoryExportModalDialog> {
  ExportFormat _selectedFormat = ExportFormat.excel;
  late Set<int> _selectedCodes;
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _searchFilter = '';

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.accounts.map((e) => e.pCode).toSet();
    _modalSearchCtrl.addListener(() {
      setState(() {
        _searchFilter = _modalSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _modalSearchCtrl.dispose();
    _exportTimer?.cancel();
    super.dispose();
  }

  List<PartyAccountLookupItem> get _previewItems {
    if (_searchFilter.isEmpty) return widget.accounts;
    return widget.accounts.where((a) {
      return a.pCode.toString().contains(_searchFilter) ||
          a.account.toLowerCase().contains(_searchFilter) ||
          a.gstin.toLowerCase().contains(_searchFilter) ||
          a.mobileNo.toLowerCase().contains(_searchFilter) ||
          a.address.toLowerCase().contains(_searchFilter) ||
          a.stateCode.toLowerCase().contains(_searchFilter);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _previewItems;
    if (preview.isEmpty) return false;
    return preview.every((a) => _selectedCodes.contains(a.pCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _previewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final a in preview) {
          _selectedCodes.remove(a.pCode);
        }
      } else {
        for (final a in preview) {
          _selectedCodes.add(a.pCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double progress = (currentStep / 20.0).clamp(0.0, 1.0);

      setState(() {
        _exportProgress = progress;
      });

      if (progress >= 1.0) {
        timer.cancel();
        _finalizeFileAndComplete();
      }
    });
  }

  Future<void> _finalizeFileAndComplete() async {
    try {
      final selectedList = widget.accounts
          .where((a) => _selectedCodes.contains(a.pCode))
          .toList();

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      String filePath = '';

      if (_selectedFormat == ExportFormat.excel) {
        filePath = '$downloadsPath\\Account_Directory_Export_$timeStamp.xlsx';
        await _generateExcelFile(filePath, selectedList);
      } else {
        filePath = '$downloadsPath\\Account_Directory_Export_$timeStamp.pdf';
        await _generatePdfFile(filePath, selectedList);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();

        try {
          await Process.run('explorer.exe', ['/select,', filePath]);
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _generateExcelFile(String filePath, List<PartyAccountLookupItem> records) async {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Account Directory');
    final excel_pkg.Sheet sheet = excel['Account Directory'];

    // Set explicit wide column widths to prevent squeezed/messy layout in Excel
    sheet.setColumnWidth(0, 36.0); // ACCOUNT NAME
    sheet.setColumnWidth(1, 18.0); // MOBILE NO
    sheet.setColumnWidth(2, 22.0); // GSTIN
    sheet.setColumnWidth(3, 18.0); // SERIES / STATE
    sheet.setColumnWidth(4, 65.0); // ADDRESS

    sheet.setRowHeight(0, 28.0); // Header row height

    final cellBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
      borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
    );

    final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0C3B2E'),
      fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
      horizontalAlign: excel_pkg.HorizontalAlign.Left,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: excel_pkg.HorizontalAlign.Left,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      leftBorder: cellBorder,
      rightBorder: cellBorder,
      topBorder: cellBorder,
      bottomBorder: cellBorder,
    );

    final headers = ['ACCOUNT NAME', 'MOBILE NO', 'GSTIN', 'SERIES / STATE', 'ADDRESS'];
    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.value = excel_pkg.TextCellValue(headers[col]);
      cell.cellStyle = headerStyle;
    }

    for (int rIdx = 0; rIdx < records.length; rIdx++) {
      final item = records[rIdx];
      final style = (rIdx % 2 == 0) ? evenStyle : oddStyle;
      final row = rIdx + 1;

      sheet.setRowHeight(row, 22.0);

      final values = [
        excel_pkg.TextCellValue(item.account),
        excel_pkg.TextCellValue(item.mobileNo),
        excel_pkg.TextCellValue(item.gstin),
        excel_pkg.TextCellValue(item.stateCode),
        excel_pkg.TextCellValue(item.address),
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row));
        cell.value = values[col];
        cell.cellStyle = style;
      }
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      file.writeAsBytesSync(fileBytes);
    }
  }

  Future<void> _generatePdfFile(String filePath, List<PartyAccountLookupItem> records) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        maxPages: 5000,
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ACCOUNT DIRECTORY REPORT',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0C3B2E)),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF0C3B2E)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (pw.Context context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated: ${DateTime.now().toString().split('.').first}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (pw.Context context) => [
          pw.TableHelper.fromTextArray(
            headers: ['ACCOUNT NAME', 'MOBILE NO', 'GSTIN', 'SERIES / STATE', 'ADDRESS'],
            data: records.map((e) => [
              e.account,
              e.mobileNo,
              e.gstin,
              e.stateCode,
              e.address,
            ]).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(4),
            },
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      ),
    );

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 920,
            height: 610,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.98), width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT COLUMN: Format Selector & Options (440px)
                    SizedBox(
                      width: 440,
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF5EE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Account Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSideBySideCard(
                                    format: ExportFormat.excel,
                                    title: 'Excel (.xlsx)',
                                    subtitle: 'Structured sheet with zebra rows',
                                    logoWidget: const Excel3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFF2E7D32),
                                    bgColor: const Color(0xFFEAF5EE),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSideBySideCard(
                                    format: ExportFormat.pdf,
                                    title: 'PDF (.pdf)',
                                    subtitle: 'Clean printable report document',
                                    logoWidget: const Pdf3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFFC62828),
                                    bgColor: const Color(0xFFFFEBEE),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            if (_isExporting) ...[
                              LinearProgressIndicator(
                                value: _exportProgress,
                                backgroundColor: AppColors.divider,
                                color: const Color(0xFF0C3B2E),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Generating Export File... ${(_exportProgress * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSuccessButton(
                                    status: _isExporting
                                        ? ButtonStatus.loading
                                        : (_isExportSuccess ? ButtonStatus.success : ButtonStatus.idle),
                                    onPressed: _startExportProcess,
                                    idleText: 'Download File',
                                    loadingText: 'Exporting...',
                                    successText: 'Exported!',
                                    idleIcon: Icons.file_download_outlined,
                                    idleBackgroundColor: const Color(0xFF0C3B2E),
                                    successBackgroundColor: const Color(0xFF10B981),
                                    height: 44,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            _buildPreviewTableToolbar(),
                            const SizedBox(height: 14),
                            Expanded(child: _buildPreviewDataTable()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      hoverColor: Colors.black.withValues(alpha: 0.12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
                    tooltip: 'Close Modal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideCard({
    required ExportFormat format,
    required String title,
    required String subtitle,
    required Widget logoWidget,
    required Color brandColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == format;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : AppColors.divider,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: isSelected ? brandColor : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? brandColor : AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.neutralDark.withValues(alpha: 0.65),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTableToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.secondaryColor),
                suffixIcon: _modalSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => _modalSearchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            Checkbox(
              value: _isAllFilteredSelected,
              onChanged: (val) => _toggleSelectAllFiltered(),
              activeColor: AppColors.secondaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            const Text(
              'Select All',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedCodes.length} of ${widget.accounts.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 40,
              color: const Color(0xFF0C3B2E),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text('CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('ACCOUNT NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 140, child: Text('GSTIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _previewItems.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final a = _previewItems[idx];
                  final isChecked = _selectedCodes.contains(a.pCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isChecked) {
                          _selectedCodes.remove(a.pCode);
                        } else {
                          _selectedCodes.add(a.pCode);
                        }
                      });
                    },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: isChecked ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.white,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: isChecked,
                              activeColor: AppColors.secondaryColor,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedCodes.add(a.pCode);
                                  } else {
                                    _selectedCodes.remove(a.pCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Text(
                              '${a.pCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              a.account,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: Text(
                              a.gstin.isNotEmpty ? a.gstin : 'UNREGISTERED',
                              style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
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
    );
  }
}



// ============================================================================
// 100% IDENTICAL 3D VECTOR ILLUSTRATION PAINTER FOR DELETE MODAL
// ============================================================================
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft Oval Ground Shadow
    final shadowPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.12), shadowPaint);

    // 2. Background Windows (Light Stroke Rounded Rectangles)
    final windowPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Left Window (With 4 Grid Panes)
    final leftWin = Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.24, h * 0.38);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWin, const Radius.circular(3)), windowPaint);
    canvas.drawLine(Offset(leftWin.left + leftWin.width / 2, leftWin.top), Offset(leftWin.left + leftWin.width / 2, leftWin.bottom), windowPaint);
    canvas.drawLine(Offset(leftWin.left, leftWin.top + leftWin.height / 2), Offset(leftWin.right, leftWin.top + leftWin.height / 2), windowPaint);

    // Right Window (Single Frame)
    final rightWin = Rect.fromLTWH(w * 0.54, h * 0.20, w * 0.22, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWin, const Radius.circular(3)), windowPaint);

    // 3. Red Trash Bin (Right Side)
    final binBody = Path()
      ..moveTo(w * 0.60, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(w * 0.77, h * 0.86)
      ..lineTo(w * 0.63, h * 0.86)
      ..close();
    canvas.drawPath(binBody, Paint()..color = const Color(0xFFEF4444));

    // Trash bin vertical stripe lines
    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.65, h * 0.50), Offset(w * 0.66, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.50), Offset(w * 0.70, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.75, h * 0.50), Offset(w * 0.74, h * 0.84), stripePaint);

    // Trash bin top rim
    final binLid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.44, w * 0.24, h * 0.06), const Radius.circular(3));
    canvas.drawRRect(binLid, Paint()..color = const Color(0xFFEF4444));

    // 4. Person Figure (Standing Left Side)
    final skinPaint = Paint()..color = const Color(0xFFFFCCBC);
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    final coralShirtPaint = Paint()..color = const Color(0xFFEF4444);
    final navyPantsPaint = Paint()..color = const Color(0xFF1E293B);

    // Head (Peach Face + Black Hair Cap)
    final headCenter = Offset(w * 0.38, h * 0.32);
    canvas.drawCircle(headCenter, w * 0.07, skinPaint);
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: w * 0.07), math.pi, math.pi);
    canvas.drawPath(hairPath, hairPaint);

    // Torso (Coral Red Shirt)
    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.39, w * 0.10, h * 0.18), coralShirtPaint);

    // Arms extending over to the trash bin
    final armPath = Path()
      ..moveTo(w * 0.38, h * 0.41)
      ..lineTo(w * 0.55, h * 0.37)
      ..lineTo(w * 0.55, h * 0.44)
      ..lineTo(w * 0.38, h * 0.48)
      ..close();
    canvas.drawPath(armPath, coralShirtPaint);

    // Red block/paper in hand going into bin
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.41, 14, 10), const Radius.circular(2)), Paint()..color = const Color(0xFFF87171));

    // Legs (Dark Navy)
    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.39, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);

    // Red Shoes
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED DEPARTMENT ROW WIDGET
// ============================================================================
class _AnimatedDepartmentRow extends StatefulWidget {
  final DepartmentMasterItem item;
  final bool isSelected;
  final bool isGlowing;
  final bool isGlowingEdit;
  final bool isGlowingNew;
  final List<Color> avatarGradient;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedDepartmentRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isGlowing,
    required this.isGlowingEdit,
    required this.isGlowingNew,
    required this.avatarGradient,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedDepartmentRow> createState() => _AnimatedDepartmentRowState();
}

class _AnimatedDepartmentRowState extends State<_AnimatedDepartmentRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isGlowing = widget.isGlowing;
    final isGlowingEdit = widget.isGlowingEdit;
    final isActive = item.labStatus.toUpperCase() != 'NO';

    final glowColor = isGlowingEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.006 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isGlowing
                  ? glowColor.withValues(alpha: 0.12)
                  : (isSelected
                      ? AppColors.secondaryColor.withValues(alpha: 0.08)
                      : (_isHovered ? const Color(0xFFF0FDF4) : Colors.white)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isGlowing
                    ? glowColor
                    : (isSelected
                        ? AppColors.secondaryColor
                        : (_isHovered ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0))),
                width: isGlowing ? 2.0 : (_isHovered || isSelected ? 1.6 : 1.0),
              ),
              boxShadow: isGlowing
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.40),
                        blurRadius: 10,
                        spreadRadius: 1.5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.22),
                            blurRadius: 10,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]),
            ),
            child: Row(
              children: [
                // Code Badge + Star Badge (75px + FittedBox guarantees 0 overflow)
                SizedBox(
                  width: 75,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isGlowing || isSelected || _isHovered
                                ? (isGlowing ? glowColor : (_isHovered ? const Color(0xFF16A34A) : AppColors.secondaryColor))
                                : const Color(0xFF6366F1).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !(isGlowing || isSelected || _isHovered) ? const Color(0xFF6366F1).withValues(alpha: 0.22) : Colors.transparent,
                              width: 1.0,
                            ),
                            boxShadow: isGlowing || isSelected || _isHovered
                                ? [
                                    BoxShadow(
                                      color: (isGlowing ? glowColor : (_isHovered ? const Color(0xFF16A34A) : AppColors.secondaryColor)).withValues(alpha: 0.32),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '#${item.labCode}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isGlowing || isSelected || _isHovered ? Colors.white : const Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        if (isGlowing) ...[
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              color: glowColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 9,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Department Name (Clean text with Tooltip for long names)
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: item.labName,
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      item.labName,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Series Tag
                Expanded(
                  flex: 2,
                  child: Text(
                    item.labSeries.isNotEmpty ? item.labSeries : '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neutralDark.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // Active Status Badge
                SizedBox(
                  width: 120,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        isActive ? 'YES (ACTIVE)' : 'NO (INACTIVE)',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isActive ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Address (With Tooltip for long addresses)
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: item.labAdd.isNotEmpty ? item.labAdd : 'No Address',
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      item.labAdd.isNotEmpty ? item.labAdd : '-',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.neutralDark.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Linked Account Name (With Tooltip for long account names)
                Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: item.pName.isNotEmpty ? item.pName : 'Unlinked Account',
                    waitDuration: const Duration(milliseconds: 600),
                    child: Text(
                      item.pName.isNotEmpty ? item.pName : 'Unlinked',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: item.pName.isNotEmpty ? FontWeight.w700 : FontWeight.w400,
                        fontStyle: item.pName.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        color: item.pName.isNotEmpty ? AppColors.primaryColor : AppColors.neutralDark.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Actions Buttons (Edit & Delete - No Outer Box)
                SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Department',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Department',
                        onPressed: widget.onDelete,
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
  }
}

// ============================================================================
// INTERACTIVE HOVER ACTION BUTTON WIDGET
// ============================================================================
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: IconButton(
            icon: Icon(widget.icon, size: 13.5, color: _isHovered ? widget.color : widget.color.withValues(alpha: 0.8)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: widget.tooltip,
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// UNIQUE 12-COLOR PALETTE GENERATOR FOR DEPARTMENTS
// ============================================================================
List<Color> _getAvatarGradient(String name, int labCode) {
  int hash = labCode * 17;
  for (int i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.codeUnitAt(i)) & 0xFFFFFF;
  }
  final mod = (hash + labCode * 7) % 12;
  switch (mod) {
    case 0:
      return const [Color(0xFF6366F1), Color(0xFF4F46E5)]; // Indigo Blue
    case 1:
      return const [Color(0xFFEC4899), Color(0xFFBE185D)]; // Rose Pink
    case 2:
      return const [Color(0xFF10B981), Color(0xFF059669)]; // Emerald Green
    case 3:
      return const [Color(0xFFF59E0B), Color(0xFFD97706)]; // Amber Gold
    case 4:
      return const [Color(0xFF3B82F6), Color(0xFF1D4ED8)]; // Sapphire Blue
    case 5:
      return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)]; // Deep Purple
    case 6:
      return const [Color(0xFF06B6D4), Color(0xFF0891B2)]; // Cyan Teal
    case 7:
      return const [Color(0xFFF97316), Color(0xFFC2410C)]; // Vibrant Orange
    case 8:
      return const [Color(0xFFEF4444), Color(0xFFDC2626)]; // Crimson Red
    case 9:
      return const [Color(0xFF84CC16), Color(0xFF65A30D)]; // Lime Green
    case 10:
      return const [Color(0xFFD946EF), Color(0xFFC026D3)]; // Fuchsia Magenta
    default:
      return const [Color(0xFF0EA5E9), Color(0xFF0284C7)]; // Sky Blue
  }
}





// ============================================================================
// REALISTIC GLOWING LIGHT BULB PAINTER (Silver Screw Base, Golden Glass Dome, Black Filament)
// ============================================================================
class _RealisticGlowingBulbPainter extends CustomPainter {
  const _RealisticGlowingBulbPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blackOutline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final blackFill = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // 1. Silver Screw Base (Metallic Silver/Grey)
    final silverPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFCBD5E1), Color(0xFF64748B), Color(0xFFE2E8F0)],
      ).createShader(Rect.fromLTWH(w * 0.34, h * 0.62, w * 0.32, h * 0.28));

    // Silver Base Threads
    final baseRect1 = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.34, h * 0.62, w * 0.32, h * 0.08), Radius.circular(w * 0.02));
    final baseRect2 = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.37, h * 0.70, w * 0.26, h * 0.08), Radius.circular(w * 0.02));
    final baseRect3 = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.40, h * 0.78, w * 0.20, h * 0.08), Radius.circular(w * 0.02));

    canvas.drawRRect(baseRect1, silverPaint);
    canvas.drawRRect(baseRect1, blackOutline);
    canvas.drawRRect(baseRect2, silverPaint);
    canvas.drawRRect(baseRect2, blackOutline);
    canvas.drawRRect(baseRect3, silverPaint);
    canvas.drawRRect(baseRect3, blackOutline);

    // Black Contact Tip at Bottom
    canvas.drawCircle(Offset(w * 0.50, h * 0.88), w * 0.05, blackFill);

    // 2. Golden Glass Dome Bulb (Warm Glowing Amber/Gold)
    final goldGlassPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFEF08A), Color(0xFFF59E0B), Color(0xFFD97706)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.50, h * 0.36), radius: w * 0.36));

    final bulbPath = Path()
      ..moveTo(w * 0.34, h * 0.62)
      ..cubicTo(w * 0.18, h * 0.50, w * 0.12, h * 0.32, w * 0.26, h * 0.16)
      ..cubicTo(w * 0.38, h * 0.04, w * 0.62, h * 0.04, w * 0.74, h * 0.16)
      ..cubicTo(w * 0.88, h * 0.32, w * 0.82, h * 0.50, w * 0.66, h * 0.62)
      ..close();

    canvas.drawPath(bulbPath, goldGlassPaint);
    canvas.drawPath(bulbPath, blackOutline);

    // 3. Black Inner Filament Loops
    final filamentPath = Path()
      ..moveTo(w * 0.40, h * 0.58)
      ..lineTo(w * 0.44, h * 0.32)
      ..lineTo(w * 0.50, h * 0.24)
      ..lineTo(w * 0.56, h * 0.32)
      ..lineTo(w * 0.60, h * 0.58);
    canvas.drawPath(filamentPath, Paint()..color = const Color(0xFF0F172A)..style = PaintingStyle.stroke..strokeWidth = w * 0.065..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// COMPACT FLUID ACTIVE STATUS ANIMATED SWITCH (Liquid Wave Motion & Glowing Knob)
// ============================================================================
class _FluidActiveStatusSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FluidActiveStatusSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_FluidActiveStatusSwitch> createState() => _FluidActiveStatusSwitchState();
}

class _FluidActiveStatusSwitchState extends State<_FluidActiveStatusSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: widget.value ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(covariant _FluidActiveStatusSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          final progress = Curves.fastOutSlowIn.transform(_animCtrl.value);
          final activeColor = Color.lerp(const Color(0xFFF43F5E), const Color(0xFF10B981), progress)!;
          final bgFillColor = Color.lerp(const Color(0xFFFEF2F2), const Color(0xFFECFDF5), progress)!;
          final textColor = Color.lerp(const Color(0xFFBE185D), const Color(0xFF047857), progress)!;

          return Container(
            height: 34,
            width: 124,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: bgFillColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: activeColor, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FluidWaveBgPainter(
                        progress: progress,
                        activeColor: activeColor,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: widget.value ? 8 : 28,
                          right: widget.value ? 28 : 8,
                        ),
                        child: Text(
                          widget.value ? 'YES (ACTIVE)' : 'NO (INACTIVE)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentTween(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).transform(progress),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.value
                              ? [const Color(0xFF34D399), const Color(0xFF059669)]
                              : [const Color(0xFFFB7185), const Color(0xFFE11D48)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.value ? Icons.check_rounded : Icons.close_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FluidWaveBgPainter extends CustomPainter {
  final double progress;
  final Color activeColor;

  const _FluidWaveBgPainter({
    required this.progress,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fillW = w * progress;
    if (fillW > 0) {
      final fluidPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;

      final wavePath = Path()
        ..moveTo(0, 0)
        ..lineTo(fillW, 0)
        ..cubicTo(fillW + 6, h * 0.3, fillW - 4, h * 0.7, fillW, h)
        ..lineTo(0, h)
        ..close();

      canvas.drawPath(wavePath, fluidPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FluidWaveBgPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.activeColor != activeColor;
}

// ============================================================================
// ANIMATED ACCOUNT LOOKUP ROW WITH 3D ELEVATION HOVER EFFECT
// ============================================================================
class _AnimatedAccountLookupRow extends StatefulWidget {
  final PartyAccountLookupItem item;
  final bool isSelected;
  final int index;
  final double tableWidth;
  final VoidCallback onTap;

  const _AnimatedAccountLookupRow({
    required this.item,
    required this.isSelected,
    required this.index,
    required this.tableWidth,
    required this.onTap,
  });

  @override
  State<_AnimatedAccountLookupRow> createState() => _AnimatedAccountLookupRowState();
}

class _AnimatedAccountLookupRowState extends State<_AnimatedAccountLookupRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final tableWidth = widget.tableWidth;
    final activeHighlight = isSelected || _isHovered;

    final hasMobile = item.mobileNo.trim().isNotEmpty && item.mobileNo.trim() != '-';
    final hasGstin = item.gstin.trim().isNotEmpty && item.gstin.trim() != '-';
    final hasState = item.stateCode.trim().isNotEmpty && item.stateCode.trim() != '-';
    final hasAddress = item.address.trim().isNotEmpty && item.address.trim() != '-';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.004 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: activeHighlight
                  ? const Color(0xFFF0FDF4)
                  : (widget.index % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC)),
              border: Border(
                left: BorderSide(
                  color: activeHighlight ? const Color(0xFF10B981) : Colors.transparent,
                  width: 4.0,
                ),
                bottom: BorderSide(
                  color: _isHovered ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Account Name
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 230),
                  child: SizedBox(
                    width: (tableWidth - 100) * 0.23,
                    child: Text(
                      item.account,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: activeHighlight ? FontWeight.bold : FontWeight.w600,
                        color: activeHighlight ? const Color(0xFF047857) : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Mobile No
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 130),
                  child: SizedBox(
                    width: (tableWidth - 100) * 0.13,
                    child: Text(
                      hasMobile ? item.mobileNo : '-',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: hasMobile ? FontWeight.w600 : FontWeight.w400,
                        color: hasMobile
                            ? (activeHighlight ? const Color(0xFF047857) : const Color(0xFF334155))
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),

                // GSTIN Badge
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 170),
                  child: SizedBox(
                    width: (tableWidth - 100) * 0.17,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: hasGstin
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: hasGstin
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          hasGstin ? item.gstin : 'UNREGISTERED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasGstin ? const Color(0xFF047857) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // State Badge
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 110),
                  child: SizedBox(
                    width: (tableWidth - 100) * 0.11,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: hasState
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: hasState
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          hasState ? item.stateCode : '-',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasState ? const Color(0xFFB45309) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Address
                Expanded(
                  child: Text(
                    hasAddress ? item.address : 'No address recorded',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: !hasAddress ? FontStyle.italic : FontStyle.normal,
                      color: hasAddress ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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

// ============================================================================
// ANIMATED EXPORT BUTTON WITH LIGHT EDGE ORBIT ANIMATION (100% Matching Project Master)
// ============================================================================
class _AnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedExportButton({required this.onPressed});

  @override
  State<_AnimatedExportButton> createState() => _AnimatedExportButtonState();
}

class _AnimatedExportButtonState extends State<_AnimatedExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrl.reset();
        if (mounted) {
          setState(() => _isAnimating = false);
        }
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerClickOrbit() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _triggerClickOrbit,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = _ctrl.value;

            return CustomPaint(
              painter: _OrbitButtonBorderPainter(
                progress: progress,
                isHovered: _isHovered,
                isAnimating: _isAnimating,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isAnimating ? AppColors.secondaryColor : AppColors.divider,
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? AppColors.secondaryColor.withValues(alpha: 0.3)
                          : AppColors.secondaryColor.withValues(alpha: _isHovered ? 0.18 : 0.05),
                      blurRadius: _isAnimating || _isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 16,
                      color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN & FASHIONED CIRCULAR GAUGE KPI CARD WIDGET (BLUE & PINK)
// ============================================================================
class _HeaderKpiCard extends StatefulWidget {
  final String label;
  final String value;
  final double progress;
  final List<Color> gradientColors;
  final Color? trackColor;

  const _HeaderKpiCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.gradientColors,
    this.trackColor,
  });

  @override
  State<_HeaderKpiCard> createState() => _HeaderKpiCardState();
}

class _HeaderKpiCardState extends State<_HeaderKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.gradientColors.first;
    final effectiveTrackColor =
        widget.trackColor ?? primaryColor.withValues(alpha: 0.12);

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
                // Frosted translucent white glassmorphic surface
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
                  // Circular Arc Gauge with Neon Ambient Glow
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
                  // Modern Label with Glowing Indicator Dot
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

    // Start angle at 135 degrees and sweep 270 degrees clockwise
    const startAngle = 135.0 * (math.pi / 180.0);
    const totalSweepAngle = 270.0 * (math.pi / 180.0);

    // Track paint with sleek rounded cap
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

    // Active arc paint with gradient & subtle neon glow
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0.0) {
      final activeSweep = totalSweepAngle * clampedProgress;
      final primaryColor = gradientColors.first;

      // 1. Soft Ambient Neon Glow Behind Arc
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

      // 2. Crisp Gradient Active Arc
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
