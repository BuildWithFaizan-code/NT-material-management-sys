import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../design/app_colors.dart';
import '../services/group_master_service.dart';
import '../utils/file_export_helper.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// MAIN PAGE: GroupMasterPage (Category Master Form-Only Architecture)
// ============================================================================
class GroupMasterPage extends StatefulWidget {
  const GroupMasterPage({super.key});

  @override
  State<GroupMasterPage> createState() => _GroupMasterPageState();
}

class _GroupMasterPageState extends State<GroupMasterPage> {
  final GroupMasterService _service = GroupMasterService();
  final FocusNode _pageKeyFocusNode = FocusNode();

  // State Data
  List<GroupMasterItem> _allItems = [];
  List<TaxSlabItem> _taxSlabs = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Active Form Controls
  bool _isEditing = false;
  final TextEditingController _catCodeCtrl = TextEditingController();
  final TextEditingController _catNameCtrl = TextEditingController();
  final TextEditingController _catHsnCtrl = TextEditingController();
  final TextEditingController _catTolCtrl = TextEditingController();
  final TextEditingController _catShortCtrl = TextEditingController();
  final TextEditingController _packTypeNameCtrl = TextEditingController();

  String _selectedTaxSlab = '';

  // Config Switches / Toggles ('Yes'/'No')
  bool _palletReq = false;
  bool _sizeReq = false;
  bool _boxReq = false;
  bool _gradeReq = false;
  bool _gsmReq = false;

  final FocusNode _catCodeFocusNode = FocusNode();
  final FocusNode _catNameFocusNode = FocusNode();
  final FocusNode _catHsnFocusNode = FocusNode();

  // Button Action & Notification States
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  String? _buttonValidationMsg;
  bool _isResetting = false;

  // Row Glow Highlight State (4-second Strategy)
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  String? _glowingCode;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _pageKeyFocusNode.dispose();
    _catCodeCtrl.dispose();
    _catNameCtrl.dispose();
    _catHsnCtrl.dispose();
    _catTolCtrl.dispose();
    _catShortCtrl.dispose();
    _packTypeNameCtrl.dispose();
    _catCodeFocusNode.dispose();
    _catNameFocusNode.dispose();
    _catHsnFocusNode.dispose();
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
      final taxSlabs = await _service.getTaxSlabs();
      if (!mounted) return;

      setState(() {
        _allItems = items;
        _taxSlabs = taxSlabs;
        if (_taxSlabs.isNotEmpty && _selectedTaxSlab.isEmpty) {
          _selectedTaxSlab = _taxSlabs.first.taxCode;
        }
        _isLoading = false;
      });

