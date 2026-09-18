import 'dart:async';
import '../utils/file_export_helper.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/sub_department_service.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

class SubDepartmentMasterPage extends StatefulWidget {
  const SubDepartmentMasterPage({super.key});

  @override
  State<SubDepartmentMasterPage> createState() => _SubDepartmentMasterPageState();
}

class _SubDepartmentMasterPageState extends State<SubDepartmentMasterPage> {
  List<SubDepartmentMasterItem> _subDepartments = [];
  List<SubDepartmentMasterItem> _filteredSubDepartments = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Form & Selection State
  bool _isEditing = false;
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;

  int _formCode = 1;
  int? _selectedRowCode;

  // Glow Entry Highlight State & Timer
  int? _recentlySavedCode;
  bool _isRecentlyUpdated = false;
  Timer? _glowTimer;

  // Table Scroll Controller
  final ScrollController _tableScrollCtrl = ScrollController();

  // Controllers & FocusNodes (Persistent lifecycle - NEVER re-created inside build())
  late TextEditingController _nameCtrl;
  late TextEditingController _searchCtrl;
  late FocusNode _nameFocusNode;
  late FocusNode _searchFocusNode;
  late FocusNode _pageKeyFocusNode;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _searchCtrl = TextEditingController();
    _nameFocusNode = FocusNode();
    _searchFocusNode = FocusNode();
    _pageKeyFocusNode = FocusNode();

    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _glowTimer?.cancel();
    _tableScrollCtrl.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    _nameFocusNode.dispose();
    _searchFocusNode.dispose();
    _pageKeyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await SubDepartmentService.fetchAllSubDepartments(forceRefresh: true);
      final nextCode = await SubDepartmentService.fetchNextCode();
      if (mounted) {
        setState(() {
          _subDepartments = items;
          _applySearchFilter(_searchCtrl.text);
          _formCode = nextCode;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load sub-departments from SQL database: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final items = await SubDepartmentService.fetchAllSubDepartments(forceRefresh: true);
      final nextCode = await SubDepartmentService.fetchNextCode();
      if (mounted) {
        setState(() {
          _subDepartments = items;
          _applySearchFilter(_searchCtrl.text);
          if (!_isEditing) {
            _formCode = nextCode;
          }
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _applySearchFilter(query);
        });
      }
    });
  }

