import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../services/operation_service.dart';

// ============================================================================
// MAIN PAGE: OperationMasterPage (Top Workbench + Data Sheet Grid Layout)
// ============================================================================
class OperationMasterPage extends StatefulWidget {
  final OperationService? operationService;

  const OperationMasterPage({super.key, this.operationService});

  @override
  State<OperationMasterPage> createState() => _OperationMasterPageState();
}

class _OperationMasterPageState extends State<OperationMasterPage> {
  late final OperationService _service;

  // Global State Variables
  List<OperationMaster> _operations = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Search & Filter State
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Form State
  bool _isEditing = false;
  int _formOmCode = 1;
  final TextEditingController _descCtrl = TextEditingController();
  final FocusNode _descFocusNode = FocusNode();
  final TextEditingController _rateCtrl = TextEditingController(text: '0.00');
  final FocusNode _rateFocusNode = FocusNode();
  bool _isSaveSuccess = false;

  int? _selectedRowCode;
  String? _buttonValidationMsg;
  Timer? _validationTimer;

  // Glowing Entry Highlight State (New & Updated)
  int? _highlightedOmCode;
  bool _isHighlightedEdit = false;
  Timer? _highlightTimer;

  void _highlightOperationRow(int code, {bool isEdit = false}) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedOmCode = code;
      _isHighlightedEdit = isEdit;
      _selectedRowCode = code;
    });

    // Auto-deselect and remove glow highlight after 3.5 seconds
    _highlightTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          if (_highlightedOmCode == code) {
            _highlightedOmCode = null;
            _isHighlightedEdit = false;
          }
          if (_selectedRowCode == code) {
            _selectedRowCode = null;
          }
        });
      }
    });
  }

  // Table Scroll Controller for auto-scroll
  final ScrollController _tableScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _service = widget.operationService ?? OperationService();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _validationTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _descCtrl.dispose();
    _descFocusNode.dispose();
    _rateCtrl.dispose();
    _rateFocusNode.dispose();
    _tableScrollCtrl.dispose();
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
    setState(() {
      _searchQuery = _searchCtrl.text.trim().toLowerCase();
    });
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        _service.fetchOperations(),
        _service.fetchNextCode(),
      ]);

      if (!mounted) return;

      setState(() {
        _operations = results[0] as List<OperationMaster>;
        _formOmCode = results[1] as int;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _populateFormForEdit(OperationMaster oper) {
    setState(() {
      _isEditing = true;
      _selectedRowCode = oper.omCode;
      _formOmCode = oper.omCode;
      _descCtrl.text = oper.omDesc;
      _rateCtrl.text = oper.omFixRate.toStringAsFixed(2);
    });
    _descFocusNode.requestFocus();
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _selectedRowCode = null;
      _buttonValidationMsg = null;
      _descCtrl.clear();
      _rateCtrl.text = '0.00';
    });
    _service.fetchNextCode().then((code) {
      if (mounted && !_isEditing) {
        setState(() => _formOmCode = code);
      }
    });
  }

  Future<void> _submitForm() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _showButtonValidation('Please enter an operation description');
      _descFocusNode.requestFocus();
      return;
    }

    final rateText = _rateCtrl.text.trim();
    final rate = double.tryParse(rateText);
    if (rate == null || rate < 0) {
      _showButtonValidation('Please enter a valid fixed rate (>= 0)');
      _rateFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    try {
      bool success = false;
      if (_isEditing) {
        success = await _service.updateOperation(_formOmCode, desc, rate);
      } else {
        success = await _service.createOperation(_formOmCode, desc, rate);
      }

      if (!mounted) return;

      if (success) {
        final savedCode = _formOmCode;
        final wasEditing = _isEditing;
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });

        // Fast, crisp animation feedback directly on Save/Update button
        await Future.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        _clearForm();

        // Refresh silently without showing shimmer loading state
        await _refreshDataSilently();
        setState(() {
          _isSaveSuccess = false;
        });

        // Auto-scroll to newly created/updated operation row and trigger glowing highlight
        _scrollToOperationCode(savedCode);
        _highlightOperationRow(savedCode, isEdit: wasEditing);
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save operation record.');
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

  // Silent refresh without shimmer loading screen
  Future<void> _refreshDataSilently() async {
    try {
      final results = await Future.wait([
        _service.fetchOperations(),
        _service.fetchNextCode(),
      ]);

      if (!mounted) return;

      setState(() {
        _operations = results[0] as List<OperationMaster>;
        _formOmCode = results[1] as int;
      });
    } catch (_) {}
  }

  // Auto-scroll table to targeted operation code
  void _scrollToOperationCode(int omCode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tableScrollCtrl.hasClients) return;
      final list = _filteredOperations;
      final idx = list.indexWhere((o) => o.omCode == omCode);
      if (idx < 0) return;
      final targetOffset = idx * 47.0;
      final maxScroll = _tableScrollCtrl.position.maxScrollExtent;
      _tableScrollCtrl.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      setState(() => _selectedRowCode = omCode);
    });
  }

  Future<void> _deleteOperation(OperationMaster oper) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () => _service.deleteOperation(oper.omCode),
      ),
    );

    if (deleted == true) {
      if (_selectedRowCode == oper.omCode) {
        _clearForm();
      }
      await _refreshDataSilently();
    }
  }

  List<OperationMaster> get _filteredOperations {
    if (_searchQuery.isEmpty) return _operations;
    return _operations.where((o) {
      final codeStr = o.omCode.toString();
      final descStr = o.omDesc.toLowerCase();
      final rateStr = o.omFixRate.toString();
      return codeStr.contains(_searchQuery) ||
          descStr.contains(_searchQuery) ||
          rateStr.contains(_searchQuery);
    }).toList();
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _OperationExportModalDialog(
        operations: _filteredOperations,
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
                    // 1. TOP GLASS HEADER & METRIC BANNER
                    _buildTopHeaderBar(),
                    const SizedBox(height: 16),

                    // 2. MAIN BODY (TOP WORKBENCH + BOTTOM DATA GRID DESK)
                    Expanded(
                      child: _isLoading
                          ? _buildShimmerLoadingState()
                          : _errorMessage != null
                              ? _buildErrorState()
                              : Column(
                                  children: [
                                    // TOP HORIZONTAL QUICK-FORM WORKBENCH
                                    _buildHorizontalFormWorkbench(),
                                    const SizedBox(height: 18),

                                    // BOTTOM FULL-WIDTH MASTER DATA SHEET GRID
                                    Expanded(
                                      child: _buildMasterDataGridDesk(),
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
  // 1. TOP GLASS HEADER & METRIC BANNER
  // ============================================================================
  Widget _buildTopHeaderBar() {
    final totalOps = _operations.length;
    final avgRate = _operations.isEmpty
        ? 0.0
        : _operations.map((e) => e.omFixRate).reduce((a, b) => a + b) / totalOps;

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 920;
              final isVeryNarrow = constraints.maxWidth < 750;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo + Title & Subtitle
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/operation_master_header_logo.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Operation Master',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Configure plant production operations & fixed rates',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Indicator KPI Cards (Image 3 Style) & Export Controls (Right Aligned)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // KPI Card 1: Total Operations (Electric Cyan / Royal Blue Gradient Indicator)
                      if (!isVeryNarrow) ...[
                        _buildKpiCard(
                          label: 'TOTAL OPS',
                          value: totalOps.toString(),
                          progress: totalOps > 0 ? (totalOps / 20.0).clamp(0.15, 1.0) : 0.0,
                          gradientColors: const [
                            Color(0xFF2563EB), // Royal Blue
                            Color(0xFF06B6D4), // Cyan Teal
                          ],
                        ),
                        const SizedBox(width: 10),
                      ],

                      // KPI Card 2: Avg Fixed Rate (Vibrant Orange / Amber Gradient Indicator)
                      if (!isNarrow) ...[
                        _buildKpiCard(
                          label: 'AVG. RATE',
                          value: '₹${avgRate.toStringAsFixed(1)}',
                          progress: avgRate > 0 ? (avgRate / 250.0).clamp(0.15, 1.0) : 0.0,
                          gradientColors: const [
                            Color(0xFFF97316), // Warm Orange
                            Color(0xFFFBBF24), // Amber Gold
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Standardized Export Button (ALWAYS FULLY VISIBLE)
                      _AnimatedExportButton(onPressed: _openExportModal),
                    ],
                  ),
                ],
              );
            },
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
  // 2. HORIZONTAL QUICK-FORM WORKBENCH (TOP GLASS CARD - SLEEK & COMPACT)
  // ============================================================================
  Widget _buildHorizontalFormWorkbench() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/add_operation_entry_logo.png',
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
              const SizedBox(width: 12),
              Text(
                _isEditing ? 'Edit Operation #$_formOmCode' : 'Add New Operation Entry',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black),
              ),
              const Spacer(),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.neutralDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Cancel Edit',
                  onPressed: _clearForm,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Field 1: OM_CODE (Auto Read-only Badge)
              SizedBox(
                width: 105,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3)),
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
                          const Icon(Icons.lock_outline_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text(
                            '#$_formOmCode',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Field 2: OM_DESC (Operation Description)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('OPERATION DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3)),
                        Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _descCtrl,
                        focusNode: _descFocusNode,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Enter operation name (e.g. CNC MILLING)',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.precision_manufacturing_rounded, size: 15, color: Color(0xFF6366F1)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Field 3: OM_FIXRATE (Fixed Rate)
              SizedBox(
                width: 155,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('FIXED RATE (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569), letterSpacing: 0.3)),
                        Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _rateCtrl,
                        focusNode: _rateFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF064E3B)),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                            child: Text('₹', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), fontSize: 13)),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 18),

              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(' ', style: TextStyle(fontSize: 10.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Minimal Reset Ghost Button
                      SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: _clearForm,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Reset (Esc)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Sleek Primary Save / Update Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
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
                                  const Icon(Icons.info_outline_rounded, color: Colors.white, size: 12),
                                  const SizedBox(width: 5),
                                  Text(
                                    _buttonValidationMsg!,
                                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          SizedBox(
                            height: 38,
                            child: AnimatedSuccessButton(
                              status: _isSubmitting
                                  ? ButtonStatus.loading
                                  : (_isSaveSuccess ? ButtonStatus.success : ButtonStatus.idle),
                              onPressed: _isSubmitting ? null : _submitForm,
                              idleText: _isEditing ? 'Update Operation' : 'Save Operation',
                              loadingText: 'Saving...',
                              successText: _isEditing ? 'Updated!' : 'Saved!',
                              idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                              idleBackgroundColor: AppColors.secondaryColor,
                              successBackgroundColor: const Color(0xFF10B981),
                              height: 38,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. MASTER DATA GRID (FULL-WIDTH BOTTOM DESK - SLEEK & COMPACT)
  // ============================================================================
  Widget _buildMasterDataGridDesk() {
    final displayList = _filteredOperations;

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
          // Table Card Header - Image 2 Logo Direct on Plain White Screen (No Borders, No Box)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/operation_directory_sheet_logo.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Operation Master Directory Sheet',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const Spacer(),
                // Search Field Moved to Table Header
                Container(
                  constraints: const BoxConstraints(maxWidth: 240, minWidth: 140),
                  height: 34,
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark),
                    decoration: InputDecoration(
                      hintText: 'Search operations... (Ctrl+K)',
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // Responsive Table Body Grid (LayoutBuilder with Min Width & Horizontal Scroll)
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = math.max(constraints.maxWidth, 780.0);

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          // Column Header Bar (Proper Alignment Matching Data Rows)
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
                                  flex: 5,
                                  child: Row(
                                    children: [
                                      Icon(Icons.handshake_rounded, size: 13, color: Color(0xFF10B981)),
                                      SizedBox(width: 5),
                                      Text('OPERATION DESCRIPTION', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                SizedBox(
                                  width: 140,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.payments_rounded, size: 12, color: Color(0xFFF59E0B)),
                                      SizedBox(width: 5),
                                      Text('FIXED RATE (₹)', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
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

                          // Data Rows ListView
                          Expanded(
                            child: displayList.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
                                        const SizedBox(height: 6),
                                        Text(
                                          'No operations found matching search criteria',
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
                                      final isSelected = _selectedRowCode == oper.omCode;
                                      final isGlowing = _highlightedOmCode == oper.omCode;
                                      final isGlowingEdit = isGlowing && _isHighlightedEdit;
                                      final isGlowingNew = isGlowing && !_isHighlightedEdit;
                                      final avatarGradient = _getAvatarGradient(oper.omDesc, oper.omCode);

                                      return _AnimatedOperationRow(
                                        key: ValueKey<int>(oper.omCode),
                                        oper: oper,
                                        isSelected: isSelected,
                                        isGlowing: isGlowing,
                                        isGlowingEdit: isGlowingEdit,
                                        isGlowingNew: isGlowingNew,
                                        avatarGradient: avatarGradient,
                                        onTap: () {
                                          setState(() {
                                            _selectedRowCode = oper.omCode;
                                          });
                                        },
                                        onDoubleTap: () => _populateFormForEdit(oper),
                                        onEdit: () => _populateFormForEdit(oper),
                                        onDelete: () => _deleteOperation(oper),
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

  // Shimmer & Error Loading States
  Widget _buildShimmerLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.secondaryColor),
          const SizedBox(height: 16),
          Text(
            'Loading Operation Master records...',
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
        margin: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(
              'Error Loading Data: $_errorMessage',
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED EXPORT BUTTON (WITH 1-LAP ORBIT ROTATION BEAM)
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
// STANDARDIZED DUAL-PANE EXPORT MODAL DIALOG (MATCHES IMAGE 3 STANDARD 100%)
// ============================================================================
// ============================================================================
// STANDARDIZED DUAL-PANE EXPORT MODAL DIALOG (100% FROM PROJECT MASTER SCREEN)
// ============================================================================
class _OperationExportModalDialog extends StatefulWidget {
  final List<OperationMaster> operations;

  const _OperationExportModalDialog({required this.operations});

  @override
  State<_OperationExportModalDialog> createState() => _OperationExportModalDialogState();
}

class _OperationExportModalDialogState extends State<_OperationExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedOmCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedOmCodes = widget.operations.map((o) => o.omCode).toSet();
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

  List<OperationMaster> get _filteredPreviewOperations {
    if (_modalSearchQuery.isEmpty) return widget.operations;
    return widget.operations.where((o) {
      final codeMatch = o.omCode.toString().contains(_modalSearchQuery);
      final descMatch = o.omDesc.toLowerCase().contains(_modalSearchQuery);
      final rateMatch = o.omFixRate.toString().contains(_modalSearchQuery);
      return codeMatch || descMatch || rateMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewOperations;
    if (preview.isEmpty) return false;
    return preview.every((o) => _selectedOmCodes.contains(o.omCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewOperations;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final o in preview) {
          _selectedOmCodes.remove(o.omCode);
        }
      } else {
        for (final o in preview) {
          _selectedOmCodes.add(o.omCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedOmCodes.isEmpty) {
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

  Future<void> _openFileInSystemExplorer(String filePath) async {
    if (Platform.isWindows) {
      try {
        await Process.run('explorer.exe', ['/select,', filePath]);
        return;
      } catch (_) {}
    }
    try {
      final fileUri = Uri.file(filePath);
      await launchUrl(fileUri);
    } catch (_) {}
  }

  Future<void> _finalizeFileAndComplete() async {
    try {
      final selectedList = widget.operations
          .where((o) => _selectedOmCodes.contains(o.omCode))
          .toList();

      Directory? downloadsDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          downloadsDir = Directory('$userProfile\\Downloads');
        }
      }
      downloadsDir ??= await getDownloadsDirectory();
      downloadsDir ??= await getApplicationDocumentsDirectory();

      if (!downloadsDir.existsSync()) {
        downloadsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'OperationMaster_Export_$timestamp.$extension';
      final filePath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Operation Master');
        final excel_pkg.Sheet sheet = excel['Operation Master'];

        // Set Generous Column Widths (Prevents text clipping)
        sheet.setColumnWidth(0, 20.0); // OPERATION CODE
        sheet.setColumnWidth(1, 42.0); // OPERATION DESCRIPTION
        sheet.setColumnWidth(2, 26.0); // FIXED RATE

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

        // Set Header Row Height & Append Headers
        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('OPERATION CODE'),
          excel_pkg.TextCellValue('OPERATION DESCRIPTION'),
          excel_pkg.TextCellValue('FIXED RATE (₹)'),
        ]);

        for (int col = 0; col < 3; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        // Append Data Rows with Heights & Styles
        for (int i = 0; i < selectedList.length; i++) {
          final o = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(o.omCode),
            excel_pkg.TextCellValue(o.omDesc),
            excel_pkg.TextCellValue('₹${o.omFixRate.toStringAsFixed(2)}'),
          ]);

          for (int col = 0; col < 3; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
        }
      } else {
        final pdfDoc = pw.Document();
        final fontData = await rootBundle.load('assets/fonts/Inter-Regular.ttf').catchError((_) => ByteData(0));
        final ttf = fontData.lengthInBytes > 0 ? pw.Font.ttf(fontData) : null;

        final headers = ['Operation Code', 'Operation Description', 'Fixed Rate (Rs.)'];
        final data = selectedList.map((o) => [
          '#${o.omCode}',
          o.omDesc,
          o.omFixRate.toStringAsFixed(2),
        ]).toList();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            maxPages: 1000,
            header: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Operation Master Register Report',
                    style: pw.TextStyle(
                      font: ttf,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: const PdfColor.fromInt(0xFF0C3B2E),
                    ),
                  ),
                  pw.Text(
                    'Total Records: ${selectedList.length}',
                    style: pw.TextStyle(font: ttf, fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            footer: (pw.Context ctx) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(font: ttf, fontSize: 9, color: PdfColors.grey600),
              ),
            ),
            build: (pw.Context ctx) => [
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: data,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(
                  font: ttf,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0C3B2E),
                ),
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(font: ttf, fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
              ),
            ],
          ),
        );
        final pdfBytes = await pdfDoc.save();
        await file.writeAsBytes(pdfBytes);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();

        await _openFileInSystemExplorer(filePath);
      }
    } catch (e) {
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
                                    Text('Export Operation Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
            '${_selectedOmCodes.length} of ${widget.operations.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewOperations;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No operation records found',
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
                  Expanded(child: Text('OPERATION DESCRIPTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 120, child: Text('FIXED RATE (₹)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final o = previewList[idx];
                  final isSelected = _selectedOmCodes.contains(o.omCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedOmCodes.remove(o.omCode);
                        } else {
                          _selectedOmCodes.add(o.omCode);
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
                                    _selectedOmCodes.add(o.omCode);
                                  } else {
                                    _selectedOmCodes.remove(o.omCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '#${o.omCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              o.omDesc,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              '₹${o.omFixRate.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
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

// ============================================================================
// CONFIRM DELETE DIALOG (WITH IN-BUTTON ANIMATED DELETE CONFIRMATION & VECTOR ILLUSTRATION)
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

            // Red Message Title matching project standard
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
// MODERN & FASHIONED CIRCULAR GAUGE KPI CARD WIDGET (BLUE & ORANGE / AMBER)
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
        width: 118,
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
                  // Circular Arc Gauge with Neon Ambient Glow (Generous 42x42 Box with 11px Padding)
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
                          padding: const EdgeInsets.symmetric(horizontal: 11),
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
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

// Top-level Operation Initial Avatar Gradient Helper (Unique Color Palette for Every Entry)
List<Color> _getAvatarGradient(String desc, int omCode) {
  int hash = omCode * 17;
  for (int i = 0; i < desc.length; i++) {
    hash = (hash * 31 + desc.codeUnitAt(i)) & 0xFFFFFF;
  }
  final mod = (hash + omCode * 7) % 12;
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

// Professional Enterprise Operation Category Emblem Builder (Clean Neutral Titanium/Slate Aesthetic)
Widget _buildOperationLogo(String desc, {bool isHovered = false}) {
  final clean = desc.toLowerCase();
  IconData iconData;

  if (clean.contains('dye') || clean.contains('color') || clean.contains('print')) {
    iconData = Icons.palette_outlined;
  } else if (clean.contains('cotton') || clean.contains('fabric') || clean.contains('yarn') || clean.contains('textile') || clean.contains('cloth') || clean.contains('weaving') || clean.contains('sew')) {
    iconData = Icons.layers_outlined;
  } else if (clean.contains('test') || clean.contains('inspect') || clean.contains('lab') || clean.contains('ndt') || clean.contains('check') || clean.contains('quality')) {
    iconData = Icons.verified_outlined;
  } else if (clean.contains('laser') || clean.contains('plasma') || clean.contains('cut') || clean.contains('bevel')) {
    iconData = Icons.content_cut_rounded;
  } else if (clean.contains('mill') || clean.contains('drill') || clean.contains('lathe') || clean.contains('cnc')) {
    iconData = Icons.precision_manufacturing_outlined;
  } else if (clean.contains('weld') || clean.contains('solder')) {
    iconData = Icons.hardware_outlined;
  } else if (clean.contains('bend') || clean.contains('press') || clean.contains('hydraulic')) {
    iconData = Icons.compress_rounded;
  } else if (clean.contains('sandblast') || clean.contains('surface') || clean.contains('coat') || clean.contains('paint')) {
    iconData = Icons.brush_outlined;
  } else if (clean.contains('heat') || clean.contains('quench') || clean.contains('temper')) {
    iconData = Icons.local_fire_department_outlined;
  } else if (clean.contains('pack') || clean.contains('box') || clean.contains('ship')) {
    iconData = Icons.inventory_2_outlined;
  } else if (clean.contains('assembly') || clean.contains('assemble')) {
    iconData = Icons.extension_outlined;
  } else if (clean.contains('manufacture')) {
    iconData = Icons.domain_rounded;
  } else {
    iconData = Icons.build_outlined;
  }

  return AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: 24,
    height: 24,
    decoration: BoxDecoration(
      color: isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isHovered ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    alignment: Alignment.center,
    child: Icon(
      iconData,
      size: 13,
      color: isHovered ? const Color(0xFF0F172A) : const Color(0xFF475569),
    ),
  );
}

// Animated & Interactive Operation Data Row Widget (With Hovering, Glowing Halos & Unique Initial Color Logos)
class _AnimatedOperationRow extends StatefulWidget {
  final OperationMaster oper;
  final bool isSelected;
  final bool isGlowing;
  final bool isGlowingEdit;
  final bool isGlowingNew;
  final List<Color> avatarGradient;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedOperationRow({
    super.key,
    required this.oper,
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
  State<_AnimatedOperationRow> createState() => _AnimatedOperationRowState();
}

class _AnimatedOperationRowState extends State<_AnimatedOperationRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final oper = widget.oper;
    final isSelected = widget.isSelected;
    final isGlowing = widget.isGlowing;
    final isGlowingEdit = widget.isGlowingEdit;

    // Standardized Glowing Aura Colors (Emerald Green for New, Amber / Orange for Edit)
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
                // Column 1: Code Badge + Glowing Star Badge (75px width + FittedBox guarantees 0 overflow)
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
                            '#${oper.omCode}',
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

                // Column 2: Operation Logo + Description Text with Tooltip
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      _buildOperationLogo(oper.omDesc, isHovered: _isHovered),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Tooltip(
                          message: oper.omDesc,
                          waitDuration: const Duration(milliseconds: 600),
                          child: Text(
                            oper.omDesc,
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
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Column 3: Fixed Rate Badge Pill (Clean & Proportional)
                SizedBox(
                  width: 140,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: oper.omFixRate > 0
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: oper.omFixRate > 0
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.currency_rupee_rounded,
                            size: 11,
                            color: oper.omFixRate > 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 1),
                          Text(
                            oper.omFixRate.toStringAsFixed(2),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: oper.omFixRate > 0 ? const Color(0xFF047857) : const Color(0xFF64748B),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Column 4: Actions Buttons (Edit & Delete - Exact match with Department Master)
                SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Operation',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      _ActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Operation',
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
// ANIMATED SUCCESS BUTTON WIDGET (PREMIUM CONFETTI BURST + RIPPLE ANIMATION)
// ============================================================================



// 100% IDENTICAL VECTOR ILLUSTRATION PAINTER FOR DELETE DIALOG (Person throwing files into red trash bin)
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Light Grey Interior Room Lines (Window, Picture Frame, Table)
    final linePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Left Window Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.10, w * 0.24, h * 0.44), const Radius.circular(2)),
      linePaint,
    );
    canvas.drawLine(Offset(w * 0.38, h * 0.10), Offset(w * 0.38, h * 0.54), linePaint);
    canvas.drawLine(Offset(w * 0.26, h * 0.32), Offset(w * 0.50, h * 0.32), linePaint);

    // Right Picture Frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.14, w * 0.20, h * 0.28), const Radius.circular(2)),
      linePaint,
    );

    // Right Side Table & Fruit Bowl
    canvas.drawLine(Offset(w * 0.54, h * 0.72), Offset(w * 0.86, h * 0.72), linePaint);
    final bowlPath = Path()
      ..addArc(Rect.fromLTWH(w * 0.64, h * 0.62, w * 0.14, h * 0.12), 0, math.pi);
    canvas.drawPath(bowlPath, linePaint);

    // 2. Ground Oval Shadow on Floor
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.88, w * 0.62, h * 0.08),
      Paint()..color = const Color(0xFFF1F5F9)..style = PaintingStyle.fill,
    );

    // 3. Red Trash Container (Right Side)
    final trashRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.56, h * 0.58, w * 0.18, h * 0.32),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      trashRect,
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );
    // Vertical stripe grooves on trash bin
    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(w * 0.60, h * 0.62), Offset(w * 0.60, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.65, h * 0.62), Offset(w * 0.65, h * 0.86), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.62), Offset(w * 0.70, h * 0.86), stripePaint);

    // Trash bin rim top
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.55, h * 0.55, w * 0.20, h * 0.06), const Radius.circular(3)),
      Paint()..color = const Color(0xFFDC2626)..style = PaintingStyle.fill,
    );

    // 4. Character Person (Standing Left Side)
    // Dark Navy Trousers
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

    // Red Shoes
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.46, h * 0.86, w * 0.08, h * 0.04), const Radius.circular(2)),
      Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill,
    );

    // Coral Pink Top / Shirt
    final torsoPath = Path()
      ..moveTo(w * 0.39, h * 0.38)
      ..lineTo(w * 0.47, h * 0.38)
      ..lineTo(w * 0.45, h * 0.56)
      ..lineTo(w * 0.38, h * 0.56)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill);

    // Skin Tone Arms & Head
    final skinPaint = Paint()..color = const Color(0xFFFED7AA)..style = PaintingStyle.fill;
    // Head & Neck
    canvas.drawCircle(Offset(w * 0.43, h * 0.31), w * 0.05, skinPaint);
    // Dark Hair
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.43, h * 0.30), radius: w * 0.055), math.pi, math.pi, true, Paint()..color = const Color(0xFF0F172A));

    // Arms holding red folder
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.40, w * 0.10, h * 0.08), Paint()..color = const Color(0xFFEF4444));

    // 5. Red Floating Envelopes / Files Falling into Trash
    final envPaint = Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill;

    // Envelope 1 (Mid Air)
    canvas.save();
    canvas.translate(w * 0.54, h * 0.42);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();

    // Envelope 2 (Lower Air)
    canvas.save();
    canvas.translate(w * 0.58, h * 0.49);
    canvas.rotate(-0.25);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


