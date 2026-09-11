import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import '../design/app_colors.dart';
import '../services/non_stockable_item_service.dart';

enum ExportFormat { excel, pdf }
enum ButtonStatus { idle, loading, success }

// ============================================================================
// UNIT SIGN LOGO ICON MAPPER (38 UNITS)
// ============================================================================
IconData _getUnitIcon(String unitName) {
  final u = unitName.trim().toUpperCase();
  switch (u) {
    case 'BAG': return Icons.shopping_bag_outlined;
    case 'BAL': return Icons.inventory_outlined;
    case 'BDL': return Icons.all_inbox_rounded;
    case 'BKL': return Icons.link_rounded;
    case 'BOOK': return Icons.menu_book_rounded;
    case 'BOU': return Icons.local_florist_rounded;
    case 'BOX': return Icons.inbox_rounded;
    case 'BRASS': return Icons.architecture_rounded;
    case 'BTL': return Icons.liquor_rounded;
    case 'BUN': return Icons.grain_rounded;
    case 'CAN': return Icons.propane_tank_rounded;
    case 'CBM': return Icons.view_in_ar_rounded;
    case 'CCM': return Icons.view_in_ar_outlined;
    case 'CMS': return Icons.straighten_rounded;
    case 'COPS': return Icons.blur_circular_rounded;
    case 'CTN': return Icons.inventory_2_outlined;
    case 'DOZ': return Icons.grid_4x4_rounded;
    case 'DRM': return Icons.oil_barrel_rounded;
    case 'FT': return Icons.height_rounded;
    case 'GGK': return Icons.numbers_rounded;
    case 'GMS': return Icons.scale_rounded;
    case 'GRS': return Icons.grid_on_rounded;
    case 'GYD': return Icons.square_foot_rounded;
    case 'HOUR': return Icons.schedule_rounded;
    case 'KGS': return Icons.monitor_weight_outlined;
    case 'KLR': return Icons.water_drop_outlined;
    case 'KME': return Icons.speed_rounded;
    case 'KWH': return Icons.bolt_rounded;
    case 'LTR': return Icons.water_drop_rounded;
    case 'MTR': return Icons.straighten_rounded;
    case 'NOS': return Icons.tag_rounded;
    case 'PAC': return Icons.card_giftcard_rounded;
    case 'PCS': return Icons.extension_rounded;
    case 'PKT': return Icons.markunread_mailbox_rounded;
    case 'RIM': return Icons.description_outlined;
    case 'SET': return Icons.layers_rounded;
    case 'SHEETS': return Icons.file_present_rounded;
    case 'SQF': return Icons.aspect_ratio_rounded;
    default: return Icons.straighten_rounded;
  }
}

// ============================================================================
// MAIN PAGE: NonStockableItemMasterPage
// ============================================================================
class NonStockableItemMasterPage extends StatefulWidget {
  const NonStockableItemMasterPage({super.key});

  @override
  State<NonStockableItemMasterPage> createState() => _NonStockableItemMasterPageState();
}

class _NonStockableItemMasterPageState extends State<NonStockableItemMasterPage> {
  final NonStockableItemService _service = NonStockableItemService();
  final FocusNode _pageKeyFocusNode = FocusNode();

  // Data Lists & Options
  List<NonStockableItem> _items = [];
  List<UnitOption> _unitOptions = [];
  List<TaxSlabOption> _taxSlabOptions = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Filter
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchDebounce;

  // Form State
  bool _isEditing = false;
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _rateCtrl = TextEditingController();
  final TextEditingController _sacCtrl = TextEditingController();

  final FocusNode _codeFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();
  final FocusNode _sacFocusNode = FocusNode();

  int? _selectedUnitCode;
  int? _selectedTaxCode;

  // Button Micro-Animations State
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;

  // Glow Badges Tracking & Department Master Glowing Strategy
  String? _highlightedCode;
  bool _isHighlightedEdit = false;
  String? _selectedRowCode;
  Timer? _highlightTimer;

  // Scroll Controller for Master Table Grid
  final ScrollController _tableScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _tableScrollCtrl.dispose();
    _pageKeyFocusNode.dispose();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();

    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _sacCtrl.dispose();

