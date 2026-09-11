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
import '../services/head_master_service.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// MAIN PAGE: HeadMasterPage (Costing Head Workstation Module)
// ============================================================================
class HeadMasterPage extends StatefulWidget {
  const HeadMasterPage({super.key});

  @override
  State<HeadMasterPage> createState() => _HeadMasterPageState();
}

class _HeadMasterPageState extends State<HeadMasterPage> {
  // Data State
  List<HeadMasterItem> _heads = [];
  List<HeadMasterItem> _filteredHeads = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Controllers & Focus Nodes (Persistent Lifecycle Members)
  final FocusNode _pageKeyFocusNode = FocusNode();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();

  // Form State
  bool _isEditing = false;
  int _formLocCode = 1;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final TextEditingController _seriesCtrl = TextEditingController();
  final FocusNode _seriesFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  int? _selectedRowCode;

  String? _buttonValidationMsg;
  Timer? _validationTimer;
  Timer? _searchDebounceTimer;
  int? _recentlySavedCode;
  int? _recentlyUpdatedCode;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchInputChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _glowTimer?.cancel();
    _pageKeyFocusNode.dispose();
    _searchCtrl.removeListener(_onSearchInputChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _seriesCtrl.dispose();
    _seriesFocusNode.dispose();
    _tableScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        HeadMasterService.fetchAllHeads(forceRefresh: true),
        HeadMasterService.fetchNextCode(),
      ]);

      if (mounted) {
        setState(() {
          _heads = results[0] as List<HeadMasterItem>;
          _filteredHeads = List.from(_heads);
          _formLocCode = results[1] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to connect to Head Master API: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final results = await Future.wait([
        HeadMasterService.fetchAllHeads(forceRefresh: true),
        HeadMasterService.fetchNextCode(),
      ]);

      if (!mounted) return;

      setState(() {
        _heads = results[0] as List<HeadMasterItem>;
        _formLocCode = results[1] as int;
        _applySearchFilterDirectly();
      });
    } catch (_) {}
  }

  void _onSearchInputChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) {
        _applySearchFilterDirectly();
      }
    });
  }

  void _applySearchFilterDirectly() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredHeads = List.from(_heads);
      } else {
        _filteredHeads = _heads.where((h) {
          return h.locCode.toString().contains(query) ||
              h.location.toLowerCase().contains(query) ||
              h.locSeries.toLowerCase().contains(query);
        }).toList();
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

  void _populateFormForEdit(HeadMasterItem item) {
    setState(() {
      _isEditing = true;
      _selectedRowCode = item.locCode;
      _formLocCode = item.locCode;
      _nameCtrl.text = item.location;
      _seriesCtrl.text = item.locSeries;
      _buttonValidationMsg = null;
    });
    _nameFocusNode.requestFocus();
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _selectedRowCode = null;
      _buttonValidationMsg = null;
      _nameCtrl.clear();
      _seriesCtrl.clear();
    });
    HeadMasterService.fetchNextCode().then((code) {
      if (mounted && !_isEditing) {
        setState(() => _formLocCode = code);
      }
    });
  }

  Future<void> _submitForm() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showButtonValidation('Costing Head Name is required!');
      _nameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final item = HeadMasterItem(
      locCode: _formLocCode,
      location: name,
      mode: 'COSTING HEAD',
      locSeries: _seriesCtrl.text.trim(),
    );

    final wasEditing = _isEditing;
    bool success = false;
    if (_isEditing) {
      success = await HeadMasterService.updateHead(item);
    } else {
      success = await HeadMasterService.saveHead(item);
    }

    if (!mounted) return;

    if (success) {
      final savedCode = _formLocCode;
      setState(() {
        _isSubmitting = false;
        _isSaveSuccess = true;
        if (wasEditing) {
          _recentlyUpdatedCode = savedCode;
          _recentlySavedCode = null;
        } else {
          _recentlySavedCode = savedCode;
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

      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      _clearForm();
      await _refreshDataSilently();
      setState(() {
        _isSaveSuccess = false;
      });
      _scrollToHeadCode(savedCode);
    } else {
      setState(() => _isSubmitting = false);
      _showButtonValidation('Failed to save Head Master record.');
    }
  }

  void _scrollToHeadCode(int code) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tableScrollCtrl.hasClients) return;
      final idx = _filteredHeads.indexWhere((h) => h.locCode == code);
      if (idx < 0) return;
      final targetOffset = idx * 44.0;
      final maxScroll = _tableScrollCtrl.position.maxScrollExtent;
      _tableScrollCtrl.animateTo(
        targetOffset.clamp(0.0, maxScroll),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      setState(() => _selectedRowCode = code);
    });
  }

  Future<void> _deleteHead(HeadMasterItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        itemCode: item.locCode,
        itemName: item.location,
        onDelete: () async {
          await HeadMasterService.deleteHead(item.locCode);
          return true;
        },
      ),
    );

    if (confirmed == true) {
      if (_selectedRowCode == item.locCode) {
        _clearForm();
      }
      await _refreshDataSilently();
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => _HeadExportModalDialog(heads: _heads),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;

      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyK) {
        _searchFocusNode.requestFocus();
      }

      if ((isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyS) ||
          event.logicalKey == LogicalKeyboardKey.f1) {
        if (!_isSubmitting) _submitForm();
      }

      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _clearForm();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
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

                    // 2. UP-DOWN VERTICAL WORKSPACE LAYOUT
                    // TOP PANE: ENTRY FORM CARD (UP)
                    _buildTopEntryPane(),
                    const SizedBox(height: 14),

                    // BOTTOM PANE: INTERACTIVE MASTER DATA GRID (DOWN)
                    Expanded(
                      child: RepaintBoundary(
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0F382C),
                                ),
                              )
                            : _errorMessage != null
                                ? _buildErrorState()
                                : _buildRightDataTablePane(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SCREEN HEADER TOOLBAR (WITH 3D LOGO & ANIMATED ORBIT EXPORT BUTTON)
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
          // 100% IDENTICAL IMAGE 2 VECTOR LOGO (MODERN CORPORATE HEADQUARTERS ARCHITECTURE)
          const _HeadMasterHeaderLogoWidget(size: 56.0),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Head Master',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_heads.length} Costing Heads Registered',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF047857),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search Bar Input
          SizedBox(
            width: 240,
            height: 36,
            child: RepaintBoundary(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search heads... (Ctrl+K)',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applySearchFilterDirectly();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF0F382C), width: 1.5)),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ANIMATED ORBIT EXPORT BUTTON (CIRCULATING LIGHT BEAM)
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP PANE: HIGH-DENSITY ENTRY FORM (UP SECTION)
  // --------------------------------------------------------------------------
  Widget _buildTopEntryPane() {
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const _AddCostingHeadFormLogoWidget(size: 32.0),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Edit Costing Head' : 'Add Costing Head',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'EDITING #$_formLocCode',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ),
                ],
              ),
            ),

            // Form Inputs Row (Horizontal Layout)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 1. Head Code (Read-Only)
                  SizedBox(
                    width: 140,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'HEAD CODE',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB), letterSpacing: 0.5),
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
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '# CODE: $_formLocCode',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // 2. Costing Head Name (Required)
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'COSTING HEAD NAME',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.5),
                            ),
                            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _nameCtrl,
                            focusNode: _nameFocusNode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'e.g. MATERIAL COST',
                              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // 3. Prefix Series
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.tag_rounded, size: 14, color: Color(0xFFD97706)),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'PREFIX SERIES',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706), letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 38,
                          child: TextField(
                            controller: _seriesCtrl,
                            focusNode: _seriesFocusNode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'e.g. 01, MC',
                              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 4. Action Buttons (Reset & Save/Update)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 110,
                        height: 38,
                        child: OutlinedButton.icon(
                          onPressed: _clearForm,
                          icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
                          label: const Text('Reset (Esc)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 150,
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
                                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
                              idleText: _isEditing ? 'Update Head' : 'Save Head (F1)',
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RIGHT PANE: VIRTUALIZED DATA SHEET GRID
  // --------------------------------------------------------------------------
  Widget _buildRightDataTablePane() {
    if (_filteredHeads.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey.shade400),
              const SizedBox(height: 10),
              Text(
                _searchCtrl.text.isNotEmpty
                    ? 'No costing heads matching "${_searchCtrl.text.trim()}"'
                    : 'No costing head records found.',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = math.max(constraints.maxWidth, 750.0);
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
                      // ── Department-Master Style Column Header Bar ────────────────
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
                              width: 70,
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
                                  Icon(Icons.account_tree_rounded, size: 12, color: Color(0xFF10B981)),
                                  SizedBox(width: 5),
                                  Text('COSTING HEAD NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                                ],
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Icon(Icons.bookmark_rounded, size: 12, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 5),
                                  Text('PREFIX SERIES', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
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

                      // Rows List with Department Master Separated Card Style
                      Expanded(
                        child: ListView.separated(
                          controller: _tableScrollCtrl,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredHeads.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final item = _filteredHeads[index];
                            final isSelected = _selectedRowCode == item.locCode;
                            final isNewGlow = _recentlySavedCode == item.locCode;
                            final isUpdateGlow = _recentlyUpdatedCode == item.locCode;

                            return _HeadTableRowTile(
                              key: ValueKey(item.locCode),
                              item: item,
                              index: index,
                              isSelected: isSelected,
                              isNewGlow: isNewGlow,
                              isUpdateGlow: isUpdateGlow,
                              onEdit: () => _populateFormForEdit(item),
                              onDelete: () => _deleteHead(item),
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
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInitialData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F382C), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED EXPORT BUTTON (CIRCULATING LIGHT BEAM AROUND EDGE)
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
          const Color(0xFF0F382C).withValues(alpha: 0.2),
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
// TABLE ROW TILE
// ============================================================================
// ============================================================================
// ANIMATED HEAD TABLE ROW WIDGET (DEPARTMENT MASTER HOVER PARITY)
// ============================================================================
class _HeadTableRowTile extends StatefulWidget {
  final HeadMasterItem item;
  final int index;
  final bool isSelected;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HeadTableRowTile({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    this.isNewGlow = false,
    this.isUpdateGlow = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_HeadTableRowTile> createState() => _HeadTableRowTileState();
}

class _HeadTableRowTileState extends State<_HeadTableRowTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;
    final isGlowing = isNewGlow || isUpdateGlow;
    final isSelected = widget.isSelected;

    final Color glowColor = isUpdateGlow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
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
                // 🔢 Code Badge (Department Master Badge Style with Hover Switch)
                SizedBox(
                  width: 70,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                            color: !(isGlowing || isSelected || _isHovered)
                                ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                                : Colors.transparent,
                            width: 1.0,
                          ),
                          boxShadow: isGlowing || isSelected || _isHovered
                              ? [
                                  BoxShadow(
                                    color: (isGlowing
                                            ? glowColor
                                            : (_isHovered
                                                ? const Color(0xFF16A34A)
                                                : AppColors.secondaryColor))
                                        .withValues(alpha: 0.32),
                                    blurRadius: 5,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          '#${item.locCode}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: isGlowing || isSelected || _isHovered
                                ? Colors.white
                                : const Color(0xFF6366F1),
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
                const SizedBox(width: 10),

                // Costing Head Name (Clean, professional typography)
                Expanded(
                  flex: 5,
                  child: Text(
                    item.location,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // Prefix Series (Clean typography)
                Expanded(
                  flex: 3,
                  child: Text(
                    item.locSeries.isNotEmpty ? item.locSeries : '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475569).withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),

                // Actions (Department Master Parity Action Buttons)
                SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeadActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Costing Head',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 6),
                      _HeadActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Costing Head',
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
// INTERACTIVE HOVER ACTION BUTTON WIDGET (DEPARTMENT MASTER PARITY)
// ============================================================================
class _HeadActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeadActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_HeadActionButton> createState() => _HeadActionButtonState();
}

class _HeadActionButtonState extends State<_HeadActionButton> {
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
// 100% EXACT & IDENTICAL IMAGE 2 LOGO: LOCATION PIN OFFICE BUILDING
// Direct on plain white screen, no background borders, box, or container frames
// ============================================================================
class _AddCostingHeadFormLogoWidget extends StatelessWidget {
  final double size;
  const _AddCostingHeadFormLogoWidget({this.size = 32.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/add_costing_head_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }
}

// ============================================================================
// 100% EXACT & IDENTICAL IMAGE 2 LOGO: CORPORATE HEADQUARTERS ARCHITECTURE
// Direct on plain screen, no background borders, box, or container frames
// ============================================================================
class _HeadMasterHeaderLogoWidget extends StatelessWidget {
  final double size;
  const _HeadMasterHeaderLogoWidget({this.size = 56.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/head_master_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
      ),
    );
  }
}

class _HoverTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverTactileButton({required this.child, required this.onTap});

  @override
  State<_HoverTactileButton> createState() => _HoverTactileButtonState();
}

class _HoverTactileButtonState extends State<_HoverTactileButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, _isHovered ? -2.5 : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

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

            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

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

    final backWall = Path()
      ..moveTo(w * 0.05, h * 0.10)
      ..lineTo(w * 0.95, h * 0.10)
      ..lineTo(w * 0.95, h * 0.72)
      ..lineTo(w * 0.05, h * 0.72)
      ..close();
    canvas.drawPath(backWall, Paint()..color = const Color(0xFFF1F5F9));

    final floorPath = Path()
      ..moveTo(w * 0.05, h * 0.72)
      ..lineTo(w * 0.95, h * 0.72)
      ..lineTo(w * 0.95, h * 0.92)
      ..lineTo(w * 0.05, h * 0.92)
      ..close();
    canvas.drawPath(floorPath, Paint()..color = const Color(0xFFE2E8F0));

    canvas.drawLine(Offset(w * 0.05, h * 0.72), Offset(w * 0.95, h * 0.72), Paint()..color = const Color(0xFFCBD5E1)..strokeWidth = 2.0);

    final binBody = Path()
      ..moveTo(w * 0.60, h * 0.48)
      ..lineTo(w * 0.82, h * 0.48)
      ..lineTo(w * 0.78, h * 0.88)
      ..lineTo(w * 0.64, h * 0.88)
      ..close();
    final binGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B)],
      ).createShader(Rect.fromLTWH(w * 0.60, h * 0.48, w * 0.22, h * 0.40));
    canvas.drawPath(binBody, binGradient);

    final binLid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.44, w * 0.26, h * 0.06), const Radius.circular(3));
    canvas.drawRRect(binLid, Paint()..color = const Color(0xFFB91C1C));

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.15);
    canvas.drawOval(Rect.fromLTWH(w * 0.62, h * 0.86, w * 0.18, h * 0.06), shadowPaint);

    final skinPaint = Paint()..color = const Color(0xFFFFD1B3);
    final shirtPaint = Paint()..color = const Color(0xFF38BDF8);
    final pantsPaint = Paint()..color = const Color(0xFF1E293B);

    canvas.drawCircle(Offset(w * 0.26, h * 0.26), w * 0.07, skinPaint);
    canvas.drawCircle(Offset(w * 0.24, h * 0.23), w * 0.075, Paint()..color = const Color(0xFF475569));
    canvas.drawCircle(Offset(w * 0.26, h * 0.27), w * 0.062, skinPaint);

    final bodyPath = Path()
      ..moveTo(w * 0.21, h * 0.34)
      ..lineTo(w * 0.32, h * 0.34)
      ..lineTo(w * 0.34, h * 0.60)
      ..lineTo(w * 0.19, h * 0.60)
      ..close();
    canvas.drawPath(bodyPath, shirtPaint);

    canvas.drawRect(Rect.fromLTWH(w * 0.20, h * 0.60, w * 0.06, h * 0.24), pantsPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.27, h * 0.60, w * 0.06, h * 0.24), pantsPaint);

    final armPath = Path()
      ..moveTo(w * 0.30, h * 0.38)
      ..lineTo(w * 0.48, h * 0.32)
      ..lineTo(w * 0.52, h * 0.40)
      ..lineTo(w * 0.32, h * 0.44)
      ..close();
    canvas.drawPath(armPath, shirtPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.37), w * 0.035, skinPaint);

    final filePaint = Paint()..color = Colors.white;
    final fileBorder = Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    canvas.save();
    canvas.translate(w * 0.46, h * 0.36);
    canvas.rotate(-0.2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 16, 22), const Radius.circular(2)), filePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 16, 22), const Radius.circular(2)), fileBorder);
    canvas.drawRect(Rect.fromLTWH(3, 4, 10, 2), Paint()..color = const Color(0xFFEF4444));
    canvas.drawRect(Rect.fromLTWH(3, 8, 8, 1.5), Paint()..color = const Color(0xFF94A3B8));
    canvas.drawRect(Rect.fromLTWH(3, 12, 10, 1.5), Paint()..color = const Color(0xFF94A3B8));
    canvas.restore();

    canvas.save();
    canvas.translate(w * 0.56, h * 0.38);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 15, 20), const Radius.circular(2)), filePaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 15, 20), const Radius.circular(2)), fileBorder);
    canvas.drawRect(Rect.fromLTWH(3, 4, 9, 2), Paint()..color = const Color(0xFFEF4444));
    canvas.drawRect(Rect.fromLTWH(3, 8, 7, 1.5), Paint()..color = const Color(0xFF94A3B8));
    canvas.restore();

    final envPaint = Paint()..color = const Color(0xFFF87171)..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(w * 0.54, h * 0.42);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 14, 9), const Radius.circular(1.5)), envPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL STANDARDIZED DUAL-PANE EXPORT MODAL DIALOG
