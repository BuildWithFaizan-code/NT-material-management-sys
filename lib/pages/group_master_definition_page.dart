import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/group_master_definition_service.dart';
import '../utils/file_export_helper.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// MAIN PAGE: GroupMasterDefinitionPage (Sub-Group Mapping Module - ITEMSUBMST)
// ============================================================================
class GroupMasterDefinitionPage extends StatefulWidget {
  const GroupMasterDefinitionPage({super.key});

  @override
  State<GroupMasterDefinitionPage> createState() => _GroupMasterDefinitionPageState();
}

class _GroupMasterDefinitionPageState extends State<GroupMasterDefinitionPage> {
  final GroupMasterDefinitionService _service = GroupMasterDefinitionService();
  final FocusNode _pageKeyFocusNode = FocusNode();

  // State Data
  List<GroupMasterDefinitionItem> _allItems = [];
  List<CategoryLookupItem> _categories = [];
  List<MainGroupLookupItem> _mainGroups = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Active Form Controls
  bool _isEditing = false;
  String _selectedMCode = '';
  String _selectedMCodeName = '';
  final TextEditingController _subCodeCtrl = TextEditingController();
  String _selectedCatCode = '';

  final FocusNode _subCodeFocusNode = FocusNode();

  // Button Action & Notification States
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  String? _buttonValidationMsg;
  bool _isResetting = false;

  // Row Glow Highlight State
  String? _glowingCode;
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  Timer? _glowTimer;

  // Computed MS Code Preview: ISM_MCode + ISM_SubCode (e.g., "1412")
  String get _computedMsCode => '${_selectedMCode.trim()}${_subCodeCtrl.text.trim()}';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _subCodeCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageKeyFocusNode.dispose();
    _subCodeCtrl.dispose();
    _subCodeFocusNode.dispose();
    _glowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _service.getMappedDefinitions();
      final categories = await _service.getCategories();
      final mainGroups = await _service.getMainGroups();

      if (!mounted) return;