    _codeFocusNode.dispose();
    _nameFocusNode.dispose();
    _rateFocusNode.dispose();
    _sacFocusNode.dispose();
    super.dispose();
  }

  void _triggerGlowingHighlight(String code, bool isEdit) {
    _highlightTimer?.cancel();
    setState(() {
      _highlightedCode = code;
      _isHighlightedEdit = isEdit;
      _selectedRowCode = code;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_tableScrollCtrl.hasClients && mounted) {
          final idx = _filteredItems.indexWhere((i) => i.iCode.toLowerCase() == code.toLowerCase());
          if (idx != -1) {
            final targetOffset = idx * 39.0;
            _tableScrollCtrl.animateTo(
              targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    });

    _highlightTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        setState(() {
          if (_highlightedCode == code) {
            _highlightedCode = null;
            _isHighlightedEdit = false;
          }
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
      final dropdownsTask = _service.getDropdowns();
      final itemsTask = _service.getAll();

      final dropdowns = await dropdownsTask;
      final items = await itemsTask;

      setState(() {
        if (dropdowns != null) {
          _unitOptions = dropdowns.units;
          _taxSlabOptions = dropdowns.taxSlabs;
        }
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load Non-Stockable Item data: $e';
      });
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final items = await _service.getAll();
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } catch (_) {}
  }

  String _getTaxSlabDisplay(NonStockableItem item) {
    if (item.taxName.isNotEmpty) return item.taxName;
    final match = _taxSlabOptions.firstWhere(
      (t) => t.taxCode == item.taxCode || t.taxName == '${item.taxCode}%',
      orElse: () => TaxSlabOption(taxCode: item.taxCode, taxName: '${item.taxCode}%'),
    );
    return match.taxName.isNotEmpty ? match.taxName : '${item.taxCode}%';
  }

  String? _buttonValidationMsg;
  bool _isNotificationError = true;

  void _showButtonNotification(String msg, {bool isError = true}) {
    setState(() {
      _buttonValidationMsg = msg;
      _isNotificationError = isError;
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _codeCtrl.clear();
      _nameCtrl.clear();
      _rateCtrl.clear();
      _sacCtrl.clear();
      _selectedUnitCode = null; // No auto-select of unit: let user choose manually
      _selectedTaxCode = _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first.taxCode : null;
      _buttonValidationMsg = null;
    });
    _showButtonNotification('Form reset successfully!', isError: false);
  }

  void _populateFormForEditing(NonStockableItem item) {
    setState(() {
      _isEditing = true;
      _selectedRowCode = item.iCode;
      _codeCtrl.text = item.iCode;
      _nameCtrl.text = item.iName1;
      _rateCtrl.text = item.rate > 0 ? item.rate.toStringAsFixed(2) : '';
      _sacCtrl.text = item.sacCode;

      _selectedUnitCode = _unitOptions.any((u) => u.unitCode == item.unitCode)
          ? item.unitCode
          : null;

      final matchTax = _taxSlabOptions.firstWhere(
        (t) => t.taxCode == item.taxCode || t.taxName == item.taxName || t.taxName == '${item.taxCode}%',
        orElse: () => _taxSlabOptions.isNotEmpty ? _taxSlabOptions.first : TaxSlabOption(taxCode: 0, taxName: '0%'),
      );
      _selectedTaxCode = matchTax.taxCode;

      _buttonValidationMsg = null;
    });
  }

  void _openUnassignedItemPicker() async {
    final selected = await showDialog<UnassignedItem>(
      context: context,
      builder: (ctx) => _UnassignedItemPickerModal(service: _service),
    );

    if (selected != null) {
      setState(() {
        _isEditing = false;
        _codeCtrl.text = selected.iCode;
        _nameCtrl.text = selected.iName1;
        _rateCtrl.text = selected.rate > 0 ? selected.rate.toStringAsFixed(2) : '';
        _sacCtrl.text = selected.sacCode;

        // Try mapping UnitCode or leave null so user chooses manually
        int? parsedUnit = int.tryParse(selected.unitCode);
        if (parsedUnit != null && _unitOptions.any((u) => u.unitCode == parsedUnit)) {
          _selectedUnitCode = parsedUnit;
        } else {
          _selectedUnitCode = null;
        }

        // Try mapping TaxCode accurately
        int? parsedTax = int.tryParse(selected.taxCode);
        if (parsedTax != null) {
          final matchTax = _taxSlabOptions.firstWhere(
            (t) => t.taxCode == parsedTax || t.taxName == '$parsedTax%',
            orElse: () => _taxSlabOptions.first,
          );
          _selectedTaxCode = matchTax.taxCode;
        } else if (_taxSlabOptions.isNotEmpty) {
          _selectedTaxCode = _taxSlabOptions.first.taxCode;
        }
      });
      _showButtonNotification('Item ${selected.iCode} selected from ITEMMST!', isError: false);
    }
  }

  void _showButtonValidation(String msg) {
    _showButtonNotification(msg, isError: true);
  }

  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final rateVal = double.tryParse(_rateCtrl.text.trim()) ?? 0.0;

    if (code.isEmpty) {
      _showButtonNotification('Please enter/select Item Code!', isError: true);
      _codeFocusNode.requestFocus();
      return;
    }

    if (name.isEmpty) {
      _showButtonNotification('Please enter Item Name!', isError: true);
      _nameFocusNode.requestFocus();
      return;
    }

    if (_selectedUnitCode == null) {
      _showButtonValidation('Please select Unit of Measure!');
      return;
    }

    if (_selectedTaxCode == null) {
      _showButtonValidation('Please select Tax Slab!');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final dto = SaveNonStockableItemDto(
      iCode: code,
      iName1: name,
      rate: rateVal,
      unitCode: _selectedUnitCode!,
      sacCode: _sacCtrl.text.trim(),
      taxCode: _selectedTaxCode!,
    );

    final bool wasEditing = _isEditing;
    final String savedCode = code;

    final success = await _service.save(dto);

    if (mounted) {
      if (success) {
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });

        await _refreshDataSilently();

        if (mounted) {
          _clearForm();
          setState(() => _isSaveSuccess = false);
          _triggerGlowingHighlight(savedCode, wasEditing);
          _showButtonNotification(
            wasEditing ? 'Item #$savedCode updated successfully!' : 'New Item #$savedCode created successfully!',
            isError: false,
          );
        }
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save record to SQL Server.');
      }
    }
  }

  Future<void> _deleteItem(String code, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        itemCode: code,
        itemName: name,
        onDelete: () async {
          return await _service.delete(code);
        },
      ),
    );

    if (confirmed == true) {
      _clearForm();
      await _loadInitialData();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.f1) {
        _submitForm();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _clearForm();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _NonStockableExportModalDialog(items: _items),
    );
  }

  List<NonStockableItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((i) {
      return i.iCode.toLowerCase().contains(q) ||
          i.iName1.toLowerCase().contains(q) ||
          i.unitName.toLowerCase().contains(q) ||
          i.sacCode.toLowerCase().contains(q) ||
          i.taxName.toLowerCase().contains(q);
    }).toList();
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
        padding: const EdgeInsets.fromLTRB(10.0, 6.0, 10.0, 10.0),
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
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    // 1. SCREEN HEADER TOOLBAR
                    _buildScreenHeader(),
                    const SizedBox(height: 12),

                    // 2. DUAL PANEL WORKSPACE LAYOUT (LEFT - RIGHT)
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT PANE: HIGH-FASHION ENTRY FORM CARD (OPTIMIZED COMPACT WIDTH 300)
                          SizedBox(
                            width: 300,
                            child: _buildLeftEntryPane(),
                          ),
                          const SizedBox(width: 10),

                          // RIGHT PANE: MASTER DATA TABLE GRID
                          Expanded(
                            child: RepaintBoundary(
                              child: _isLoading
                                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                                  : _errorMessage != null
                                      ? _buildErrorState()
                                      : _buildRightDataTablePane(),
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
  // 1. SCREEN HEADER TOOLBAR
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
          // 3D HEADER LOGO BADGE
          const _NonStockableHeaderLogoWidget(),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Non-Stockable Item Master',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF3E8FF), Color(0xFFEEF2FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFDDD6FE), width: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5.5,
                      height: 5.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_items.length} Non-Stockable Items Configured',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B21B6),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search Bar Input with 200ms debounce
          SizedBox(
            width: 240,
            height: 36,
            child: RepaintBoundary(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                onChanged: (val) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 200), () {
                    setState(() => _searchQuery = val);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search items... (Ctrl+K)',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.secondaryColor),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5)),
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
  // 2. LEFT ENTRY FORM CARD (LEFT PANE DUAL PANEL - ZERO SCROLLBAR)
  // --------------------------------------------------------------------------
  Widget _buildLeftEntryPane() {
    final selectedUnit = _unitOptions.firstWhere(
      (u) => u.unitCode == _selectedUnitCode,
      orElse: () => UnitOption(unitName: 'Select Unit', unitCode: -1),
    );

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const _AddNonStockableItemLogoWidget(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Edit Item' : 'Add Non-Stockable Item',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '#${_codeCtrl.text}',
                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                      ),
                    ),
                ],
              ),
            ),

            // High-Density Vertical Form Body (Fits 100% on Screen, Zero Scrollbar)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 1. Item Code Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(5)),
                              child: const Icon(Icons.sell_outlined, size: 13, color: Color(0xFF6366F1)),
                            ),
                            const SizedBox(width: 5),
                            const Text('ITEM CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 0.4)),
                            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 35,
                          child: TextField(
                            controller: _codeCtrl,
                            focusNode: _codeFocusNode,
                            readOnly: _isEditing,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Item Code...',
                              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              filled: true,
                              fillColor: _isEditing ? const Color(0xFFF1F5F9) : Colors.white,
                              suffixIcon: InkWell(
                                onTap: _openUnassignedItemPicker,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFC7D2FE)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search_rounded, size: 13, color: Color(0xFF4338CA)),
                                      SizedBox(width: 3),
                                      Text('Pick', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                                    ],
                                  ),
                                ),
                              ),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 2. Item Name Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(5)),
                              child: const Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFF64748B)),
                            ),
                            const SizedBox(width: 5),
                            const Text('ITEM NAME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.4)),
                            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 35,
                          child: TextField(
                            controller: _nameCtrl,
                            focusNode: _nameFocusNode,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'e.g. COTTON TRUNKS',
                              hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF64748B), width: 1.5)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 3. Item Rate & SAC/HSN (2-Column Sub-Row)
                    Row(
                      children: [
                        // Rate
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(5)),
                                    child: const Icon(Icons.payments_outlined, size: 13, color: Color(0xFF10B981)),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('RATE (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981), letterSpacing: 0.4)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 35,
                                child: TextField(
                                  controller: _rateCtrl,
                                  focusNode: _rateFocusNode,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // SAC / HSN Code
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(5)),
                                    child: const Icon(Icons.receipt_outlined, size: 13, color: Color(0xFFD97706)),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('SAC/HSN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706), letterSpacing: 0.4)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 35,
                                child: TextField(
                                  controller: _sacCtrl,
                                  focusNode: _sacFocusNode,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. 321456',
                                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
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
                      ],
                    ),

                    // 4. Cool Custom Interactive Unit Picker Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(5)),
                              child: const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 5),
                            const Text('UNIT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7), letterSpacing: 0.4)),
                            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _showCoolUnitPickerModal,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                Icon(_getUnitIcon(selectedUnit.unitName), size: 15, color: const Color(0xFF0284C7)),
                                const SizedBox(width: 8),
                                Text(
                                  selectedUnit.unitName.isEmpty ? 'Select Unit' : selectedUnit.unitName,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const Spacer(),
                                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF0284C7)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 5. Cool Custom Segmented Tax Slab Picker
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(5)),
                              child: const Icon(Icons.balance_rounded, size: 13, color: Color(0xFFF43F5E)),
                            ),
                            const SizedBox(width: 5),
                            const Text('TAX SLAB', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E), letterSpacing: 0.4)),
                            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: _taxSlabOptions.map((t) {
                            final isSelected = t.taxCode == _selectedTaxCode;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: _TaxSlabOptionHoverPill(
                                  tax: t,
                                  isSelected: isSelected,
                                  onTap: () => setState(() => _selectedTaxCode = t.taxCode),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    // Validation Alert if any
                    if (_buttonValidationMsg != null) ...[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isNotificationError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: (_isNotificationError ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isNotificationError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _buttonValidationMsg!,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearForm,
                            icon: const Icon(Icons.restart_alt_rounded, size: 13),
                            label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: AnimatedSuccessButton(
                            status: _isSubmitting
                                ? ButtonStatus.loading
                                : (_isSaveSuccess ? ButtonStatus.success : ButtonStatus.idle),
                            onPressed: _submitForm,
                            idleText: _isEditing ? 'Update Item' : 'Save Item (F1)',
                            loadingText: 'Saving...',
                            successText: 'Saved!',
                            idleIcon: Icons.save_rounded,
                            idleBackgroundColor: AppColors.secondaryColor,
                            successBackgroundColor: const Color(0xFF10B981),
                            height: 36,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCoolUnitPickerModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        String searchVal = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _unitOptions.where((u) => u.unitName.toLowerCase().contains(searchVal.toLowerCase())).toList();
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
              child: Container(
                width: 520,
                height: 480,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Modal Header (Clean Light Styling)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF0284C7)),
                          const SizedBox(width: 8),
                          Text('Select Unit of Measurement (${filtered.length} / ${_unitOptions.length})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: (val) => setModalState(() => searchVal = val),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search 38 unit options...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0284C7)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0284C7))),
                        ),
                      ),
                    ),
                    // Unit Grid
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final u = filtered[idx];
                          final isSelected = u.unitCode == _selectedUnitCode;
                          final icon = _getUnitIcon(u.unitName);

                          return _UnitOptionHoverCard(
                            unit: u,
                            isSelected: isSelected,
                            icon: icon,
                            onTap: () {
                              setState(() => _selectedUnitCode = u.unitCode);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // 3. MASTER DATA TABLE GRID (DEPARTMENT MASTER TABLE 100% PARITY)
  // --------------------------------------------------------------------------
  Widget _buildRightDataTablePane() {
    final filtered = _filteredItems;

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
                  const _ConfiguredItemCardsLogoWidget(size: 32),
                  const SizedBox(width: 10),
                  const Text(
                    'Item Sheet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.touch_app_outlined, size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Double-click row to edit',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filtered.length} Records',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.secondaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Responsive Table Body Grid (Department Master Style)
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.inbox_outlined, size: 32, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No non-stockable items matching "$_searchQuery"'
                                : 'No non-stockable items configured yet',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Use the entry form or Pick from ITEMMST to add non-stockable items',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final isVeryNarrow = constraints.maxWidth < 500;

                        Widget content = Column(
                          children: [
                            // Column Header Bar (Department Master Style with Column Logos & Spacious 14px Gaps)
                            Container(
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9),
                                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: const Row(
                                children: [
                                  // 1. CODE
                                  SizedBox(
                                    width: 66,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.tag_rounded, size: 10.5, color: Color(0xFF6366F1)),
                                          SizedBox(width: 2),
                                          Text('CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),

                                  // 2. ITEM NAME
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 10.5, color: Color(0xFF10B981)),
                                        SizedBox(width: 4),
                                        Text('ITEM NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 14),

                                  // 3. UNIT
                                  SizedBox(
                                    width: 48,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.straighten_rounded, size: 10, color: Color(0xFF06B6D4)),
                                          SizedBox(width: 2),
                                          Text('UNIT', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14),

                                  // 4. RATE
                                  SizedBox(
                                    width: 60,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerRight,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Icon(Icons.currency_rupee_rounded, size: 10, color: Color(0xFF059669)),
                                          SizedBox(width: 1),
                                          Text('RATE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14),

                                  // 5. SAC
                                  SizedBox(
                                    width: 60,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.receipt_long_rounded, size: 10, color: Color(0xFFF59E0B)),
                                          SizedBox(width: 2),
                                          Text('SAC', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14),

                                  // 6. TAX
                                  SizedBox(
                                    width: 46,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.percent_rounded, size: 10, color: Color(0xFFF43F5E)),
                                          SizedBox(width: 1),
                                          Text('TAX', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 14),

                                  // 7. ACTIONS
                                  SizedBox(
                                    width: 54,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.tune_rounded, size: 10, color: Color(0xFF8B5CF6)),
                                          SizedBox(width: 1),
                                          Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9.5)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                                // Rows List
                                Expanded(
                                  child: ListView.separated(
                                    controller: _tableScrollCtrl,
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: filtered.length,
                                    separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                                    itemBuilder: (ctx, idx) {
                                      final item = filtered[idx];
                                      final isSelected = _selectedRowCode == item.iCode;
                                      final isGlowing = _highlightedCode == item.iCode;
                                      final isGlowingEdit = isGlowing && _isHighlightedEdit;
                                      final isGlowingNew = isGlowing && !_isHighlightedEdit;

                                      return _AnimatedNonStockableItemRow(
                                        key: ValueKey<String>(item.iCode),
                                        item: item,
                                        index: idx,
                                        isSelected: isSelected,
                                        isGlowing: isGlowing,
                                        isGlowingEdit: isGlowingEdit,
                                        isGlowingNew: isGlowingNew,
                                        taxDisplay: _getTaxSlabDisplay(item),
                                        onTap: () {
                                          setState(() {
                                            _selectedRowCode = item.iCode;
                                          });
                                        },
                                        onDoubleTap: () => _populateFormForEditing(item),
                                        onEdit: () => _populateFormForEditing(item),
                                        onDelete: () => _deleteItem(item.iCode, item.iName1),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );

                            if (isVeryNarrow) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 500,
                                  child: content,
                                ),
                              );
                            }

                            return content;
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UNASSIGNED ITEM PICKER MODAL (100% MATCHING IMAGE 2 DESIGN & ALPHABET BAR)
// ============================================================================
class _UnassignedItemPickerModal extends StatefulWidget {
  final NonStockableItemService service;
  const _UnassignedItemPickerModal({required this.service});

  @override
  State<_UnassignedItemPickerModal> createState() => _UnassignedItemPickerModalState();
}

class _UnassignedItemPickerModalState extends State<_UnassignedItemPickerModal> {
  List<UnassignedItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  Timer? _debounce;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final list = await widget.service.getUnassignedItems();
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  List<UnassignedItem> get _filteredAndSorted {
    List<UnassignedItem> result = List.from(_items);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((i) {
        return i.iCode.toLowerCase().contains(q) ||
            i.iName1.toLowerCase().contains(q) ||
            i.sacCode.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Alphabet Filter (Image 2 filtration bar)
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        result = result.where((i) {
          final first = i.iName1.trim().isNotEmpty ? i.iName1.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        result = result.where((i) {
          final nameStr = i.iName1.trim();
          final codeStr = i.iCode.trim();
          return nameStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase()) ||
              codeStr.toLowerCase().startsWith(_selectedAlphabet.toLowerCase());
        }).toList();
      }
    }

    // Sort alphabetically
    result.sort((a, b) => a.iName1.toLowerCase().compareTo(b.iName1.toLowerCase()));

    return result;
  }

  void _openModalExport(List<UnassignedItem> exportList) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _UnassignedItemExportModalDialog(items: exportList),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredAndSorted;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1060,
        height: 640,
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
        child: Column(
          children: [
            // Modal Top Bar (Matching Image 2 Top Header)
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
                    'Select Unassigned Item (from ITEMMST)',
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
                      '${filteredList.length} / ${_items.length} Items',
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

            // Top Search Bar & Export Button Row (Matching Image 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: TextField(
                        onChanged: (val) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 200), () {
                            setState(() => _searchQuery = val);
                          });
                        },
                        style: const TextStyle(fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Type to live filter by Item Name, Code, SAC/HSN...',
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

                  // Standalone Export Orbit Button (Matching Image 2)
                  _AnimatedExportButton(onPressed: () => _openModalExport(filteredList)),
                ],
              ),
            ),

            // Alphabetical A to Z Filtration Bar (Matching Image 2 100%)
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

            // Table Content (Matching Image 2 Structure & Clean Rows)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  : filteredList.isEmpty
                      ? const Center(
                          child: Text(
                            'No unassigned items found matching criteria',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Column(
                                children: [
                                  // Light Grey / Emerald Tint Header Bar (Matching Image 2)
                                  Container(
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF8FAFC),
                                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 210,
                                          child: Row(
                                            children: [
                                              Icon(Icons.sell_outlined, size: 14, color: Color(0xFF6366F1)),
                                              SizedBox(width: 6),
                                              Text('ITEM CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Row(
                                            children: [
                                              Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF0284C7)),
                                              SizedBox(width: 6),
                                              Text('ITEM NAME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 110,
                                          child: Row(
                                            children: [
                                              Icon(Icons.payments_outlined, size: 14, color: Color(0xFF10B981)),
                                              SizedBox(width: 6),
                                              Text('RATE (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 110,
                                          child: Row(
                                            children: [
                                              Icon(Icons.straighten_rounded, size: 14, color: Color(0xFFD97706)),
                                              SizedBox(width: 6),
                                              Text('UOM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 24),
                                        SizedBox(
                                          width: 120,
                                          child: Row(
                                            children: [
                                              Icon(Icons.receipt_outlined, size: 14, color: Color(0xFFF43F5E)),
                                              SizedBox(width: 6),
                                              Text('HSN/SAC', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // List Rows with Clean Spacing & Hover Highlight (Matching Image 2)
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: filteredList.length,
                                      separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, idx) {
                                        final item = filteredList[idx];
                                        final isEven = idx % 2 == 0;

                                        return InkWell(
                                          onTap: () => Navigator.pop(context, item),
                                          hoverColor: const Color(0xFFF0FDF4),
                                          child: Container(
                                            height: 42,
                                            color: isEven ? const Color(0xFFFAFAFA) : Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Row(
                                              children: [
                                                // Item Code (Pill badge style like Image 2 GSTIN column)
                                                SizedBox(
                                                  width: 210,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF0FDF4),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFFBBF7D0)),
                                                    ),
                                                    child: Text(
                                                      item.iCode,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF166534)),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                // Item Name
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    item.iName1,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // Rate
                                                SizedBox(
                                                  width: 110,
                                                  child: Text(
                                                    item.rate > 0 ? '₹${item.rate.toStringAsFixed(2)}' : '-',
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                                  ),
                                                ),
                                                // UOM (Pill badge with specific unit sign logo)
                                                SizedBox(
                                                  width: 110,
                                                  child: item.unitCode.isEmpty
                                                      ? const Text('-', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                                      : Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFEF3C7),
                                                            borderRadius: BorderRadius.circular(10),
                                                            border: Border.all(color: const Color(0xFFFDE68A)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                              Icon(_getUnitIcon(item.unitCode), size: 12, color: const Color(0xFFD97706)),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                item.unitCode,
                                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                ),
                                                const SizedBox(width: 24),
                                                // HSN/SAC
                                                SizedBox(
                                                  width: 120,
                                                  child: Text(
                                                    item.sacCode.isEmpty ? '-' : item.sacCode,
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
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
                        ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXPORT MODAL FOR UNASSIGNED ITEMS (100% IDENTICAL TO PROJECT MASTER EXPORT)
// ============================================================================
class _UnassignedItemExportModalDialog extends StatefulWidget {
  final List<UnassignedItem> items;
  const _UnassignedItemExportModalDialog({required this.items});

  @override
  State<_UnassignedItemExportModalDialog> createState() => _UnassignedItemExportModalDialogState();
}

class _UnassignedItemExportModalDialogState extends State<_UnassignedItemExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.iCode).toSet();
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

  List<UnassignedItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      final codeMatch = i.iCode.toLowerCase().contains(_modalSearchQuery);
      final nameMatch = i.iName1.toLowerCase().contains(_modalSearchQuery);
      final sacMatch = i.sacCode.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || sacMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewItems;
    if (preview.isEmpty) return false;
    return preview.every((i) => _selectedCodes.contains(i.iCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final i in preview) {
          _selectedCodes.remove(i.iCode);
        }
      } else {
        for (final i in preview) {
          _selectedCodes.add(i.iCode);
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
      final selectedList = widget.items.where((i) => _selectedCodes.contains(i.iCode)).toList();

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'UnassignedItems_Export_$timestamp.$extension';
      final filePath = '$downloadsPath\\$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Unassigned Items');
        final excel_pkg.Sheet sheet = excel['Unassigned Items'];

        sheet.setColumnWidth(0, 20.0); // ITEM CODE
        sheet.setColumnWidth(1, 40.0); // ITEM NAME
        sheet.setColumnWidth(2, 16.0); // RATE (₹)
        sheet.setColumnWidth(3, 16.0); // UNIT
        sheet.setColumnWidth(4, 18.0); // HSN/SAC CODE

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
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('ITEM CODE'),
          excel_pkg.TextCellValue('ITEM NAME'),
          excel_pkg.TextCellValue('RATE (₹)'),
          excel_pkg.TextCellValue('UNIT'),
          excel_pkg.TextCellValue('HSN/SAC CODE'),
        ]);

        for (int col = 0; col < 5; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final item = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.TextCellValue(item.iCode),
            excel_pkg.TextCellValue(item.iName1),
            excel_pkg.DoubleCellValue(item.rate),
            excel_pkg.TextCellValue(item.unitCode),
            excel_pkg.TextCellValue(item.sacCode),
          ]);

          for (int col = 0; col < 5; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
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
                      'UNASSIGNED ITEMS REGISTER REPORT (ITEMMST)',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0C3B2E)),
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
                headers: ['SR NO', 'ITEM CODE', 'ITEM NAME', 'RATE (RS.)', 'UNIT', 'HSN/SAC'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return [
                    '${idx + 1}',
                    item.iCode,
                    item.iName1,
                    item.rate > 0 ? item.rate.toStringAsFixed(2) : '-',
                    item.unitCode.isNotEmpty ? item.unitCode : '-',
                    item.sacCode.isNotEmpty ? item.sacCode : '-',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(2.5),
                  2: const pw.FlexColumnWidth(4.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1.5),
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
    } catch (e, stack) {
      debugPrint('Export unassigned items failed: $e\n$stack');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(screenWidth - 32, 1060.0);
    final dialogHeight = math.min(screenHeight - 32, 630.0);
    final leftColWidth = dialogWidth < 960 ? 350.0 : 380.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
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
                    // LEFT COLUMN: Format Selector & Options
                    SizedBox(
                      width: leftColWidth,
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
                                    Text('Export Unassigned Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards (With 3D Excel & PDF Logos)
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
              'No item records found',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 540.0;
            final isOverflowing = constraints.maxWidth < minTableWidth;

            Widget tableWidget = SizedBox(
              width: isOverflowing ? minTableWidth : constraints.maxWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Container(
                    height: 40,
                    color: const Color(0xFF0C3B2E),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      children: [
                        SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                        SizedBox(width: 12),
                        SizedBox(width: 160, child: Text('ITEM CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.left)),
                        SizedBox(width: 12),
                        Expanded(child: Text('ITEM NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.left)),
                        SizedBox(width: 12),
                        SizedBox(width: 90, child: Text('SAC CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: previewList.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      itemBuilder: (ctx, idx) {
                        final item = previewList[idx];
                        final isSelected = _selectedCodes.contains(item.iCode);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCodes.remove(item.iCode);
                              } else {
                                _selectedCodes.add(item.iCode);
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
                                          _selectedCodes.add(item.iCode);
                                        } else {
                                          _selectedCodes.remove(item.iCode);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.iCode,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.iName1,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    item.sacCode.isEmpty ? '-' : item.sacCode,
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
            );

            if (isOverflowing) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tableWidget,
              );
            }
            return tableWidget;
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 3D HEADER LOGO WIDGET
// ============================================================================
// NON-STOCKABLE ITEM MASTER HEADER LOGO WIDGET (100% IDENTICAL VECTOR TO IMAGE 2)
// ============================================================================
class _NonStockableHeaderLogoWidget extends StatelessWidget {
  const _NonStockableHeaderLogoWidget();

  @override
  Widget build(BuildContext context) {
    const double size = 50.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          // Soft ambient glowy aura behind the logo on pure plain white space
          BoxShadow(
            color: const Color(0xFFFF6B8B).withValues(alpha: 0.30),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF36C5F0).withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: -1,
            offset: const Offset(-2, 4),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _IdenticalNonStockableLogoPainter(),
      ),
    );
  }
}

class _IdenticalNonStockableLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale);

    // Paints
    final navyPaint = Paint()
      ..color = const Color(0xFF0B1B4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cyanPaint = Paint()
      ..color = const Color(0xFF36C5F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final cyanFillPaint = Paint()
      ..color = const Color(0xFF36C5F0)
      ..style = PaintingStyle.fill;

    final whiteFillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final lavenderFillPaint = Paint()
      ..color = const Color(0xFFD8E0FF)
      ..style = PaintingStyle.fill;

    final pinkFillPaint = Paint()
      ..color = const Color(0xFFFF6B8B)
      ..style = PaintingStyle.fill;

    final whiteStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;

    // 1. Bottom Chassis Rail
    final chassisPath = Path()
      ..moveTo(27, 75)
      ..lineTo(27, 83)
      ..lineTo(88, 83);
    canvas.drawPath(chassisPath, cyanPaint);

    // 2. Wheels (Dark Navy Outer, Cyan Inner Hub)
    // Left Wheel
    canvas.drawCircle(const Offset(42, 90), 8.5, Paint()..color = const Color(0xFF0B1B4F));
    canvas.drawCircle(const Offset(42, 90), 4.5, cyanFillPaint);

    // Right Wheel
    canvas.drawCircle(const Offset(76, 90), 8.5, Paint()..color = const Color(0xFF0B1B4F));
    canvas.drawCircle(const Offset(76, 90), 4.5, cyanFillPaint);

    // 3. Handle Bar (Left Top)
    // Arm
    canvas.drawLine(const Offset(13, 16), const Offset(18, 32), cyanPaint);

    // Grip Pill
    final RRect gripRRect = RRect.fromLTRBR(3, 8, 19, 18, const Radius.circular(5));
    canvas.drawRRect(gripRRect, cyanFillPaint);
    canvas.drawRRect(gripRRect, navyPaint);

    // 4. Shopping Basket Body
    final Path basketPath = Path()
      ..moveTo(17, 36)
      ..lineTo(93, 36)
      ..lineTo(82, 73)
      ..lineTo(28, 73)
      ..close();

    // Fill Basket Interior with White & Lavender
    canvas.drawPath(basketPath, whiteFillPaint);

    // Upper Lavender Tint inside basket
    final Path lavenderPath = Path()
      ..moveTo(17, 36)
      ..lineTo(93, 36)
      ..lineTo(88, 52)
      ..lineTo(23, 52)
      ..close();
    canvas.drawPath(lavenderPath, lavenderFillPaint);

    // Vertical Cyan Ribs inside Basket
    canvas.drawLine(const Offset(39, 44), const Offset(39, 66), cyanPaint);
    canvas.drawLine(const Offset(55, 44), const Offset(55, 68), cyanPaint);
    canvas.drawLine(const Offset(71, 44), const Offset(71, 66), cyanPaint);

    // Basket Wire Outer Outline
    canvas.drawPath(basketPath, navyPaint);

    // Top Rim Bar (Cyan Fill + Navy Outline)
    final RRect rimRRect = RRect.fromLTRBR(11, 31, 97, 41, const Radius.circular(5));
    canvas.drawRRect(rimRRect, cyanFillPaint);
    canvas.drawRRect(rimRRect, navyPaint);

    // 5. Prohibition / Block Sign Overlay (Pink Circle with Navy Border & White Slash)
    const Offset signCenter = Offset(56, 30);
    const double signRadius = 26.0;

    // Outer Navy Border
    canvas.drawCircle(signCenter, signRadius, Paint()..color = const Color(0xFF0B1B4F));

    // Pink Salmon Inner Circle
    canvas.drawCircle(signCenter, signRadius - 3.8, pinkFillPaint);

    // White Inner Circle Ring
    canvas.drawCircle(
      signCenter,
      signRadius - 8.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );

    // White Diagonal Prohibition Slash Bar (Top-Left to Bottom-Right)
    canvas.drawLine(
      const Offset(38, 48),
      const Offset(74, 12),
      whiteStrokePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
// ANIMATED ORBIT EXPORT BUTTON & PAINTER
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerExport() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() => _isAnimating = false);
        widget.onPressed();
      }
    });
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
                height: 36,
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
// ANIMATED SUCCESS BUTTON WIDGET (100% IDENTICAL TO PROJECT MASTER)
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
// EXPORT MODAL FOR NON-STOCKABLE ITEMS (100% IDENTICAL TO PROJECT MASTER EXPORT)
// ============================================================================
class _NonStockableExportModalDialog extends StatefulWidget {
  final List<NonStockableItem> items;
  const _NonStockableExportModalDialog({required this.items});

  @override
  State<_NonStockableExportModalDialog> createState() => _NonStockableExportModalDialogState();
}

class _NonStockableExportModalDialogState extends State<_NonStockableExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.iCode).toSet();
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

  List<NonStockableItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      final codeMatch = i.iCode.toLowerCase().contains(_modalSearchQuery);
      final nameMatch = i.iName1.toLowerCase().contains(_modalSearchQuery);
      final unitMatch = i.unitName.toLowerCase().contains(_modalSearchQuery);
      final taxMatch = i.taxName.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || nameMatch || unitMatch || taxMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewItems;
    if (preview.isEmpty) return false;
    return preview.every((i) => _selectedCodes.contains(i.iCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final i in preview) {
          _selectedCodes.remove(i.iCode);
        }
      } else {
        for (final i in preview) {
          _selectedCodes.add(i.iCode);
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
      final selectedList = widget.items.where((i) => _selectedCodes.contains(i.iCode)).toList();

      final String userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\Default';
      final String downloadsPath = '$userProfile\\Downloads';
      final Directory dir = Directory(downloadsPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'NonStockableItems_Export_$timestamp.$extension';
      final filePath = '$downloadsPath\\$fileName';

      final file = File(filePath);

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Non-Stockable Items');
        final excel_pkg.Sheet sheet = excel['Non-Stockable Items'];

        sheet.setColumnWidth(0, 18.0); // ITEM CODE
        sheet.setColumnWidth(1, 38.0); // ITEM NAME
        sheet.setColumnWidth(2, 16.0); // RATE (₹)
        sheet.setColumnWidth(3, 16.0); // UNIT
        sheet.setColumnWidth(4, 18.0); // SAC/HSN
        sheet.setColumnWidth(5, 22.0); // TAX SLAB

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
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder, rightBorder: cellBorder, topBorder: cellBorder, bottomBorder: cellBorder,
        );

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('ITEM CODE'),
          excel_pkg.TextCellValue('ITEM NAME'),
          excel_pkg.TextCellValue('RATE (₹)'),
          excel_pkg.TextCellValue('UNIT'),
          excel_pkg.TextCellValue('SAC/HSN'),
          excel_pkg.TextCellValue('TAX SLAB'),
        ]);

        for (int col = 0; col < 6; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final item = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.TextCellValue(item.iCode),
            excel_pkg.TextCellValue(item.iName1),
            excel_pkg.DoubleCellValue(item.rate),
            excel_pkg.TextCellValue(item.unitName),
            excel_pkg.TextCellValue(item.sacCode),
            excel_pkg.TextCellValue(item.taxName),
          ]);

          for (int col = 0; col < 6; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
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
                      'NON-STOCKABLE ITEMS MASTER REGISTER REPORT',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0C3B2E)),
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
                headers: ['SR NO', 'ITEM CODE', 'ITEM NAME', 'RATE (RS.)', 'UNIT', 'SAC CODE', 'TAX SLAB'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return [
                    '${idx + 1}',
                    item.iCode,
                    item.iName1,
                    item.rate > 0 ? item.rate.toStringAsFixed(2) : '-',
                    item.unitName.isNotEmpty ? item.unitName : '-',
                    item.sacCode.isNotEmpty ? item.sacCode : '-',
                    item.taxName.isNotEmpty ? item.taxName : '-',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.8),
                  1: const pw.FlexColumnWidth(2.3),
                  2: const pw.FlexColumnWidth(4.2),
                  3: const pw.FlexColumnWidth(1.4),
                  4: const pw.FlexColumnWidth(1.2),
                  5: const pw.FlexColumnWidth(1.4),
                  6: const pw.FlexColumnWidth(1.4),
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
    } catch (e, stack) {
      debugPrint('Export non-stockable items failed: $e\n$stack');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(screenWidth - 32, 1060.0);
    final dialogHeight = math.min(screenHeight - 32, 630.0);
    final leftColWidth = dialogWidth < 960 ? 350.0 : 380.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
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
                    // LEFT COLUMN: Format Selector & Options
                    SizedBox(
                      width: leftColWidth,
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
                                    Text('Export Non-Stockable Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards (With 3D Excel & PDF Logos)
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
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? brandColor : const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
              'No item records found',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 540.0;
            final isOverflowing = constraints.maxWidth < minTableWidth;

            Widget tableWidget = SizedBox(
              width: isOverflowing ? minTableWidth : constraints.maxWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Container(
                    height: 40,
                    color: const Color(0xFF0C3B2E),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      children: [
                        SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                        SizedBox(width: 12),
                        SizedBox(width: 160, child: Text('ITEM CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.left)),
                        SizedBox(width: 12),
                        Expanded(child: Text('ITEM NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.left)),
                        SizedBox(width: 12),
                        SizedBox(width: 90, child: Text('SAC CODE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: previewList.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                      itemBuilder: (ctx, idx) {
                        final item = previewList[idx];
                        final isSelected = _selectedCodes.contains(item.iCode);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCodes.remove(item.iCode);
                              } else {
                                _selectedCodes.add(item.iCode);
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
                                          _selectedCodes.add(item.iCode);
                                        } else {
                                          _selectedCodes.remove(item.iCode);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 160,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      item.iCode,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.primaryColor),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.iName1,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    item.sacCode.isEmpty ? '-' : item.sacCode,
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
            );

            if (isOverflowing) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tableWidget,
              );
            }
            return tableWidget;
          },
        ),
      ),
    );
  }
}

// ============================================================================
// 3D BRAND LOGO WIDGETS FOR EXPORT FORMAT CARDS
// ============================================================================
// ============================================================================
// 3D BRAND LOGO WIDGETS FOR EXPORT FORMAT CARDS (100% IDENTICAL TO PROJECT MASTER)
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
// ANIMATED NON-STOCKABLE ITEM ROW WIDGET (DEPARTMENT MASTER TABLE 100% PARITY)
// ============================================================================
class _AnimatedNonStockableItemRow extends StatefulWidget {
  final NonStockableItem item;
  final int index;
  final bool isSelected;
  final bool isGlowing;
  final bool isGlowingEdit;
  final bool isGlowingNew;
  final String taxDisplay;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedNonStockableItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.isSelected,
    required this.isGlowing,
    required this.isGlowingEdit,
    required this.isGlowingNew,
    required this.taxDisplay,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedNonStockableItemRow> createState() => _AnimatedNonStockableItemRowState();
}

class _AnimatedNonStockableItemRowState extends State<_AnimatedNonStockableItemRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final isGlowing = widget.isGlowing;
    final isGlowingEdit = widget.isGlowingEdit;
    final isGlowingNew = widget.isGlowingNew;

    // Glowing color: Amber/Orange for edit/update (Main Group Master parity), Emerald green for new
    final Color glowColor = isGlowingEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedScale(
          scale: isGlowing ? 1.006 : (_isHovered ? 1.006 : 1.0),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 1.5, horizontal: 2),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isGlowingNew
                  ? const Color(0xFFECFDF5)
                  : (isGlowingEdit
                      ? const Color(0xFFFFFBEB)
                      : (isSelected
                          ? AppColors.secondaryColor.withValues(alpha: 0.08)
                          : (_isHovered ? const Color(0xFFF0FDF4) : Colors.white))),
              borderRadius: BorderRadius.circular(8),
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
                        blurRadius: 12,
                        spreadRadius: 2.0,
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
                // 1. Code Badge Box (Fixed Width: 66, Height: 24 - Same Size Across All Rows)
                SizedBox(
                  width: 66,
                  height: 24,
                  child: Tooltip(
                    message: '#${item.iCode}',
                    waitDuration: const Duration(milliseconds: 300),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 66,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isGlowingNew
                            ? const Color(0xFF10B981)
                            : (isGlowingEdit
                                ? const Color(0xFFF59E0B)
                                : (isSelected
                                    ? AppColors.secondaryColor
                                    : (_isHovered
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF6366F1).withValues(alpha: 0.08)))),
                        borderRadius: BorderRadius.circular(6),
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
                                          : (_isHovered ? const Color(0xFF16A34A) : AppColors.secondaryColor))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.5),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isGlowing) ...[
                                  Container(
                                    padding: const EdgeInsets.all(1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: Colors.white,
                                      size: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  '#${item.iCode}',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isGlowing || isSelected || _isHovered
                                        ? Colors.white
                                        : const Color(0xFF6366F1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Item Name Box (Emerald Theme matching Header Logo: 0xFF10B981)
                Expanded(
                  child: Tooltip(
                    message: item.iName1,
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: _isHovered ? 0.13 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: _isHovered ? 0.38 : 0.22),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.iName1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 3. Unit Box (Cyan Theme matching Header Logo: 0xFF06B6D4)
                SizedBox(
                  width: 48,
                  height: 24,
                  child: Tooltip(
                    message: item.unitName.isNotEmpty ? item.unitName : '-',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 48,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: _isHovered ? 0.13 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF06B6D4).withValues(alpha: _isHovered ? 0.38 : 0.22),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.unitName.isNotEmpty ? item.unitName : '-',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0891B2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 4. Rate Box (Green Theme matching Header Logo: 0xFF059669)
                SizedBox(
                  width: 60,
                  height: 24,
                  child: Tooltip(
                    message: item.rate > 0 ? '₹${item.rate.toStringAsFixed(2)}' : '₹0.00',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 60,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: _isHovered ? 0.13 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF059669).withValues(alpha: _isHovered ? 0.38 : 0.22),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.rate > 0 ? '₹${item.rate.toStringAsFixed(2)}' : '₹0.00',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 5. SAC Code Box (Amber Theme matching Header Logo: 0xFFF59E0B)
                SizedBox(
                  width: 60,
                  height: 24,
                  child: Tooltip(
                    message: item.sacCode.isNotEmpty ? item.sacCode : '-',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 60,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: _isHovered ? 0.13 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: _isHovered ? 0.38 : 0.22),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.sacCode.isNotEmpty ? item.sacCode : '-',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 6. Tax Slab Box (Rose Theme matching Header Logo: 0xFFF43F5E)
                SizedBox(
                  width: 46,
                  height: 24,
                  child: Tooltip(
                    message: widget.taxDisplay.isNotEmpty ? widget.taxDisplay : '-',
                    waitDuration: const Duration(milliseconds: 300),
                    child: Container(
                      width: 46,
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF43F5E).withValues(alpha: _isHovered ? 0.13 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFF43F5E).withValues(alpha: _isHovered ? 0.38 : 0.22),
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.taxDisplay.isNotEmpty ? widget.taxDisplay : '-',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 7. Actions Box (Violet Theme matching Header Logo: 0xFF8B5CF6)
                SizedBox(
                  width: 54,
                  height: 24,
                  child: Container(
                    width: 54,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: _isHovered ? 0.13 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF8B5CF6).withValues(alpha: _isHovered ? 0.38 : 0.22),
                        width: 1.0,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ActionButton(
                          icon: Icons.edit_rounded,
                          color: const Color(0xFF10B981),
                          tooltip: 'Edit Item',
                          onPressed: widget.onEdit,
                        ),
                        const SizedBox(width: 3),
                        _ActionButton(
                          icon: Icons.delete_outline_rounded,
                          color: const Color(0xFFEF4444),
                          tooltip: 'Delete Item',
                          onPressed: widget.onDelete,
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
}

// ============================================================================
// INTERACTIVE HOVER ACTION BUTTON WIDGET (DEPARTMENT MASTER PARITY)
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
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: IconButton(
            icon: Icon(
              widget.icon,
              size: 11.0,
              color: _isHovered ? widget.color : widget.color.withValues(alpha: 0.8),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: widget.tooltip,
            onPressed: widget.onPressed,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ADD NON-STOCKABLE ITEM FORM HEADER LOGO (100% IDENTICAL TO IMAGE 2)
// ============================================================================
class _AddNonStockableItemLogoWidget extends StatelessWidget {
  final double size;
  const _AddNonStockableItemLogoWidget({this.size = 32.0});

  @override
  Widget build(BuildContext context) {
    // Direct on plain white screen with no background borders, box, or shadow
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/add_non_stockable_item_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          size: Size(size, size),
          painter: const _AddNonStockableItemLogoPainter(),
        ),
      ),
    );
  }
}

class _AddNonStockableItemLogoPainter extends CustomPainter {
  const _AddNonStockableItemLogoPainter();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 512.0;
    canvas.save();
    canvas.scale(scale);

    // Color definitions exact to Image 2
    const Color cCloud = Color(0xFF7CD9F2);
    const Color cPaper = Color(0xFFECEEF1);
    const Color cFold = Color(0xFFD9DDE2);
    const Color cArrow = Color(0xFFFF8C78);
    const Color cArrowShade = Color(0xFFDB6B5E);
    const Color cBar = Color(0xFFDB6B5E);

    final Paint fillCloud = Paint()..color = cCloud..style = PaintingStyle.fill;
    final Paint fillPaper = Paint()..color = cPaper..style = PaintingStyle.fill;
    final Paint fillFold = Paint()..color = cFold..style = PaintingStyle.fill;
    final Paint fillArrow = Paint()..color = cArrow..style = PaintingStyle.fill;
    final Paint fillArrowShade = Paint()..color = cArrowShade..style = PaintingStyle.fill;
    final Paint fillBar = Paint()..color = cBar..style = PaintingStyle.fill;

    // 1. CLOUD BACKGROUND
    final Path cloudPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(256, 160), radius: 156))
      ..addOval(Rect.fromCircle(center: const Offset(118, 240), radius: 118))
      ..addOval(Rect.fromCircle(center: const Offset(400, 260), radius: 112))
      ..addRect(const Rect.fromLTRB(118, 200, 400, 375));
    canvas.drawPath(cloudPath, fillCloud);

    // 2. DOCUMENT (PAPER)
    final Path paperPath = Path()
      ..moveTo(144, 218)
      ..lineTo(320, 218)
      ..lineTo(384, 282)
      ..lineTo(384, 496)
      ..arcToPoint(const Offset(368, 512), radius: const Radius.circular(16))
      ..lineTo(160, 512)
      ..arcToPoint(const Offset(144, 496), radius: const Radius.circular(16))
      ..close();
    canvas.drawPath(paperPath, fillPaper);

    // Top-right folded flap
    final Path foldPath = Path()
      ..moveTo(320, 218)
      ..lineTo(320, 282)
      ..lineTo(384, 282)
      ..close();
    canvas.drawPath(foldPath, fillFold);

    // 3. DOCUMENT TEXT BARS (Rounded Horizontal Lines)
    canvas.drawRRect(RRect.fromLTRBR(209, 368, 303, 384, const Radius.circular(8)), fillBar);
    canvas.drawRRect(RRect.fromLTRBR(209, 400, 303, 416, const Radius.circular(8)), fillBar);
    canvas.drawRRect(RRect.fromLTRBR(209, 432, 303, 448, const Radius.circular(8)), fillBar);

    // 4. UPWARD CORAL ARROW WITH 3D DEPTH SHADING
    // Left shading / 3D facet
    final Path arrowShadePath = Path()
      ..moveTo(256, 89)
      ..lineTo(193, 154)
      ..lineTo(224, 154)
      ..lineTo(224, 332)
      ..arcToPoint(const Offset(232, 339), radius: const Radius.circular(8))
      ..lineTo(256, 339)
      ..lineTo(256, 89)
      ..close();
    canvas.drawPath(arrowShadePath, fillArrowShade);

    // Main arrow front body
    final Path arrowFrontPath = Path()
      ..moveTo(256, 89)
      ..lineTo(318, 154)
      ..lineTo(287, 154)
      ..lineTo(287, 332)
      ..arcToPoint(const Offset(279, 339), radius: const Radius.circular(8))
      ..lineTo(232, 339)
      ..arcToPoint(const Offset(224, 332), radius: const Radius.circular(8))
      ..lineTo(224, 154)
      ..lineTo(256, 89)
      ..close();
    canvas.drawPath(arrowFrontPath, fillArrow);

    canvas.restore();
  }
}

// ============================================================================
// CONFIGURED ITEM CARDS HEADER LOGO (100% IDENTICAL VECTOR TO IMAGE 2)
// ============================================================================
class _ConfiguredItemCardsLogoWidget extends StatelessWidget {
  final double size;
  const _ConfiguredItemCardsLogoWidget({this.size = 32.0});

  @override
  Widget build(BuildContext context) {
    // Direct on plain white screen with no background borders, box, or shadow
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/item_sheet_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => CustomPaint(
          size: Size(size, size),
          painter: const _IdenticalConfiguredItemBoxesLogoPainter(),
        ),
      ),
    );
  }
}

class _IdenticalConfiguredItemBoxesLogoPainter extends CustomPainter {
  const _IdenticalConfiguredItemBoxesLogoPainter();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.width / 256.0;
    canvas.save();
    canvas.scale(scale);

    // Color definitions exact to Image 2
    const Color cFront = Color(0xFFE29A6C);
    const Color cSideLeft = Color(0xFFD48C64);
    const Color cTop = Color(0xFFC48563);
    const Color cTape = Color(0xFFECEAEC);
    const Color cTapeShadow = Color(0xFFDBD8DB);
    const Color cBlack = Color(0xFF000000);

    final Paint fillFront = Paint()..color = cFront..style = PaintingStyle.fill;
    final Paint fillSideLeft = Paint()..color = cSideLeft..style = PaintingStyle.fill;
    final Paint fillTop = Paint()..color = cTop..style = PaintingStyle.fill;
    final Paint fillTape = Paint()..color = cTape..style = PaintingStyle.fill;
    final Paint fillTapeShadow = Paint()..color = cTapeShadow..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = cBlack
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint dashPaint = Paint()
      ..color = cBlack
      ..style = PaintingStyle.fill;

    // 1. TOP-LEFT BOX
    // -------------------------------------------------------------
    // Top Face
    final Path tlTopFace = Path()
      ..moveTo(8, 8)
      ..lineTo(123, 8)
      ..lineTo(144, 38)
      ..lineTo(29, 38)
      ..close();
    canvas.drawPath(tlTopFace, fillTop);

    // Left Side Face
    final Path tlSideFace = Path()
      ..moveTo(8, 8)
      ..lineTo(29, 38)
      ..lineTo(29, 136)
      ..lineTo(8, 106)
      ..close();
    canvas.drawPath(tlSideFace, fillSideLeft);

    // Front Face
    final Rect tlFrontRect = const Rect.fromLTRB(29, 38, 144, 136);
    canvas.drawRect(tlFrontRect, fillFront);

    // Top-Left Tape (Top face part)
    final Path tlTapeTop = Path()
      ..moveTo(76, 8)
      ..lineTo(98, 8)
      ..lineTo(98, 38)
      ..lineTo(76, 38)
      ..close();
    canvas.drawPath(tlTapeTop, fillTapeShadow);

    // Top-Left Tape (Front face part with inverted V swallowtail notch)
    final Path tlTapeFront = Path()
      ..moveTo(76, 38)
      ..lineTo(98, 38)
      ..lineTo(98, 72)
      ..lineTo(87, 62)
      ..lineTo(76, 72)
      ..close();
    canvas.drawPath(tlTapeFront, fillTape);

    // Top-Left Dash Marks
    canvas.drawRRect(RRect.fromLTRBR(44, 104, 72, 110, const Radius.circular(3)), dashPaint);
    canvas.drawRRect(RRect.fromLTRBR(44, 116, 62, 122, const Radius.circular(3)), dashPaint);

    // 2. BOTTOM-LEFT BOX
    // -------------------------------------------------------------
    // Left Side Face
    final Path blSideFace = Path()
      ..moveTo(8, 106)
      ..lineTo(29, 136)
      ..lineTo(29, 246)
      ..lineTo(8, 216)
      ..close();
    canvas.drawPath(blSideFace, fillSideLeft);

    // Front Face
    final Rect blFrontRect = const Rect.fromLTRB(29, 136, 144, 246);
    canvas.drawRect(blFrontRect, fillFront);

    // Bottom-Left Tape (Front face part with inverted V swallowtail notch)
    final Path blTapeFront = Path()
      ..moveTo(76, 136)
      ..lineTo(98, 136)
      ..lineTo(98, 168)
      ..lineTo(87, 158)
      ..lineTo(76, 168)
      ..close();
    canvas.drawPath(blTapeFront, fillTape);

    // Bottom-Left Dash Marks
    canvas.drawRRect(RRect.fromLTRBR(44, 214, 72, 220, const Radius.circular(3)), dashPaint);
    canvas.drawRRect(RRect.fromLTRBR(44, 226, 62, 232, const Radius.circular(3)), dashPaint);

    // 3. RIGHT BOX
    // -------------------------------------------------------------
    // Top Face
    final Path rTopFace = Path()
      ..moveTo(144, 80)
      ..lineTo(168, 50)
      ..lineTo(248, 50)
      ..lineTo(248, 80)
      ..close();
    canvas.drawPath(rTopFace, fillTop);

    // Front Face
    final Rect rFrontRect = const Rect.fromLTRB(144, 80, 248, 246);
    canvas.drawRect(rFrontRect, fillFront);

    // Right Box Tape (Top face part)
    final Path rTapeTop = Path()
      ..moveTo(192, 50)
      ..lineTo(214, 50)
      ..lineTo(214, 80)
      ..lineTo(192, 80)
      ..close();
    canvas.drawPath(rTapeTop, fillTapeShadow);

    // Right Box Tape (Front face part with inverted V swallowtail notch)
    final Path rTapeFront = Path()
      ..moveTo(192, 80)
      ..lineTo(214, 80)
      ..lineTo(214, 114)
      ..lineTo(203, 104)
      ..lineTo(192, 114)
      ..close();
    canvas.drawPath(rTapeFront, fillTape);

    // Right Box Dash Marks
    canvas.drawRRect(RRect.fromLTRBR(160, 214, 188, 220, const Radius.circular(3)), dashPaint);
    canvas.drawRRect(RRect.fromLTRBR(160, 226, 178, 232, const Radius.circular(3)), dashPaint);

    // 4. BOLD BLACK OUTLINES (Matching Image 2)
    // -------------------------------------------------------------
    // Outer Border & Dividing Edges
    canvas.drawPath(tlTopFace, strokePaint);
    canvas.drawPath(tlSideFace, strokePaint);
    canvas.drawRect(tlFrontRect, strokePaint);
    canvas.drawPath(tlTapeFront, strokePaint);

    canvas.drawPath(blSideFace, strokePaint);
    canvas.drawRect(blFrontRect, strokePaint);
    canvas.drawPath(blTapeFront, strokePaint);

    canvas.drawPath(rTopFace, strokePaint);
    canvas.drawRect(rFrontRect, strokePaint);
    canvas.drawPath(rTapeFront, strokePaint);

    canvas.restore();
  }
}

// ============================================================================
// STATEFUL HOVERABLE UNIT OPTION PICKER CARD
// ============================================================================
class _UnitOptionHoverCard extends StatefulWidget {
  final UnitOption unit;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _UnitOptionHoverCard({
    required this.unit,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_UnitOptionHoverCard> createState() => _UnitOptionHoverCardState();
}

class _UnitOptionHoverCardState extends State<_UnitOptionHoverCard> {
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
          curve: Curves.easeOutCubic,
          transform: _isHovered ? Matrix4.translationValues(0.0, -3.0, 0.0) : Matrix4.identity(),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFE0F2FE)
                : (_isHovered ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF0284C7)
                  : (_isHovered ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0)),
              width: widget.isSelected || _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? const Color(0xFF0284C7).withValues(alpha: 0.25)
                    : (_isHovered
                        ? const Color(0xFF0284C7).withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.02)),
                blurRadius: _isHovered ? 10 : 4,
                offset: _isHovered ? const Offset(0, 4) : const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected || _isHovered ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.unit.unitName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: widget.isSelected || _isHovered ? FontWeight.bold : FontWeight.w600,
                    color: widget.isSelected || _isHovered ? const Color(0xFF0369A1) : const Color(0xFF334155),
                  ),
                  overflow: TextOverflow.ellipsis,
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
// STATEFUL HOVERABLE TAX SLAB SELECTION PILL
// ============================================================================
class _TaxSlabOptionHoverPill extends StatefulWidget {
  final TaxSlabOption tax;
  final bool isSelected;
  final VoidCallback onTap;

  const _TaxSlabOptionHoverPill({
    required this.tax,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_TaxSlabOptionHoverPill> createState() => _TaxSlabOptionHoverPillState();
}

class _TaxSlabOptionHoverPillState extends State<_TaxSlabOptionHoverPill> {
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
          curve: Curves.easeOutCubic,
          transform: _isHovered ? Matrix4.translationValues(0.0, -2.0, 0.0) : Matrix4.identity(),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFF0C3B2E)
                : (_isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFF0C3B2E)
                  : (_isHovered ? const Color(0xFF0C3B2E) : const Color(0xFFCBD5E1)),
              width: widget.isSelected || _isHovered ? 1.4 : 1.0,
            ),
            boxShadow: [
              if (_isHovered || widget.isSelected)
                BoxShadow(
                  color: const Color(0xFF0C3B2E).withValues(alpha: widget.isSelected ? 0.25 : 0.15),
                  blurRadius: _isHovered ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Text(
            widget.tax.taxName,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: widget.isSelected || _isHovered ? FontWeight.bold : FontWeight.w600,
              color: widget.isSelected ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 100% IDENTICAL CONFIRM DELETE DIALOG (COPIED FROM PROJECT MASTER)
// ============================================================================
class _ConfirmDeleteDialog extends StatefulWidget {
  final String itemCode;
  final String itemName;
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteDialog({
    required this.itemCode,
    required this.itemName,
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

            // 100% IDENTICAL VECTOR ILLUSTRATION
            SizedBox(
              width: 180,
              height: 130,
              child: CustomPaint(
                painter: _IdenticalDeleteDialogIllustrationPainter(),
              ),
            ),
            const SizedBox(height: 16),

            // Red Title
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
                // Red Delete Button (Left) with Red Glow
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

// 100% IDENTICAL VECTOR ILLUSTRATION
class _IdenticalDeleteDialogIllustrationPainter extends CustomPainter {
  const _IdenticalDeleteDialogIllustrationPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Soft Oval Ground Shadow
    final shadowPaint = Paint()..color = const Color(0xFFF1F5F9);
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.78, w * 0.76, h * 0.12), shadowPaint);

    // 2. Background Windows
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

    // 3. Red Trash Bin
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

    // 4. Person Figure
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