// ============================================================================
class _HeadExportModalDialog extends StatefulWidget {
  final List<HeadMasterItem> heads;

  const _HeadExportModalDialog({required this.heads});

  @override
  State<_HeadExportModalDialog> createState() => _HeadExportModalDialogState();
}

class _HeadExportModalDialogState extends State<_HeadExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedHeadCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedHeadCodes = widget.heads.map((h) => h.locCode).toSet();
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

  List<HeadMasterItem> get _filteredPreviewHeads {
    if (_modalSearchQuery.isEmpty) return widget.heads;
    return widget.heads.where((h) {
      final codeMatch = h.locCode.toString().contains(_modalSearchQuery);
      final nameMatch = h.location.toLowerCase().contains(_modalSearchQuery);
      final seriesMatch = h.locSeries.toLowerCase().contains(_modalSearchQuery);
      final modeMatch = h.mode.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || seriesMatch || modeMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewHeads;
    if (preview.isEmpty) return false;
    return preview.every((h) => _selectedHeadCodes.contains(h.locCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewHeads;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final h in preview) {
          _selectedHeadCodes.remove(h.locCode);
        }
      } else {
        for (final h in preview) {
          _selectedHeadCodes.add(h.locCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedHeadCodes.isEmpty) {
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
      final selectedList = widget.heads
          .where((h) => _selectedHeadCodes.contains(h.locCode))
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
      final fileName = 'HeadMaster_Export_$timestamp.$extension';
      final filePath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Costing Head Master');
        final excel_pkg.Sheet sheet = excel['Costing Head Master'];

        sheet.setColumnWidth(0, 20.0);
        sheet.setColumnWidth(1, 42.0);
        sheet.setColumnWidth(2, 22.0);
        sheet.setColumnWidth(3, 22.0);

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
          excel_pkg.TextCellValue('HEAD CODE'),
          excel_pkg.TextCellValue('COSTING HEAD NAME'),
          excel_pkg.TextCellValue('PREFIX SERIES'),
          excel_pkg.TextCellValue('MODE'),
        ]);

        for (int col = 0; col < 4; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final item = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(item.locCode),
            excel_pkg.TextCellValue(item.location),
            excel_pkg.TextCellValue(item.locSeries.isEmpty ? '-' : item.locSeries),
            excel_pkg.TextCellValue(item.mode),
          ]);

          for (int col = 0; col < 4; col++) {
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

        final headers = ['Head Code', 'Costing Head Name', 'Prefix Series', 'Mode'];
        final data = selectedList.map((item) => [
          '#${item.locCode}',
          item.location,
          item.locSeries.isEmpty ? '-' : item.locSeries,
          item.mode,
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
                    'Costing Head Master Register Report',
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
                                    Text('Export Costing Head Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5)),
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
            '${_selectedHeadCodes.length} of ${widget.heads.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewHeads;

    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No costing head records found',
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
                  Expanded(child: Text('COSTING HEAD NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('PREFIX SERIES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final h = previewList[idx];
                  final isSelected = _selectedHeadCodes.contains(h.locCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedHeadCodes.remove(h.locCode);
                        } else {
                          _selectedHeadCodes.add(h.locCode);
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
                                    _selectedHeadCodes.add(h.locCode);
                                  } else {
                                    _selectedHeadCodes.remove(h.locCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '#${h.locCode}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              h.location,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(
                              h.locSeries.isEmpty ? '-' : h.locSeries,
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

// Authentic 3D Microsoft Excel Brand Badge Logo
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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

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

    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    final platePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)));

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
