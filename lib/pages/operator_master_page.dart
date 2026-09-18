import 'dart:async';
import '../utils/file_export_helper.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../design/app_colors.dart';
import '../services/operator_service.dart';

class _DepartmentTheme {
  final Color bgColor;
  final Color textColor;
  final Color borderColor;
  final Color iconBgColor;
  final IconData icon;

  const _DepartmentTheme({
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
    required this.iconBgColor,
    required this.icon,
  });
}

// Top-level Department Theme Data Helper
_DepartmentTheme _getDepartmentTheme(String depName, int depCd) {
  final nameUpper = depName.toUpperCase();
  if (nameUpper.contains('REGULAR') || nameUpper.contains('MAIN')) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFECFDF5),
      textColor: Color(0xFF047857),
      borderColor: Color(0xFFA7F3D0),
      iconBgColor: Color(0xFF10B981),
      icon: Icons.check_circle_rounded,
    );
  } else if (nameUpper.contains('PACKAGE') || nameUpper.contains('FINAL')) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFEFF6FF),
      textColor: Color(0xFF1D4ED8),
      borderColor: Color(0xFFBFDBFE),
      iconBgColor: Color(0xFF3B82F6),
      icon: Icons.archive_rounded,
    );
  } else if (nameUpper.contains('REPACK') || nameUpper.contains('PACK')) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFFFFBEB),
      textColor: Color(0xFFB45309),
      borderColor: Color(0xFFFDE68A),
      iconBgColor: Color(0xFFF59E0B),
      icon: Icons.all_inbox_rounded,
    );
  } else if (nameUpper.contains('QUALITY') || nameUpper.contains('QC')) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFF5F3FF),
      textColor: Color(0xFF6D28D9),
      borderColor: Color(0xFFDDD6FE),
      iconBgColor: Color(0xFF8B5CF6),
      icon: Icons.verified_rounded,
    );
  }

  final mod = depCd % 4;
  if (mod == 0) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFF0FDFA),
      textColor: Color(0xFF0F766E),
      borderColor: Color(0xFF99F6E4),
      iconBgColor: Color(0xFF14B8A6),
      icon: Icons.apartment_rounded,
    );
  } else if (mod == 1) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFFDF2F8),
      textColor: Color(0xFFBE185D),
      borderColor: Color(0xFFFBCFE8),
      iconBgColor: Color(0xFFEC4899),
      icon: Icons.work_outline_rounded,
    );
  } else if (mod == 2) {
    return const _DepartmentTheme(
      bgColor: Color(0xFFF0F9FF),
      textColor: Color(0xFF0369A1),
      borderColor: Color(0xFFBAE6FD),
      iconBgColor: Color(0xFF0EA5E9),
      icon: Icons.engineering_rounded,
    );
  } else {
    return const _DepartmentTheme(
      bgColor: Color(0xFFFEF2F2),
      textColor: Color(0xFFB91C1C),
      borderColor: Color(0xFFFECACA),
      iconBgColor: Color(0xFFEF4444),
      icon: Icons.precision_manufacturing_rounded,
    );
  }
}

class _OperatorCapsuleTheme {
  final Color bgColor;
  final Color borderColor;
  final Color avatarColor;
  final Color textColor;

  const _OperatorCapsuleTheme({
    required this.bgColor,
    required this.borderColor,
    required this.avatarColor,
    required this.textColor,
  });
}

_OperatorCapsuleTheme _getOperatorCapsuleTheme(String name, int operCode) {
  final nameUpper = name.trim().toUpperCase();
  if (nameUpper == 'TANMAY' || nameUpper.startsWith('T')) {
    return const _OperatorCapsuleTheme(
      bgColor: Color(0xFFFDF2F8),
      borderColor: Color(0xFFFCE7F3),
      avatarColor: Color(0xFFDB2777),
      textColor: Color(0xFF9D174D),
    );
  } else if (nameUpper == 'RAHUL' || nameUpper.startsWith('R')) {
    return const _OperatorCapsuleTheme(
      bgColor: Color(0xFFF5F3FF),
      borderColor: Color(0xFFDDD6FE),
      avatarColor: Color(0xFF7C3AED),
      textColor: Color(0xFF5B21B6),
    );
  } else if (nameUpper == 'KRISHA' || nameUpper.startsWith('K')) {
    return const _OperatorCapsuleTheme(
      bgColor: Color(0xFFFAF5FF),
      borderColor: Color(0xFFE9D5FF),
      avatarColor: Color(0xFF8B5CF6),
      textColor: Color(0xFF6D28D9),
    );
  } else if (nameUpper == 'FAIZAN' || nameUpper.startsWith('F')) {
    return const _OperatorCapsuleTheme(
      bgColor: Color(0xFFEFF6FF),
      borderColor: Color(0xFFBFDBFE),
      avatarColor: Color(0xFF2563EB),
      textColor: Color(0xFF1E40AF),
    );
  }

  int hash = operCode * 17;
  for (int i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.codeUnitAt(i)) & 0xFFFFFF;
  }
  final mod = (hash + operCode * 7) % 6;
  switch (mod) {
    case 0:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFFDF2F8),
        borderColor: Color(0xFFFCE7F3),
        avatarColor: Color(0xFFDB2777),
        textColor: Color(0xFF9D174D),
      );
    case 1:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFF5F3FF),
        borderColor: Color(0xFFDDD6FE),
        avatarColor: Color(0xFF7C3AED),
        textColor: Color(0xFF5B21B6),
      );
    case 2:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFFAF5FF),
        borderColor: Color(0xFFE9D5FF),
        avatarColor: Color(0xFF8B5CF6),
        textColor: Color(0xFF6D28D9),
      );
    case 3:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFEFF6FF),
        borderColor: Color(0xFFBFDBFE),
        avatarColor: Color(0xFF2563EB),
        textColor: Color(0xFF1E40AF),
      );
    case 4:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFECFDF5),
        borderColor: Color(0xFFA7F3D0),
        avatarColor: Color(0xFF10B981),
        textColor: Color(0xFF047857),
      );
    default:
      return const _OperatorCapsuleTheme(
        bgColor: Color(0xFFFFFBEB),
        borderColor: Color(0xFFFDE68A),
        avatarColor: Color(0xFFF59E0B),
        textColor: Color(0xFFB45309),
      );
  }
}