  void _applySearchFilter(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      _filteredSubDepartments = List.from(_subDepartments);
    } else {
      _filteredSubDepartments = _subDepartments.where((item) {
        final codeStr = item.sdmCode.toString();
        final nameStr = item.sdmName.toLowerCase();
        return codeStr.contains(clean) || nameStr.contains(clean);
      }).toList();
    }
  }

  // Keyboard Event Listener
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;

      // Ctrl + N -> Reset Form for New Record
      if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyN) {
        _resetFormForNew();
      }
      // Ctrl + S or F1 -> Save Record
      else if ((isCtrl && event.logicalKey == LogicalKeyboardKey.keyS) ||
          event.logicalKey == LogicalKeyboardKey.f1) {
        if (!_isSubmitting) {
          _submitForm();
        }
      }
      // Ctrl + K -> Focus Search Bar
      else if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyK) {
        _searchFocusNode.requestFocus();
      }
      // Esc -> Cancel / Reset Focus
      else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _resetFormForNew();
      }
    }
  }

  Future<void> _resetFormForNew() async {
    final nextCode = await SubDepartmentService.fetchNextCode();
    if (mounted) {
      setState(() {
        _isEditing = false;
        _selectedRowCode = null;
        _formCode = nextCode;
        _nameCtrl.clear();
        _isSaveSuccess = false;
        _isSubmitting = false;
      });
      _nameFocusNode.requestFocus();
    }
  }

  void _selectRowForEdit(SubDepartmentMasterItem item) {
    setState(() {
      _isEditing = true;
      _selectedRowCode = item.sdmCode;
      _formCode = item.sdmCode;
      _nameCtrl.text = item.sdmName;
      _isSaveSuccess = false;
      _isSubmitting = false;
    });
    _nameFocusNode.requestFocus();
  }

  // Form Submit Handler (Inline Button Status Strategy - NO Bottom SnackBar Toasts)
  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _nameFocusNode.requestFocus();
      return;
    }

    // Check duplicate name
    final existing = _subDepartments.firstWhere(
      (element) => element.sdmCode != _formCode && element.sdmName.trim().toUpperCase() == name.toUpperCase(),
      orElse: () => const SubDepartmentMasterItem(sdmCode: -1, sdmName: ''),
    );
    if (existing.sdmCode != -1) {
      _nameFocusNode.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);

    final item = SubDepartmentMasterItem(sdmCode: _formCode, sdmName: name);
    final wasEditing = _isEditing;
    final savedCode = item.sdmCode;
    bool success = false;

    if (_isEditing) {
      success = await SubDepartmentService.updateSubDepartment(item);
    } else {
      success = await SubDepartmentService.saveSubDepartment(item);
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSaveSuccess = success;
      });

      if (success) {
        Future.delayed(const Duration(milliseconds: 650), () async {
          if (mounted) {
            setState(() {
              _isSaveSuccess = false;
            });
            await _resetFormForNew();
            await _refreshDataSilently();
            _triggerGlowingHighlight(savedCode, wasEditing);
          }
        });
      }
    }
  }

  void _triggerGlowingHighlight(int code, bool isEdit) {
    _glowTimer?.cancel();
    setState(() {
      _recentlySavedCode = code;
      _isRecentlyUpdated = isEdit;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final index = _filteredSubDepartments.indexWhere((item) => item.sdmCode == code);
      if (index != -1 && _tableScrollCtrl.hasClients) {
        final targetOffset = (index * 42.0) - 100.0;
        _tableScrollCtrl.animateTo(
          targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });

    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _recentlySavedCode = null;
        });
      }
    });
  }

  // Delete Action Handler
  Future<void> _deleteSubDepartment(SubDepartmentMasterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        itemCode: item.sdmCode,
        itemName: item.sdmName,
        onDelete: () async {
          return await SubDepartmentService.deleteSubDepartment(item.sdmCode);
        },
      ),
    );

    if (confirmed == true) {
      if (_selectedRowCode == item.sdmCode) {
        _resetFormForNew();
      }
      await _refreshDataSilently();
    }
  }

  // Export Modal Trigger
  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _SubDepartmentExportModalDialog(subDepartments: _subDepartments),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageKeyFocusNode, // Persistent FocusNode fixes search bar de-selection!
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // 1. SCREEN HEADER TOOLBAR
                    _buildScreenHeader(),
                    const SizedBox(height: 14),

                    // 2. DOUBLE-SCREEN SPLIT LAYOUT (LEFT ENTRY PANE + RIGHT DATA TABLE PANE)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT PANE: HIGH-DENSITY ENTRY FORM (360px Width)
                          SizedBox(
                            width: 360,
                            child: _buildLeftEntryPane(),
                          ),
                          const SizedBox(width: 14),

                          // RIGHT PANE: INTERACTIVE MASTER DATA GRID
                          Expanded(
                            child: RepaintBoundary(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF0284C7),
                                      ),
                                    )
                                  : _errorMessage != null
                                      ? _buildErrorState()
                                      : _buildMainDataGridDesk(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SCREEN HEADER TOOLBAR (WITH 3D LOGO & QUICK ACTIONS)
  // --------------------------------------------------------------------------
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/sub_department_master_logo.png',
            width: 48,
            height: 48,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sub-Department Master',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.black, // Plain black text per user request!
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${_subDepartments.length} total sub-departments registered',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search Bar Input (Connected to _searchFocusNode)
          SizedBox(
            width: 280,
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocusNode, // Persistent focus node fixes search bar de-selection!
              onChanged: _onSearchChanged,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search code or name... (Ctrl+K)',
                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF10B981)),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchCtrl.clear();
                          _applySearchFilter('');
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Standardized Export Pill Button
          StandardizedMasterExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // LEFT PANE: HIGH-DENSITY ENTRY FORM (DOUBLE-SCREEN LAYOUT)
  // --------------------------------------------------------------------------
  Widget _buildLeftEntryPane() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/create_sub_department_logo.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isEditing ? 'Edit Sub-Department' : 'Create Sub-Department',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    TextButton(
                      onPressed: _resetFormForNew,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    ),
                ],
              ),
            ),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Steel-Blue Tag Icon: Sub-Department Code
                    Row(
                      children: const [
                        Icon(Icons.label_important_outline_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 6),
                        Text(
                          'Sub-Department Code',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '# $_formCode',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(Auto Generated)',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2. Amber/Orange Folder Icon: Sub-Department Name
                    Row(
                      children: const [
                        Icon(Icons.folder_rounded, size: 14, color: Color(0xFFD97706)),
                        SizedBox(width: 6),
                        Text(
                          'Sub-Department Name *',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _nameCtrl,
                        focusNode: _nameFocusNode,
                        onSubmitted: (_) => _submitForm(),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Enter sub-department title (e.g. ELECTRICAL)...',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card Action Footer (DIRECT BUTTON ANIMATED NOTIFICATION STRATEGY)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  if (_isEditing) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _resetFormForNew,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: AnimatedSuccessButton(
                      status: _isSaveSuccess
                          ? ButtonStatus.success
                          : (_isSubmitting ? ButtonStatus.loading : ButtonStatus.idle),
                      onPressed: _submitForm,
                      idleText: _isEditing ? 'Update (F1)' : 'Save (F1)',
                      loadingText: 'Saving...',
                      successText: 'Saved!',
                      idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                      idleBackgroundColor: AppColors.secondaryColor,
                      successBackgroundColor: const Color(0xFF10B981),
                      height: 38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // --------------------------------------------------------------------------
  // --------------------------------------------------------------------------
  // RIGHT PANE: DATA GRID DESK (PROFESSIONAL & MODERN TABLE LAYOUT)
  // --------------------------------------------------------------------------
  Widget _buildMainDataGridDesk() {
    final displayList = _filteredSubDepartments;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
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
          // Table Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/sub_department_directory_sheet_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Sub-Department Directory Sheet',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const Spacer(),

                // Record Count Badge Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.0),
                  ),
                  child: Text(
                    '${displayList.length} Records',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0369A1)),
                  ),
                ),
              ],
            ),
          ),

          // Body Content: Pure Table View
          Expanded(
            child: _buildTableDeskBody(displayList),
          ),
        ],
      ),
    );
  }

  Widget _buildTableDeskBody(List<SubDepartmentMasterItem> displayList) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = math.max(constraints.maxWidth, 420.0);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  // Clean, Modern Column Header Bar (Icons on every column, No unnecessary columns)
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
                          width: 85,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tag_rounded, size: 12.5, color: Color(0xFF6366F1)),
                              SizedBox(width: 4),
                              Text('CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.domain_rounded, size: 13, color: Color(0xFF10B981)),
                              SizedBox(width: 6),
                              Text('SUB-DEPARTMENT NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        SizedBox(
                          width: 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded, size: 12.5, color: Color(0xFF64748B)),
                              SizedBox(width: 4),
                              Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5, letterSpacing: 0.5)),
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
                                Icon(Icons.search_off_rounded, size: 36, color: const Color(0xFF64748B).withValues(alpha: 0.3)),
                                const SizedBox(height: 6),
                                Text(
                                  'No sub-department records found matching search criteria',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B).withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _tableScrollCtrl,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: displayList.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                            itemBuilder: (ctx, idx) {
                              final item = displayList[idx];
                              final isSelected = _selectedRowCode == item.sdmCode;
                              final isGlowing = _recentlySavedCode == item.sdmCode;
                              final isGlowingEdit = isGlowing && _isRecentlyUpdated;
                              final isGlowingNew = isGlowing && !_isRecentlyUpdated;

                              return _AnimatedSubDepartmentRow(
                                key: ValueKey<int>(item.sdmCode),
                                item: item,
                                isSelected: isSelected,
                                isGlowing: isGlowing,
                                isGlowingEdit: isGlowingEdit,
                                isGlowingNew: isGlowingNew,
                                onTap: () => _selectRowForEdit(item),
                                onDoubleTap: () => _selectRowForEdit(item),
                                onEdit: () => _selectRowForEdit(item),
                                onDelete: () => _deleteSubDepartment(item),
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
    );
  }


  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// STANDARDIZED MASTER EXPORT BUTTON (WITH 1-LAP ORBIT ROTATION BEAM)
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
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
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
                      size: 15,
                      color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12,
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
// SUB-DEPARTMENT DOMAIN CATEGORY & ICON RESOLVER
// ============================================================================
class _SubDeptCategoryInfo {
  final IconData icon;
  final String categoryTitle;
  final String darkBadgeTag;

  const _SubDeptCategoryInfo({
    required this.icon,
    required this.categoryTitle,
    required this.darkBadgeTag,
  });
}

_SubDeptCategoryInfo _resolveSubDeptCategory(String name) {
  final clean = name.trim().toUpperCase();

  if (clean.contains('ELECTR')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.bolt_rounded,
      categoryTitle: 'Power, Wiring & Electrical',
      darkBadgeTag: 'ELEC UNIT',
    );
  } else if (clean.contains('MACH') || clean.contains('MECH')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.settings_suggest_rounded,
      categoryTitle: 'Machinery & Equipment',
      darkBadgeTag: 'MECH UNIT',
    );
  } else if (clean.contains('PACK')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.inventory_2_rounded,
      categoryTitle: 'Packaging & Dispatch',
      darkBadgeTag: 'PACK UNIT',
    );
  } else if (clean.contains('DYE') || clean.contains('COLOR')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.palette_rounded,
      categoryTitle: 'Coloring & Dye Processing',
      darkBadgeTag: 'DYE UNIT',
    );
  } else if (clean.contains('MATER') || clean.contains('STORE') || clean.contains('RAW')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.layers_rounded,
      categoryTitle: 'Raw Material & Storage',
      darkBadgeTag: 'MAT UNIT',
    );
  } else if (clean.contains('QUAL') || clean.contains('QC') || clean.contains('TEST')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.verified_rounded,
      categoryTitle: 'Quality Control & Audit',
      darkBadgeTag: 'QC UNIT',
    );
  } else if (clean.contains('MAINT')) {
    return const _SubDeptCategoryInfo(
      icon: Icons.handyman_rounded,
      categoryTitle: 'Plant Maintenance & Repairs',
      darkBadgeTag: 'MAINT UNIT',
    );
  } else {
    final firstWord = clean.split(' ').first;
    return _SubDeptCategoryInfo(
      icon: Icons.account_tree_rounded,
      categoryTitle: 'Sub-Department Unit',
      darkBadgeTag: '$firstWord UNIT',
    );
  }
}

