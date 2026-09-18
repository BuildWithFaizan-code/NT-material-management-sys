import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/main_group_master_service.dart';
import '../utils/file_export_helper.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// MAIN PAGE: MainGroupMasterPage (WIPMST Setup & Responsive Table)
// ============================================================================
class MainGroupMasterPage extends StatefulWidget {
  const MainGroupMasterPage({super.key});

  @override
  State<MainGroupMasterPage> createState() => _MainGroupMasterPageState();
}

class _MainGroupMasterPageState extends State<MainGroupMasterPage> {
  final MainGroupMasterService _service = MainGroupMasterService();
  final FocusNode _pageKeyFocusNode = FocusNode();
  final ScrollController _tableScrollCtrl = ScrollController();

  // State Data
  List<MainGroupMasterItem> _allItems = [];
  List<MainGroupMasterItem> _filteredItems = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search Controller
  final TextEditingController _tableSearchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Active Form Controls
  bool _isEditing = false;
  final TextEditingController _wipCodeCtrl = TextEditingController();
  final TextEditingController _wipNameCtrl = TextEditingController();
  String _selectedWipMode = 'Regular';

  final FocusNode _wipCodeFocusNode = FocusNode();
  final FocusNode _wipNameFocusNode = FocusNode();

  // Mode Options
  final List<String> _modeOptions = ['Regular', 'Optional', 'Process', 'Custom', 'Job'];

  // Button Action & Notification States
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  String? _buttonValidationMsg;

  bool _isResetting = false;
  String? _deletingCode;