// ============================================================================
// MAIN PAGE: OperatorMasterPage (Split Workstation Architecture)
// ============================================================================
class OperatorMasterPage extends StatefulWidget {
  final OperatorService? operatorService;

  const OperatorMasterPage({super.key, this.operatorService});

  @override
  State<OperatorMasterPage> createState() => _OperatorMasterPageState();
}

class _OperatorMasterPageState extends State<OperatorMasterPage> {
  late final OperatorService _service;

  // Global State Variables
  List<OperatorMaster> _operators = [];
  List<Department> _departments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Search & Filter State
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Table scroll controller for auto-scroll to new entry
  final ScrollController _tableScrollCtrl = ScrollController();

  // Form State
  bool _isEditing = false;
  int _formOperCode = 1;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  int? _selectedDepCd;
  bool _isSaveSuccess = false;

  int? _selectedRowCode;
  String? _buttonValidationMsg;
  Timer? _validationTimer;

  // Entry Glow Strategy (4-second auto-fade: New = Emerald, Updated = Amber)
  int? _recentlySavedCode;    // newly added → emerald glow
  int? _recentlyUpdatedCode;  // recently updated → amber glow
  Timer? _glowTimer;

  void _highlightOperatorRow(int code, {bool isEdit = false}) {
    _glowTimer?.cancel();
    setState(() {
      if (isEdit) {
        _recentlyUpdatedCode = code;
        _recentlySavedCode = null;
      } else {
        _recentlySavedCode = code;
        _recentlyUpdatedCode = null;
      }
      _selectedRowCode = code;
    });

    // Auto-fade glow highlight after 4 seconds (Consistent Entry Glow Strategy)
    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _recentlySavedCode = null;
          _recentlyUpdatedCode = null;
          if (_selectedRowCode == code) {
            _selectedRowCode = null;
          }
        });
      }
    });
  }

  int _assignedDepsCount = 0;
  List<OperatorMaster> _cachedFilteredOperators = [];
  Timer? _debounceTimer;
  final ScrollController _horizontalScrollCtrl = ScrollController();

  void _updateFilteredOperators() {
    if (_searchQuery.isEmpty) {
      _cachedFilteredOperators = List.from(_operators);
    } else {
      final q = _searchQuery; // already lowercase
      _cachedFilteredOperators = _operators.where((o) {
        final codeStr = o.operCode.toString();
        final nameStr = o.operName.toLowerCase();
        final depStr = o.labName.toLowerCase();
        return codeStr.contains(q) ||
            nameStr.contains(q) ||
            depStr.contains(q);
      }).toList();
    }
    _assignedDepsCount = _operators.map((e) => e.operDepCd).toSet().length;
  }

  @override
  void initState() {
    super.initState();
    _service = widget.operatorService ?? OperatorService();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _glowTimer?.cancel();
    _validationTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _tableScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
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

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
      _updateFilteredOperators();
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchOperators(),
        _service.fetchDepartments(),
        _service.fetchNextCode(),
      ]);

      if (!mounted) return;

      setState(() {
        _operators = results[0] as List<OperatorMaster>;
        _departments = results[1] as List<Department>;
        _formOperCode = results[2] as int;
        _isLoading = false;

        if (_departments.isNotEmpty && _selectedDepCd == null) {
          _selectedDepCd = _departments.first.labCode;
        }
        _updateFilteredOperators();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _populateFormForEdit(OperatorMaster oper) {
    setState(() {
      _isEditing = true;
      _selectedRowCode = oper.operCode;
      _formOperCode = oper.operCode;
      _nameCtrl.text = oper.operName;
      _selectedDepCd = oper.operDepCd;
    });
    _nameFocusNode.requestFocus();
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _selectedRowCode = null;
      _buttonValidationMsg = null;
      _nameCtrl.clear();
      if (_departments.isNotEmpty) {
        _selectedDepCd = _departments.first.labCode;
      }
    });
    _service.fetchNextCode().then((code) {
      if (mounted && !_isEditing) {
        setState(() => _formOperCode = code);
      }
    });
  }

  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showButtonValidation('Please enter an operator name');
      _nameFocusNode.requestFocus();
      return;
    }

    if (_selectedDepCd == null) {
      _showButtonValidation('Please select a department');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    try {
      bool success = false;
      if (_isEditing) {
        success = await _service.updateOperator(_formOperCode, name, _selectedDepCd!);
      } else {
        success = await _service.createOperator(_formOperCode, name, _selectedDepCd!);
      }

      if (!mounted) return;

      if (success) {
        // Remember the code & mode for auto-scroll and glow highlight
        final savedCode = _formOperCode;
        final wasEditing = _isEditing;
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });
        // Fast, crisp animation feedback directly on Save/Update button
        await Future.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        _clearForm();
        // Silently refresh data without showing shimmer loading screen
        await _refreshDataSilently();
        setState(() {
          _isSaveSuccess = false;
        });
        // Auto-scroll to the newly added/updated entry and trigger glowing halo
        _scrollToOperatorCode(savedCode);
        _highlightOperatorRow(savedCode, isEdit: wasEditing);
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save operator record.');
      }
    } catch (e) {
      if (!mounted) return;
      _showButtonValidation(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Refresh data silently WITHOUT showing shimmer loading state
  Future<void> _refreshDataSilently() async {
    try {
      final results = await Future.wait([
        _service.fetchOperators(),
        _service.fetchDepartments(),
        _service.fetchNextCode(),
      ]);

      if (!mounted) return;

      setState(() {
        _operators = results[0] as List<OperatorMaster>;
        _departments = results[1] as List<Department>;
        _formOperCode = results[2] as int;
        _updateFilteredOperators();

        if (_departments.isNotEmpty && _selectedDepCd == null) {
          _selectedDepCd = _departments.first.labCode;
        }
      });
    } catch (e) {
      // Silent fail — data just stays as-is
    }
  }

  /// Auto-scroll the table to the row matching the given operator code
  void _scrollToOperatorCode(int operCode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tableScrollCtrl.hasClients) return;
      final list = _cachedFilteredOperators;
      final idx = list.indexWhere((o) => o.operCode == operCode);
      if (idx < 0) return;
      // Each row is 46px + 1px divider = 47px
      final targetOffset = idx * 47.0;
      final maxScroll = _tableScrollCtrl.position.maxScrollExtent;
      _tableScrollCtrl.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      // Briefly highlight the saved row
      setState(() => _selectedRowCode = operCode);
    });
  }

  Future<void> _deleteOperator(OperatorMaster oper) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () => _service.deleteOperator(oper.operCode),
      ),
    );

    if (deleted == true) {
      if (_selectedRowCode == oper.operCode) {
        _clearForm();
      }
      await _refreshDataSilently();
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OperatorExportModalDialog(
        operators: _cachedFilteredOperators,
        departments: _departments,
      ),
    );
  }

  // Keyboard Shortcuts Handling
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
          _searchFocusNode.requestFocus();
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (!_isSubmitting) _submitForm();
        },
        const SingleActivator(LogicalKeyboardKey.f1): () {
          if (!_isSubmitting) _submitForm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _clearForm();
        },
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // TOP HEADER & KPI SUMMARY BAR
                    _buildTopHeaderBar(),
                    const SizedBox(height: 16),

                    // MAIN BODY: SPLIT WORKSTATION (2-COLUMN DESKTOP VIEW)
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoadingState()
                          : _errorMessage != null
                              ? _buildErrorState()
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // LEFT PANEL (60% width - Master Operator Directory Table)
                                    Expanded(
                                      flex: 6,
                                      child: _buildLeftDirectoryPanel(),
                                    ),
                                    const SizedBox(width: 20),

                                    // RIGHT PANEL (40% width - Operator Management Form Card)
                                    Expanded(
                                      flex: 4,
                                      child: _buildRightFormCard(),
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

  // ============================================================================
  // TOP HEADER & KPI SUMMARY BAR
  // ============================================================================
  Widget _buildTopHeaderBar() {
    final totalOps = _operators.length;
    final assignedDepsCount = _assignedDepsCount;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 920;
              final isVeryNarrow = constraints.maxWidth < 750;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title & Subtitle with Header Hierarchy Logo (52x52)
                  Row(
                    children: [
                      const _HeaderLogo(),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Operator Master',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage plant operators and department allocations',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.neutralDark.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // KPI Progress Cards & Export Controls (Right Aligned)
                  Flexible(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // KPI Card 1: Total Operators (Pink Gradient - Operation Master Style)
                        if (!isVeryNarrow) ...[
                          _HeaderKpiCard(
                            label: 'TOTAL OPERATORS',
                            value: totalOps.toString(),
                            progress: (totalOps / 10).clamp(0.05, 1.0),
                            gradientColors: const [
                              Color(0xFFEC4899),
                              Color(0xFFF43F5E),
                            ],
                            trackColor: const Color(0xFFEC4899).withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 10),
                        ],

                        // KPI Card 2: Assigned Departments (Cyan Gradient - Operation Master Style)
                        if (!isNarrow) ...[
                          _HeaderKpiCard(
                            label: 'ASSIGNED DEPTS',
                            value: assignedDepsCount.toString(),
                            progress: (assignedDepsCount / 6).clamp(0.05, 1.0),
                            gradientColors: const [
                              Color(0xFF06B6D4),
                              Color(0xFF0EA5E9),
                            ],
                            trackColor: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                          ),
                          const SizedBox(width: 12),
                        ],

                        // Export Button (ALWAYS FULLY VISIBLE & RESPONSIVE)
                        _AnimatedExportButton(onPressed: _openExportModal),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
    );
  }





  // ============================================================================
  // LEFT PANEL: MASTER OPERATOR DIRECTORY TABLE (60% WIDTH)
  // ============================================================================
  Widget _buildLeftDirectoryPanel() {
    final displayList = _cachedFilteredOperators;

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
          // ── Table Card Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/operator_directory_sheet_logo.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Operator Directory Sheet',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const Spacer(),
                // Search bar in table header
                Container(
                  constraints: const BoxConstraints(maxWidth: 210, minWidth: 130),
                  height: 32,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark),
                    decoration: InputDecoration(
                      hintText: 'Search operators…',
                      hintStyle: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 14, color: Color(0xFF06B6D4)),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 12),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Records badge
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

          // ── Column Header Bar + Data Rows ─────────────────────────────────
          // ── Column Header Bar ─────────────────────────────────────────────
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
                  width: 72,
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
                      Icon(Icons.badge_rounded, size: 12, color: Color(0xFF10B981)),
                      SizedBox(width: 5),
                      Text('OPERATOR NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF3B82F6)),
                      SizedBox(width: 5),
                      Text('DEPARTMENT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_outlined, size: 12, color: Color(0xFF64748B)),
                      SizedBox(width: 3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Data Rows List ─────────────────────────────────────────────────
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: displayList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
                          const SizedBox(height: 6),
                          Text(
                            'No operators found',
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
                        final oper = displayList[idx];
                        final isSelected = _selectedRowCode == oper.operCode;
                        final isNewGlow = _recentlySavedCode == oper.operCode;
                        final isUpdateGlow = _recentlyUpdatedCode == oper.operCode;
                        final depTheme = _getDepartmentTheme(oper.labName, oper.operDepCd);
                        final operTheme = _getOperatorCapsuleTheme(oper.operName, oper.operCode);

                        return _AnimatedOperatorRow(
                          key: ValueKey<int>(oper.operCode),
                          oper: oper,
                          isSelected: isSelected,
                          isNewGlow: isNewGlow,
                          isUpdateGlow: isUpdateGlow,
                          depTheme: depTheme,
                          operTheme: operTheme,
                          onTap: () {
                            setState(() {
                              _selectedRowCode = oper.operCode;
                            });
                          },
                          onDoubleTap: () => _populateFormForEdit(oper),
                          onEdit: () => _populateFormForEdit(oper),
                          onDelete: () => _deleteOperator(oper),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFieldCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3.5),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 11.5, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  // ============================================================================
  // RIGHT PANEL: OPERATOR MANAGEMENT FORM CARD (GROUP MASTER FIELD UI)
  // ============================================================================
  Widget _buildRightFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Card Header Bar (Matching Light Lavender/Slate Palette)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const _AddOperatorLogo(),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Edit Operator #$_formOperCode' : 'Add New Operator',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Cancel Edit',
                      onPressed: _clearForm,
                    ),
                ],
              ),
            ),

            // Form Input Fields (GROUP MASTER FIELD UI & GENEROUS WHITE SPACE)
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              // FIELD 1: OPERATOR CODE (GROUP MASTER COBALT BLUE STYLE)
                              _buildFormFieldCard(
                                title: 'OPERATOR CODE (AUTO)',
                                icon: Icons.qr_code_rounded,
                                iconColor: const Color(0xFF2563EB),
                                bgColor: const Color(0xFFEFF6FF),
                                borderColor: const Color(0xFFBFDBFE),
                                child: SizedBox(
                                  height: 36,
                                  child: TextField(
                                    readOnly: true,
                                    controller: TextEditingController(text: '#$_formOperCode'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _isEditing ? const Color(0xFF475569) : const Color(0xFF0F172A),
                                      letterSpacing: 0.2,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(
                                        _isEditing ? Icons.lock_outline_rounded : Icons.numbers_rounded,
                                        size: 15,
                                        color: _isEditing ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
                                      ),
                                      suffixIcon: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        alignment: Alignment.centerRight,
                                        width: 52,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: _isEditing ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: _isEditing ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: Text(
                                            _isEditing ? 'Lock' : 'Auto',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: _isEditing ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      hintText: 'Auto Code',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      filled: true,
                                      fillColor: _isEditing ? const Color(0xFFF8FAFC) : const Color(0xFFF0F7FF),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _isEditing ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: _isEditing ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // White Space between Field 1 and Field 2
                              const SizedBox(height: 12),

                              // FIELD 2: OPERATOR NAME (GROUP MASTER EMERALD GREEN STYLE)
                              _buildFormFieldCard(
                                title: 'OPERATOR NAME *',
                                icon: Icons.person_rounded,
                                iconColor: const Color(0xFF059669),
                                bgColor: const Color(0xFFD1FAE5),
                                borderColor: const Color(0xFFA7F3D0),
                                child: SizedBox(
                                  height: 36,
                                  child: TextField(
                                    controller: _nameCtrl,
                                    focusNode: _nameFocusNode,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. JOHN DOE, FAISAL AHMAD',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                      filled: true,
                                      fillColor: Colors.white,
                                      prefixIcon: const Icon(Icons.badge_outlined, size: 15, color: Color(0xFF059669)),
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
                                        borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // White Space between Field 2 and Field 3
                              const SizedBox(height: 12),

                              // FIELD 3: DEPARTMENT ALLOCATION (GROUP MASTER PURPLE STYLE WITH MODERN DROPDOWN)
                              _buildFormFieldCard(
                                title: 'DEPARTMENT ALLOCATION *',
                                icon: Icons.apartment_rounded,
                                iconColor: const Color(0xFF7C3AED),
                                bgColor: const Color(0xFFF5F3FF),
                                borderColor: const Color(0xFFDDD6FE),
                                child: _ModernDepartmentDropdown(
                                  selectedDepCd: _selectedDepCd,
                                  departments: _departments,
                                  onChanged: (val) {
                                    setState(() => _selectedDepCd = val);
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Helper Hint Bar (Glowing Bulb with Plain Black Text)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
                                            blurRadius: 10,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.lightbulb_rounded,
                                        size: 15,
                                        color: Color(0xFFF59E0B),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Shortcuts: Ctrl+S or F1 to Save | Esc to Reset',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
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
                    );
                  },
                ),
            ),

            // Form Card Footer Action Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  // Secondary Cancel Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.neutralDark),
                      label: const Text(
                        'Clear (Esc)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // Primary Save/Update Button with In-Button Checkmark Animation & Floating Validation Badge
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
                          idleText: _isEditing ? 'Update Operator' : 'Save Operator',
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
    );
  }

  // ============================================================================
  // SHIMMER LOADING & ERROR STATES
  // ============================================================================
  Widget _buildShimmerLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.secondaryColor),
          SizedBox(height: 16),
          Text(
            'Loading Operator Master Workstation...',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
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
// ANIMATED EXPORT BUTTON (Circulating Edge Light Orbit Animation)
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
// OPERATOR EXPORT MODAL DIALOG (.xlsx / .pdf local download)
// ============================================================================
enum ExportFormat { excel, pdf }

class _OperatorExportModalDialog extends StatefulWidget {
  final List<OperatorMaster> operators;
  final List<Department> departments;

  const _OperatorExportModalDialog({
    required this.operators,
    required this.departments,
  });

  @override
  State<_OperatorExportModalDialog> createState() => _OperatorExportModalDialogState();
}

class _OperatorExportModalDialogState extends State<_OperatorExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedOperCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedOperCodes = widget.operators.map((o) => o.operCode).toSet();
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

  List<OperatorMaster> get _filteredPreviewOperators {
    if (_modalSearchQuery.isEmpty) return widget.operators;
    return widget.operators.where((o) {
      final codeStr = o.operCode.toString();
      final nameStr = o.operName.toLowerCase();
      final depStr = o.labName.toLowerCase();
      return codeStr.contains(_modalSearchQuery) ||
          nameStr.contains(_modalSearchQuery) ||
          depStr.contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewOperators;
    if (filtered.isEmpty) return false;
    return filtered.every((o) => _selectedOperCodes.contains(o.operCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewOperators;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var o in filtered) {
          _selectedOperCodes.remove(o.operCode);
        }
      } else {
        for (var o in filtered) {
          _selectedOperCodes.add(o.operCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedOperCodes.isEmpty) return;

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
    final selectedList = widget.operators
        .where((o) => _selectedOperCodes.contains(o.operCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

      if (_selectedFormat == 'XLSX') {
        final fileName = 'Operator_Master_Export_$timeStamp.xlsx';
        final bytes = _generateExcelBytes(selectedList);
        if (bytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
        }
      } else {
        final fileName = 'Operator_Master_Export_$timeStamp.pdf';
        final bytes = await _generatePdfBytes(selectedList);
        await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
      }

      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _isExportSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  List<int>? _generateExcelBytes(List<OperatorMaster> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Operator Master');
    final excel_pkg.Sheet sheet = excel['Operator Master'];

    // Define Grid Cell Borders
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

    sheet.setColumnWidth(0, 16.0);
    sheet.setColumnWidth(1, 35.0);
    sheet.setColumnWidth(2, 35.0);

    // Set Header Row Height & Append Headers
    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('OPER CODE'),
      excel_pkg.TextCellValue('OPERATOR NAME'),
      excel_pkg.TextCellValue('DEPARTMENT'),
    ]);

    for (int col = 0; col < 3; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    // Append Data Rows with Heights & Styles
    for (int i = 0; i < records.length; i++) {
      final o = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final deptStr = o.labName.isNotEmpty ? o.labName : 'Dept #${o.operDepCd}';
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.IntCellValue(o.operCode),
        excel_pkg.TextCellValue(o.operName),
        excel_pkg.TextCellValue(deptStr),
      ]);

      for (int col = 0; col < 3; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<OperatorMaster> records) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'OPERATOR MASTER DIRECTORY',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.teal800),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated on: ${DateTime.now().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: ['OPER CODE', 'OPERATOR NAME', 'DEPARTMENT'],
            data: records.map((o) => [
              '#${o.operCode}',
              o.operName,
              o.labName.isNotEmpty ? o.labName : 'Dept #${o.operDepCd}',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          ),
        ],
      ),
    );

    return pdf.save();
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
            child: Row(
              children: [
                // LEFT COLUMN: Format Selector & Options (440px)
                SizedBox(
                  width: 440,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: const BoxDecoration(
                      border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C3B2E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Export Operator Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                SizedBox(height: 2),
                                Text('Select format & download records to PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),

                        const Text('Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 12),

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
                            backgroundColor: const Color(0xFFE2E8F0),
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

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AnimatedSuccessButton(
                                status: _isExportSuccess
                                    ? ButtonStatus.success
                                    : (_isExporting ? ButtonStatus.loading : ButtonStatus.idle),
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

                // RIGHT COLUMN: Interactive Table Preview Box
                Expanded(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPreviewTableToolbar(),
                        const SizedBox(height: 14),

                        Expanded(
                          child: _buildPreviewDataTable(),
                        ),
                      ],
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
      onTap: () => setState(() => _selectedFormat = formatKey),
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

  Widget _buildPreviewTableToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
              decoration: InputDecoration(
                hintText: 'Search operators...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.5)),
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
            '${_selectedOperCodes.length} of ${widget.operators.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewOperators;

    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No operator records found',
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
                  SizedBox(width: 60, child: Text('CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('OPERATOR NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 160, child: Text('DEPARTMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final o = previewList[idx];
                  final isSelected = _selectedOperCodes.contains(o.operCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedOperCodes.remove(o.operCode);
                        } else {
                          _selectedOperCodes.add(o.operCode);
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
                                    _selectedOperCodes.add(o.operCode);
                                  } else {
                                    _selectedOperCodes.remove(o.operCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${o.operCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              o.operName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 160,
                            child: Text(
                              o.labName.isNotEmpty ? o.labName : 'Dept #${o.operDepCd}',
                              style: TextStyle(fontSize: 11, color: AppColors.neutralDark.withValues(alpha: 0.7)),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
// RICH 3D VECTOR BRAND LOGO WIDGETS (EXCEL & PDF)
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

// ============================================================================
// MODERN DEPARTMENT DROPDOWN (GROUP MASTER OVERLAY STYLE WITH COOL SCROLL)
// ============================================================================
class _ModernDepartmentDropdown extends StatefulWidget {
  final int? selectedDepCd;
  final List<Department> departments;
  final ValueChanged<int> onChanged;

  const _ModernDepartmentDropdown({
    required this.selectedDepCd,
    required this.departments,
    required this.onChanged,
  });

  @override
  State<_ModernDepartmentDropdown> createState() => _ModernDepartmentDropdownState();
}

class _ModernDepartmentDropdownState extends State<_ModernDepartmentDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    if (widget.departments.isEmpty) return;
    _closeDropdown();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - (offset.dy + size.height);

    const double maxMenuHeight = 220.0;
    final double calculatedHeight = math.min<double>(widget.departments.length * 40.0 + 44.0, maxMenuHeight);
    final bool openUpwards = spaceBelow < (calculatedHeight + 10);
    final double offsetY = openUpwards ? -(calculatedHeight + 4) : (size.height + 4);

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Barrier to dismiss when clicking outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (_) => _closeDropdown(),
                child: Container(color: Colors.transparent),
              ),
            ),
            // Positioned Dropdown Menu
            Positioned(
              width: math.max(size.width, 260.0),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, offsetY),
                child: Material(
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.20),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFCBD5E1),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: BoxConstraints(maxHeight: maxMenuHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F3FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF7C3AED)),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'DEPARTMENTS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${widget.departments.length} Options',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Scrollable List with Cool Scrollbar
                        Flexible(
                          child: RawScrollbar(
                            thumbVisibility: true,
                            thickness: 4,
                            radius: const Radius.circular(4),
                            thumbColor: const Color(0xFFCBD5E1),
                            padding: const EdgeInsets.only(right: 2),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: widget.departments.map((dep) {
                                  final isSelected = dep.labCode == widget.selectedDepCd;
                                  final depTheme = _getDepartmentTheme(dep.labName, dep.labCode);
                                  return _DepartmentDropdownMenuItem(
                                    dep: dep,
                                    depTheme: depTheme,
                                    isSelected: isSelected,
                                    onTap: () {
                                      widget.onChanged(dep.labCode);
                                      _closeDropdown();
                                    },
                                  );
                                }).toList(),
                              ),
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
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_isOpen && mounted) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void didUpdateWidget(covariant _ModernDepartmentDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _closeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Department? selectedDep;
    try {
      selectedDep = widget.departments.firstWhere((d) => d.labCode == widget.selectedDepCd);
    } catch (_) {
      selectedDep = widget.departments.isNotEmpty ? widget.departments.first : null;
    }

    final depTheme = selectedDep != null
        ? _getDepartmentTheme(selectedDep.labName, selectedDep.labCode)
        : null;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _toggleDropdown,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isOpen
                    ? const Color(0xFF7C3AED)
                    : (_isHovered ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1)),
                width: _isOpen ? 1.5 : 1.0,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                if (depTheme != null && selectedDep != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: depTheme.bgColor,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: depTheme.borderColor),
                    ),
                    child: Icon(depTheme.icon, size: 10, color: depTheme.textColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedDep.labName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const Expanded(
                    child: Text(
                      'Select Department...',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
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

class _DepartmentDropdownMenuItem extends StatefulWidget {
  final Department dep;
  final _DepartmentTheme depTheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _DepartmentDropdownMenuItem({
    required this.dep,
    required this.depTheme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_DepartmentDropdownMenuItem> createState() => _DepartmentDropdownMenuItemState();
}

class _DepartmentDropdownMenuItemState extends State<_DepartmentDropdownMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF5F3FF)
                : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFDDD6FE)
                  : (_isHovered ? const Color(0xFFE2E8F0) : Colors.transparent),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.depTheme.bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: widget.depTheme.borderColor),
                ),
                child: Icon(widget.depTheme.icon, size: 11, color: widget.depTheme.textColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.dep.labName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFF334155),
                    letterSpacing: 0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF7C3AED)),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED OPERATOR ROW WIDGET (MATCHING DEPARTMENT MASTER & REFERENCE IMAGE)
// ============================================================================
class _AnimatedOperatorRow extends StatefulWidget {
  final OperatorMaster oper;
  final bool isSelected;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final _DepartmentTheme depTheme;
  final _OperatorCapsuleTheme operTheme;

  const _AnimatedOperatorRow({
    super.key,
    required this.oper,
    required this.isSelected,
    this.isNewGlow = false,
    this.isUpdateGlow = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
    required this.depTheme,
    required this.operTheme,
  });

  @override
  State<_AnimatedOperatorRow> createState() => _AnimatedOperatorRowState();
}

class _AnimatedOperatorRowState extends State<_AnimatedOperatorRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final oper = widget.oper;
    final isSelected = widget.isSelected;
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;
    final isGlowing = isNewGlow || isUpdateGlow;
    final depTheme = widget.depTheme;

    final Color glowColor = isNewGlow ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFF1F5F9);
    List<BoxShadow>? shadows;

    if (isNewGlow) {
      bgColor = const Color(0xFFECFDF5);
      borderColor = const Color(0xFF10B981);
      shadows = [
        BoxShadow(
          color: const Color(0xFF10B981).withValues(alpha: 0.45),
          blurRadius: 12,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isUpdateGlow) {
      bgColor = const Color(0xFFFFFBEB);
      borderColor = const Color(0xFFF59E0B);
      shadows = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
          blurRadius: 12,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isSelected) {
      bgColor = AppColors.secondaryColor.withValues(alpha: 0.08);
      borderColor = AppColors.secondaryColor;
    } else if (_isHovered) {
      bgColor = const Color(0xFFF0FDF4);
      borderColor = const Color(0xFF16A34A);
      shadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onDoubleTap: widget.onDoubleTap,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.004 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isGlowing ? 2.0 : (_isHovered || isSelected ? 1.5 : 1.0),
                  ),
                  boxShadow: shadows,
                ),
                child: Row(
                  children: [
                    // ── CODE ──────────────────────────────────────────────────────
                    SizedBox(
                      width: 72,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isGlowing ? glowColor : const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isGlowing ? glowColor : const Color(0xFFC7D2FE),
                            ),
                            boxShadow: isGlowing
                                ? [
                                    BoxShadow(
                                      color: glowColor.withValues(alpha: 0.45),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '#${oper.operCode}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isGlowing ? Colors.white : const Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── OPERATOR NAME (Clean, Professional & Sleek) ──────────────
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 15,
                            color: isGlowing ? glowColor : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              oper.operName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isGlowing ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
                                letterSpacing: 0.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── DEPARTMENT ────────────────────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Icon(depTheme.icon, size: 12, color: const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              oper.labName.isNotEmpty ? oper.labName.toUpperCase() : 'DEPT #${oper.operDepCd}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ── ACTIONS (Always visible colored icons, no container box) ─
                    SizedBox(
                      width: 96,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onEdit,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: widget.onDelete,
                              borderRadius: BorderRadius.circular(20),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.delete_rounded,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 🌟 Floating Glow Pill Badges (NEWLY ADDED / RECENTLY UPDATED)
              if (isNewGlow)
                Positioned(
                  top: -6,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stars_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'NEWLY ADDED',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isUpdateGlow)
                Positioned(
                  top: -6,
                  right: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'RECENTLY UPDATED',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.3,
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
// CONFIRM DELETE DIALOG (100% IDENTICAL VECTOR ARTWORK CONFIRMATION MODAL)
// ============================================================================
class _ConfirmDeleteDialog extends StatefulWidget {
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteDialog({
    required this.onDelete,
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

            // Vector Illustration (Person throwing red files into trash)
            const SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

            // Red Title Message
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

            // Action Buttons Row (Delete on Left, Cancel on Right)
            Row(
              children: [
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
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.2),
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

// 100% IDENTICAL VECTOR ILLUSTRATION PAINTER (Person throwing red files into trash)
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.10, w * 0.24, h * 0.44), const Radius.circular(2)),
      linePaint,
    );
    canvas.drawLine(Offset(w * 0.38, h * 0.10), Offset(w * 0.38, h * 0.54), linePaint);
    canvas.drawLine(Offset(w * 0.26, h * 0.32), Offset(w * 0.50, h * 0.32), linePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.14, w * 0.20, h * 0.28), const Radius.circular(2)),
      linePaint,
    );

    canvas.drawLine(Offset(w * 0.54, h * 0.72), Offset(w * 0.86, h * 0.72), linePaint);
    final bowlPath = Path()
      ..addArc(Rect.fromLTWH(w * 0.64, h * 0.62, w * 0.14, h * 0.12), 0, math.pi);
    canvas.drawPath(bowlPath, linePaint);

    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.88, w * 0.62, h * 0.08),
      Paint()..color = const Color(0xFFF1F5F9)..style = PaintingStyle.fill,
    );

    final trashRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.56, h * 0.58, w * 0.18, h * 0.32),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      trashRect,
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );

    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(w * 0.60, h * 0.62), Offset(w * 0.60, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.65, h * 0.62), Offset(w * 0.65, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.62), Offset(w * 0.70, h * 0.86), stripePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.55, h * 0.55, w * 0.20, h * 0.06), const Radius.circular(3)),
      Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.fill,
    );

    final legLeft = Path()
      ..moveTo(w * 0.38, h * 0.56)
      ..lineTo(w * 0.36, h * 0.88)
      ..lineTo(w * 0.40, h * 0.88)
      ..lineTo(w * 0.42, h * 0.56)
      ..close();
    final legRight = Path()
      ..moveTo(w * 0.44, h * 0.56)
      ..lineTo(w * 0.47, h * 0.88)
      ..lineTo(w * 0.51, h * 0.88)
      ..lineTo(w * 0.46, h * 0.56)
      ..close();
    final pantsPaint = Paint()..color = const Color(0xFF1E293B)..style = PaintingStyle.fill;
    canvas.drawPath(legLeft, pantsPaint);
    canvas.drawPath(legRight, pantsPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.46, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );

    final torsoPath = Path()
      ..moveTo(w * 0.39, h * 0.38)
      ..lineTo(w * 0.47, h * 0.38)
      ..lineTo(w * 0.45, h * 0.56)
      ..lineTo(w * 0.38, h * 0.56)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill);

    final skinPaint = Paint()..color = const Color(0xFFFED7AA)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.43, h * 0.31), w * 0.05, skinPaint);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.43, h * 0.30), radius: w * 0.055), math.pi, math.pi, true, Paint()..color = const Color(0xFF0F172A));

    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.40, w * 0.10, h * 0.08), Paint()..color = const Color(0xFFEF4444));

    final envPaint = Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(w * 0.54, h * 0.42);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();

    canvas.save();
    canvas.translate(w * 0.58, h * 0.49);
    canvas.rotate(-0.25);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WIDGET (PREMIUM CONFETTI BURST + RIPPLE ANIMATION)
// ============================================================================
enum ButtonStatus { idle, loading, success }

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
    this.idleBackgroundColor = AppColors.secondaryColor,
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

// 100% IDENTICAL ADD OPERATOR LOGO WIDGET (IMAGE 2 - ID BADGE ICON)
class _AddOperatorLogo extends StatelessWidget {
  const _AddOperatorLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/add_operator_logo.png',
      width: 28,
      height: 28,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

// HEADER LOGO WIDGET (100% IDENTICAL TO USER IMAGE 2, DIRECT ON PLAIN WHITE SCREEN, NO BOX, NO BORDERS)
class _HeaderLogo extends StatelessWidget {
  const _HeaderLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/operator_master_header_logo.png',
      width: 56,
      height: 56,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

// ============================================================================
// ============================================================================
// MODERN CIRCULAR GAUGE KPI CARD WIDGET (OPERATION MASTER STYLE - PINK & CYAN)
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
        width: 122,
        height: 64,
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                  // Circular Arc Gauge with Neon Ambient Glow
                  SizedBox(
                    width: 42,
                    height: 38,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(42, 38),
                          painter: _CircularGaugePainter(
                            progress: widget.progress,
                            gradientColors: widget.gradientColors,
                            trackColor: effectiveTrackColor,
                            strokeWidth: 2.8,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.value,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
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
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF475569),
                              letterSpacing: 0.45,
                              height: 1.0,
                            ),
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
    this.strokeWidth = 2.8,
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

      // Soft Ambient Neon Glow Behind Arc
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

      // Crisp Gradient Active Arc
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