// ============================================================================
// CARD GRID THEME PALETTE & 3D ISOMETRIC EMBLEM WIDGET
// ============================================================================
class _CardTheme {
  final Color primary;
  final Color titleColor;
  final Color darkPillBg;
  final Color subPillBg;
  final Color subPillBorder;
  final Color subPillText;
  final Color iconColor;
  final Color cubeTop;
  final Color cubeLeft;
  final Color cubeRight;
  final Color dotColor;

  const _CardTheme({
    required this.primary,
    required this.titleColor,
    required this.darkPillBg,
    required this.subPillBg,
    required this.subPillBorder,
    required this.subPillText,
    required this.iconColor,
    required this.cubeTop,
    required this.cubeLeft,
    required this.cubeRight,
    required this.dotColor,
  });
}

const List<_CardTheme> _subDeptCardThemes = [
  // 0: Emerald Green (Surat Theme)
  _CardTheme(
    primary: Color(0xFF059669),
    titleColor: Color(0xFF047857),
    darkPillBg: Color(0xFF0F172A),
    subPillBg: Color(0xFFECFDF5),
    subPillBorder: Color(0xFFA7F3D0),
    subPillText: Color(0xFF047857),
    iconColor: Color(0xFFF43F5E),
    cubeTop: Color(0xFF10B981),
    cubeLeft: Color(0xFF047857),
    cubeRight: Color(0xFF059669),
    dotColor: Color(0xFFEF4444),
  ),
  // 1: Royal Purple (Aarya Theme)
  _CardTheme(
    primary: Color(0xFF7C3AED),
    titleColor: Color(0xFF6D28D9),
    darkPillBg: Color(0xFF1E1B4B),
    subPillBg: Color(0xFFF5F3FF),
    subPillBorder: Color(0xFFDDD6FE),
    subPillText: Color(0xFF6D28D9),
    iconColor: Color(0xFF0284C7),
    cubeTop: Color(0xFF8B5CF6),
    cubeLeft: Color(0xFF5B21B6),
    cubeRight: Color(0xFF7C3AED),
    dotColor: Color(0xFF06B6D4),
  ),
  // 2: Warm Amber (Cotton Hub Theme)
  _CardTheme(
    primary: Color(0xFFD97706),
    titleColor: Color(0xFFB45309),
    darkPillBg: Color(0xFF1F2937),
    subPillBg: Color(0xFFFEF3C7),
    subPillBorder: Color(0xFFFDE68A),
    subPillText: Color(0xFFB45309),
    iconColor: Color(0xFFEA580C),
    cubeTop: Color(0xFFF59E0B),
    cubeLeft: Color(0xFF92400E),
    cubeRight: Color(0xFFD97706),
    dotColor: Color(0xFF10B981),
  ),
  // 3: Ocean Cyan Theme
  _CardTheme(
    primary: Color(0xFF0284C7),
    titleColor: Color(0xFF0369A1),
    darkPillBg: Color(0xFF0F172A),
    subPillBg: Color(0xFFE0F2FE),
    subPillBorder: Color(0xFFBAE6FD),
    subPillText: Color(0xFF0369A1),
    iconColor: Color(0xFF0284C7),
    cubeTop: Color(0xFF38BDF8),
    cubeLeft: Color(0xFF075985),
    cubeRight: Color(0xFF0284C7),
    dotColor: Color(0xFFF43F5E),
  ),
  // 4: Crimson Rose Theme
  _CardTheme(
    primary: Color(0xFFE11D48),
    titleColor: Color(0xFFBE123C),
    darkPillBg: Color(0xFF1E293B),
    subPillBg: Color(0xFFFFE4E6),
    subPillBorder: Color(0xFFFECDD3),
    subPillText: Color(0xFFBE123C),
    iconColor: Color(0xFFE11D48),
    cubeTop: Color(0xFFFB7185),
    cubeLeft: Color(0xFF9F1239),
    cubeRight: Color(0xFFE11D48),
    dotColor: Color(0xFFF59E0B),
  ),
  // 5: Deep Indigo Theme
  _CardTheme(
    primary: Color(0xFF4F46E5),
    titleColor: Color(0xFF4338CA),
    darkPillBg: Color(0xFF0F172A),
    subPillBg: Color(0xFFEEF2FF),
    subPillBorder: Color(0xFFC7D2FE),
    subPillText: Color(0xFF4338CA),
    iconColor: Color(0xFF4F46E5),
    cubeTop: Color(0xFF818CF8),
    cubeLeft: Color(0xFF3730A3),
    cubeRight: Color(0xFF4F46E5),
    dotColor: Color(0xFF10B981),
  ),
];

/// Dynamic 3D Emblem Logo Widget - Renders a DIFFERENT 3D Logo Shape for EVERY Entry!
class _DynamicEntryLogoWidget extends StatelessWidget {
  final int index;
  final int itemCode;
  final double size;
  final _CardTheme theme;