      _prepareNewGroup();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to Group Master API: $e';
      });
    }
  }

  String _generateNextCodeLocally() {
    int maxNum = 0;
    for (final item in _allItems) {
      final n = int.tryParse(item.catCode.trim());
      if (n != null && n > maxNum) {
        maxNum = n;
      }
    }
    return (maxNum + 1).toString();
  }

  Future<void> _fetchRemoteNextCode() async {
    try {
      final remoteCode = await _service.getNextCode();
      if (remoteCode.isNotEmpty && mounted && !_isEditing) {
        setState(() {
          _catCodeCtrl.text = remoteCode;
        });
      }
    } catch (_) {}
  }

  Future<void> _prepareNewGroup() async {
    final nextCode = _generateNextCodeLocally();
    setState(() {
      _isResetting = true;
      _isEditing = false;
      _catCodeCtrl.text = nextCode;
      _catNameCtrl.clear();
      _catHsnCtrl.clear();
      _catTolCtrl.text = '0';
      _catShortCtrl.clear();
      _packTypeNameCtrl.clear();
      _palletReq = false;
      _sizeReq = false;
      _boxReq = false;
      _gradeReq = false;
      _gsmReq = false;
      _buttonValidationMsg = null;
    });

    if (_taxSlabs.isNotEmpty) {
      _selectedTaxSlab = _taxSlabs.first.taxCode;
    }

    _fetchRemoteNextCode();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    });
  }

  void _selectGroupForEditing(GroupMasterItem item) {
    setState(() {
      _isEditing = true;
      _catCodeCtrl.text = item.catCode;
      _catNameCtrl.text = item.catName;
      _catHsnCtrl.text = item.catHsn;
      _catTolCtrl.text = item.catTol.toString();
      _catShortCtrl.text = item.catShort;
      _packTypeNameCtrl.text = item.packTypeName;

      if (_taxSlabs.any((t) => t.taxCode == item.catTaxSlab)) {
        _selectedTaxSlab = item.catTaxSlab;
      } else if (_taxSlabs.isNotEmpty) {
        _selectedTaxSlab = _taxSlabs.first.taxCode;
      }

      _palletReq = item.palletReq.toLowerCase() == 'yes';
      _sizeReq = item.sizeReq.toLowerCase() == 'yes';
      _boxReq = item.boxReq.toLowerCase() == 'yes';
      _gradeReq = item.gradeReq.toLowerCase() == 'yes';
      _gsmReq = item.gsmReq.toLowerCase() == 'yes';

      _buttonValidationMsg = null;
    });
    _catNameFocusNode.requestFocus();
    _triggerEntryGlow(item.catCode, isUpdate: true);
  }

  void _triggerEntryGlow(String code, {bool isNew = false, bool isUpdate = false}) {
    _glowTimer?.cancel();
    setState(() {
      _glowingCode = code;
      if (isNew) {
        _recentlySavedCode = code;
        _recentlyUpdatedCode = null;
      } else if (isUpdate) {
        _recentlyUpdatedCode = code;
        _recentlySavedCode = null;
      }
    });

    _glowTimer = Timer(const Duration(seconds: 4), () {
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

    String code = _catCodeCtrl.text.trim();
    if (code.isEmpty && !_isEditing) {
      code = _generateNextCodeLocally();
      _catCodeCtrl.text = code;
    }
    final name = _catNameCtrl.text.trim();

    if (code.isEmpty) {
      _showButtonValidation('Group Code could not be generated!');
      return;
    }

    if (name.isEmpty) {
      _showButtonValidation('Please enter Group Name!');
      _catNameFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final item = GroupMasterItem(
      catCode: code,
      catName: name,
      catHsn: _catHsnCtrl.text.trim(),
      catTaxSlab: _selectedTaxSlab,
      palletReq: _palletReq ? 'Yes' : 'No',
      sizeReq: _sizeReq ? 'Yes' : 'No',
      boxReq: _boxReq ? 'Yes' : 'No',
      gradeReq: _gradeReq ? 'Yes' : 'No',
      gsmReq: _gsmReq ? 'Yes' : 'No',
      catTol: double.tryParse(_catTolCtrl.text.trim()) ?? 0.0,
      catShort: _catShortCtrl.text.trim(),
      packTypeName: _packTypeNameCtrl.text.trim(),
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

        // TRIGGER ENTRY GLOW & REFRESH DATA FOR NEXT ENTRY
        _triggerEntryGlow(code, isNew: isCreatingNew, isUpdate: !isCreatingNew);
        Future.delayed(const Duration(milliseconds: 1200), () async {
          if (mounted) {
            setState(() => _isSaveSuccess = false);
            final updatedItems = await _service.getAllItems();
            setState(() {
              _allItems = updatedItems;
            });
            _prepareNewGroup();
          }
        });
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save Group Record to database.');
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

  void _openShowRecordModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GroupMasterRecordLookupModal(
        items: _allItems,
        service: _service,
        recentlySavedCode: _recentlySavedCode,
        recentlyUpdatedCode: _recentlyUpdatedCode,
        glowingCode: _glowingCode,
        onSelect: (item) {
          _selectGroupForEditing(item);
        },
        onRefreshNeeded: () async {
          final updated = await _service.getAllItems();
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
      builder: (context) => _GroupMasterExportModalDialog(items: _allItems),
    );
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD (SINGLE VIEWPORT PAGE - NO VERTICAL SCROLLBAR)
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
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  children: [
                    // 1. SCREEN HEADER TOOLBAR
                    _buildScreenHeader(),
                    const SizedBox(height: 12),

                    // 2. MAIN SINGLE PAGE FORM-ONLY WORKSPACE (NO VERTICAL SCROLL)
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                          : _errorMessage != null
                              ? _buildErrorState()
                              : _buildHomeFormCard(),
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
          // 100% IDENTICAL 3D ISOMETRIC GEOMETRIC SHAPES LOGO (DIRECT ON WHITE)
          const _GroupMasterHeaderLogoWidget(height: 44),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Group Master',
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
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_allItems.length} Category Groups',
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

          // SHOW RECORD LOOKUP BUTTON
          _AnimatedShowRecordButton(onTap: _openShowRecordModal),

          const SizedBox(width: 10),

          // ANIMATED ORBIT EXPORT BUTTON (OPERATOR MASTER STYLE)
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. FORM-ONLY HOME SCREEN CARD (CLEAN TITLES WITHOUT BRACKETS & SLEEK TOGGLES)
  // --------------------------------------------------------------------------
  Widget _buildHomeFormCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // Section Title Header
          Row(
            children: [
              const _GroupCategoryDetailsLogoWidget(size: 30),
              const SizedBox(width: 10),
              const Text(
                'GROUP CATEGORY DETAILS',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
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
                        'Editing Group #${_catCodeCtrl.text}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // ROW 1: GROUP CODE, GROUP NAME, HSN/SAC CODE (BRACKETS REMOVED)
          Row(
            children: [
              // FIELD 1: GROUP CODE (COBALT BLUE #2563EB)
              Expanded(
                flex: 2,
                child: _buildFormFieldCard(
                  title: 'GROUP CODE',
                  icon: Icons.qr_code_rounded,
                  iconColor: const Color(0xFF2563EB),
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _catCodeCtrl,
                      focusNode: _catCodeFocusNode,
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
                        hintText: 'Auto Code',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
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
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // FIELD 2: GROUP NAME (EMERALD GREEN #059669)
              Expanded(
                flex: 4,
                child: _buildFormFieldCard(
                  title: 'GROUP NAME',
                  icon: Icons.category_rounded,
                  iconColor: const Color(0xFF059669),
                  bgColor: const Color(0xFFD1FAE5),
                  borderColor: const Color(0xFFA7F3D0),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _catNameCtrl,
                      focusNode: _catNameFocusNode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. CHEMICAL, RAW MATERIALS',
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

              const SizedBox(width: 12),

              // FIELD 3: HSN/SAC CODE (INDIGO #4F46E5)
              Expanded(
                flex: 3,
                child: _buildFormFieldCard(
                  title: 'HSN / SAC CODE',
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  borderColor: const Color(0xFFC7D2FE),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _catHsnCtrl,
                      focusNode: _catHsnFocusNode,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. 657887',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ROW 2: TOLERANCE, TAX SLAB, WIP / SHORT NAME, PACK TYPE (BRACKETS REMOVED)
          Row(
            children: [
              // FIELD 4: TOLERANCE (CYAN #0891B2)
              Expanded(
                flex: 2,
                child: _buildFormFieldCard(
                  title: 'TOLERANCE %',
                  icon: Icons.tune_rounded,
                  iconColor: const Color(0xFF0891B2),
                  bgColor: const Color(0xFFECFEFF),
                  borderColor: const Color(0xFFA5F3FC),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _catTolCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: '0.0',
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

              const SizedBox(width: 12),

              // FIELD 5: TAX SLAB (AMBER #D97706)
              Expanded(
                flex: 3,
                child: _buildFormFieldCard(
                  title: 'TAX SLAB',
                  icon: Icons.percent_rounded,
                  iconColor: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFFDE68A),
                  child: _ModernTaxSlabDropdown(
                    selectedCode: _selectedTaxSlab,
                    slabs: _taxSlabs,
                    onChanged: (val) {
                      setState(() => _selectedTaxSlab = val);
                    },
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // FIELD 6: WIP / SHORT NAME (PURPLE #7C3AED)
              Expanded(
                flex: 2,
                child: _buildFormFieldCard(
                  title: 'WIP / SHORT NAME',
                  icon: Icons.alt_route_rounded,
                  iconColor: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFDDD6FE),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _catShortCtrl,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. YES, CHEM',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // FIELD 7: PACK TYPE NAME (SLATE #475569)
              Expanded(
                flex: 3,
                child: _buildFormFieldCard(
                  title: 'PACK TYPE NAME',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                  borderColor: const Color(0xFFCBD5E1),
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _packTypeNameCtrl,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'e.g. BOX, DRUM, BAG',
                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF475569), width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // CONFIG SWITCHES SECTION (SLEEK MODERN COMPACT ANIMATED TOGGLE CARDS)
          const Text(
            'CATEGORY CONFIGURATION SWITCHES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.3),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SleekConfigToggleCard(
                title: 'Pallet Required',
                icon: Icons.grid_view_rounded,
                iconColor: const Color(0xFF0D9488),
                bgColor: const Color(0xFFF0FDF4),
                value: _palletReq,
                onChanged: (val) => setState(() => _palletReq = val),
              ),
              _SleekConfigToggleCard(
                title: 'Size Master Required',
                icon: Icons.straighten_rounded,
                iconColor: const Color(0xFFE11D48),
                bgColor: const Color(0xFFFFE4E6),
                value: _sizeReq,
                onChanged: (val) => setState(() => _sizeReq = val),
              ),
              _SleekConfigToggleCard(
                title: 'Box Wise Transaction',
                icon: Icons.inventory_rounded,
                iconColor: const Color(0xFFEA580C),
                bgColor: const Color(0xFFFFEDD5),
                value: _boxReq,
                onChanged: (val) => setState(() => _boxReq = val),
              ),
              _SleekConfigToggleCard(
                title: 'Grade Wise Rate in PO',
                icon: Icons.grade_rounded,
                iconColor: const Color(0xFF65A30D),
                bgColor: const Color(0xFFECFDF5),
                value: _gradeReq,
                onChanged: (val) => setState(() => _gradeReq = val),
              ),
              _SleekConfigToggleCard(
                title: 'Lot+Design+Shade+GSM on BOM',
                icon: Icons.layers_rounded,
                iconColor: const Color(0xFF6D28D9),
                bgColor: const Color(0xFFF5F3FF),
                value: _gsmReq,
                onChanged: (val) => setState(() => _gsmReq = val),
              ),
            ],
          ),

          const Spacer(),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // FORM ACTION BUTTONS (RESET & GLOWING SAVE/UPDATE BUTTON)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildResetButton(),
              const SizedBox(width: 12),
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
// SLEEK ANIMATED CONFIGURATION TOGGLE CARD (COMPACT, GLOWING & ANIMATED)
// ============================================================================
class _SleekConfigToggleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SleekConfigToggleCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SleekConfigToggleCard> createState() => _SleekConfigToggleCardState();
}

class _SleekConfigToggleCardState extends State<_SleekConfigToggleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.value;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!active),
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: active ? widget.bgColor : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? widget.iconColor : const Color(0xFFE2E8F0),
                width: active ? 1.4 : 1.0,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: widget.iconColor.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : []),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: active ? widget.iconColor : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    widget.icon,
                    size: 13,
                    color: active ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.w600,
                    color: active ? widget.iconColor : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(width: 10),

                // Custom Animated Toggle Switch Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 34,
                  height: 18,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: active ? widget.iconColor : const Color(0xFFCBD5E1),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: active ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(0, 1),
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
      ),
    );
  }
}

// ============================================================================
// 3. "SHOW RECORD" LOOKUP MODAL (100% IDENTICAL TO NON-STOCKABLE ITEM IMAGE 2)
// ============================================================================
class _GroupMasterRecordLookupModal extends StatefulWidget {
  final List<GroupMasterItem> items;
  final GroupMasterService service;
  final String? recentlySavedCode;
  final String? recentlyUpdatedCode;
  final String? glowingCode;
  final ValueChanged<GroupMasterItem> onSelect;
  final Future<void> Function() onRefreshNeeded;

  const _GroupMasterRecordLookupModal({
    required this.items,
    required this.service,
    this.recentlySavedCode,
    this.recentlyUpdatedCode,
    this.glowingCode,
    required this.onSelect,
    required this.onRefreshNeeded,
  });

  @override
  State<_GroupMasterRecordLookupModal> createState() => _GroupMasterRecordLookupModalState();
}

class _GroupMasterRecordLookupModalState extends State<_GroupMasterRecordLookupModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  String? _deletingCode;
  late List<GroupMasterItem> _localItems;
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

    final targetCode = widget.recentlySavedCode ?? widget.recentlyUpdatedCode ?? widget.glowingCode;
    if (targetCode != null && targetCode.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final list = _filteredAndSorted;
        final idx = list.indexWhere((i) => i.catCode == targetCode);
        if (idx >= 0 && _tableScrollCtrl.hasClients) {
          final double targetOffset = math.max(0.0, (idx * 43.0) - 80.0);
          _tableScrollCtrl.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<GroupMasterItem> get _filteredAndSorted {
    List<GroupMasterItem> list = List.from(_localItems);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((i) {
        return i.catCode.toLowerCase().contains(_searchQuery) ||
            i.catName.toLowerCase().contains(_searchQuery) ||
            i.catHsn.toLowerCase().contains(_searchQuery) ||
            i.catShort.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter (100% Image 2 Parity)
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((i) {
          final first = i.catName.trim().isNotEmpty ? i.catName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((i) {
          final nameStr = i.catName.trim();
          final codeStr = i.catCode.trim();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    // Sort alphabetically by Group Name
    list.sort((a, b) => a.catName.toLowerCase().compareTo(b.catName.toLowerCase()));
    return list;
  }

  Future<void> _handleDelete(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await widget.service.deleteItem(code);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _localItems.removeWhere((i) => i.catCode == code);
      });
      await widget.onRefreshNeeded();
    }
  }

  void _openModalExport(List<GroupMasterItem> exportList) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _GroupMasterExportModalDialog(items: exportList),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAndSorted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        width: 1350,
        height: 670,
        constraints: const BoxConstraints(maxWidth: 1400),
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
              // 1. MODAL TOP HEADER BAR (EXACT IMAGE 2 PARITY)
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
                      'Select Group Master Record',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 10),

                    // Green Count Pill Badge (Image 2 style)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Text(
                        '${list.length} / ${widget.items.length} Items',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                      ),
                    ),

                    const Spacer(),

                    // Keyboard Navigation Helper Pill (Image 2 style)
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

              // 2. SEARCH BAR & EXPORT ORBIT BUTTON ROW (EXACT IMAGE 2 PARITY)
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
                            hintText: 'Type to live filter by Group Name, Code, HSN...',
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

                    // Standalone Export Orbit Button (Image 2 parity with circulating motion)
                    _AnimatedExportButton(onPressed: () => _openModalExport(list)),
                  ],
                ),
              ),

              // 3. ALPHABETICAL A TO Z FILTRATION BAR (EXACT IMAGE 2 PARITY)
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

              // 4. 13 COLUMNS TABLE VIEW (RESPONSIVE & FULLY VISIBLE - NO COLLAPSING)
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('No Group Master records match your filter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          const double minTableWidth = 1180.0;
                          final double tableWidth = math.max(constraints.maxWidth, minTableWidth);

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: tableWidth,
                              child: Column(
                                children: [
                                  // Table Header Row with Vector Icons & Natural Color Accents
                                  Container(
                                    height: 38,
                                    color: const Color(0xFFF8FAFC),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          child: Row(
                                            children: [
                                              Icon(Icons.sell_outlined, size: 13, color: Color(0xFF2563EB)),
                                              SizedBox(width: 4),
                                              Text('GROUP CODE', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              Icon(Icons.category_rounded, size: 13, color: Color(0xFF059669)),
                                              SizedBox(width: 4),
                                              Text('GROUP NAME', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 85,
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFFD97706)),
                                              SizedBox(width: 4),
                                              Text('HSN/SAC', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5)),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 60, child: Text('TOL %', style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 70, child: Text('TAX SLAB', style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 60, child: Text('PALLET', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 60, child: Text('SIZE', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 60, child: Text('BOX', style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 60, child: Text('GRADE', style: TextStyle(color: Color(0xFF65A30D), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 60, child: Text('GSM', style: TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 70, child: Text('SHORT', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 90, child: Text('PACK TYPE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 10.5), textAlign: TextAlign.center)),
                                        SizedBox(width: 75, child: Center(child: Text('ACTIONS', style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 10.5)))),
                                      ],
                                    ),
                                  ),

                                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                  // ListView Rows (WITH EMERALD PILL BADGES & DATA GLOW UI STRATEGY)
                                  Expanded(
                                    child: ListView.separated(
                                      controller: _tableScrollCtrl,
                                      itemCount: list.length,
                                      separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, idx) {
                                        final item = list[idx];
                                        final isDeleting = _deletingCode == item.catCode;
                                        final isNewGlow = widget.recentlySavedCode == item.catCode ||
                                            (widget.glowingCode == item.catCode && widget.recentlyUpdatedCode == null);
                                        final isUpdateGlow = widget.recentlyUpdatedCode == item.catCode;

                                        return _GroupMasterLookupRow(
                                          item: item,
                                          idx: idx,
                                          isNewGlow: isNewGlow,
                                          isUpdateGlow: isUpdateGlow,
                                          isDeleting: isDeleting,
                                          onSelect: () {
                                            widget.onSelect(item);
                                            Navigator.of(context).pop();
                                          },
                                          onDelete: () => _handleDelete(item.catCode),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. 100% IDENTICAL EXPORT MODAL DIALOG (OPERATOR MASTER PARITY)
// ============================================================================
class _GroupMasterExportModalDialog extends StatefulWidget {
  final List<GroupMasterItem> items;
  const _GroupMasterExportModalDialog({required this.items});

  @override
  State<_GroupMasterExportModalDialog> createState() => _GroupMasterExportModalDialogState();
}

class _GroupMasterExportModalDialogState extends State<_GroupMasterExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.catCode).toSet();
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

  List<GroupMasterItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      return i.catCode.toLowerCase().contains(_modalSearchQuery) ||
          i.catName.toLowerCase().contains(_modalSearchQuery) ||
          i.catHsn.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.catCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.catCode);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.catCode);
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
        .where((i) => _selectedCodes.contains(i.catCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String fileName = _selectedFormat == 'XLSX'
          ? 'Group_Master_Export_$timeStamp.xlsx'
          : 'Group_Master_Export_$timeStamp.pdf';

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

  List<int>? _generateExcelBytes(List<GroupMasterItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Group Master');
    final excel_pkg.Sheet sheet = excel['Group Master'];

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

    sheet.setColumnWidth(0, 16.0);
    sheet.setColumnWidth(1, 35.0);
    sheet.setColumnWidth(2, 18.0);
    sheet.setColumnWidth(3, 14.0);
    sheet.setColumnWidth(4, 16.0);
    sheet.setColumnWidth(5, 14.0);
    sheet.setColumnWidth(6, 14.0);
    sheet.setColumnWidth(7, 14.0);
    sheet.setColumnWidth(8, 14.0);
    sheet.setColumnWidth(9, 14.0);
    sheet.setColumnWidth(10, 18.0);
    sheet.setColumnWidth(11, 22.0);

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('GROUP CODE'),
      excel_pkg.TextCellValue('GROUP NAME'),
      excel_pkg.TextCellValue('HSN SAC'),
      excel_pkg.TextCellValue('TOLERANCE'),
      excel_pkg.TextCellValue('TAX SLAB'),
      excel_pkg.TextCellValue('PALLET REQ'),
      excel_pkg.TextCellValue('SIZE REQ'),
      excel_pkg.TextCellValue('BOX REQ'),
      excel_pkg.TextCellValue('GRADE REQ'),
      excel_pkg.TextCellValue('GSM REQ'),
      excel_pkg.TextCellValue('SHORT NAME'),
      excel_pkg.TextCellValue('PACK TYPE'),
    ]);

    for (int col = 0; col < 12; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.TextCellValue(item.catCode),
        excel_pkg.TextCellValue(item.catName),
        excel_pkg.TextCellValue(item.catHsn),
        excel_pkg.TextCellValue('${item.catTol}%'),
        excel_pkg.TextCellValue(item.catTaxSlab),
        excel_pkg.TextCellValue(item.palletReq),
        excel_pkg.TextCellValue(item.sizeReq),
        excel_pkg.TextCellValue(item.boxReq),
        excel_pkg.TextCellValue(item.gradeReq),
        excel_pkg.TextCellValue(item.gsmReq),
        excel_pkg.TextCellValue(item.catShort),
        excel_pkg.TextCellValue(item.packTypeName),
      ]);

      for (int col = 0; col < 12; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<GroupMasterItem> records) async {
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
                  'GROUP MASTER REPORT (CATEGORY MASTER)',
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
            headers: ['CODE', 'GROUP NAME', 'HSN/SAC', 'TOL', 'TAX', 'PALLET', 'SIZE', 'BOX', 'GRADE', 'GSM', 'SHORT', 'PACK TYPE'],
            data: records.map((i) => [
              i.catCode,
              i.catName,
              i.catHsn,
              '${i.catTol}%',
              i.catTaxSlab,
              i.palletReq,
              i.sizeReq,
              i.boxReq,
              i.gradeReq,
              i.gsmReq,
              i.catShort,
              i.packTypeName,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF10B981)),
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
                                    Text('Export Group Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
    final previewList = _filteredPreviewItems;
    final selectedCount = previewList.where((i) => _selectedCodes.contains(i.catCode)).length;

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
            '$selectedCount of ${widget.items.length} selected',
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
              'No group records found',
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
                  Expanded(child: Text('GROUP NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 100, child: Text('HSN/SAC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedCodes.contains(item.catCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.catCode);
                        } else {
                          _selectedCodes.add(item.catCode);
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
                                    _selectedCodes.add(item.catCode);
                                  } else {
                                    _selectedCodes.remove(item.catCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: Text(
                              item.catCode,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.catName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              item.catHsn.isNotEmpty ? item.catHsn : '-',
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
// 100% IDENTICAL 3D ISOMETRIC GEOMETRIC SHAPES LOGO (NO BOX/BORDER, DIRECT ON WHITE)
// ============================================================================
class _GroupMasterHeaderLogoWidget extends StatelessWidget {
  final double height;
  const _GroupMasterHeaderLogoWidget({this.height = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Optical ambient glow (no border, no box)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(-2, 2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.10),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(0, -2),
                  ),
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    blurRadius: 14,
                    spreadRadius: 2,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
          // 100% Identical 3D Isometric Geometric Shapes Logo
          Image.asset(
            'assets/images/group_master_logo.png',
            height: height,
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
// 100% IDENTICAL GROUP CATEGORY DETAILS LOGO (NO BOX/BORDER, DIRECT ON WHITE)
// ============================================================================
class _GroupCategoryDetailsLogoWidget extends StatelessWidget {
  final double size;
  const _GroupCategoryDetailsLogoWidget({this.size = 30.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Optical ambient depth glow (no box, no border)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(1, -1),
                  ),
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(-1, 1),
                  ),
                ],
              ),
            ),
          ),
          // 100% Identical Hand Holding Gear & Person Logo
          Image.asset(
            'assets/images/group_category_details_logo.png',
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
// ANIMATED "SHOW RECORD" BUTTON (WITH MAGNIFY MOVING & PULSE ANIMATION)
// ============================================================================
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
                    // MAGNIFYING GLASS MOVING ANIMATION
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

// ============================================================================
// MODERN TAX SLAB DROPDOWN WIDGET
// ============================================================================
class _ModernTaxSlabDropdown extends StatefulWidget {
  final String selectedCode;
  final List<TaxSlabItem> slabs;
  final ValueChanged<String> onChanged;

  const _ModernTaxSlabDropdown({
    required this.selectedCode,
    required this.slabs,
    required this.onChanged,
  });

  @override
  State<_ModernTaxSlabDropdown> createState() => _ModernTaxSlabDropdownState();
}

class _ModernTaxSlabDropdownState extends State<_ModernTaxSlabDropdown> {
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
    if (widget.slabs.isEmpty) return;
    _closeDropdown();

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

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
              width: math.max(size.width, 240.0),
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 4),
                child: Material(
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.22),
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
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 270),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.percent_rounded, size: 11, color: Color(0xFFD97706)),
                              ),
                              const SizedBox(width: 7),
                              const Text(
                                'TAX SLABS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF64748B),
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${widget.slabs.length} Options',
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // List
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: widget.slabs.map((slab) {
                                final isSelected = slab.taxCode == widget.selectedCode;
                                return _TaxSlabMenuItem(
                                  slab: slab,
                                  isSelected: isSelected,
                                  onTap: () {
                                    widget.onChanged(slab.taxCode);
                                    _closeDropdown();
                                  },
                                );
                              }).toList(),
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
  void didUpdateWidget(covariant _ModernTaxSlabDropdown oldWidget) {
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
    TaxSlabItem? currentSlab;
    try {
      currentSlab = widget.slabs.firstWhere((s) => s.taxCode == widget.selectedCode);
    } catch (_) {}

    final badgeText = currentSlab != null
        ? (currentSlab.taxCode.toLowerCase().contains('slab')
            ? currentSlab.taxCode
            : 'Slab ${currentSlab.taxCode}')
        : '';

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
                    ? const Color(0xFFD97706)
                    : (_isHovered ? const Color(0xFF94A3B8) : const Color(0xFFCBD5E1)),
                width: _isOpen ? 1.5 : 1.0,
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                if (currentSlab != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentSlab.taxName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
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
                      'Select Tax Slab',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFD97706),
                    size: 19,
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

class _TaxSlabMenuItem extends StatefulWidget {
  final TaxSlabItem slab;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaxSlabMenuItem({
    required this.slab,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TaxSlabMenuItem> createState() => _TaxSlabMenuItemState();
}

class _TaxSlabMenuItemState extends State<_TaxSlabMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final slab = widget.slab;
    final isSelected = widget.isSelected;
    final badgeText = slab.taxCode.toLowerCase().contains('slab')
        ? slab.taxCode
        : 'Slab ${slab.taxCode}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFEF3C7).withValues(alpha: 0.85)
                : (_isHovered ? const Color(0xFFF1F5F9) : Colors.transparent),
            border: Border(
              bottom: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
              left: BorderSide(
                color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
                width: 3.5,
              ),
            ),
          ),
          child: Row(
            children: [
              // Code Badge Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Tax Rate Name
              Expanded(
                child: Text(
                  slab.taxName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF92400E) : const Color(0xFF1E293B),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              // Checkmark indicator on right
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 11,
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

class _GroupMasterLookupRow extends StatefulWidget {
  final GroupMasterItem item;
  final int idx;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final bool isDeleting;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _GroupMasterLookupRow({
    required this.item,
    required this.idx,
    required this.isNewGlow,
    required this.isUpdateGlow,
    required this.isDeleting,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_GroupMasterLookupRow> createState() => _GroupMasterLookupRowState();
}

class _GroupMasterLookupRowState extends State<_GroupMasterLookupRow> {
  bool _isHovered = false;

  Widget _buildBadge(String val, Color color) {
    if (val.isEmpty || val == 'N') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(val, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final idx = widget.idx;
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;
    final isDeleting = widget.isDeleting;
    final isHovered = _isHovered;

    Color rowBgColor;
    Color? rowBorderColor;
    List<BoxShadow> rowShadows = [];

    if (isNewGlow) {
      rowBgColor = const Color(0xFFECFDF5);
      rowBorderColor = const Color(0xFF10B981);
      rowShadows = [
        BoxShadow(
          color: const Color(0xFF10B981).withValues(alpha: 0.42),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 1.5),
        ),
      ];
    } else if (isUpdateGlow) {
      rowBgColor = const Color(0xFFFFFBEB);
      rowBorderColor = const Color(0xFFF59E0B);
      rowShadows = [
        BoxShadow(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.42),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 1.5),
        ),
      ];
    } else if (isHovered) {
      rowBgColor = const Color(0xFFF1F5F9);
      rowBorderColor = const Color(0xFFCBD5E1);
      rowShadows = [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];
    } else {
      rowBgColor = idx % 2 == 0 ? const Color(0xFFFAFAFA) : Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: rowBgColor,
            border: rowBorderColor != null
                ? Border.all(color: rowBorderColor, width: (isNewGlow || isUpdateGlow) ? 1.6 : 1.0)
                : null,
            boxShadow: rowShadows,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 100,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isNewGlow ? const Color(0xFF10B981) : (isUpdateGlow ? const Color(0xFFF59E0B) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isNewGlow ? const Color(0xFF059669) : (isUpdateGlow ? const Color(0xFFD97706) : const Color(0xFFA7F3D0)),
                          width: (isNewGlow || isUpdateGlow) ? 1.0 : 0.8,
                        ),
                        boxShadow: (isNewGlow || isUpdateGlow)
                            ? [BoxShadow(color: (isNewGlow ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 1))]
                            : [],
                      ),
                      child: Text(
                        item.catCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (isNewGlow || isUpdateGlow) ? Colors.white : const Color(0xFF059669),
                        ),
                      ),
                    ),
                    if (isNewGlow) ...[const SizedBox(width: 4), const Icon(Icons.stars_rounded, size: 14, color: Color(0xFF10B981))]
                    else if (isUpdateGlow) ...[const SizedBox(width: 4), const Icon(Icons.change_circle_rounded, size: 14, color: Color(0xFFF59E0B))],
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.catName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: (isNewGlow || isUpdateGlow || isHovered) ? FontWeight.w800 : FontWeight.w600,
                    color: isNewGlow ? const Color(0xFF047857) : (isUpdateGlow ? const Color(0xFFB45309) : const Color(0xFF0F172A)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 85,
                child: Text(
                  item.catHsn.isNotEmpty ? item.catHsn : '-',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: item.catHsn.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    color: item.catHsn.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('${item.catTol}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0891B2)), textAlign: TextAlign.center),
              ),
              SizedBox(
                width: 70,
                child: Text(item.catTaxSlab.isNotEmpty ? item.catTaxSlab : '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)), textAlign: TextAlign.center),
              ),
              SizedBox(width: 60, child: _buildBadge(item.palletReq, const Color(0xFF0D9488))),
              SizedBox(width: 60, child: _buildBadge(item.sizeReq, const Color(0xFFE11D48))),
              SizedBox(width: 60, child: _buildBadge(item.boxReq, const Color(0xFFEA580C))),
              SizedBox(width: 60, child: _buildBadge(item.gradeReq, const Color(0xFF65A30D))),
              SizedBox(width: 60, child: _buildBadge(item.gsmReq, const Color(0xFF6D28D9))),
              SizedBox(width: 70, child: Text(item.catShort.isNotEmpty ? item.catShort : '-', style: const TextStyle(fontSize: 11, color: Color(0xFF7C3AED)), textAlign: TextAlign.center)),
              SizedBox(
                width: 90,
                child: Text(item.packTypeName.isNotEmpty ? item.packTypeName : '-', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: 75,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF059669)),
                      tooltip: 'Select & Edit Record',
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      padding: EdgeInsets.zero,
                      onPressed: widget.onSelect,
                    ),
                    const SizedBox(width: 8),
                    if (isDeleting) ...[
                      const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444))),
                    ] else ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                        tooltip: 'Delete Record',
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        padding: EdgeInsets.zero,
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
    );
  }
}