      setState(() {
        _allItems = items;
        _categories = categories;
        _mainGroups = mainGroups;

        if (_mainGroups.isNotEmpty && _selectedMCode.isEmpty) {
          _selectedMCode = _mainGroups.first.wipCode;
          _selectedMCodeName = _mainGroups.first.wipName;
        }

        if (_categories.isNotEmpty && _selectedCatCode.isEmpty) {
          _selectedCatCode = _categories.first.catCode;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to Group Master Definition API: $e';
      });
    }
  }

  void _prepareNewMapping({bool clearGlow = true}) {
    setState(() {
      _isResetting = true;
      _isEditing = false;
      _selectedMCode = '';
      _selectedMCodeName = '';
      _selectedCatCode = '';
      _subCodeCtrl.clear();
      if (clearGlow) {
        _glowingCode = null;
        _recentlySavedCode = null;
        _recentlyUpdatedCode = null;
      }
      _buttonValidationMsg = null;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    });
  }

  void _selectMappingForEditing(GroupMasterDefinitionItem item) {
    setState(() {
      _isEditing = true;
      _selectedMCode = item.ismMCode;
      _subCodeCtrl.text = item.ismSubCode;

      final foundMGroup = _mainGroups.firstWhere(
        (m) => m.wipCode == item.ismMCode,
        orElse: () => MainGroupLookupItem(wipCode: item.ismMCode, wipName: item.wipName),
      );
      _selectedMCodeName = foundMGroup.wipName;

      if (_categories.any((c) => c.catCode == item.ismSubCatCode)) {
        _selectedCatCode = item.ismSubCatCode;
      } else if (_categories.isNotEmpty) {
        _selectedCatCode = _categories.first.catCode;
      }

      _buttonValidationMsg = null;
    });
    _subCodeFocusNode.requestFocus();
    _triggerEntryGlow(item.ismMsCode);
  }

  void _triggerEntryGlow(String msCode, {bool isNew = false, bool isUpdate = false}) {
    _glowTimer?.cancel();
    setState(() {
      _glowingCode = msCode;
      if (isNew) {
        _recentlySavedCode = msCode;
        _recentlyUpdatedCode = null;
      } else if (isUpdate) {
        _recentlyUpdatedCode = msCode;
        _recentlySavedCode = null;
      }
    });

    _glowTimer = Timer(const Duration(milliseconds: 4000), () {
      if (mounted) {
        setState(() {
          _glowingCode = null;
          _recentlySavedCode = null;
          _recentlyUpdatedCode = null;
        });
      }
    });
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

    if (_selectedMCode.isEmpty) {
      _showButtonValidation('Please select Main Group Code!');
      return;
    }

    final subCode = _subCodeCtrl.text.trim();
    if (subCode.isEmpty) {
      _showButtonValidation('Please enter Sub Group Code!');
      _subCodeFocusNode.requestFocus();
      return;
    }

    if (_selectedCatCode.isEmpty) {
      _showButtonValidation('Please select Category / Group Name!');
      return;
    }

    final msCode = _computedMsCode;

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final selectedCatObj = _categories.firstWhere(
      (c) => c.catCode == _selectedCatCode,
      orElse: () => CategoryLookupItem(catCode: _selectedCatCode, catName: ''),
    );

    final item = GroupMasterDefinitionItem(
      ismMsCode: msCode,
      ismMCode: _selectedMCode,
      ismSubCode: subCode,
      ismSubCatCode: _selectedCatCode,
      catName: selectedCatObj.catName,
      wipName: _selectedMCodeName,
    );

    final bool isCreatingNew = !_isEditing;
    final bool success = isCreatingNew
        ? await _service.insertItem(item)
        : await _service.updateItem(item);

    if (mounted) {
      if (success) {
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });

        _triggerEntryGlow(msCode, isNew: isCreatingNew, isUpdate: !isCreatingNew);
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (mounted) {
            setState(() => _isSaveSuccess = false);
            final updatedItems = await _service.getMappedDefinitions();
            setState(() {
              _allItems = updatedItems;
            });
            _prepareNewMapping(clearGlow: false);
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save Sub-Group Mapping to database.');
      }
    }
  }

  Future<void> _handleDeleteMapping(String msCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteItem(msCode);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _allItems.removeWhere((i) => i.ismMsCode == msCode);
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _submitForm();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _prepareNewMapping();
      }
    }
  }

  void _openShowRecordModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GroupMasterDefinitionRecordLookupModal(
        items: _allItems,
        service: _service,
        glowingCode: _glowingCode,
        onSelect: (item) {
          _selectMappingForEditing(item);
        },
        onRefreshNeeded: () async {
          final updated = await _service.getMappedDefinitions();
          if (mounted) {
            setState(() => _allItems = updated);
          }
        },
      ),
    );
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GroupMasterDefinitionExportModalDialog(items: _allItems),
    );
  }

  // Mapped Table filtered dynamically by selected Main Group Code (empty when no Main Group selected)
  List<GroupMasterDefinitionItem> get _filteredTableItems {
    if (_selectedMCode.isEmpty) return [];
    return _allItems.where((i) => i.ismMCode == _selectedMCode).toList();
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD (SINGLE VIEWPORT PAGE WITH EMBEDDED TABLE)
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _pageKeyFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                // 1. SCREEN HEADER TOOLBAR
                _buildScreenHeader(),
                const SizedBox(height: 12),

                // 2. MAIN WORKSPACE (TOP FORM CARD + EMBEDDED MAPPED TABLE)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                      : _errorMessage != null
                          ? _buildErrorState()
                          : Column(
                              children: [
                                // TOP INPUT & MAPPING CARD
                                _buildHomeFormCard(),
                                const SizedBox(height: 12),

                                // EMBEDDED RESPONSIVE MAPPED DATA GRID
                                Expanded(
                                  child: _buildEmbeddedDataGrid(),
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

  // --------------------------------------------------------------------------
  // 1. SCREEN HEADER TOOLBAR
  // --------------------------------------------------------------------------
  Widget _buildScreenHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          // 100% IDENTICAL GROUP MASTER DEFINITION LOGO (IMAGE 2 PARITY)
          const _GroupMasterDefinitionHeaderLogoWidget(size: 50),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Group Master Definition',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
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
                      '${_allItems.length} Mapped Sub-Groups',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // SHOW RECORD LOOKUP BUTTON (MAGNIFY MOVING ANIMATION)
          _AnimatedShowRecordButton(onTap: _openShowRecordModal),

          const SizedBox(width: 10),

          // ANIMATED ORBIT EXPORT BUTTON (OPERATOR MASTER STYLE)
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. TOP FORM INPUT CARD (4 DISTINCT FIELDS WITH UNIQUE NATURAL COLORS)
  // --------------------------------------------------------------------------
  Widget _buildHomeFormCard() {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 Header Title
          Row(
            children: [
              // 100% IDENTICAL SUB-GROUP MAPPING DEFINITION LOGO (IMAGE 2 PARITY)
              const _SubGroupMappingDefinitionLogoWidget(size: 34),
              const SizedBox(width: 10),
              const Text(
                'SUB-GROUP MAPPING DEFINITION',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: 0.2),
              ),
              const Spacer(),
              if (_isEditing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Editing Mapping #$_computedMsCode',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // ROW 2: 4 DISTINCT FIELDS (MAIN CODE, SUB CODE, CATEGORY NAME, MS CODE PREVIEW)
          Row(
            children: [
              // FIELD 1: MAIN GROUP CODE (COBALT BLUE #2563EB)
              Expanded(
                flex: 3,
                child: _buildFormFieldCard(
                  title: 'MAIN GROUP CODE',
                  icon: Icons.qr_code_2_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  child: SizedBox(
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: _SearchableDropdownField<MainGroupLookupItem>(
                        hintText: 'Select Main Group',
                        selectedValue: _selectedMCode,
                        displayLabel: _selectedMCode.isNotEmpty ? '[$_selectedMCode] $_selectedMCodeName' : '',
                        items: _mainGroups,
                        getItemCode: (m) => m.wipCode,
                        getItemName: (m) => m.wipName,
                        accentColor: const Color(0xFF2563EB),
                        badgeBgColor: const Color(0xFFDBEAFE),
                        badgeTextColor: const Color(0xFF1D4ED8),
                        onSelected: (m) {
                          setState(() {
                            _selectedMCode = m.wipCode;
                            _selectedMCodeName = m.wipName;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // FIELD 2: SUB GROUP CODE (CYAN #0891B2)
              Expanded(
                flex: 2,
                child: _buildFormFieldCard(
                  title: 'SUB GROUP CODE',
                  icon: Icons.tag_rounded,
                  iconColor: const Color(0xFF0891B2),
                  bgColor: const Color(0xFFECFEFF),
                  borderColor: const Color(0xFFA5F3FC),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _subCodeCtrl,
                      focusNode: _subCodeFocusNode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. 12',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0891B2), width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // FIELD 3: CATEGORY / GROUP NAME (EMERALD GREEN #059669)
              Expanded(
                flex: 4,
                child: _buildFormFieldCard(
                  title: 'CATEGORY / GROUP NAME',
                  icon: Icons.category_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  borderColor: const Color(0xFFA7F3D0),
                  child: SizedBox(
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: _SearchableDropdownField<CategoryLookupItem>(
                        hintText: 'Select Category',
                        selectedValue: _selectedCatCode,
                        displayLabel: _selectedCatCode.isNotEmpty
                            ? '[$_selectedCatCode] ${_categories.firstWhere((c) => c.catCode == _selectedCatCode, orElse: () => CategoryLookupItem(catCode: _selectedCatCode, catName: '')).catName}'
                            : '',
                        items: _categories,
                        getItemCode: (c) => c.catCode,
                        getItemName: (c) => c.catName,
                        accentColor: const Color(0xFF059669),
                        badgeBgColor: const Color(0xFFA7F3D0),
                        badgeTextColor: const Color(0xFF047857),
                        onSelected: (c) {
                          setState(() {
                            _selectedCatCode = c.catCode;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // FIELD 4: MS CODE PREVIEW (AMBER ORANGE #D97706)
              Expanded(
                flex: 2,
                child: _buildFormFieldCard(
                  title: 'MS CODE PREVIEW',
                  icon: Icons.badge_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFFDE68A),
                  child: SizedBox(
                    height: 36,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        _computedMsCode.isEmpty ? 'Auto-Preview' : _computedMsCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: _computedMsCode.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFFD97706),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // FORM ACTION BUTTONS (RESET & SAVE MAPPING BUTTON)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildResetButton(),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: _buildSaveButton(),
              ),
            ],
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
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildResetButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: OutlinedButton.icon(
        onPressed: _prepareNewMapping,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          idleText: _isEditing ? 'Update Mapping' : 'Save Mapping (F1)',
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

  // --------------------------------------------------------------------------
  // 3. EMBEDDED RESPONSIVE MAPPED DATA GRID (DEPARTMENT MASTER TABLE 100% PARITY)
  // --------------------------------------------------------------------------
  Widget _buildEmbeddedDataGrid() {
    final list = _filteredTableItems;

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
                  const _TableDocumentLogoWidget(size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
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
                              'Mapped Sub-Groups Directory',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: 0.2,
                              ),
                            ),
                            if (_selectedMCode.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.0),
                                ),
                                child: Text(
                                  _selectedMCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                              if (_selectedMCodeName.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _selectedMCodeName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${list.length} Records',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                    ),
                  ),
                ],
              ),
            ),

            // Column Header Bar (Exact Department Master Grid Columns & Icons)
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
                    width: 65,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tag_rounded, size: 12, color: Color(0xFF6366F1)),
                        SizedBox(width: 3),
                        Text('SR NO', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.vpn_key_rounded, size: 12, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text('MS CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.layers_rounded, size: 12, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('MAIN CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.subdirectory_arrow_right_rounded, size: 12, color: Color(0xFF0891B2)),
                        SizedBox(width: 4),
                        Text('SUB CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.category_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 5),
                        Text('CATEGORY NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
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
              child: list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 36, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            _selectedMCode.isNotEmpty
                                ? 'No sub-group mappings found for Main Group [$_selectedMCode]'
                                : 'No mapped records available',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: list.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                      itemBuilder: (ctx, idx) {
                        final item = list[idx];
                        final bool isNewGlow = _recentlySavedCode == item.ismMsCode;
                        final bool isUpdateGlow = _recentlyUpdatedCode == item.ismMsCode;
                        final bool isSelected = _isEditing &&
                            _selectedMCode == item.ismMCode &&
                            _subCodeCtrl.text.trim() == item.ismSubCode;
                        final bool isGlowing = _glowingCode == item.ismMsCode;

                        return _HoverableDataGridRow(
                          key: ValueKey(item.ismMsCode),
                          index: idx,
                          item: item,
                          isGlowing: isGlowing,
                          isNewGlow: isNewGlow,
                          isUpdateGlow: isUpdateGlow,
                          isSelected: isSelected,
                          onSelect: () => _selectMappingForEditing(item),
                          onEdit: () => _selectMappingForEditing(item),
                          onDelete: () => _handleDeleteMapping(item.ismMsCode),
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
// 4. "SHOW RECORD" LOOKUP MODAL (100% PARITY & INSTANT DELETE REFRESH)
// ============================================================================
class _GroupMasterDefinitionRecordLookupModal extends StatefulWidget {
  final List<GroupMasterDefinitionItem> items;
  final GroupMasterDefinitionService service;
  final String? glowingCode;
  final ValueChanged<GroupMasterDefinitionItem> onSelect;
  final Future<void> Function() onRefreshNeeded;

  const _GroupMasterDefinitionRecordLookupModal({
    required this.items,
    required this.service,
    required this.glowingCode,
    required this.onSelect,
    required this.onRefreshNeeded,
  });

  @override
  State<_GroupMasterDefinitionRecordLookupModal> createState() => _GroupMasterDefinitionRecordLookupModalState();
}

class _GroupMasterDefinitionRecordLookupModalState extends State<_GroupMasterDefinitionRecordLookupModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  String? _deletingCode;
  late List<GroupMasterDefinitionItem> _localItems;
  Timer? _debounce;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _localItems = List.from(widget.items);
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<GroupMasterDefinitionItem> get _filteredAndSorted {
    List<GroupMasterDefinitionItem> list = List.from(_localItems);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) {
        return i.ismMsCode.toLowerCase().contains(_searchQuery) ||
            i.ismMCode.toLowerCase().contains(_searchQuery) ||
            i.ismSubCode.toLowerCase().contains(_searchQuery) ||
            i.catName.toLowerCase().contains(_searchQuery) ||
            i.wipName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((i) {
          final first = i.catName.trim().isNotEmpty ? i.catName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((i) {
          final nameStr = i.catName.trim();
          final codeStr = i.ismMsCode.trim();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    // Sort by MS Code
    list.sort((a, b) => a.ismMsCode.toLowerCase().compareTo(b.ismMsCode.toLowerCase()));
    return list;
  }

  Future<void> _handleDelete(String msCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await widget.service.deleteItem(msCode);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _localItems.removeWhere((i) => i.ismMsCode == msCode);
      });
      await widget.onRefreshNeeded();
    }
  }

  void _openModalExport(List<GroupMasterDefinitionItem> exportList) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GroupMasterDefinitionExportModalDialog(items: exportList),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAndSorted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 1150,
        height: 670,
        constraints: const BoxConstraints(maxWidth: 1200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // 1. MODAL TOP HEADER BAR
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.manage_search_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Group Master Definition Record',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),

                    // Green Count Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        '${list.length} / ${_localItems.length} Mapped Items',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),

                    const Spacer(),

                    // Keyboard Navigation Helper Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_vert_rounded, size: 14, color: Color(0xFF64748B)),
                          SizedBox(width: 4),
                          Text(
                            '↑/↓ to navigate | Enter to select | Esc to close',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 2. SEARCH BAR & EXPORT ORBIT BUTTON ROW
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 12.5),
                          decoration: InputDecoration(
                            hintText: 'Type to live filter by MS Code, Main Code, Sub Code, Category Name...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF10B981)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF10B981))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF10B981))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF059669), width: 2.0)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Standalone Export Orbit Button
                    _AnimatedExportButton(onPressed: () => _openModalExport(list)),
                  ],
                ),
              ),

              // 3. ALPHABETICAL A TO Z FILTRATION BAR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _alphabets.length,
                    separatorBuilder: (ctx, idx) => const SizedBox(width: 4),
                    itemBuilder: (ctx, idx) {
                      final alpha = _alphabets[idx];
                      final isSelected = _selectedAlphabet == alpha;

                      return InkWell(
                        onTap: () => setState(() => _selectedAlphabet = alpha),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: EdgeInsets.symmetric(
                            horizontal: alpha == 'ALL' ? 12 : 9,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF10B981) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            alpha,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // 4. DATA TABLE VIEW
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('No Group Definition records match your filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            height: 38,
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: const Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    children: [
                                      Icon(Icons.badge_rounded, size: 13, color: Color(0xFFD97706)),
                                      SizedBox(width: 6),
                                      Text('MS CODE', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    children: [
                                      Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF2563EB)),
                                      SizedBox(width: 6),
                                      Text('MAIN CODE', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    children: [
                                      Icon(Icons.tag_rounded, size: 13, color: Color(0xFF0891B2)),
                                      SizedBox(width: 6),
                                      Text('SUB CODE', style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.category_rounded, size: 13, color: Color(0xFF059669)),
                                      SizedBox(width: 6),
                                      Text('CATEGORY NAME', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 75, child: Center(child: Text('ACTIONS', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 11)))),
                              ],
                            ),
                          ),

                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                          Expanded(
                            child: ListView.separated(
                              controller: _tableScrollCtrl,
                              itemCount: list.length,
                              separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (ctx, idx) {
                                final item = list[idx];
                                final isDeleting = _deletingCode == item.ismMsCode;
                                final isGlowing = widget.glowingCode == item.ismMsCode;

                                final Color rowBgColor = isGlowing
                                    ? const Color(0xFFD1FAE5)
                                    : (idx % 2 == 0 ? const Color(0xFFFAFAFA) : Colors.white);

                                return InkWell(
                                  onTap: () {
                                    widget.onSelect(item);
                                    Navigator.of(context).pop();
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    height: 42,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: rowBgColor,
                                      border: Border(
                                        left: BorderSide(
                                          color: isGlowing ? const Color(0xFF10B981) : Colors.transparent,
                                          width: isGlowing ? 4 : 0,
                                        ),
                                      ),
                                      boxShadow: isGlowing
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Row(
                                      children: [
                                        // MS CODE (Amber Badge)
                                        SizedBox(
                                          width: 120,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isGlowing ? const Color(0xFF10B981) : const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(14),
                                                  border: Border.all(color: isGlowing ? const Color(0xFF047857) : const Color(0xFFFDE68A)),
                                                ),
                                                child: Text(
                                                  item.ismMsCode,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isGlowing ? Colors.white : const Color(0xFFD97706),
                                                  ),
                                                ),
                                              ),
                                              if (isGlowing) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF047857)),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // MAIN CODE (Blue)
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            item.ismMCode,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                          ),
                                        ),

                                        // SUB CODE (Cyan)
                                        SizedBox(
                                          width: 120,
                                          child: Text(
                                            item.ismSubCode,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)),
                                          ),
                                        ),

                                        // CATEGORY NAME (Emerald)
                                        Expanded(
                                          child: Text(
                                            item.catName.isNotEmpty ? item.catName : 'Cat #${item.ismSubCatCode}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: isGlowing ? FontWeight.w800 : FontWeight.w600,
                                              color: isGlowing ? const Color(0xFF047857) : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        // ACTIONS (SELECTION CHECKBOX + EDIT BUTTON + DELETE BUTTON)
                                        SizedBox(
                                          width: 110,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Round Green Selection Checkbox
                                              Tooltip(
                                                message: 'Select Record',
                                                child: InkWell(
                                                  onTap: () {
                                                    widget.onSelect(item);
                                                    Navigator.of(context).pop();
                                                  },
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(milliseconds: 180),
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isGlowing ? const Color(0xFF10B981) : Colors.white,
                                                      border: Border.all(
                                                        color: isGlowing ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                                                        width: 1.6,
                                                      ),
                                                      boxShadow: isGlowing
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                                                blurRadius: 6,
                                                                offset: const Offset(0, 1),
                                                              ),
                                                            ]
                                                          : [],
                                                    ),
                                                    child: isGlowing
                                                        ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Edit Icon Button
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF2563EB)),
                                                tooltip: 'Select & Edit Record',
                                                constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                                padding: EdgeInsets.zero,
                                                onPressed: () {
                                                  widget.onSelect(item);
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              const SizedBox(width: 6),
                                              if (isDeleting) ...[
                                                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444))),
                                              ] else ...[
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                                                  tooltip: 'Delete Record',
                                                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () => _handleDelete(item.ismMsCode),
                                                ),
                                              ],
                                            ],
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
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. 100% IDENTICAL EXPORT MODAL DIALOG (OPERATOR MASTER PARITY)
// ============================================================================
class _GroupMasterDefinitionExportModalDialog extends StatefulWidget {
  final List<GroupMasterDefinitionItem> items;
  const _GroupMasterDefinitionExportModalDialog({required this.items});

  @override
  State<_GroupMasterDefinitionExportModalDialog> createState() => _GroupMasterDefinitionExportModalDialogState();
}

class _GroupMasterDefinitionExportModalDialogState extends State<_GroupMasterDefinitionExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.ismMsCode).toSet();
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

  List<GroupMasterDefinitionItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      return i.ismMsCode.toLowerCase().contains(_modalSearchQuery) ||
          i.ismMCode.toLowerCase().contains(_modalSearchQuery) ||
          i.ismSubCode.toLowerCase().contains(_modalSearchQuery) ||
          i.catName.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.ismMsCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.ismMsCode);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.ismMsCode);
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
        .where((i) => _selectedCodes.contains(i.ismMsCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String fileName = _selectedFormat == 'XLSX'
          ? 'Group_Master_Definition_$timeStamp.xlsx'
          : 'Group_Master_Definition_$timeStamp.pdf';

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

  List<int>? _generateExcelBytes(List<GroupMasterDefinitionItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Group Definitions');
    final excel_pkg.Sheet sheet = excel['Group Definitions'];

    final cellBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
      borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
    );

    final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#2563EB'),
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
    sheet.setColumnWidth(1, 16.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 35.0);

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('MS CODE'),
      excel_pkg.TextCellValue('MAIN CODE'),
      excel_pkg.TextCellValue('SUB CODE'),
      excel_pkg.TextCellValue('CATEGORY NAME'),
    ]);

    for (int col = 0; col < 4; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.TextCellValue(item.ismMsCode),
        excel_pkg.TextCellValue(item.ismMCode),
        excel_pkg.TextCellValue(item.ismSubCode),
        excel_pkg.TextCellValue(item.catName),
      ]);

      for (int col = 0; col < 4; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<GroupMasterDefinitionItem> records) async {
    final pdf = pw.Document();

    pdf.addPage(
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
                  'GROUP MASTER DEFINITION REPORT (ITEMSUBMST)',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                pw.Text(
                  'NEW TECH INFOSOL MMS',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1, color: PdfColors.blue800),
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
            headers: ['MS CODE', 'MAIN CODE', 'SUB CODE', 'CATEGORY NAME'],
            data: records.map((i) => [
              i.ismMsCode,
              i.ismMCode,
              i.ismSubCode,
              i.catName,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2563EB)),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                // LEFT COLUMN: Format Selector & Options
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
                                Text('Export Group Master Definition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
    final previewList = _filteredPreviewItems;
    final selectedCount = previewList.where((i) => _selectedCodes.contains(i.ismMsCode)).length;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12, color: AppColors.neutralDark),
              decoration: InputDecoration(
                hintText: 'Search definitions...',
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
            '$selectedCount of ${widget.items.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
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
              'No records found',
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
                  SizedBox(width: 90, child: Text('MS CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('MAIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 80, child: Text('SUB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('CATEGORY NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedCodes.contains(item.ismMsCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.ismMsCode);
                        } else {
                          _selectedCodes.add(item.ismMsCode);
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
                                    _selectedCodes.add(item.ismMsCode);
                                  } else {
                                    _selectedCodes.remove(item.ismMsCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(
                              item.ismMsCode,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              item.ismMCode,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              item.ismSubCode,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.catName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bodyText),
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
// ── HOVERABLE DATA GRID ROW WIDGET (DEPARTMENT MASTER PARITY & GOOD SPACING)
// ============================================================================
class _HoverableDataGridRow extends StatefulWidget {
  final int index;
  final GroupMasterDefinitionItem item;
  final bool isGlowing;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HoverableDataGridRow({
    super.key,
    required this.index,
    required this.item,
    required this.isGlowing,
    required this.isNewGlow,
    required this.isUpdateGlow,
    required this.isSelected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_HoverableDataGridRow> createState() => _HoverableDataGridRowState();
}

class _HoverableDataGridRowState extends State<_HoverableDataGridRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final idx = widget.index;
    final isNew = widget.isNewGlow;
    final isUpdate = widget.isUpdateGlow;
    final isGlowing = widget.isGlowing || isNew || isUpdate;
    final isSelected = widget.isSelected;

    // Glowing color logic (Matching Department Master: Green for new, Amber/Purple for update)
    final Color glowColor = isUpdate ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onSelect,
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
                // SR NO (65px) - Code Badge + Star (Identical to Department Master)
                SizedBox(
                  width: 65,
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
                          '#${idx + 1}',
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

                // MS CODE (100px) - Clean typography
                SizedBox(
                  width: 100,
                  child: Center(
                    child: Text(
                      item.ismMsCode,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // MAIN CODE (90px) - Clean typography
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      item.ismMCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // SUB CODE (90px) - Clean typography
                SizedBox(
                  width: 90,
                  child: Center(
                    child: Text(
                      item.ismSubCode,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutralDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // CATEGORY NAME (Expanded) - Clean Bold Text (Identical to Department Name in Department Master)
                Expanded(
                  child: Text(
                    item.catName.isNotEmpty ? item.catName : 'Category #${item.ismSubCatCode}',
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

                // ACTIONS (75px) - Edit & Delete Buttons (Department Master Parity)
                SizedBox(
                  width: 75,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _GridActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Mapping',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 4),
                      _GridActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFEF4444),
                        tooltip: 'Delete Mapping',
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
class _GridActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _GridActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_GridActionButton> createState() => _GridActionButtonState();
}

class _GridActionButtonState extends State<_GridActionButton> {
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
// RICH 3D VECTOR BRAND LOGO WIDGETS & ANIMATED BUTTONS
// ============================================================================

/// 100% Identical Sub-Group Mapping Definition Vector Network Logo (Image 2 Parity)
class _SubGroupMappingDefinitionLogoWidget extends StatelessWidget {
  final double size;
  const _SubGroupMappingDefinitionLogoWidget({this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _SubGroupMappingDefinitionLogoPainter(),
      ),
    );
  }
}

class _SubGroupMappingDefinitionLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 980.0;

    final cx = 496.0 * s;
    final cy = 484.0 * s;
    final blueR = 234.5 * s;

    // 6 Outer Nodes: (Color, nx, ny, nr)
    final nodes = [
      (const Color(0xFFFAAE58), 496.0 * s, 115.0 * s, 49.0 * s), // 1. Top (Orange)
      (const Color(0xFFEF5555), 857.5 * s, 121.5 * s, 48.5 * s), // 2. Top-Right (Red)
      (const Color(0xFF44B86D), 760.5 * s, 754.0 * s, 48.5 * s), // 3. Bottom-Right (Green)
      (const Color(0xFFFAAE58), 496.5 * s, 864.5 * s, 48.5 * s), // 4. Bottom (Orange)
      (const Color(0xFFEF5555), 143.5 * s, 835.5 * s, 48.5 * s), // 5. Bottom-Left (Red)
      (const Color(0xFF44B86D), 121.0 * s, 480.5 * s, 49.0 * s), // 6. Left (Green)
    ];

    // 1. Connector Lines (Connecting outer nodes to center)
    final linePaint = Paint()
      ..color = const Color(0xFFCFCFCD)
      ..strokeWidth = 28.0 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    for (final node in nodes) {
      canvas.drawLine(Offset(cx, cy), Offset(node.$2, node.$3), linePaint);
    }

    // 2. Connector Joint Collars at edge of blue circle
    final jointPaint = Paint()
      ..color = const Color(0xFFB8B9BB)
      ..strokeWidth = 28.0 * s
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt
      ..isAntiAlias = true;

    const jointLen = 28.0;
    for (final node in nodes) {
      final ang = math.atan2(node.$3 - cy, node.$2 - cx);
      final x1 = cx + (blueR - 2.0 * s) * math.cos(ang);
      final y1 = cy + (blueR - 2.0 * s) * math.sin(ang);
      final x2 = cx + (blueR + jointLen * s) * math.cos(ang);
      final y2 = cy + (blueR + jointLen * s) * math.sin(ang);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), jointPaint);
    }

    // 3. Central Blue Circle
    final bluePaint = Paint()
      ..color = const Color(0xFF4A81C2)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(cx, cy), blueR, bluePaint);

    // 4. White Avatar inside Blue Circle
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Avatar Head
    canvas.drawCircle(Offset(496.0 * s, 396.0 * s), 76.0 * s, whitePaint);

    // Avatar Body (rounded shoulders & rounded bottom)
    final bwHalf = 150.0 * s;
    final bodyPath = Path();
    bodyPath.moveTo(496.0 * s - bwHalf, 595.0 * s);

    // Shoulders curve up to neck
    bodyPath.cubicTo(
      496.0 * s - bwHalf, 520.0 * s,
      496.0 * s - 70.0 * s, 486.0 * s,
      496.0 * s, 486.0 * s,
    );
    bodyPath.cubicTo(
      496.0 * s + 70.0 * s, 486.0 * s,
      496.0 * s + bwHalf, 520.0 * s,
      496.0 * s + bwHalf, 595.0 * s,
    );

    // Rounded bottom corners
    bodyPath.quadraticBezierTo(
      496.0 * s + bwHalf, 618.0 * s,
      496.0 * s + bwHalf - 20.0 * s, 618.0 * s,
    );
    bodyPath.lineTo(496.0 * s - bwHalf + 20.0 * s, 618.0 * s);
    bodyPath.quadraticBezierTo(
      496.0 * s - bwHalf, 618.0 * s,
      496.0 * s - bwHalf, 595.0 * s,
    );
    bodyPath.close();

    canvas.drawPath(bodyPath, whitePaint);

    // 5. Outer Node Circles
    for (final node in nodes) {
      final nodePaint = Paint()
        ..color = node.$1
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawCircle(Offset(node.$2, node.$3), node.$4, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 100% Identical Vector Table Document Logo (Image 2 Parity)
class _TableDocumentLogoWidget extends StatelessWidget {
  final double size;
  const _TableDocumentLogoWidget({this.size = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: const _TableDocumentLogoPainter(),
      ),
    );
  }
}

class _TableDocumentLogoPainter extends CustomPainter {
  const _TableDocumentLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    // 1. Electric Cyan/Azure Circular Background
    final circlePaint = Paint()
      ..color = const Color(0xFF00BEFF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, circlePaint);

    // 2. White Document Sheet Geometry
    final double docW = w * 0.49;
    final double docH = h * 0.63;
    final double docLeft = (w - docW) / 2;
    final double docTop = (h - docH) / 2;
    final double docRight = docLeft + docW;
    final double docBottom = docTop + docH;

    // Dog-Ear Fold Dimension
    final double foldW = docW * 0.40;
    final double foldH = docH * 0.165;
    final double foldLeft = docRight - foldW;
    final double foldBottom = docTop + foldH;

    // Draw Main White Paper with Fold Cutout
    final paperPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final paperPath = Path()
      ..moveTo(docLeft, docTop)
      ..lineTo(foldLeft, docTop)
      ..lineTo(foldLeft, foldBottom)
      ..lineTo(docRight, foldBottom)
      ..lineTo(docRight, docBottom)
      ..lineTo(docLeft, docBottom)
      ..close();
    canvas.drawPath(paperPath, paperPaint);

    // 3. Gray Dog-Ear Fold Flap
    final grayPaint = Paint()
      ..color = const Color(0xFFAFAFAF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final foldPath = Path()
      ..moveTo(foldLeft, docTop)
      ..lineTo(foldLeft, foldBottom)
      ..lineTo(docRight, foldBottom)
      ..close();
    canvas.drawPath(foldPath, grayPaint);

    // 4. Gray Placeholder Text Lines (5 Lines with Exact Segmentation)
    final double lineH = docH * 0.040;
    final rRadius = Radius.circular(lineH * 0.3);

    void drawSegment(double relX1, double relX2, double relY) {
      final rect = Rect.fromLTRB(
        docLeft + docW * relX1,
        docTop + docH * relY - lineH / 2,
        docLeft + docW * relX2,
        docTop + docH * relY + lineH / 2,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, rRadius), grayPaint);
    }

    // Line 1: solid before fold
    drawSegment(0.10, 0.48, 0.24);

    // Line 2: two segments
    drawSegment(0.10, 0.44, 0.39);
    drawSegment(0.53, 0.88, 0.39);

    // Line 3: two segments
    drawSegment(0.10, 0.68, 0.54);
    drawSegment(0.76, 0.88, 0.54);

    // Line 4: three segments
    drawSegment(0.10, 0.38, 0.69);
    drawSegment(0.46, 0.74, 0.69);
    drawSegment(0.81, 0.88, 0.69);

    // Line 5: two segments
    drawSegment(0.10, 0.26, 0.84);
    drawSegment(0.34, 0.88, 0.84);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GroupMasterDefinitionHeaderLogoWidget extends StatelessWidget {
  final double size;
  const _GroupMasterDefinitionHeaderLogoWidget({this.size = 50.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GroupMasterDefinitionLogoPainter(),
      ),
    );
  }
}

class _GroupMasterDefinitionLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 128.0;

    final ringPaint = Paint()
      ..color = const Color(0xFF7986BF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5 * s
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final arrowFillPaint = Paint()
      ..color = const Color(0xFF7986BF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final cx = 63.5 * s;
    final cy = 63.5 * s;
    final r = 60.5 * s;

    // 1. Two Circular Arrows (Clockwise circular flow)
    // Arc 1: from bottom under handle (78°) clockwise to top-left (236°)
    const angle1Start = 78.0 * math.pi / 180.0;
    const angle1End = 236.0 * math.pi / 180.0;
    const sweep1 = angle1End - angle1Start;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      angle1Start,
      sweep1,
      false,
      ringPaint,
    );

    // Arc 2: from top (253°) clockwise to bottom-right (44°)
    const angle2Start = 253.0 * math.pi / 180.0;
    const sweep2 = (360.0 - 253.0 + 44.0) * math.pi / 180.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      angle2Start,
      sweep2,
      false,
      ringPaint,
    );

    // Arrowhead helper
    void drawArrowhead(double angleDeg) {
      final rad = angleDeg * math.pi / 180.0;
      final px = cx + r * math.cos(rad);
      final py = cy + r * math.sin(rad);

      // Tangent (clockwise)
      final tx = -math.sin(rad);
      final ty = math.cos(rad);
      // Normal (outward)
      final nx = math.cos(rad);
      final ny = math.sin(rad);

      final tip = Offset(px + tx * 8.5 * s, py + ty * 8.5 * s);
      final w1 = Offset(px - tx * 1.5 * s + nx * 5.2 * s, py - ty * 1.5 * s + ny * 5.2 * s);
      final w2 = Offset(px - tx * 1.5 * s - nx * 5.2 * s, py - ty * 1.5 * s - ny * 5.2 * s);

      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(w1.dx, w1.dy)
        ..lineTo(px, py)
        ..lineTo(w2.dx, w2.dy)
        ..close();

      canvas.drawPath(path, arrowFillPaint);
    }

    drawArrowhead(236.0);
    drawArrowhead(44.0);

    // 2. Three Person Avatars
    void drawPersonBody({
      required double bx,
      required double topY,
      required double bottomY,
      required double width,
      required Color color,
    }) {
      final height = bottomY - topY;
      final left = bx - width / 2;
      final right = bx + width / 2;

      final path = Path();
      path.moveTo(left, bottomY);
      // Smooth bell curve / shoulder dome
      path.cubicTo(
        left, bottomY - height * 0.45,
        bx - width * 0.32, topY,
        bx, topY,
      );
      path.cubicTo(
        bx + width * 0.32, topY,
        right, bottomY - height * 0.45,
        right, bottomY,
      );
      path.close();

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawPath(path, paint);
    }

    void drawPersonHead(double hx, double hy, double hr) {
      final headPaint = Paint()
        ..color = const Color(0xFFFFCEC0)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.drawCircle(Offset(hx, hy), hr, headPaint);
    }

    // Top Person (Orange)
    drawPersonBody(
      bx: 63.5 * s,
      topY: 27.5 * s,
      bottomY: 43.5 * s,
      width: 34.0 * s,
      color: const Color(0xFFFF8748),
    );
    drawPersonHead(63.5 * s, 19.5 * s, 7.0 * s);

    // Bottom-Left Person (Lime Green)
    drawPersonBody(
      bx: 36.5 * s,
      topY: 62.5 * s,
      bottomY: 77.5 * s,
      width: 30.0 * s,
      color: const Color(0xFFBAED2C),
    );
    drawPersonHead(36.5 * s, 54.5 * s, 7.0 * s);

    // Bottom-Right Person (Sky Blue)
    drawPersonBody(
      bx: 90.5 * s,
      topY: 62.5 * s,
      bottomY: 77.5 * s,
      width: 30.0 * s,
      color: const Color(0xFF4EB1FC),
    );
    drawPersonHead(90.5 * s, 54.5 * s, 7.0 * s);

    // 3. Magnifying Glass
    final lx = 63.5 * s;
    final ly = 86.5 * s;
    final rimR = 21.0 * s;
    final glassR = 14.5 * s;

    // Handle (45° diagonal down-right)
    const hAngle = math.pi / 4.0;
    final hDx = math.cos(hAngle);
    final hDy = math.sin(hAngle);
    final hPx = -hDy;
    final hPy = hDx;
    final hw = 4.6 * s;

    final sOff = Offset(lx + hDx * 18.5 * s, ly + hDy * 18.5 * s);
    final eOff = Offset(lx + hDx * 47.5 * s, ly + hDy * 47.5 * s);

    final pTop1 = Offset(sOff.dx - hPx * hw, sOff.dy - hPy * hw);
    final pTop2 = Offset(eOff.dx - hPx * hw, eOff.dy - hPy * hw);
    final pBot1 = Offset(sOff.dx + hPx * hw, sOff.dy + hPy * hw);
    final pBot2 = Offset(eOff.dx + hPx * hw, eOff.dy + hPy * hw);

    // Upper lighter half of handle
    final handleTopPaint = Paint()
      ..color = const Color(0xFFC86F5C)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final handleTopPath = Path()
      ..moveTo(pTop1.dx, pTop1.dy)
      ..lineTo(pTop2.dx, pTop2.dy)
      ..lineTo(eOff.dx, eOff.dy)
      ..lineTo(sOff.dx, sOff.dy)
      ..close();
    canvas.drawPath(handleTopPath, handleTopPaint);

    // Lower darker half of handle
    final handleDarkPaint = Paint()
      ..color = const Color(0xFFA34F41)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final handleDarkPath = Path()
      ..moveTo(sOff.dx, sOff.dy)
      ..lineTo(eOff.dx, eOff.dy)
      ..lineTo(pBot2.dx, pBot2.dy)
      ..lineTo(pBot1.dx, pBot1.dy)
      ..close();
    canvas.drawPath(handleDarkPath, handleDarkPaint);

    // Rounded tip of handle
    canvas.drawCircle(eOff, hw, handleDarkPaint);

    // Soft drop shadow under magnifying glass rim
    canvas.drawCircle(
      Offset(lx, ly + 1.5 * s),
      rimR,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
    );

    // Outer Rim
    final rimPaint = Paint()
      ..color = const Color(0xFFFFCEC0)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(lx, ly), rimR, rimPaint);

    // Glass Lens
    final glassPaint = Paint()
      ..color = const Color(0xFFF3F3FF)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(Offset(lx, ly), glassR, glassPaint);

    // Subtle glossy glass shine arc
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(lx, ly), radius: glassR * 0.72),
      -140.0 * math.pi / 180.0,
      65.0 * math.pi / 180.0,
      false,
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

class _AnimatedShowRecordButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedShowRecordButton({required this.onTap});

  @override
  State<_AnimatedShowRecordButton> createState() => _AnimatedShowRecordButtonState();
}

class _AnimatedShowRecordButtonState extends State<_AnimatedShowRecordButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _magnifySwingAnim;
  late Animation<double> _magnifyScaleAnim;
  late Animation<double> _pulseGlowAnim;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _magnifySwingAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -0.22).chain(CurveTween(curve: Curves.easeOut)), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: -0.22, end: 0.22).chain(CurveTween(curve: Curves.easeInOut)), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.22, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_animController);

    _magnifyScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 70),
    ]).animate(_animController);

    _pulseGlowAnim = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _isHovered = true);
    _animController.repeat(reverse: true);
  }

  void _onExit(_) {
    setState(() => _isHovered = false);
    _animController.stop();
    _animController.animateTo(0.0, duration: const Duration(milliseconds: 200));
  }

  void _handleTap() {
    _animController.forward(from: 0.0).then((_) {
      if (mounted && !_isHovered) {
        _animController.animateTo(0.0);
      }
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: _handleTap,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isHovered ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _isHovered ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isHovered ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: _isHovered ? 0.25 : 0.08),
                      blurRadius: _isHovered ? _pulseGlowAnim.value : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _magnifyScaleAnim.value,
                      child: Transform.rotate(
                        angle: _magnifySwingAnim.value,
                        child: Icon(
                          Icons.manage_search_rounded,
                          size: 17,
                          color: _isHovered ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Show Record',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? const Color(0xFF1E40AF) : const Color(0xFF1D4ED8),
                        letterSpacing: 0.1,
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
// ANIMATED EXPORT BUTTON (Circulating Edge Light Orbit Animation - 100% OPERATOR MASTER PARITY)
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
// 10. SEARCHABLE DROPDOWN FIELD WIDGET (LIVE SEARCH + GLASSMORPHIC POPOVER)
// ============================================================================
class _SearchableDropdownField<T> extends StatefulWidget {
  final String hintText;
  final String selectedValue;
  final String displayLabel;
  final List<T> items;
  final String Function(T) getItemCode;
  final String Function(T) getItemName;
  final ValueChanged<T> onSelected;
  final Color accentColor;
  final Color badgeBgColor;
  final Color badgeTextColor;

  const _SearchableDropdownField({
    super.key,
    required this.hintText,
    required this.selectedValue,
    required this.displayLabel,
    required this.items,
    required this.getItemCode,
    required this.getItemName,
    required this.onSelected,
    required this.accentColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
  });

  @override
  State<_SearchableDropdownField<T>> createState() => _SearchableDropdownFieldState<T>();
}

class _SearchableDropdownFieldState<T> extends State<_SearchableDropdownField<T>> {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: widget.hintText,
      offset: const Offset(-10, 40),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      constraints: const BoxConstraints(maxHeight: 380, minWidth: 300, maxWidth: 360),
      itemBuilder: (context) {
        return [
          PopupMenuItem<T>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: _SearchableDropdownMenuContent<T>(
              hintText: widget.hintText,
              selectedValue: widget.selectedValue,
              items: widget.items,
              getItemCode: widget.getItemCode,
              getItemName: widget.getItemName,
              onSelected: (val) {
                widget.onSelected(val);
                Navigator.of(context).pop();
              },
              accentColor: widget.accentColor,
              badgeBgColor: widget.badgeBgColor,
              badgeTextColor: widget.badgeTextColor,
            ),
          ),
        ];
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.selectedValue.isNotEmpty ? widget.displayLabel : widget.hintText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.selectedValue.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded, color: widget.accentColor),
          ],
        ),
      ),
    );
  }
}

class _SearchableDropdownMenuContent<T> extends StatefulWidget {
  final String hintText;
  final String selectedValue;
  final List<T> items;
  final String Function(T) getItemCode;
  final String Function(T) getItemName;
  final ValueChanged<T> onSelected;
  final Color accentColor;
  final Color badgeBgColor;
  final Color badgeTextColor;

  const _SearchableDropdownMenuContent({
    required this.hintText,
    required this.selectedValue,
    required this.items,
    required this.getItemCode,
    required this.getItemName,
    required this.onSelected,
    required this.accentColor,
    required this.badgeBgColor,
    required this.badgeTextColor,
  });

  @override
  State<_SearchableDropdownMenuContent<T>> createState() => _SearchableDropdownMenuContentState<T>();
}

class _SearchableDropdownMenuContentState<T> extends State<_SearchableDropdownMenuContent<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<T> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    return widget.items.where((item) {
      final code = widget.getItemCode(item).toLowerCase();
      final name = widget.getItemName(item).toLowerCase();
      return code.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Container(
      width: 320,
      constraints: const BoxConstraints(maxHeight: 340),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Search Bar Input
          SizedBox(
            height: 36,
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Search by code or name...',
                hintStyle: TextStyle(fontSize: 11.5, color: const Color(0xFF0F172A).withValues(alpha: 0.4), fontWeight: FontWeight.normal),
                prefixIcon: Icon(Icons.search_rounded, size: 16, color: widget.accentColor),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.accentColor, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),

          // Filtered List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No matching items found', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final item = filtered[idx];
                      final code = widget.getItemCode(item);
                      final name = widget.getItemName(item);
                      final isSelected = code == widget.selectedValue;

                      return InkWell(
                        onTap: () => widget.onSelected(item),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? widget.accentColor.withValues(alpha: 0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              // Green Checkbox Indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF10B981) : Colors.white,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                                    width: 1.5,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              // Code Badge Pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected ? widget.accentColor : widget.badgeBgColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '[$code]',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : widget.badgeTextColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Name Text
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? widget.accentColor : const Color(0xFF0F172A),
                                  ),
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