  // Newly & Updated Entry Glow State (4-second Strategy)
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _tableSearchCtrl.addListener(_onSearchChanged);
    _loadInitialData();
  }

  void _onSearchChanged() {
    final text = _tableSearchCtrl.text.trim();
    if (_searchQuery != text) {
      setState(() {
        _searchQuery = text;
        _applySearchFilter();
      });
    }
  }

  @override
  void dispose() {
    _pageKeyFocusNode.dispose();
    _wipCodeCtrl.dispose();
    _wipNameCtrl.dispose();
    _tableSearchCtrl.removeListener(_onSearchChanged);
    _tableSearchCtrl.dispose();
    _searchFocusNode.dispose();
    _tableScrollCtrl.dispose();
    _wipCodeFocusNode.dispose();
    _wipNameFocusNode.dispose();
    _glowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _service.getAllItems();
      if (!mounted) return;

      setState(() {
        _allItems = items;
        _applySearchFilter();
        _isLoading = false;
      });

      _prepareNewGroup();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to Main Group Master API: $e';
      });
    }
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_allItems);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredItems = _allItems.where((item) {
        return item.wipCode.toLowerCase().contains(q) ||
            item.wipName.toLowerCase().contains(q) ||
            item.wipMode.toLowerCase().contains(q);
      }).toList();
    }
  }

  String _generateNextCodeLocally() {
    int maxNum = 0;
    for (final item in _allItems) {
      final n = int.tryParse(item.wipCode.trim());
      if (n != null && n > maxNum) {
        maxNum = n;
      }
    }
    return (maxNum + 1).toString();
  }

  Future<void> _fetchRemoteNextCode() async {
    try {
      final remoteCode = await _service.fetchNextCode();
      if (remoteCode != null && remoteCode.isNotEmpty && mounted && !_isEditing) {
        setState(() {
          _wipCodeCtrl.text = remoteCode;
        });
      }
    } catch (_) {}
  }

  void _prepareNewGroup() {
    final nextCode = _generateNextCodeLocally();
    setState(() {
      _isResetting = true;
      _isEditing = false;
      _wipCodeCtrl.text = nextCode;
      _wipNameCtrl.clear();
      _selectedWipMode = 'Regular';
      _buttonValidationMsg = null;
    });

    _fetchRemoteNextCode();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    });
  }

  void _selectGroupForEditing(MainGroupMasterItem item) {
    setState(() {
      _isEditing = true;
      _wipCodeCtrl.text = item.wipCode;
      _wipNameCtrl.text = item.wipName;
      _selectedWipMode = _modeOptions.contains(item.wipMode) ? item.wipMode : 'Regular';
      _buttonValidationMsg = null;
    });
    _wipNameFocusNode.requestFocus();
    _scrollToCode(item.wipCode);
  }

  void _scrollToCode(String code) {
    final idx = _filteredItems.indexWhere((i) => i.wipCode == code);
    if (idx >= 0 && _tableScrollCtrl.hasClients) {
      final double targetOffset = math.max(0.0, (idx * 43.0) - 80.0);
      _tableScrollCtrl.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _showButtonValidation(String msg) {
    setState(() => _buttonValidationMsg = msg);
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    String code = _wipCodeCtrl.text.trim();
    if (code.isEmpty && !_isEditing) {
      code = _generateNextCodeLocally();
      _wipCodeCtrl.text = code;
    }
    final name = _wipNameCtrl.text.trim();

    if (code.isEmpty) {
      _showButtonValidation('Main Code could not be generated!');
      return;
    }

    if (name.isEmpty) {
      _showButtonValidation('Please enter Main Name!');
      _wipNameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final item = MainGroupMasterItem(
      wipCode: code,
      wipName: name,
      wipMode: _selectedWipMode,
    );

    final bool isCreatingNew = !_isEditing;
    final bool success = isCreatingNew
        ? await _service.insertItem(item)
        : await _service.updateItem(item);

    if (mounted) {
      if (success) {
        // BUTTON NOTIFICATION STRATEGY: Update button UI state to success ('Saved!' / 'Updated!') with animated glowing pulse
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
          if (isCreatingNew) {
            _recentlySavedCode = code;
            _recentlyUpdatedCode = null;
          } else {
            _recentlyUpdatedCode = code;
            _recentlySavedCode = null;
          }
        });

        // 4-SECOND GLOW STRATEGY (AUTO-FADES OUT)
        _glowTimer?.cancel();
        _glowTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _recentlySavedCode = null;
              _recentlyUpdatedCode = null;
            });
          }
        });

        // AUTOMATICALLY RESET FORM FIELDS, REFRESH DATA & TRIGGER ROW SCROLL
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (mounted) {
            setState(() => _isSaveSuccess = false);
            final updatedItems = await _service.getAllItems();
            setState(() {
              _allItems = updatedItems;
              _applySearchFilter();
            });

            _scrollToCode(code);
            _prepareNewGroup();
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save Main Group to database.');
      }
    }
  }

  Future<void> _deleteGroup(String code, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteItem(code);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      final updatedItems = await _service.getAllItems();
      setState(() {
        _allItems = updatedItems;
        _applySearchFilter();
      });

      if (_wipCodeCtrl.text.trim() == code) {
        _prepareNewGroup();
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _submitForm();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _prepareNewGroup();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _MainGroupExportModalDialog(items: _allItems),
    );
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20.0),
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

                    // 2. MAIN WORKSPACE AREA
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                          : _errorMessage != null
                              ? _buildErrorState()
                              : Column(
                                  children: [
                                    // Top Header Input Card
                                    _buildHeaderInputCard(),
                                    const SizedBox(height: 14),

                                    // Bottom Responsive Data Table
                                    Expanded(child: _buildResponsiveDataTable()),
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
  // 1. SCREEN HEADER TOOLBAR
  // --------------------------------------------------------------------------
  Widget _buildScreenHeader() {
    final regularCount = _allItems.where((i) => i.wipMode.toLowerCase() == 'regular').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          // Header Logo (Direct Image, No Box/Border)
          const _MainGroupHeaderLogoWidget(size: 54),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Main Group Master',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'WIP Setup',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_allItems.length} Main Groups',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$regularCount Regular',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF15803D),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.filter_list_rounded, size: 11, color: Color(0xFFD97706)),
                          const SizedBox(width: 4),
                          Text(
                            '${_filteredItems.length} matched',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          const Spacer(),

          // Search Field in Header
          SizedBox(
            width: 240,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _tableSearchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search main groups...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF2563EB)),
                  suffixIcon: _tableSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _tableSearchCtrl.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ANIMATED ORBIT EXPORT BUTTON
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. TOP HEADER INPUT CARD (FORM SETUP)
  // --------------------------------------------------------------------------
  Widget _buildHeaderInputCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          if (isNarrow) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildMainCodeField(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: _buildFormFieldCard(
                        title: 'MAIN NAME',
                        icon: Icons.folder_special_rounded,
                        iconColor: const Color(0xFF059669),
                        bgColor: const Color(0xFFD1FAE5),
                        borderColor: const Color(0xFFA7F3D0),
                        child: SizedBox(
                          height: 36,
                          child: TextField(
                            controller: _wipNameCtrl,
                            focusNode: _wipNameFocusNode,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'e.g. RAW MATERIALS',
                              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormFieldCard(
                        title: 'MODE',
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFFD97706),
                        bgColor: const Color(0xFFFEF3C7),
                        borderColor: const Color(0xFFFDE68A),
                        child: _ModernModeDropdown(
                          value: _selectedWipMode,
                          onChanged: (val) {
                            setState(() => _selectedWipMode = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        _buildResetButton(),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 140,
                          child: _buildSaveButton(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FIELD 1: MAIN CODE
              Expanded(
                flex: 3,
                child: _buildMainCodeField(),
              ),

              const SizedBox(width: 10),

              // FIELD 2: MAIN NAME
              Expanded(
                flex: 5,
                child: _buildFormFieldCard(
                  title: 'MAIN NAME',
                  icon: Icons.folder_special_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  borderColor: const Color(0xFFA7F3D0),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _wipNameCtrl,
                      focusNode: _wipNameFocusNode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. RAW MATERIALS',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // FIELD 3: MODE
              Expanded(
                flex: 3,
                child: _buildFormFieldCard(
                  title: 'MODE',
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFFDE68A),
                  child: _ModernModeDropdown(
                    value: _selectedWipMode,
                    onChanged: (val) {
                      setState(() => _selectedWipMode = val);
                    },
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // ACTION BUTTONS (WITH GLOWING BUTTON NOTIFICATION STRATEGY)
              Row(
                children: [
                  _buildResetButton(),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 145,
                    child: _buildSaveButton(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResetButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: OutlinedButton.icon(
        onPressed: _prepareNewGroup,
        icon: AnimatedRotation(
          turns: _isResetting ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF475569)),
        ),
        label: Text(
          _isResetting ? 'Resetting...' : 'Reset (Esc)',
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          side: BorderSide(color: _isResetting ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
          backgroundColor: _isResetting ? const Color(0xFFEFF6FF) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_buttonValidationMsg != null) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                Expanded(
                  child: Text(
                    _buttonValidationMsg!,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
          idleText: _isEditing ? 'Update Group' : 'Save Group (F1)',
          loadingText: 'Saving...',
          successText: _isEditing ? 'Updated!' : 'Saved!',
          idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
          idleBackgroundColor: AppColors.secondaryColor,
          successBackgroundColor: const Color(0xFF10B981),
          height: 36,
        ),
      ],
    );
  }

  Widget _buildFormFieldCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    Widget? badge,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: iconColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                badge,
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildMainCodeField() {
    return _buildFormFieldCard(
      title: 'MAIN CODE',
      icon: Icons.qr_code_rounded,
      iconColor: const Color(0xFF2563EB),
      bgColor: const Color(0xFFEFF6FF),
      borderColor: const Color(0xFFBFDBFE),
      child: SizedBox(
        height: 36,
        child: TextField(
          controller: _wipCodeCtrl,
          focusNode: _wipCodeFocusNode,
          readOnly: true,
          style: TextStyle(
            fontSize: 12.5,
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
              width: 50,
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
    );
  }

  // --------------------------------------------------------------------------
  // 3. RESPONSIVE DATA TABLE (DEPARTMENT MASTER 100% PARITY)
  // --------------------------------------------------------------------------
  Widget _buildResponsiveDataTable() {
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Table Card Header Bar (Department Master Parity)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  const _MainGroupTableLogoWidget(size: 34),
                  const SizedBox(width: 12),
                  // Curvy Element Box for Title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Main Group Directory',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_filteredItems.length} Records',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Live Search Field (Sleek Clean Styling)
                  SizedBox(
                    width: 260,
                    height: 34,
                    child: TextField(
                      controller: _tableSearchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                          _applySearchFilter();
                        });
                      },
                      style: const TextStyle(fontSize: 11.5),
                      decoration: InputDecoration(
                        hintText: 'Search by Code, Name, or Mode...',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 15, color: AppColors.secondaryColor),
                        suffixIcon: _tableSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 13, color: Color(0xFF64748B)),
                                onPressed: () {
                                  _tableSearchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _applySearchFilter();
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Column Header Bar (Department Master Parity)
            Container(
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: const Row(
                children: [
                  SizedBox(
                    width: 80,
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
                    child: Row(
                      children: [
                        Icon(Icons.folder_special_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 5),
                        Text('MAIN NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune_rounded, size: 12, color: Color(0xFFF59E0B)),
                        SizedBox(width: 4),
                        Text('MODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
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

            // Data ListView with Department Master Separated Card Style
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No Main Group records found',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _tableScrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filteredItems.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                      itemBuilder: (ctx, idx) {
                        final item = _filteredItems[idx];
                        final isSelected = _isEditing && _wipCodeCtrl.text.trim() == item.wipCode;
                        final isNewGlow = _recentlySavedCode == item.wipCode;
                        final isUpdateGlow = _recentlyUpdatedCode == item.wipCode;
                        final isDeleting = _deletingCode == item.wipCode;

                        return _MainGroupTableRowWidget(
                          key: ValueKey(item.wipCode),
                          item: item,
                          index: idx,
                          isSelected: isSelected,
                          isNewGlow: isNewGlow,
                          isUpdateGlow: isUpdateGlow,
                          isDeleting: isDeleting,
                          onEdit: () => _selectGroupForEditing(item),
                          onDelete: () => _deleteGroup(item.wipCode, item.wipName),
                        );
                      },
                    ),
            ),
          ],
        ),
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
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'An error occurred',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================
// 100% IDENTICAL TEAM & SUPPORTIVE HANDS MAIN GROUP HEADER LOGO
// Direct on plain screen — no background borders or box container
// Enhanced with subtle optical glow for clarity and visual depth
// ============================================================================
class _MainGroupHeaderLogoWidget extends StatelessWidget {
  final double size;
  const _MainGroupHeaderLogoWidget({this.size = 54.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle ambient optical glow — no box, purely optical depth
          Positioned(
            bottom: 2,
            left: size * 0.12,
            right: size * 0.12,
            child: Container(
              height: size * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.20),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(3, 2),
                  ),
                ],
              ),
            ),
          ),
          // The crisp 100% identical team & supportive hands logo
          Image.asset(
            'assets/images/main_group_master_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODERN INTERACTIVE MODE DROPDOWN & METADATA
// ============================================================================
class _ModeMeta {
  final String key;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final String badgeText;

  const _ModeMeta({
    required this.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.badgeText,
  });
}

const List<_ModeMeta> _kMainGroupModes = [
  _ModeMeta(
    key: 'Regular',
    label: 'Regular',
    subtitle: 'Standard WIP production flow',
    icon: Icons.verified_rounded,
    color: Color(0xFF059669),
    bgColor: Color(0xFFECFDF5),
    borderColor: Color(0xFFA7F3D0),
    badgeText: 'STANDARD',
  ),
  _ModeMeta(
    key: 'Optional',
    label: 'Optional',
    subtitle: 'Conditional stage routing',
    icon: Icons.alt_route_rounded,
    color: Color(0xFF4F46E5),
    bgColor: Color(0xFFEEF2FF),
    borderColor: Color(0xFFC7D2FE),
    badgeText: 'FLEXIBLE',
  ),
  _ModeMeta(
    key: 'Process',
    label: 'Process',
    subtitle: 'Stage-wise operational track',
    icon: Icons.precision_manufacturing_rounded,
    color: Color(0xFFD97706),
    bgColor: Color(0xFFFEF3C7),
    borderColor: Color(0xFFFDE68A),
    badgeText: 'OPERATION',
  ),
  _ModeMeta(
    key: 'Custom',
    label: 'Custom',
    subtitle: 'Tailored client specific logic',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFF5F3FF),
    borderColor: Color(0xFFDDD6FE),
    badgeText: 'CUSTOM',
  ),
  _ModeMeta(
    key: 'Job',
    label: 'Job',
    subtitle: 'Direct work order execution',
    icon: Icons.engineering_rounded,
    color: Color(0xFF2563EB),
    bgColor: Color(0xFFEFF6FF),
    borderColor: Color(0xFFBFDBFE),
    badgeText: 'WORK ORDER',
  ),
];

_ModeMeta _getModeMeta(String mode) {
  return _kMainGroupModes.firstWhere(
    (m) => m.key.toLowerCase() == mode.trim().toLowerCase(),
    orElse: () => _ModeMeta(
      key: mode,
      label: mode,
      subtitle: 'Configured Mode',
      icon: Icons.tune_rounded,
      color: const Color(0xFF64748B),
      bgColor: const Color(0xFFF1F5F9),
      borderColor: const Color(0xFFE2E8F0),
      badgeText: mode.toUpperCase(),
    ),
  );
}

class _ModernModeDropdown extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _ModernModeDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ModernModeDropdown> createState() => _ModernModeDropdownState();
}

class _ModernModeDropdownState extends State<_ModernModeDropdown> {
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
    _closeDropdown();

    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? const Size(200, 36);

    setState(() => _isOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final currentMeta = _getModeMeta(widget.value);
        String? hoveredKey;

        return StatefulBuilder(
          builder: (context, setOverlayState) {
            final activeKey = hoveredKey ?? widget.value;

            return Stack(
              children: [
                // Full-screen dismiss barrier
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (_) => _closeDropdown(),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Floating Dropdown Card directly below
                Positioned(
                  width: math.max(size.width, 280.0),
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: Offset(0, size.height + 6),
                    child: Material(
                      elevation: 16,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: currentMeta.color.withValues(alpha: 0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              color: const Color(0xFFF8FAFC),
                              child: Row(
                                children: [
                                  const Icon(Icons.tune_rounded, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'SELECT WIP MODE',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${_kMainGroupModes.length} Modes',
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                            // Mode Items List (Single highlight manager)
                            MouseRegion(
                              onExit: (_) {
                                setOverlayState(() => hoveredKey = null);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: _kMainGroupModes.map((meta) {
                                    final isHighlighted = meta.key.toLowerCase() == activeKey.toLowerCase();
                                    final isSelected = meta.key.toLowerCase() == widget.value.toLowerCase();

                                    return _ModeItemRow(
                                      meta: meta,
                                      isHighlighted: isHighlighted,
                                      isSelected: isSelected,
                                      onHover: () {
                                        if (hoveredKey != meta.key) {
                                          setOverlayState(() => hoveredKey = meta.key);
                                        }
                                      },
                                      onTap: () {
                                        widget.onChanged(meta.key);
                                        _closeDropdown();
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),

                            // Footer hint
                            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              color: const Color(0xFFF8FAFC),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF94A3B8)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Determines workflow behavior in WIP tracking',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: Color(0xFF94A3B8),
                                      fontStyle: FontStyle.italic,
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
              ],
            );
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted && _isOpen) {
      setState(() => _isOpen = false);
    }
  }

  @override
  void deactivate() {
    _closeDropdown();
    super.deactivate();
  }

  @override
  void dispose() {
    _closeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentMeta = _getModeMeta(widget.value);

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
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
                    ? currentMeta.color
                    : (_isHovered ? currentMeta.color.withValues(alpha: 0.7) : const Color(0xFFCBD5E1)),
                width: _isOpen ? 1.5 : 1.0,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: currentMeta.color.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // Selected Mode Icon Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: currentMeta.bgColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: currentMeta.borderColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(currentMeta.icon, size: 12, color: currentMeta.color),
                      const SizedBox(width: 4),
                      Text(
                        currentMeta.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: currentMeta.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Rotating Animated Chevron
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isOpen ? currentMeta.color : const Color(0xFF64748B),
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

class _ModeItemRow extends StatelessWidget {
  final _ModeMeta meta;
  final bool isHighlighted;
  final bool isSelected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _ModeItemRow({
    required this.meta,
    required this.isHighlighted,
    required this.isSelected,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final m = meta;

    return MouseRegion(
      onEnter: (_) => onHover(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isHighlighted ? m.bgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isHighlighted ? m.borderColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Mode Icon Badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isHighlighted ? Colors.white : m.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isHighlighted ? m.borderColor : m.borderColor.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Icon(m.icon, size: 15, color: m.color),
              ),
              const SizedBox(width: 10),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: (isSelected || isHighlighted) ? FontWeight.w800 : FontWeight.w600,
                            color: isHighlighted ? m.color : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isHighlighted ? Colors.white.withValues(alpha: 0.9) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            m.badgeText,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: isHighlighted ? m.color : const Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isHighlighted ? m.color.withValues(alpha: 0.8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Checkmark (Rendered for the selected item)
              if (isSelected) ...[
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isHighlighted ? m.color : m.color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 100% IDENTICAL NETWORK CONNECTED NODES LOGO WIDGET (NO BOX/BORDER)
// ============================================================================
class _MainGroupTableLogoWidget extends StatelessWidget {
  final double size;
  const _MainGroupTableLogoWidget({this.size = 38});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Optical ambient glow layer (no box, no border)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFF97316).withValues(alpha: 0.10),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
            ),
          ),
          // 100% Identical Network Connected Nodes Logo
          Image.asset(
            'assets/images/main_group_table_records_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED TABLE ROW WIDGET (COOL HOVER ANIMATION + GLOW ENTRY STRATEGY)
// ============================================================================
class _MainGroupTableRowWidget extends StatefulWidget {
  final MainGroupMasterItem item;
  final int index;
  final bool isSelected;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MainGroupTableRowWidget({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isNewGlow,
    required this.isUpdateGlow,
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MainGroupTableRowWidget> createState() => _MainGroupTableRowWidgetState();
}

class _MainGroupTableRowWidgetState extends State<_MainGroupTableRowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;
    final isGlowing = isNewGlow || isUpdateGlow;
    final isSelected = widget.isSelected;

    final Color glowColor = isUpdateGlow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
    final meta = _getModeMeta(item.wipMode);

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
                // CODE BADGE (80px) - Department Master Style
                SizedBox(
                  width: 80,
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
                          item.wipCode,
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
                const SizedBox(width: 10),

                // MAIN NAME (Expanded) - Department Master Style clean typography
                Expanded(
                  child: Text(
                    item.wipName,
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

                // MODE BADGE (130px) - Department Master Status Badge Style
                SizedBox(
                  width: 130,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: meta.bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: meta.borderColor, width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(meta.icon, size: 11, color: meta.color),
                          const SizedBox(width: 4),
                          Text(
                            meta.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: meta.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // ACTIONS (75px) - Edit & Delete Buttons (Department Master Parity)
                SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DepartmentGridActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Main Group',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      if (widget.isDeleting) ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ] else ...[
                        _DepartmentGridActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444),
                          tooltip: 'Delete Main Group',
                          onPressed: widget.onDelete,
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

// ============================================================================
// INTERACTIVE HOVER ACTION BUTTON WIDGET (DEPARTMENT MASTER PARITY)
// ============================================================================
class _DepartmentGridActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _DepartmentGridActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_DepartmentGridActionButton> createState() => _DepartmentGridActionButtonState();
}

class _DepartmentGridActionButtonState extends State<_DepartmentGridActionButton> {
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
// TACTILE HOVER BUTTON WIDGET
// ============================================================================
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
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED ORBIT EXPORT BUTTON & PAINTER (100% PARITY WITH OPERATOR MASTER)
// ============================================================================
class _AnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _AnimatedExportButton({required this.onPressed});

  @override
  State<_AnimatedExportButton> createState() => _AnimatedExportButtonState();
}

class _AnimatedExportButtonState extends State<_AnimatedExportButton> with SingleTickerProviderStateMixin {
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

  void _triggerExport() {
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
        onTap: _triggerExport,
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
// 100% IDENTICAL EXPORT MODAL DIALOG (OPERATOR MASTER PARITY)
// ============================================================================
class _MainGroupExportModalDialog extends StatefulWidget {
  final List<MainGroupMasterItem> items;
  const _MainGroupExportModalDialog({required this.items});

  @override
  State<_MainGroupExportModalDialog> createState() => _MainGroupExportModalDialogState();
}

class _MainGroupExportModalDialogState extends State<_MainGroupExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.items.map((i) => i.wipCode).toSet();
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

  List<MainGroupMasterItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      return i.wipCode.toLowerCase().contains(_modalSearchQuery) ||
          i.wipName.toLowerCase().contains(_modalSearchQuery) ||
          i.wipMode.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.wipCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.wipCode);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.wipCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) return;

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
    final selectedList = widget.items
        .where((i) => _selectedCodes.contains(i.wipCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String fileName = _selectedFormat == 'XLSX'
          ? 'Main_Group_Master_$timeStamp.xlsx'
          : 'Main_Group_Master_$timeStamp.pdf';

      final List<int>? fileBytes = _selectedFormat == 'XLSX'
          ? _generateExcelBytes(selectedList)
          : await _generatePdfBytes(selectedList);

      if (fileBytes == null) {
        throw Exception('Failed to generate export file bytes.');
      }

      await FileExportHelper.saveAndLaunchFile(
        bytes: fileBytes,
        fileName: fileName,
      );

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

  List<int>? _generateExcelBytes(List<MainGroupMasterItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Main Group Master');
    final excel_pkg.Sheet sheet = excel['Main Group Master'];

    final cellBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
      borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
    );

    final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#10B981'),
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

    sheet.setColumnWidth(0, 18.0);
    sheet.setColumnWidth(1, 40.0);
    sheet.setColumnWidth(2, 20.0);

    sheet.setRowHeight(0, 26.0);
    // REMOVED BRACKETS FROM EXCEL HEADERS AS REQUESTED BY USER
    sheet.appendRow([
      excel_pkg.TextCellValue('MAIN CODE'),
      excel_pkg.TextCellValue('MAIN NAME'),
      excel_pkg.TextCellValue('MODE'),
    ]);

    for (int col = 0; col < 3; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.TextCellValue(item.wipCode),
        excel_pkg.TextCellValue(item.wipName),
        excel_pkg.TextCellValue(item.wipMode.isNotEmpty ? item.wipMode : 'Regular'),
      ]);

      for (int col = 0; col < 3; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<MainGroupMasterItem> records) async {
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
                  'MAIN GROUP MASTER REPORT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
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
            headers: ['MAIN CODE', 'MAIN NAME', 'MODE'],
            data: records.map((i) => [
              i.wipCode,
              i.wipName,
              i.wipMode.isNotEmpty ? i.wipMode : 'Regular',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                                    Text('Export Main Group Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                hintText: 'Search groups...',
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
            '${_selectedCodes.length} of ${widget.items.length} selected',
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
              'No main group records found',
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
                  Expanded(child: Text('MAIN NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 100, child: Text('MODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedCodes.contains(item.wipCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.wipCode);
                        } else {
                          _selectedCodes.add(item.wipCode);
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
                                    _selectedCodes.add(item.wipCode);
                                  } else {
                                    _selectedCodes.remove(item.wipCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              item.wipCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.wipName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              item.wipMode.isNotEmpty ? item.wipMode : 'Regular',
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
// RICH 3D VECTOR BRAND LOGO WIDGETS (EXACT COPY FROM OPERATOR MASTER)
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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF3B30), Color(0xFFD32F2F), Color(0xFF8E0000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

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

    final foldShadow = Path()
      ..moveTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.40)
      ..close();
    canvas.drawPath(foldShadow, Paint()..color = Colors.black.withValues(alpha: 0.25));

    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), glossPaint);

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

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.28, h * 0.68));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WITH GLOWING EMERALD PULSE ANIMATION
// ============================================================================
class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback onPressed;
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
    required this.loadingText,
    required this.successText,
    required this.idleIcon,
    required this.idleBackgroundColor,
    required this.successBackgroundColor,
    this.height = 36,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.status == ButtonStatus.loading;
    final bool isSuccess = widget.status == ButtonStatus.success;
    final Color bgColor = isSuccess
        ? widget.successBackgroundColor
        : (isLoading ? widget.idleBackgroundColor.withValues(alpha: 0.85) : widget.idleBackgroundColor);

    return InkWell(
      onTap: isLoading ? null : widget.onPressed,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            height: widget.height,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(9),
              border: isSuccess ? Border.all(color: const Color(0xFF34D399), width: 1.5) : null,
              boxShadow: [
                BoxShadow(
                  color: isSuccess
                      ? widget.successBackgroundColor.withValues(alpha: 0.75)
                      : bgColor.withValues(alpha: 0.3),
                  blurRadius: isSuccess ? _glowAnimation.value : 6,
                  spreadRadius: isSuccess ? 2.5 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else if (isSuccess)
                    const Icon(Icons.check_circle_rounded, size: 15, color: Colors.white)
                  else
                    Icon(widget.idleIcon, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    isLoading ? widget.loadingText : (isSuccess ? widget.successText : widget.idleText),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
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

// ============================================================================
// 100% IDENTICAL STANDARDIZED DELETE CONFIRMATION DIALOG & VECTOR PAINTER
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
                painter: const _IdenticalDeleteDialogIllustrationPainter(),
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

class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.12), shadowPaint);

    final windowPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final leftWin = Rect.fromLTWH(w * 0.22, h * 0.16, w * 0.24, h * 0.38);
    canvas.drawRRect(RRect.fromRectAndRadius(leftWin, const Radius.circular(3)), windowPaint);
    canvas.drawLine(Offset(leftWin.left + leftWin.width / 2, leftWin.top), Offset(leftWin.left + leftWin.width / 2, leftWin.bottom), windowPaint);
    canvas.drawLine(Offset(leftWin.left, leftWin.top + leftWin.height / 2), Offset(leftWin.right, leftWin.top + leftWin.height / 2), windowPaint);

    final rightWin = Rect.fromLTWH(w * 0.54, h * 0.20, w * 0.22, h * 0.28);
    canvas.drawRRect(RRect.fromRectAndRadius(rightWin, const Radius.circular(3)), windowPaint);

    final binBody = Path()
      ..moveTo(w * 0.60, h * 0.48)
      ..lineTo(w * 0.80, h * 0.48)
      ..lineTo(w * 0.77, h * 0.86)
      ..lineTo(w * 0.63, h * 0.86)
      ..close();
    canvas.drawPath(binBody, Paint()..color = const Color(0xFFEF4444));

    final stripePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.65, h * 0.50), Offset(w * 0.66, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.50), Offset(w * 0.70, h * 0.84), stripePaint);
    canvas.drawLine(Offset(w * 0.75, h * 0.50), Offset(w * 0.74, h * 0.84), stripePaint);

    final binLid = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.58, h * 0.44, w * 0.24, h * 0.06), const Radius.circular(3));
    canvas.drawRRect(binLid, Paint()..color = const Color(0xFFEF4444));

    final skinPaint = Paint()..color = const Color(0xFFFFCCBC);
    final hairPaint = Paint()..color = const Color(0xFF0F172A);
    final coralShirtPaint = Paint()..color = const Color(0xFFEF4444);
    final navyPantsPaint = Paint()..color = const Color(0xFF1E293B);

    final headCenter = Offset(w * 0.38, h * 0.32);
    canvas.drawCircle(headCenter, w * 0.07, skinPaint);
    final hairPath = Path()
      ..addArc(Rect.fromCircle(center: headCenter, radius: w * 0.07), math.pi, math.pi);
    canvas.drawPath(hairPath, hairPaint);

    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.39, w * 0.10, h * 0.18), coralShirtPaint);

    final armPath = Path()
      ..moveTo(w * 0.38, h * 0.41)
      ..lineTo(w * 0.55, h * 0.37)
      ..lineTo(w * 0.55, h * 0.44)
      ..lineTo(w * 0.38, h * 0.48)
      ..close();
    canvas.drawPath(armPath, coralShirtPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.41, 14, 10), const Radius.circular(2)), Paint()..color = const Color(0xFFF87171));

    canvas.drawRect(Rect.fromLTWH(w * 0.33, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.39, h * 0.57, w * 0.04, h * 0.25), navyPantsPaint);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.81, w * 0.07, h * 0.04), const Radius.circular(2)), coralShirtPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