  const _DynamicEntryLogoWidget({
    required this.index,
    required this.itemCode,
    this.size = 28.0,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Unique 3D Logo shape for EVERY entry (combining grid index & itemCode)
    final logoIndex = (index * 7 + itemCode.abs() * 3) % 12;

    CustomPainter painter;
    switch (logoIndex) {
      case 0:
        painter = _IsometricCubePainter(
          topColor: theme.cubeTop,
          leftColor: theme.cubeLeft,
          rightColor: theme.cubeRight,
          dotColor: theme.dotColor,
        );
        break;
      case 1:
        painter = _DiamondGemPainter(
          primaryColor: theme.primary,
          lightColor: theme.cubeTop,
          darkColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 2:
        painter = _StackedLayersPainter(
          topColor: theme.cubeTop,
          midColor: theme.primary,
          baseColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 3:
        painter = _CylinderPainter(
          topColor: theme.cubeTop,
          frontColor: theme.primary,
          shadowColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 4:
        painter = _HexPrismPainter(
          topColor: theme.cubeTop,
          leftColor: theme.cubeLeft,
          rightColor: theme.cubeRight,
          dotColor: theme.dotColor,
        );
        break;
      case 5:
        painter = _SphereOrbPainter(
          orbColor: theme.primary,
          lightColor: theme.cubeTop,
          ringColor: theme.cubeRight,
          dotColor: theme.dotColor,
        );
        break;
      case 6:
        painter = _PyramidTetraPainter(
          topColor: theme.cubeTop,
          leftColor: theme.cubeLeft,
          rightColor: theme.cubeRight,
          dotColor: theme.dotColor,
        );
        break;
      case 7:
        painter = _RibbonLoopPainter(
          primaryColor: theme.primary,
          accentColor: theme.cubeTop,
          dotColor: theme.dotColor,
        );
        break;
      case 8:
        painter = _OctahedronGemPainter(
          topColor: theme.cubeTop,
          midColor: theme.primary,
          darkColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 9:
        painter = _ShieldCrestPainter(
          mainColor: theme.primary,
          lightColor: theme.cubeTop,
          darkColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 10:
        painter = _DoubleColumnPainter(
          col1Color: theme.primary,
          col2Color: theme.cubeTop,
          shadowColor: theme.cubeLeft,
          dotColor: theme.dotColor,
        );
        break;
      case 11:
      default:
        painter = _StarburstPolygonPainter(
          starColor: theme.primary,
          lightColor: theme.cubeTop,
          darkColor: theme.cubeRight,
          dotColor: theme.dotColor,
        );
        break;
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: painter,
      ),
    );
  }
}

// ----------------------------------------------------------------------------
// 1. 3D ISOMETRIC CUBE PAINTER
// ----------------------------------------------------------------------------
class _IsometricCubePainter extends CustomPainter {
  final Color topColor;
  final Color leftColor;
  final Color rightColor;
  final Color dotColor;

  const _IsometricCubePainter({
    required this.topColor,
    required this.leftColor,
    required this.rightColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final center = Offset(w * 0.5, h * 0.46);
    final topPoint = Offset(w * 0.5, h * 0.06);
    final leftPoint = Offset(w * 0.08, h * 0.28);
    final rightPoint = Offset(w * 0.92, h * 0.28);
    final bottomLeft = Offset(w * 0.08, h * 0.72);
    final bottomRight = Offset(w * 0.92, h * 0.72);
    final bottomCenter = Offset(w * 0.5, h * 0.94);

    // Top Face
    final topPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(rightPoint.dx, rightPoint.dy)
      ..lineTo(topPoint.dx, topPoint.dy)
      ..lineTo(leftPoint.dx, leftPoint.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topColor);

    // Left Face
    final leftPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftPoint.dx, leftPoint.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = leftColor);

    // Right Face
    final rightPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(rightPoint.dx, rightPoint.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = rightColor);

    // Dot Emblem
    canvas.drawCircle(Offset(w * 0.65, h * 0.38), w * 0.11, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _IsometricCubePainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 2. 3D FACETED DIAMOND GEM PAINTER
// ----------------------------------------------------------------------------
class _DiamondGemPainter extends CustomPainter {
  final Color primaryColor;
  final Color lightColor;
  final Color darkColor;
  final Color dotColor;

  const _DiamondGemPainter({
    required this.primaryColor,
    required this.lightColor,
    required this.darkColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topCenter = Offset(w * 0.5, h * 0.06);
    final topLeft = Offset(w * 0.22, h * 0.32);
    final topRight = Offset(w * 0.78, h * 0.32);
    final centerTable = Offset(w * 0.5, h * 0.42);
    final farLeft = Offset(w * 0.06, h * 0.38);
    final farRight = Offset(w * 0.94, h * 0.38);
    final bottomPoint = Offset(w * 0.5, h * 0.94);

    // Crown Top Facet
    final topFacet = Path()
      ..moveTo(topCenter.dx, topCenter.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(centerTable.dx, centerTable.dy)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..close();
    canvas.drawPath(topFacet, Paint()..color = lightColor);

    // Crown Left Facet
    final leftCrown = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(centerTable.dx, centerTable.dy)
      ..lineTo(farLeft.dx, farLeft.dy)
      ..lineTo(topCenter.dx, topCenter.dy)
      ..close();
    canvas.drawPath(leftCrown, Paint()..color = primaryColor);

    // Crown Right Facet
    final rightCrown = Path()
      ..moveTo(topRight.dx, topRight.dy)
      ..lineTo(farRight.dx, farRight.dy)
      ..lineTo(centerTable.dx, centerTable.dy)
      ..close();
    canvas.drawPath(rightCrown, Paint()..color = darkColor);

    // Pavilion Left Base V-Facet
    final leftPavilion = Path()
      ..moveTo(farLeft.dx, farLeft.dy)
      ..lineTo(centerTable.dx, centerTable.dy)
      ..lineTo(bottomPoint.dx, bottomPoint.dy)
      ..close();
    canvas.drawPath(leftPavilion, Paint()..color = darkColor.withValues(alpha: 0.85));

    // Pavilion Right Base V-Facet
    final rightPavilion = Path()
      ..moveTo(centerTable.dx, centerTable.dy)
      ..lineTo(farRight.dx, farRight.dy)
      ..lineTo(bottomPoint.dx, bottomPoint.dy)
      ..close();
    canvas.drawPath(rightPavilion, Paint()..color = primaryColor);

    // Sparkle Dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.10, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _DiamondGemPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 3. 3D STACKED LAYERS PAINTER
// ----------------------------------------------------------------------------
class _StackedLayersPainter extends CustomPainter {
  final Color topColor;
  final Color midColor;
  final Color baseColor;
  final Color dotColor;

  const _StackedLayersPainter({
    required this.topColor,
    required this.midColor,
    required this.baseColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Base Layer (Bottom)
    final pBase = Path()
      ..moveTo(w * 0.5, h * 0.62)
      ..lineTo(w * 0.9, h * 0.74)
      ..lineTo(w * 0.5, h * 0.94)
      ..lineTo(w * 0.1, h * 0.74)
      ..close();
    canvas.drawPath(pBase, Paint()..color = baseColor);

    // Middle Layer
    final pMid = Path()
      ..moveTo(w * 0.5, h * 0.36)
      ..lineTo(w * 0.9, h * 0.48)
      ..lineTo(w * 0.5, h * 0.68)
      ..lineTo(w * 0.1, h * 0.48)
      ..close();
    canvas.drawPath(pMid, Paint()..color = midColor);

    // Top Layer
    final pTop = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.9, h * 0.22)
      ..lineTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.1, h * 0.22)
      ..close();
    canvas.drawPath(pTop, Paint()..color = topColor);

    // Accent Dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.25), w * 0.09, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _StackedLayersPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 4. 3D CYLINDER PAINTER
// ----------------------------------------------------------------------------
class _CylinderPainter extends CustomPainter {
  final Color topColor;
  final Color frontColor;
  final Color shadowColor;
  final Color dotColor;

  const _CylinderPainter({
    required this.topColor,
    required this.frontColor,
    required this.shadowColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topEllipseRect = Rect.fromLTWH(w * 0.1, h * 0.06, w * 0.8, h * 0.30);
    final bottomEllipseRect = Rect.fromLTWH(w * 0.1, h * 0.64, w * 0.8, h * 0.30);

    // Curved Body
    final bodyPath = Path()
      ..moveTo(w * 0.1, h * 0.21)
      ..lineTo(w * 0.1, h * 0.79)
      ..arcTo(bottomEllipseRect, 3.14159, -3.14159, false)
      ..lineTo(w * 0.9, h * 0.21)
      ..arcTo(topEllipseRect, 0, 3.14159, false)
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [shadowColor, frontColor, topColor],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(bodyPath, bodyPaint);

    // Top Cap
    final topCapPath = Path()..addOval(topEllipseRect);
    canvas.drawPath(topCapPath, Paint()..color = topColor);

    // Accent Ring Dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.21), w * 0.10, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _CylinderPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 5. 3D HEXAGONAL PRISM PAINTER
// ----------------------------------------------------------------------------
class _HexPrismPainter extends CustomPainter {
  final Color topColor;
  final Color leftColor;
  final Color rightColor;
  final Color dotColor;

  const _HexPrismPainter({
    required this.topColor,
    required this.leftColor,
    required this.rightColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top Hexagon Cap
    final topHex = Path()
      ..moveTo(w * 0.5, h * 0.06)
      ..lineTo(w * 0.88, h * 0.22)
      ..lineTo(w * 0.88, h * 0.38)
      ..lineTo(w * 0.5, h * 0.52)
      ..lineTo(w * 0.12, h * 0.38)
      ..lineTo(w * 0.12, h * 0.22)
      ..close();
    canvas.drawPath(topHex, Paint()..color = topColor);

    // Left Front Face
    final leftFace = Path()
      ..moveTo(w * 0.5, h * 0.52)
      ..lineTo(w * 0.12, h * 0.38)
      ..lineTo(w * 0.12, h * 0.78)
      ..lineTo(w * 0.5, h * 0.94)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = leftColor);

    // Right Front Face
    final rightFace = Path()
      ..moveTo(w * 0.5, h * 0.52)
      ..lineTo(w * 0.88, h * 0.38)
      ..lineTo(w * 0.88, h * 0.78)
      ..lineTo(w * 0.5, h * 0.94)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = rightColor);

    // Accent Center Dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.30), w * 0.11, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _HexPrismPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 6. 3D SPHERE ORB PAINTER WITH ORBITAL RING
// ----------------------------------------------------------------------------
class _SphereOrbPainter extends CustomPainter {
  final Color orbColor;
  final Color lightColor;
  final Color ringColor;
  final Color dotColor;

  const _SphereOrbPainter({
    required this.orbColor,
    required this.lightColor,
    required this.ringColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    // Base Sphere with 3D Radial Glow
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 0.85,
        colors: [lightColor, orbColor, orbColor.withValues(alpha: 0.75)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawCircle(center, w * 0.38, spherePaint);

    // Tilted Orbital Ring
    final ringRect = Rect.fromLTWH(w * 0.04, h * 0.30, w * 0.92, h * 0.40);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = ringColor;

    canvas.drawOval(ringRect, ringPaint);

    // Orbital Node Dot
    canvas.drawCircle(Offset(w * 0.82, h * 0.42), w * 0.09, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _SphereOrbPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 7. 3D PYRAMID TETRA PAINTER
// ----------------------------------------------------------------------------
class _PyramidTetraPainter extends CustomPainter {
  final Color topColor;
  final Color leftColor;
  final Color rightColor;
  final Color dotColor;

  const _PyramidTetraPainter({
    required this.topColor,
    required this.leftColor,
    required this.rightColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final apex = Offset(w * 0.5, h * 0.05);
    final leftCorner = Offset(w * 0.08, h * 0.78);
    final rightCorner = Offset(w * 0.92, h * 0.78);
    final bottomCenter = Offset(w * 0.5, h * 0.95);

    // Front Left Face
    final leftFace = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(leftCorner.dx, leftCorner.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(leftFace, Paint()..color = leftColor);

    // Front Right Face
    final rightFace = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(rightCorner.dx, rightCorner.dy)
      ..lineTo(bottomCenter.dx, bottomCenter.dy)
      ..close();
    canvas.drawPath(rightFace, Paint()..color = rightColor);

    // Apex Cap Highlight
    final capPath = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(w * 0.35, h * 0.30)
      ..lineTo(w * 0.65, h * 0.30)
      ..close();
    canvas.drawPath(capPath, Paint()..color = topColor);

    // Glowing Apex Dot
    canvas.drawCircle(Offset(w * 0.5, h * 0.18), w * 0.10, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _PyramidTetraPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 8. 3D RIBBON LOOP PAINTER
// ----------------------------------------------------------------------------
class _RibbonLoopPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final Color dotColor;

  const _RibbonLoopPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final outerPath = Path()
      ..moveTo(w * 0.2, h * 0.2)
      ..cubicTo(w * 0.8, h * 0.1, w * 0.9, h * 0.8, w * 0.5, h * 0.9)
      ..cubicTo(w * 0.1, h * 0.9, w * 0.2, h * 0.3, w * 0.8, h * 0.2);

    final paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [primaryColor, accentColor, primaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(outerPath, paint1);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.11, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _RibbonLoopPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 9. 3D OCTAHEDRON GEM PAINTER
// ----------------------------------------------------------------------------
class _OctahedronGemPainter extends CustomPainter {
  final Color topColor;
  final Color midColor;
  final Color darkColor;
  final Color dotColor;

  const _OctahedronGemPainter({
    required this.topColor,
    required this.midColor,
    required this.darkColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final topPoint = Offset(w * 0.5, h * 0.05);
    final midLeft = Offset(w * 0.08, h * 0.50);
    final midRight = Offset(w * 0.92, h * 0.50);
    final bottomPoint = Offset(w * 0.5, h * 0.95);
    final centerPoint = Offset(w * 0.5, h * 0.50);

    // Top Left Facet
    final tl = Path()
      ..moveTo(topPoint.dx, topPoint.dy)
      ..lineTo(midLeft.dx, midLeft.dy)
      ..lineTo(centerPoint.dx, centerPoint.dy)
      ..close();
    canvas.drawPath(tl, Paint()..color = topColor);

    // Top Right Facet
    final tr = Path()
      ..moveTo(topPoint.dx, topPoint.dy)
      ..lineTo(midRight.dx, midRight.dy)
      ..lineTo(centerPoint.dx, centerPoint.dy)
      ..close();
    canvas.drawPath(tr, Paint()..color = midColor);

    // Bottom Left Facet
    final bl = Path()
      ..moveTo(bottomPoint.dx, bottomPoint.dy)
      ..lineTo(midLeft.dx, midLeft.dy)
      ..lineTo(centerPoint.dx, centerPoint.dy)
      ..close();
    canvas.drawPath(bl, Paint()..color = darkColor);

    // Bottom Right Facet
    final br = Path()
      ..moveTo(bottomPoint.dx, bottomPoint.dy)
      ..lineTo(midRight.dx, midRight.dy)
      ..lineTo(centerPoint.dx, centerPoint.dy)
      ..close();
    canvas.drawPath(br, Paint()..color = topColor.withValues(alpha: 0.8));

    // Center Sparkle
    canvas.drawCircle(centerPoint, w * 0.10, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _OctahedronGemPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 10. 3D SHIELD CREST PAINTER
// ----------------------------------------------------------------------------
class _ShieldCrestPainter extends CustomPainter {
  final Color mainColor;
  final Color lightColor;
  final Color darkColor;
  final Color dotColor;

  const _ShieldCrestPainter({
    required this.mainColor,
    required this.lightColor,
    required this.darkColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Left Shield Half
    final leftShield = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.1, h * 0.08)
      ..lineTo(w * 0.1, h * 0.55)
      ..cubicTo(w * 0.1, h * 0.80, w * 0.4, h * 0.92, w * 0.5, h * 0.96)
      ..close();
    canvas.drawPath(leftShield, Paint()..color = lightColor);

    // Right Shield Half
    final rightShield = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.9, h * 0.08)
      ..lineTo(w * 0.9, h * 0.55)
      ..cubicTo(w * 0.9, h * 0.80, w * 0.6, h * 0.92, w * 0.5, h * 0.96)
      ..close();
    canvas.drawPath(rightShield, Paint()..color = darkColor);

    // Center Crest Emblem
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.12, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _ShieldCrestPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 11. 3D DOUBLE COLUMN PAINTER
// ----------------------------------------------------------------------------
class _DoubleColumnPainter extends CustomPainter {
  final Color col1Color;
  final Color col2Color;
  final Color shadowColor;
  final Color dotColor;

  const _DoubleColumnPainter({
    required this.col1Color,
    required this.col2Color,
    required this.shadowColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Column 1 (Back Left)
    final r1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.25, w * 0.32, h * 0.65),
      Radius.circular(w * 0.16),
    );
    canvas.drawRRect(r1, Paint()..color = shadowColor);

    // Column 2 (Front Right)
    final r2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.52, h * 0.10, w * 0.36, h * 0.75),
      Radius.circular(w * 0.18),
    );
    canvas.drawRRect(r2, Paint()..color = col2Color);

    // Dot Accent
    canvas.drawCircle(Offset(w * 0.70, h * 0.30), w * 0.09, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _DoubleColumnPainter oldDelegate) => false;
}

// ----------------------------------------------------------------------------
// 12. 3D STARBURST POLYGON PAINTER
// ----------------------------------------------------------------------------
class _StarburstPolygonPainter extends CustomPainter {
  final Color starColor;
  final Color lightColor;
  final Color darkColor;
  final Color dotColor;

  const _StarburstPolygonPainter({
    required this.starColor,
    required this.lightColor,
    required this.darkColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.5);

    final path = Path();
    const points = 8;
    final outerRadius = w * 0.45;
    final innerRadius = w * 0.25;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = (i * math.pi) / points;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = starColor);
    canvas.drawCircle(center, w * 0.12, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(covariant _StarburstPolygonPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL 3D CARD ITEM WIDGET (IMAGE 2 REFERENCE)
// ============================================================================
class _SubDepartmentCardItem extends StatefulWidget {
  final SubDepartmentMasterItem item;
  final int index;
  final bool isSelected;
  final bool isRecentlySaved;
  final bool isRecentlyUpdated;
  final VoidCallback onTapCard;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubDepartmentCardItem({
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isRecentlySaved,
    required this.isRecentlyUpdated,
    required this.onTapCard,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SubDepartmentCardItem> createState() => _SubDepartmentCardItemState();
}

class _SubDepartmentCardItemState extends State<_SubDepartmentCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Unique Theme per Entry!
    final theme = _subDeptCardThemes[widget.item.sdmCode % _subDeptCardThemes.length];
    final categoryInfo = _resolveSubDeptCategory(widget.item.sdmName);

    final isGlow = widget.isRecentlySaved;
    final isUpdateGlow = isGlow && widget.isRecentlyUpdated;
    final isNewGlow = isGlow && !widget.isRecentlyUpdated;

    // Code Badge String (e.g. #01, #02, #03)
    final codeStr = '#${widget.item.sdmCode.toString().padLeft(2, '0')}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTapCard,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNewGlow
                  ? const Color(0xFF10B981)
                  : (isUpdateGlow
                      ? const Color(0xFFF59E0B)
                      : (widget.isSelected
                          ? theme.primary
                          : (_isHovered ? theme.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0)))),
              width: (widget.isSelected || isGlow) ? 2.0 : 1.2,
            ),
            boxShadow: [
              if (isNewGlow) ...[
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: Offset.zero,
                ),
              ] else if (isUpdateGlow) ...[
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                  offset: Offset.zero,
                ),
              ] else if (_isHovered)
                BoxShadow(
                  color: theme.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. TOP ROW: Solid Code Badge + Title + 3D Isometric Logo
                  Row(
                    children: [
                      // Solid Color Code Badge (#01, #02, #03)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          codeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Sub-Department Title
                      Expanded(
                        child: Text(
                          widget.item.sdmName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: theme.titleColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Unique 3D Logo Emblem (Guaranteed different geometry for every single entry!)
                      _DynamicEntryLogoWidget(
                        index: widget.index,
                        itemCode: widget.item.sdmCode,
                        size: 26.0,
                        theme: theme,
                      ),
                    ],
                  ),

                  // 2. MIDDLE ROW: Sub-Department Name Inside Themed Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: theme.subPillBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.subPillBorder, width: 1.0),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            categoryInfo.icon,
                            size: 13,
                            color: theme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.item.sdmName,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: theme.subPillText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. BOTTOM ROW: Action Buttons (Aligned Right)
                  Row(
                    children: [
                      const Spacer(),

                      // Action Buttons: Green Edit Button + Red Delete Button
                      _AnimatedActionButton(
                        icon: Icons.edit_outlined,
                        hoverIcon: Icons.edit_rounded,
                        tooltip: 'Edit Sub-Department',
                        normalColor: theme.primary,
                        hoverBgColor: theme.subPillBg,
                        hoverBorderColor: theme.subPillBorder,
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),

                      _AnimatedActionButton(
                        icon: Icons.delete_outline_rounded,
                        hoverIcon: Icons.delete_rounded,
                        tooltip: 'Delete Sub-Department',
                        normalColor: const Color(0xFFDC2626),
                        hoverBgColor: const Color(0xFFFEF2F2),
                        hoverBorderColor: const Color(0xFFFECACA),
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ],
              ),

              // GLOW STAR BADGE PILL (FOR NEW / UPDATED SAVED ENTRIES)
              if (isNewGlow)
                Positioned(
                  top: -12,
                  right: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'NEW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isUpdateGlow)
                Positioned(
                  top: -12,
                  right: 42,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome_rounded, size: 11, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'UPDATED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
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
// ANIMATED ACTION ICON BUTTON WIDGET FOR EDIT & DELETE
// ============================================================================
class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final IconData hoverIcon;
  final String tooltip;
  final Color normalColor;
  final Color hoverBgColor;
  final Color hoverBorderColor;
  final VoidCallback onPressed;

  const _AnimatedActionButton({
    required this.icon,
    required this.hoverIcon,
    required this.tooltip,
    required this.normalColor,
    required this.hoverBgColor,
    required this.hoverBorderColor,
    required this.onPressed,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered ? widget.hoverBorderColor : Colors.transparent,
                width: 1.0,
              ),
              boxShadow: [
                if (_isHovered)
                  BoxShadow(
                    color: widget.normalColor.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                _isHovered ? widget.hoverIcon : widget.icon,
                size: 16,
                color: widget.normalColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED SUB-DEPARTMENT TABLE ROW (DEPARTMENT MASTER PARITY)
// ============================================================================
class _AnimatedSubDepartmentRow extends StatefulWidget {
  final SubDepartmentMasterItem item;
  final bool isSelected;
  final bool isGlowing;
  final bool isGlowingEdit;
  final bool isGlowingNew;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedSubDepartmentRow({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isGlowing,
    required this.isGlowingEdit,
    required this.isGlowingNew,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedSubDepartmentRow> createState() => _AnimatedSubDepartmentRowState();
}

class _AnimatedSubDepartmentRowState extends State<_AnimatedSubDepartmentRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isGlowing = widget.isGlowing;
    final isGlowingEdit = widget.isGlowingEdit;

    // Glowing Colors Strategy:
    // Update Entry: Yellow/Amber (#F59E0B)
    // New Entry: Emerald Green (#10B981)
    final glowColor = isGlowingEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final codeStr = '#${item.sdmCode.toString().padLeft(2, '0')}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.004 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isGlowing
                  ? glowColor.withValues(alpha: 0.12)
                  : (isSelected
                      ? AppColors.secondaryColor.withValues(alpha: 0.08)
                      : (_isHovered ? const Color(0xFFF0FDF4) : Colors.white)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isGlowing
                    ? glowColor
                    : (isSelected
                        ? AppColors.secondaryColor
                        : (_isHovered ? const Color(0xFF10B981) : const Color(0xFFE2E8F0))),
                width: isGlowing ? 2.0 : (_isHovered || isSelected ? 1.5 : 1.0),
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
                            color: const Color(0xFF10B981).withValues(alpha: 0.16),
                            blurRadius: 8,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]),
            ),
            child: Row(
              children: [
                // 1. Code Badge (# CODE, 85px) + Star Badge if glowing
                SizedBox(
                  width: 85,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isGlowing || isSelected || _isHovered
                              ? (isGlowing ? glowColor : (_isHovered ? const Color(0xFF10B981) : AppColors.secondaryColor))
                              : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: isGlowing || isSelected || _isHovered
                                ? Colors.transparent
                                : const Color(0xFFC7D2FE),
                            width: 1.0,
                          ),
                          boxShadow: isGlowing || isSelected || _isHovered
                              ? [
                                  BoxShadow(
                                    color: (isGlowing ? glowColor : (_isHovered ? const Color(0xFF10B981) : AppColors.secondaryColor)).withValues(alpha: 0.30),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          codeStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: isGlowing || isSelected || _isHovered ? Colors.white : const Color(0xFF4338CA),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (isGlowing) ...[
                        const SizedBox(width: 4),
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
                const SizedBox(width: 12),

                // 2. Sub-Department Name (Expanded, Beautiful enterprise typography)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isGlowing || isSelected || _isHovered
                              ? const Color(0xFF10B981).withValues(alpha: 0.14)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          Icons.business_rounded,
                          size: 13.5,
                          color: isGlowing || isSelected || _isHovered
                              ? const Color(0xFF047857)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.sdmName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.secondaryColor
                                : (_isHovered ? const Color(0xFF0F766E) : const Color(0xFF0F172A)),
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // 3. Action Buttons (ACTIONS, 90px)
                SizedBox(
                  width: 90,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Sub-Department',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 6),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Sub-Department',
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
// INTERACTIVE HOVER ACTION BUTTON WIDGET (MODERN ENTERPRISE STYLE)
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
        duration: const Duration(milliseconds: 140),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.16) : widget.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _isHovered ? widget.color.withValues(alpha: 0.45) : widget.color.withValues(alpha: 0.18),
              width: 1.0,
            ),
          ),
          child: Tooltip(
            message: widget.tooltip,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(7),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 13.5,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROFESSIONAL BRAND PILL BUTTON
// ============================================================================
class _PillBrandButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final IconData icon;
  final String label;

  const _PillBrandButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.icon,
    required this.label,
  });

  @override
  State<_PillBrandButton> createState() => _PillBrandButtonState();
}

class _PillBrandButtonState extends State<_PillBrandButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0.0, _isHovered ? -2.0 : 0.0, 0.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(24.0),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withValues(alpha: _isHovered ? 0.35 : 0.2),
                blurRadius: _isHovered ? 10 : 4,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
    this.idleText = 'Save',
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
// ANIMATED DELETE CONFIRMATION DIALOG
// ============================================================================
// ============================================================================
// CONFIRM DELETE DIALOG (100% STANDARDIZED 3D DELETE UI)
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
          borderRadius: BorderRadius.circular(24),
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

            // 100% IDENTICAL IMAGE 1 VECTOR ILLUSTRATION (Person throwing red files into trash)
            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

            // Red Warning Title matching exact user image
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

            // Action Buttons Row matching Image 1 (Delete on Left, Cancel on Right)
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
// 100% IDENTICAL 3D VECTOR ILLUSTRATION PAINTER FOR DELETE MODAL
// ============================================================================
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. LIGHT WINDOW OUTLINES IN BACKGROUND
    final windowBorder = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Left 4-Pane Window
    final win1 = Rect.fromLTWH(w * 0.32, h * 0.15, w * 0.20, h * 0.28);
    canvas.drawRect(win1, windowBorder);
    canvas.drawLine(Offset(win1.left, win1.top + win1.height * 0.5), Offset(win1.right, win1.top + win1.height * 0.5), windowBorder);
    canvas.drawLine(Offset(win1.left + win1.width * 0.5, win1.top), Offset(win1.left + win1.width * 0.5, win1.bottom), windowBorder);

    // Right Single-Pane Window
    final win2 = Rect.fromLTWH(w * 0.56, h * 0.18, w * 0.18, h * 0.24);
    canvas.drawRect(win2, windowBorder);

    // 2. SOFT GROUND SHADOW (OVAL)
    final shadowPaint = Paint()..color = const Color(0xFFEEF2FF);
    canvas.drawOval(Rect.fromLTWH(w * 0.28, h * 0.78, w * 0.55, h * 0.10), shadowPaint);

    // 3. RED TRASH BIN (RIGHT SIDE)
    final binFill = Paint()..color = const Color(0xFFEF4444);
    final binDark = Paint()..color = const Color(0xFFDC2626);

    // Bin Body Path (Slight taper)
    final binBody = Path()
      ..moveTo(w * 0.62, h * 0.56)
      ..lineTo(w * 0.82, h * 0.56)
      ..lineTo(w * 0.79, h * 0.85)
      ..lineTo(w * 0.65, h * 0.85)
      ..close();
    canvas.drawPath(binBody, binFill);

    // Bin Top Rim Lid
    final binRim = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.60, h * 0.52, w * 0.24, h * 0.06),
      const Radius.circular(4),
    );
    canvas.drawRRect(binRim, binDark);

    // Vertical Rib Lines on Bin
    final ribPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.67, h * 0.58), Offset(w * 0.68, h * 0.83), ribPaint);
    canvas.drawLine(Offset(w * 0.72, h * 0.58), Offset(w * 0.72, h * 0.83), ribPaint);
    canvas.drawLine(Offset(w * 0.77, h * 0.58), Offset(w * 0.76, h * 0.83), ribPaint);

    // 4. PERSON FIGURE (STANDING LEFT, LEANING OVER BIN)
    final skinPaint = Paint()..color = const Color(0xFFFFD1B3);
    final redShirt = Paint()..color = const Color(0xFFEF4444);
    final navyLegs = Paint()..color = const Color(0xFF1E293B);
    final blackHair = Paint()..color = const Color(0xFF0F172A);
    final redShoes = Paint()..color = const Color(0xFFEF4444);

    // Head & Hair
    final headCenter = Offset(w * 0.44, h * 0.28);
    canvas.drawCircle(headCenter, w * 0.055, skinPaint);

    // Black Hair Bowl Cap
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: w * 0.056), math.pi, math.pi);
    canvas.drawPath(hairPath, blackHair);

    // Torso (Red Shirt)
    final torsoPath = Path()
      ..moveTo(w * 0.41, h * 0.35)
      ..lineTo(w * 0.49, h * 0.35)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.42, h * 0.52)
      ..close();
    canvas.drawPath(torsoPath, redShirt);

    // Trousers / Legs (Navy)
    canvas.drawRect(Rect.fromLTWH(w * 0.415, h * 0.52, w * 0.03, h * 0.28), navyLegs);
    canvas.drawRect(Rect.fromLTWH(w * 0.455, h * 0.52, w * 0.03, h * 0.28), navyLegs);

    // Red Shoes (Feet)
    final shoe1 = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.39, h * 0.78, w * 0.07, h * 0.04), const Radius.circular(3));
    final shoe2 = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.45, h * 0.78, w * 0.07, h * 0.04), const Radius.circular(3));
    canvas.drawRRect(shoe1, redShoes);
    canvas.drawRRect(shoe2, redShoes);

    // Arms & Red Document Block (Throwing into bin)
    final armPath = Path()
      ..moveTo(w * 0.47, h * 0.37)
      ..lineTo(w * 0.57, h * 0.40)
      ..lineTo(w * 0.63, h * 0.44)
      ..lineTo(w * 0.59, h * 0.48)
      ..lineTo(w * 0.47, h * 0.43)
      ..close();
    canvas.drawPath(armPath, redShirt);

    // Hand
    canvas.drawCircle(Offset(w * 0.63, h * 0.45), w * 0.025, skinPaint);

    // Red Document Block going into trash
    final docBlock = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.63, h * 0.42, w * 0.06, h * 0.06),
      const Radius.circular(2),
    );
    canvas.drawRRect(docBlock, redShirt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL EXPORT MODAL DIALOG (FROM PROJECT MASTER EXPORT MODULE)
// ============================================================================
class _SubDepartmentExportModalDialog extends StatefulWidget {
  final List<SubDepartmentMasterItem> subDepartments;

  const _SubDepartmentExportModalDialog({required this.subDepartments});

  @override
  State<_SubDepartmentExportModalDialog> createState() => _SubDepartmentExportModalDialogState();
}

class _SubDepartmentExportModalDialogState extends State<_SubDepartmentExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedSubDeptCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedSubDeptCodes = widget.subDepartments.map((p) => p.sdmCode).toSet();
    _modalSearchCtrl.addListener(() {
      setState(() {
        _modalSearchQuery = _modalSearchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _modalSearchCtrl.dispose();
    _exportTimer?.cancel();
    super.dispose();
  }

  List<SubDepartmentMasterItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.subDepartments;
    return widget.subDepartments.where((p) {
      final codeMatch = p.sdmCode.toString().contains(_modalSearchQuery);
      final nameMatch = p.sdmName.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewItems;
    if (preview.isEmpty) return false;
    return preview.every((p) => _selectedSubDeptCodes.contains(p.sdmCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final p in preview) {
          _selectedSubDeptCodes.remove(p.sdmCode);
        }
      } else {
        for (final p in preview) {
          _selectedSubDeptCodes.add(p.sdmCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedSubDeptCodes.isEmpty) {
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
      final selectedList = widget.subDepartments
          .where((p) => _selectedSubDeptCodes.contains(p.sdmCode))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'SubDepartmentMaster_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'SubDepartment Master');
        final excel_pkg.Sheet sheet = excel['SubDepartment Master'];

        sheet.setColumnWidth(0, 22.0); // SUB-DEPT CODE
        sheet.setColumnWidth(1, 42.0); // SUB-DEPARTMENT NAME

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
          excel_pkg.TextCellValue('SUB-DEPT CODE'),
          excel_pkg.TextCellValue('SUB-DEPARTMENT NAME'),
        ]);

        for (int col = 0; col < 2; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final p = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(p.sdmCode),
            excel_pkg.TextCellValue(p.sdmName),
          ]);

          for (int col = 0; col < 2; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
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
                      'SUB-DEPARTMENT MASTER REGISTER REPORT',
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
                      'Total Records: ${selectedList.length}',
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
                headers: ['SR NO', 'SUB-DEPT CODE', 'SUB-DEPARTMENT NAME'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  return [
                    '${idx + 1}',
                    '${p.sdmCode}',
                    p.sdmName,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(6.5),
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
        await FileExportHelper.saveAndLaunchFile(bytes: pdfBytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint('Export sub-department master failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
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
                                    Text('Export Sub-Department Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards (With Big 3D Excel & PDF Brand Logos)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSideBySideCard(
                                    formatKey: 'XLSX',
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
                                    formatKey: 'PDF',
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
    required String formatKey,
    required String title,
    required String subtitle,
    required Widget logoWidget,
    required Color brandColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == formatKey;

    return InkWell(
      onTap: _isExporting ? null : () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFE2E8F0),
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
            '${_selectedSubDeptCodes.length} of ${widget.subDepartments.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewItems;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No sub-department records found',
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
                  Expanded(child: Text('SUB-DEPARTMENT NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final p = previewList[idx];
                  final isSelected = _selectedSubDeptCodes.contains(p.sdmCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSubDeptCodes.remove(p.sdmCode);
                        } else {
                          _selectedSubDeptCodes.add(p.sdmCode);
                        }
                      });
                    },
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.05) : Colors.white,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.secondaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedSubDeptCodes.add(p.sdmCode);
                                  } else {
                                    _selectedSubDeptCodes.remove(p.sdmCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '#${p.sdmCode}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              p.sdmName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
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
// AUTHENTIC VECTOR BRAND LOGO WIDGETS
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

    // Authentic Adobe Ribbon Curve / 'PDF' Text Badge
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
