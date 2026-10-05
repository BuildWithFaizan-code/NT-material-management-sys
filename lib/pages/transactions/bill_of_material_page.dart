import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/app_colors.dart';
import '../bom/bom_models.dart';
import '../bom/bom_service.dart';
import '../bom/widgets/finished_good_lookup_dialog.dart';
import '../bom/widgets/bom_show_record_modal.dart';
import '../bom/widgets/bom_export_modal_dialog.dart';

enum ButtonStatus { idle, loading, success, error }

// ============================================================================
// MAIN PAGE: BillOfMaterialPage (Master Screen UI Architecture)
// ============================================================================
class BillOfMaterialPage extends StatefulWidget {
  final BomService? bomService;
  const BillOfMaterialPage({super.key, this.bomService});

  @override
  State<BillOfMaterialPage> createState() => _BillOfMaterialPageState();
}

class _BillOfMaterialPageState extends State<BillOfMaterialPage> {
  final FocusNode _pageKeyFocusNode = FocusNode();
  late final BomService _bomService;

  // Active Mode State (JOB vs REGULAR)
  BomMode _activeMode = BomMode.job;

  // Lookups State
  List<BomStoreLookup> _stores = [];
  List<BomDepartmentLookup> _departments = [];
  List<BomUnitLookup> _units = [];
  bool _isLoadingLookups = true;

  // Form Controllers & State
  int? _selectedStrCode;
  int? _selectedDepCode;
  final TextEditingController _bomIdCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _materialCodeCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _poNumberCtrl = TextEditingController();
  final TextEditingController _baseQtyCtrl = TextEditingController();
  int? _selectedUnitCode;
  String? _selectedUnitName;
  String? _selectedStatus; // Initially empty/null as requested until selected or loaded

  // Focus Nodes for Keyboard Navigation
  final FocusNode _storeFocusNode = FocusNode();
  final FocusNode _deptFocusNode = FocusNode();
  final FocusNode _materialCodeFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _poFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();

  // Status & Glow Flags
  bool _isSubmitting = false;
  bool _isSaveSuccess = false;
  bool _isResetting = false;
  String? _buttonValidationMsg;
  String? _glowingBomId;
  Timer? _glowTimer;
  Timer? _validationTimer;

  // Sub-items Grid Data
  final List<BomSubItemData> _subItems = [];
  int? _selectedComponentIndex;
  final ScrollController _horizontalTableController = ScrollController();
  final ScrollController _verticalTableController = ScrollController();
  final ScrollController _formScrollController = ScrollController();

  double get _totalConsumption => _subItems.fold(0.0, (acc, item) => acc + item.bomCons);
  double get _totalToleranceQty => _subItems.fold(0.0, (acc, item) => acc + item.bomTolQty);
  double get _totalNetQty => _subItems.fold(0.0, (acc, item) => acc + item.qty);

  @override
  void initState() {
    super.initState();
    _bomService = widget.bomService ?? BomService();
    _loadLookups();
  }

  @override
  void dispose() {
    _pageKeyFocusNode.dispose();
    _storeFocusNode.dispose();
    _deptFocusNode.dispose();
    _materialCodeFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _poFocusNode.dispose();
    _qtyFocusNode.dispose();
    _bomIdCtrl.dispose();
    _materialCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _poNumberCtrl.dispose();
    _baseQtyCtrl.dispose();
    _horizontalTableController.dispose();
    _verticalTableController.dispose();
    _formScrollController.dispose();
    _glowTimer?.cancel();
    _validationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    setState(() => _isLoadingLookups = true);

    try {
      final results = await Future.wait([
        _bomService.fetchStores(),
        _bomService.fetchDepartments(),
        _bomService.fetchUnits(),
        _bomService.fetchNextBomId(_activeMode),
      ]);

      if (mounted) {
        setState(() {
          _stores = results[0] as List<BomStoreLookup>;
          _departments = results[1] as List<BomDepartmentLookup>;
          _units = results[2] as List<BomUnitLookup>;
          _bomIdCtrl.text = results[3] as String;
          // Keep dropdowns and input fields empty on fresh load
          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLookups = false);
    }
  }

  Future<void> _handleModeChange(BomMode mode) async {
    if (_activeMode == mode) return;

    setState(() {
      _activeMode = mode;
      _materialCodeCtrl.clear();
      _descriptionCtrl.clear();
      _buttonValidationMsg = null;
    });

    final nextId = await _bomService.fetchNextBomId(mode);
    if (mounted) {
      setState(() {
        _bomIdCtrl.text = nextId;
      });
    }
  }

  Future<void> _openFinishedGoodLookup() async {
    final selected = await showDialog<FinishedGoodItem>(
      context: context,
      barrierDismissible: true,
      builder: (context) => FinishedGoodLookupDialog(
        mode: _activeMode,
        initialQuery: _materialCodeCtrl.text.trim(),
        bomService: _bomService,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _materialCodeCtrl.text = selected.iCode;
        _descriptionCtrl.text = selected.itName;
        _selectedStatus = selected.status;

        // Auto match unit if present
        if (_units.any((u) => u.unitCode == selected.unitCode)) {
          _selectedUnitCode = selected.unitCode;
          _selectedUnitName = selected.unitName;
        } else if (_units.any((u) => u.unitName.toUpperCase() == selected.unitName.toUpperCase())) {
          final matched = _units.firstWhere((u) => u.unitName.toUpperCase() == selected.unitName.toUpperCase());
          _selectedUnitCode = matched.unitCode;
          _selectedUnitName = matched.unitName;
        }

        _buttonValidationMsg = null;
      });
      _descriptionFocusNode.requestFocus();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF059669),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  void _showButtonValidation(String msg) {
    _validationTimer?.cancel();
    setState(() => _buttonValidationMsg = msg);
    _validationTimer = Timer(const Duration(milliseconds: 3500), () {
      if (mounted && _buttonValidationMsg == msg) {
        setState(() => _buttonValidationMsg = null);
      }
    });
  }

  void _triggerEntryGlow(String bomId) {
    _glowTimer?.cancel();
    setState(() => _glowingBomId = bomId);

    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _glowingBomId = null);
      }
    });
  }

  Future<void> _resetForm() async {
    setState(() => _isResetting = true);

    _selectedStrCode = null;
    _selectedDepCode = null;
    _materialCodeCtrl.clear();
    _descriptionCtrl.clear();
    _poNumberCtrl.clear();
    _baseQtyCtrl.clear();
    _selectedUnitCode = null;
    _selectedUnitName = null;
    _selectedStatus = null;
    _buttonValidationMsg = null;
    _subItems.clear();
    _selectedComponentIndex = null;

    final nextId = await _bomService.fetchNextBomId(_activeMode);

    if (mounted) {
      setState(() {
        _bomIdCtrl.text = nextId;
        _isResetting = false;
      });
    }
  }

  void _showCoolUnitPickerModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        String searchVal = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _units.where((u) => u.unitName.toLowerCase().contains(searchVal.toLowerCase())).toList();
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
                          Text(
                            'Select Unit of Measurement (${filtered.length} / ${_units.length})',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
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
                          hintText: 'Search ${_units.length} unit options...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0284C7)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF0284C7)),
                          ),
                        ),
                      ),
                    ),
                    // Unit Grid
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF94A3B8)),
                                  SizedBox(height: 6),
                                  Text(
                                    'No unit options match your search',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
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
                                  unitName: u.unitName,
                                  isSelected: isSelected,
                                  icon: icon,
                                  onTap: () {
                                    setState(() {
                                      _selectedUnitCode = u.unitCode;
                                      _selectedUnitName = u.unitName;
                                    });
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

  void _duplicateComponent(int index) {
    if (index < 0 || index >= _subItems.length) return;
    final current = _subItems[index];
    setState(() {
      _subItems.add(
        current.copyWith(
          bomsCode: '${_subItems.length + 1}',
        ),
      );
      _selectedComponentIndex = _subItems.length - 1;
    });
  }

  void _deleteComponent(int index) {
    if (index < 0 || index >= _subItems.length) return;
    setState(() {
      _subItems.removeAt(index);
      for (int i = 0; i < _subItems.length; i++) {
        _subItems[i] = _subItems[i].copyWith(bomsCode: '${i + 1}');
      }
      if (_selectedComponentIndex != null) {
        if (_subItems.isEmpty) {
          _selectedComponentIndex = null;
        } else if (_selectedComponentIndex! >= _subItems.length) {
          _selectedComponentIndex = _subItems.length - 1;
        }
      }
    });
  }

  Future<bool> _confirmDeleteComponent(int index) async {
    if (index < 0 || index >= _subItems.length) return false;
    final item = _subItems[index];

    final deleted = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          _deleteComponent(index);
          return true;
        },
      ),
    );

    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Component "${item.iCode}" deleted in real time.'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return true;
    }
    return false;
  }


  void _clearAllComponents() {
    if (_subItems.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Components?'),
        content: const Text('Are you sure you want to remove all components from this BOM?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _subItems.clear();
                _selectedComponentIndex = null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Color _getMaterialTypeColor(String type) {
    final t = type.toUpperCase();
    if (t.contains('RAW')) return const Color(0xFFD97706);
    if (t.contains('ACCESS')) return const Color(0xFF7C3AED);
    if (t.contains('PACK')) return const Color(0xFF0D9488);
    if (t.contains('WIP')) return const Color(0xFF2563EB);
    return const Color(0xFF475569);
  }

  Color _getMaterialTypeBg(String type) {
    final t = type.toUpperCase();
    if (t.contains('RAW')) return const Color(0xFFFEF3C7);
    if (t.contains('ACCESS')) return const Color(0xFFF5F3FF);
    if (t.contains('PACK')) return const Color(0xFFF0FDFA);
    if (t.contains('WIP')) return const Color(0xFFEFF6FF);
    return const Color(0xFFF1F5F9);
  }

  Future<void> _submitBomHeader() async {
    if (_isSubmitting) return;

    if (_selectedStrCode == null) {
      _showButtonValidation('Please select Plant / Store!');
      _storeFocusNode.requestFocus();
      return;
    }

    if (_selectedDepCode == null) {
      _showButtonValidation('Please select Department!');
      _deptFocusNode.requestFocus();
      return;
    }

    final code = _materialCodeCtrl.text.trim();
    if (code.isEmpty) {
      _showButtonValidation('Please enter/select Finished Good Material Code!');
      _materialCodeFocusNode.requestFocus();
      return;
    }

    final desc = _descriptionCtrl.text.trim();
    if (desc.isEmpty) {
      _showButtonValidation('Please enter BOM Item Description!');
      _descriptionFocusNode.requestFocus();
      return;
    }

    final qtyVal = double.tryParse(_baseQtyCtrl.text.trim());
    if (qtyVal == null || qtyVal <= 0) {
      _showButtonValidation('Please enter a valid Base Quantity > 0!');
      _qtyFocusNode.requestFocus();
      return;
    }

    if (_selectedUnitCode == null) {
      _showButtonValidation('Please select Unit of Measure (UOM)!');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _buttonValidationMsg = null;
    });

    final currentBomId = _bomIdCtrl.text.trim();
    final header = BomHeaderData(
      bomId: currentBomId,
      depCode: _selectedDepCode!,
      strCode: _selectedStrCode!,
      iCode: code,
      description: desc,
      qty: qtyVal,
      unitCode: _selectedUnitCode!,
      unitName: _selectedUnitName ?? (_units.any((u) => u.unitCode == _selectedUnitCode) ? _units.firstWhere((u) => u.unitCode == _selectedUnitCode).unitName : 'PCS'),
      purpose: 'Costing',
      status: _selectedStatus ?? 'OPEN',
      bomType: _activeMode.label,
      bomDate: _selectedDate,
      bomPo: _poNumberCtrl.text.trim(),
      bomEDate: DateTime.now(),
    );

    final success = await _bomService.saveBom(
      header: header,
      items: _subItems,
    );

    if (mounted) {
      if (success) {
        setState(() {
          _isSubmitting = false;
          _isSaveSuccess = true;
        });

        _triggerEntryGlow(currentBomId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 8),
                Text('BOM $currentBomId successfully registered!'),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 3),
          ),
        );

        // Fetch fresh sequence for next entry
        final nextId = await _bomService.fetchNextBomId(_activeMode);
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 1800), () {
            if (mounted) {
              setState(() {
                _isSaveSuccess = false;
                _bomIdCtrl.text = nextId;
              });
            }
          });
        }
      } else {
        setState(() => _isSubmitting = false);
        _showButtonValidation('Failed to save BOM. Check connection.');
      }
    }
  }

  Future<void> _openShowRecordModal() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BomShowRecordModal(
        bomService: _bomService,
        initialMode: _activeMode,
        recentlySavedId: _glowingBomId,
        glowingBomId: _glowingBomId,
        onSelect: (summary) => _loadRecordDetails(summary.bomId),
        onExport: _openExportModal,
      ),
    );
  }

  Future<void> _loadRecordDetails(String bomId) async {
    try {
      final record = await _bomService.fetchBomDetails(bomId);
      if (record != null && mounted) {
        final h = record.header;
        final targetMode = h.bomType.toUpperCase() == 'JOB' ? BomMode.job : BomMode.regular;

        setState(() {
          _activeMode = targetMode;

          // Header form fields
          _bomIdCtrl.text = h.bomId;
          _selectedDate = h.bomDate;
          _materialCodeCtrl.text = h.iCode;
          _descriptionCtrl.text = h.description;
          _poNumberCtrl.text = h.bomPo;
          _baseQtyCtrl.text = h.qty.toString();
          _selectedStatus = h.status;

          // Store Match
          if (_stores.any((s) => s.strCode == h.strCode)) {
            _selectedStrCode = h.strCode;
          } else if (_stores.isNotEmpty) {
            _selectedStrCode = _stores.first.strCode;
          }

          // Department Match
          if (_departments.any((d) => d.labCode == h.depCode)) {
            _selectedDepCode = h.depCode;
          } else if (_departments.isNotEmpty) {
            _selectedDepCode = _departments.first.labCode;
          }

          // Unit Match
          if (_units.any((u) => u.unitCode == h.unitCode)) {
            _selectedUnitCode = h.unitCode;
            _selectedUnitName = h.unitName;
          } else if (_units.isNotEmpty) {
            _selectedUnitCode = _units.first.unitCode;
            _selectedUnitName = _units.first.unitName;
          }

          // Sub-items Grid Table
          _subItems.clear();
          _subItems.addAll(record.items);
          _selectedComponentIndex = _subItems.isNotEmpty ? 0 : null;
          _buttonValidationMsg = null;
        });

        _triggerEntryGlow(h.bomId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                const SizedBox(width: 8),
                Text('Loaded BOM ${h.bomId} with ${_subItems.length} components.'),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading BOM details: $e');
    }
  }

  Future<void> _openExportModal() async {
    try {
      final records = await _bomService.fetchBomRecords();
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => BomExportModalDialog(records: records),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open export modal: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isAlt = HardwareKeyboard.instance.isAltPressed;
      if (event.logicalKey == LogicalKeyboardKey.f1 || (isAlt && event.logicalKey == LogicalKeyboardKey.keyS)) {
        _submitBomHeader();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        _resetForm();
      } else if (isAlt && (event.logicalKey == LogicalKeyboardKey.keyN || event.logicalKey == LogicalKeyboardKey.keyC)) {
        _resetForm();
      } else if (isAlt && event.logicalKey == LogicalKeyboardKey.keyR) {
        _openShowRecordModal();
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (_selectedComponentIndex != null && _selectedComponentIndex! < _subItems.length) {
          _deleteComponent(_selectedComponentIndex!);
        }
      }
    }
  }

  // --------------------------------------------------------------------------
  // BUILD METHOD (MATCHING MASTER SECTION ARCHITECTURE)
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const modePrimaryColor = Color(0xFF059669);

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
                color: Colors.white.withValues(alpha: 0.88),
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

                    // 2. MAIN DUAL-PANE WORKSPACE (Form & Grid)
                    Expanded(
                      child: _isLoadingLookups
                          ? Center(child: CircularProgressIndicator(color: modePrimaryColor))
                          : _buildDualPaneWorkspace(),
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
  // 1. SCREEN HEADER TOOLBAR (MASTER SCREEN STANDARD)
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
          // BILL OF MATERIAL (BOM) RECEIPT LOGO - DIRECT ON PLAIN WHITE SCREEN
          const _BomHeaderLogoWidget(height: 52),
          const SizedBox(width: 14),

          // TITLE & SUBTITLE
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bill of Material (BOM)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage and configure production item structure',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const Spacer(),

          // CENTER: BOM PROGRESS STEP BAR (JOB vs REGULAR)
          _BomStepProgressBar(
            activeMode: _activeMode,
            onModeChanged: _handleModeChange,
          ),

          const Spacer(),

          // SHOW RECORD LOOKUP BUTTON
          _AnimatedShowRecordButton(onTap: _openShowRecordModal),

          const SizedBox(width: 10),

          // ANIMATED EXPORT BUTTON
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // 2. DUAL-PANE WORKSPACE: LEFT PANE FORM & RIGHT PANE GRID
  // --------------------------------------------------------------------------
  Widget _buildDualPaneWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamically scale Left Pane width so Right Pane table never suffers cell collisions
        final double totalWidth = constraints.maxWidth;
        final double leftPaneWidth = totalWidth > 1500
            ? 410.0
            : totalWidth > 1200
                ? 380.0
                : 350.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Header Form Card (adaptively scaled)
            SizedBox(
              width: leftPaneWidth,
              child: _buildHeaderFormCard(),
            ),

            const SizedBox(width: 12),

            // Right Pane: Sub-Items Grid Table Desk
            Expanded(
              child: _buildSubItemsGridDesk(),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // LEFT PANE: BOM HEADER FORM CARD (COMPACT, DISTINCT COLORS & SLEEK SCROLL)
  // --------------------------------------------------------------------------
  Widget _buildHeaderFormCard() {
    const headerIconColor = Color(0xFF059669);
    const headerIconBg = Color(0xFFECFDF5);
    const headerIconBorder = Color(0xFFA7F3D0);
    final isGlowing = _glowingBomId == _bomIdCtrl.text;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGlowing ? const Color(0xFF34D399) : const Color(0xFFE2E8F0),
          width: isGlowing ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isGlowing ? const Color(0xFF10B981).withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.02),
            blurRadius: isGlowing ? 16 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CARD HEADER
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: headerIconBg,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: headerIconBorder),
                ),
                child: const Icon(Icons.description_rounded, size: 14, color: headerIconColor),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'BOM HEADER DETAILS',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // ID BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  _bomIdCtrl.text.isNotEmpty ? _bomIdCtrl.text : '${_activeMode.prefix}/000001/27',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 7),

          // SCROLLABLE FORM FIELDS BODY WITH PREMIUM FLOATING SCROLLBAR
          Expanded(
            child: _ModernFormScrollBar(
              controller: _formScrollController,
              child: SingleChildScrollView(
                controller: _formScrollController,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. PLANT / STORE DROPDOWN (COLOR 1: ROYAL BLUE)
                      _buildFormFieldCard(
                        title: 'PLANT / STORE',
                        icon: Icons.warehouse_rounded,
                        accentColor: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFFBFDBFE),
                        child: _BomModernDropdown<int>(
                          value: _selectedStrCode,
                          hintText: 'Select Plant / Store...',
                          dropdownTitle: 'PLANT / STORE',
                          titleIcon: Icons.warehouse_rounded,
                          accentColor: const Color(0xFF2563EB),
                          hoverBorderColor: const Color(0xFF93C5FD),
                          focusNode: _storeFocusNode,
                          items: _stores.map((s) {
                            return _BomDropdownItem<int>(
                              value: s.strCode,
                              label: s.strName,
                              subtitle: 'Code: ${s.strCode}',
                              icon: Icons.storefront_rounded,
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStrCode = val);
                          },
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 2. DEPARTMENT DROPDOWN (COLOR 2: VIVID PURPLE)
                      _buildFormFieldCard(
                        title: 'DEPARTMENT',
                        icon: Icons.domain_rounded,
                        accentColor: const Color(0xFF7C3AED),
                        bgColor: const Color(0xFFF5F3FF),
                        borderColor: const Color(0xFFDDD6FE),
                        child: _BomModernDropdown<int>(
                          value: _selectedDepCode,
                          hintText: 'Select Department...',
                          dropdownTitle: 'DEPARTMENT',
                          titleIcon: Icons.domain_rounded,
                          accentColor: const Color(0xFF7C3AED),
                          hoverBorderColor: const Color(0xFFC4B5FD),
                          focusNode: _deptFocusNode,
                          items: _departments.map((d) {
                            return _BomDropdownItem<int>(
                              value: d.labCode,
                              label: d.labName,
                              subtitle: 'Code: ${d.labCode}',
                              icon: Icons.business_center_rounded,
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedDepCode = val);
                          },
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 3. BOM ID & DATE (SPLIT ROW)
                      Row(
                        children: [
                          // FIELD 3A: BOM ID (COLOR 3: SLATE / STEEL GRAPHITE)
                          Expanded(
                            flex: 6,
                            child: _buildFormFieldCard(
                              title: 'BOM ID',
                              icon: Icons.tag_rounded,
                              accentColor: const Color(0xFF475569),
                              bgColor: const Color(0xFFF1F5F9),
                              borderColor: const Color(0xFFCBD5E1),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: const Text(
                                  'Auto',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                ),
                              ),
                              child: SizedBox(
                                height: 28,
                                child: TextField(
                                  controller: _bomIdCtrl,
                                  readOnly: true,
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // FIELD 3B: BOM DATE (COLOR 4: TEAL / CYAN)
                          Expanded(
                            flex: 5,
                            child: _buildFormFieldCard(
                              title: 'DATE',
                              icon: Icons.calendar_today_rounded,
                              accentColor: const Color(0xFF0D9488),
                              bgColor: const Color(0xFFF0FDFA),
                              borderColor: const Color(0xFF99F6E4),
                              child: _BomDateButton(
                                dateText: _formatDate(_selectedDate),
                                onTap: _pickDate,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // 4. FINISHED GOOD MATERIAL CODE (COLOR 5: DEEP INDIGO)
                      _buildFormFieldCard(
                        title: 'FINISHED GOOD MATERIAL CODE',
                        icon: Icons.qr_code_2_rounded,
                        accentColor: const Color(0xFF4338CA),
                        bgColor: const Color(0xFFEEF2FF),
                        borderColor: const Color(0xFFC7D2FE),
                        child: SizedBox(
                          height: 28,
                          child: TextField(
                            controller: _materialCodeCtrl,
                            focusNode: _materialCodeFocusNode,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Click [...] to select Finished Good',
                              hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)), borderSide: BorderSide(color: Color(0xFF4338CA), width: 1.5)),
                              suffixIcon: Tooltip(
                                message: 'Open Finished Goods Lookup (SKU: ${_activeMode.skuCross})',
                                child: _BomLookupEllipsisButton(
                                  onTap: _openFinishedGoodLookup,
                                  accentColor: const Color(0xFF4338CA),
                                  bgColor: const Color(0xFFEEF2FF),
                                  borderColor: const Color(0xFFC7D2FE),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 5. DESCRIPTION (COLOR 6: SKY BLUE)
                      _buildFormFieldCard(
                        title: 'DESCRIPTION',
                        icon: Icons.subtitles_rounded,
                        accentColor: const Color(0xFF0284C7),
                        bgColor: const Color(0xFFF0F9FF),
                        borderColor: const Color(0xFFBAE6FD),
                        child: SizedBox(
                          height: 28,
                          child: TextField(
                            controller: _descriptionCtrl,
                            focusNode: _descriptionFocusNode,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Item description / title',
                              hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)), borderSide: BorderSide(color: Color(0xFF0284C7), width: 1.5)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // 6. PO # & STATUS (SPLIT ROW)
                      Row(
                        children: [
                          // FIELD 6A: PO # (COLOR 7: WARM AMBER)
                          Expanded(
                            flex: 6,
                            child: _buildFormFieldCard(
                              title: 'PO #',
                              icon: Icons.receipt_long_rounded,
                              accentColor: const Color(0xFFD97706),
                              bgColor: const Color(0xFFFFFBEB),
                              borderColor: const Color(0xFFFDE68A),
                              child: SizedBox(
                                height: 28,
                                child: TextField(
                                  controller: _poNumberCtrl,
                                  focusNode: _poFocusNode,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'Customer PO #',
                                    hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)), borderSide: BorderSide(color: Color(0xFFD97706), width: 1.5)),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // FIELD 6B: STATUS (COLOR 8: EMERALD / CRIMSON)
                          Expanded(
                            flex: 5,
                            child: _buildFormFieldCard(
                              title: 'STATUS',
                              icon: Icons.toggle_on_rounded,
                              accentColor: _selectedStatus == 'OPEN'
                                  ? const Color(0xFF059669)
                                  : (_selectedStatus == 'BLOCKED' ? const Color(0xFFDC2626) : const Color(0xFF0D9488)),
                              bgColor: _selectedStatus == 'OPEN'
                                  ? const Color(0xFFECFDF5)
                                  : (_selectedStatus == 'BLOCKED' ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA)),
                              borderColor: _selectedStatus == 'OPEN'
                                  ? const Color(0xFFA7F3D0)
                                  : (_selectedStatus == 'BLOCKED' ? const Color(0xFFFECACA) : const Color(0xFF99F6E4)),
                              child: _BomModernDropdown<String>(
                                value: _selectedStatus,
                                hintText: 'Select Status...',
                                dropdownTitle: 'STATUS',
                                titleIcon: Icons.toggle_on_rounded,
                                height: 28,
                                accentColor: _selectedStatus == 'OPEN'
                                    ? const Color(0xFF059669)
                                    : (_selectedStatus == 'BLOCKED' ? const Color(0xFFDC2626) : const Color(0xFF0D9488)),
                                hoverBorderColor: _selectedStatus == 'OPEN'
                                    ? const Color(0xFFA7F3D0)
                                    : (_selectedStatus == 'BLOCKED' ? const Color(0xFFFECACA) : const Color(0xFF5EEAD4)),
                                items: const [
                                  _BomDropdownItem<String>(
                                    value: 'OPEN',
                                    label: 'OPEN',
                                    subtitle: 'Active BOM',
                                    icon: Icons.check_circle_outline_rounded,
                                    iconColor: Color(0xFF059669),
                                    badgeColor: Color(0xFFECFDF5),
                                  ),
                                  _BomDropdownItem<String>(
                                    value: 'BLOCKED',
                                    label: 'BLOCKED',
                                    subtitle: 'Locked / Hold',
                                    icon: Icons.block_rounded,
                                    iconColor: Color(0xFFDC2626),
                                    badgeColor: Color(0xFFFEF2F2),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStatus = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // 7. BASE QTY & UNIT (SPLIT ROW)
                      Row(
                        children: [
                          // FIELD 7A: BASE QTY (COLOR 9: CORAL ORANGE)
                          Expanded(
                            flex: 5,
                            child: _buildFormFieldCard(
                              title: 'BASE QTY',
                              icon: Icons.pin_outlined,
                              accentColor: const Color(0xFFEA580C),
                              bgColor: const Color(0xFFFFF7ED),
                              borderColor: const Color(0xFFFED7AA),
                              child: SizedBox(
                                height: 28,
                                child: TextField(
                                  controller: _baseQtyCtrl,
                                  focusNode: _qtyFocusNode,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: '0.0',
                                    hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)), borderSide: BorderSide(color: Color(0xFFEA580C), width: 1.5)),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          // FIELD 7B: UNIT / UOM PICKER (COLOR 10: SKY BLUE MATCHING NON-STOCKABLE ITEM MASTER)
                          Expanded(
                            flex: 6,
                            child: _buildFormFieldCard(
                              title: 'UNIT (UOM)',
                              icon: Icons.scale_rounded,
                              accentColor: const Color(0xFF0284C7),
                              bgColor: const Color(0xFFF0F9FF),
                              borderColor: const Color(0xFFBAE6FD),
                              child: _BomUnitTriggerButton(
                                selectedUnitName: _selectedUnitName,
                                onTap: _showCoolUnitPickerModal,
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

          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // FORM ACTION BUTTONS (COMPACT RESET & GREEN SAVE BUTTON)
          Row(
            children: [
              _buildResetButton(),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSaveButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // FORM FIELD CARD BUILDER (COMPACT, DISTINCT PALETTE, OPTIONAL TRAILING)
  // --------------------------------------------------------------------------
  Widget _buildFormFieldCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(icon, size: 10.5, color: accentColor),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                    letterSpacing: 0.25,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 3.5),
          child,
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RESET BUTTON (COMPACT WITH SPIN MICRO-ANIMATION)
  // --------------------------------------------------------------------------
  Widget _buildResetButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 30,
      child: OutlinedButton.icon(
        onPressed: _resetForm,
        icon: AnimatedRotation(
          turns: _isResetting ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF475569)),
        ),
        label: Text(
          _isResetting ? 'Resetting...' : 'Reset (Esc)',
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
          side: BorderSide(color: _isResetting ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
          backgroundColor: _isResetting ? const Color(0xFFEFF6FF) : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // GLOWING COMPACT SAVE BUTTON (GREEN ONLY, MICRO VALIDATION PILL)
  // --------------------------------------------------------------------------
  Widget _buildSaveButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_buttonValidationMsg != null) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
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
                const Icon(Icons.error_outline_rounded, size: 10, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _buttonValidationMsg!,
                    style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        _BomAnimatedSuccessButton(
          status: _isSubmitting
              ? ButtonStatus.loading
              : (_isSaveSuccess ? ButtonStatus.success : ButtonStatus.idle),
          onPressed: _submitBomHeader,
          idleText: 'Save BOM (F1)',
          loadingText: 'Saving BOM...',
          successText: 'BOM Saved!',
          idleIcon: Icons.save_rounded,
          idleBackgroundColor: AppColors.secondaryColor,
          successBackgroundColor: const Color(0xFF10B981),
          height: 30,
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // RIGHT PANE: SUB-ITEMS GRID TABLE DESK SKELETON (READY FOR PART 3)
  // --------------------------------------------------------------------------
  Widget _buildSubItemsGridDesk() {
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOOLBAR HEADER
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Icon(Icons.table_chart_rounded, size: 15, color: Color(0xFF16A34A)),
              ),
              const SizedBox(width: 8),
              const Text(
                'BOM SUB-ITEMS & COMPONENTS',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  '${_subItems.length} Components',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
              ),

              const Spacer(),

              // ACTION BUTTON: DUPLICATE ROW (WHEN ROW SELECTED)
              if (_selectedComponentIndex != null && _selectedComponentIndex! < _subItems.length) ...[
                OutlinedButton.icon(
                  onPressed: () => _duplicateComponent(_selectedComponentIndex!),
                  icon: const Icon(Icons.copy_rounded, size: 13, color: Color(0xFF2563EB)),
                  label: const Text('Duplicate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFBFDBFE)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // ACTION BUTTON: CLEAR ALL
              if (_subItems.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _clearAllComponents,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 13, color: Color(0xFF64748B)),
                  label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // 2. MAIN COMPONENT TABLE (EMPTY STATE vs DATA GRID)
          Expanded(
            child: _subItems.isEmpty
                ? _buildEmptyComponentsState()
                : _buildComponentsDataGrid(),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // 3. SUMMARY TOTALS FOOTER BAR
          _buildComponentsSummaryFooter(),
        ],
      ),
    );
  }

  Widget _buildEmptyComponentsState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.table_chart_outlined, size: 28, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          const Text(
            'No Sub-Items or Components Loaded',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Load a BOM record using "Show Record" above to view components',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentsDataGrid() {
    return Column(
      children: [
        // TABLE HEADER ROW (FITS 100% WIDTH, ZERO HORIZONTAL SCROLL)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              SizedBox(width: 36, child: Text('SR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              SizedBox(width: 95, child: Text('MATERIAL TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              SizedBox(width: 140, child: Text('MATERIAL CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              Expanded(child: Text('MATERIAL DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              SizedBox(width: 65, child: Text('CONS.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              SizedBox(width: 85, child: Text('NET QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
              SizedBox(width: 60, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // TABLE BODY (SCROLLABLE ROWS)
        Expanded(
          child: ListView.builder(
            controller: _verticalTableController,
            itemCount: _subItems.length,
            itemBuilder: (context, index) {
              final item = _subItems[index];
              final isSelected = index == _selectedComponentIndex;

              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFEFF6FF)
                      : (index.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedComponentIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Row(
                      children: [
                        // SR NO
                        SizedBox(
                          width: 36,
                          child: Text(
                            item.bomsCode,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),

                        // MATERIAL TYPE BADGE
                        SizedBox(
                          width: 95,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getMaterialTypeBg(item.materialType),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.materialType.isNotEmpty ? item.materialType : 'GENERAL',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: _getMaterialTypeColor(item.materialType),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),

                        // MATERIAL CODE
                        SizedBox(
                          width: 140,
                          child: Text(
                            item.iCode,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // DESCRIPTION
                        Expanded(
                          child: Tooltip(
                            message: item.description,
                            child: Text(
                              item.description,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),

                        // CONSUMPTION
                        SizedBox(
                          width: 65,
                          child: Text(
                            item.bomCons.toStringAsFixed(2),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                          ),
                        ),

                        // NET QTY
                        SizedBox(
                          width: 85,
                          child: Text(
                            '${item.qty.toStringAsFixed(2)} ${item.unitName}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                          ),
                        ),

                        // ACTION (DELETE ONLY, MATCHING PROJECT MASTER SCREEN)
                        SizedBox(
                          width: 60,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: _ActionIconButton(
                                icon: Icons.delete_outline_rounded,
                                color: const Color(0xFFEF4444),
                                hoverBg: const Color(0xFFFEF2F2),
                                tooltip: 'Delete Component',
                                onPressed: () => _confirmDeleteComponent(index),
                              ),
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
        ),
      ],
    );
  }

  Widget _buildComponentsSummaryFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, size: 14, color: Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(
            '${_subItems.length} Sub-Item(s)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
          ),
          const SizedBox(width: 10),

          // ZOOM IN BUTTON (FULL DETAIL MODAL)
          OutlinedButton.icon(
            onPressed: _subItems.isEmpty ? null : _showFullDetailZoomModal,
            icon: const Icon(Icons.zoom_in_rounded, size: 14, color: Color(0xFF0F172A)),
            label: const Text(
              'Zoom In (Full Detail)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
            ),
          ),

          const Spacer(),

          // TOTAL CONSUMPTION
          _buildSummaryPill(
            label: 'TOTAL CONS',
            value: _totalConsumption.toStringAsFixed(2),
            color: const Color(0xFF2563EB),
            bgColor: const Color(0xFFEFF6FF),
          ),
          const SizedBox(width: 8),

          // TOTAL TOLERANCE QTY
          _buildSummaryPill(
            label: 'TOTAL TOL',
            value: _totalToleranceQty.toStringAsFixed(2),
            color: const Color(0xFFD97706),
            bgColor: const Color(0xFFFEF3C7),
          ),
          const SizedBox(width: 8),

          // TOTAL NET QTY
          _buildSummaryPill(
            label: 'NET QTY',
            value: _totalNetQty.toStringAsFixed(2),
            color: const Color(0xFF059669),
            bgColor: const Color(0xFFECFDF5),
          ),
        ],
      ),
    );
  }

  void _showFullDetailZoomModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final ScrollController modalHorizCtrl = ScrollController();
        final ScrollController modalVertCtrl = ScrollController();

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                width: math.min(1540.0, MediaQuery.of(modalContext).size.width * 0.96),
                height: math.min(820.0, MediaQuery.of(modalContext).size.height * 0.90),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // MODAL HEADER
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: const Icon(Icons.fullscreen_rounded, size: 18, color: Color(0xFF059669)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'BOM SUB-ITEMS & COMPONENTS — FULL DETAIL VIEW',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'BOM ID: ${_bomIdCtrl.text.isNotEmpty ? _bomIdCtrl.text : "N/A"}  •  FG: ${_materialCodeCtrl.text.isNotEmpty ? _materialCodeCtrl.text : "N/A"} (${_descriptionCtrl.text.isNotEmpty ? _descriptionCtrl.text : ""})',
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              '${_subItems.length} Sub-Items Loaded',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            tooltip: 'Close (Esc)',
                          ),
                        ],
                      ),
                    ),

                    // MODAL TABLE (SPACIOUS 15 COLUMNS WITH ZERO COLLISIONS)
                    Expanded(
                      child: Scrollbar(
                        controller: modalHorizCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: modalHorizCtrl,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: 1600,
                            child: Column(
                              children: [
                                // TABLE HEADER
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: const Row(
                                    children: [
                                      SizedBox(width: 40, child: Text('SR', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 115, child: Text('MATERIAL TYPE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 165, child: Text('MATERIAL CODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 250, child: Text('MATERIAL DESCRIPTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 70, child: Text('SQM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 80, child: Text('CONS.', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 85, child: Text('TOL (+/- %)', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 85, child: Text('TOL QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 90, child: Text('TOTAL QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 65, child: Text('UOM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 70, child: Text('CONV', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 75, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 85, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 155, child: Text('REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                      SizedBox(width: 65, child: Text('ACTION', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                                    ],
                                  ),
                                ),

                                // TABLE ROWS
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: ListView.builder(
                                      controller: modalVertCtrl,
                                      itemCount: _subItems.length,
                                      itemBuilder: (ctx, idx) {
                                        final row = _subItems[idx];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: idx.isEven ? Colors.white : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(width: 40, child: Text(row.bomsCode, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569)))),
                                              SizedBox(
                                                width: 115,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: _getMaterialTypeBg(row.materialType),
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                    child: Text(
                                                      row.materialType.isNotEmpty ? row.materialType : 'GENERAL',
                                                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _getMaterialTypeColor(row.materialType)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 165, child: Text(row.iCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                                              SizedBox(width: 250, child: Text(row.description, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                              SizedBox(width: 70, child: Text(row.sqm > 0 ? row.sqm.toStringAsFixed(2) : '-', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                              SizedBox(width: 80, child: Text(row.bomCons.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                                              SizedBox(width: 85, child: Text('${row.bomExtra.toStringAsFixed(1)}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                              SizedBox(width: 85, child: Text(row.bomTolQty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))),
                                              SizedBox(width: 90, child: Text(row.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)))),
                                              SizedBox(
                                                width: 65,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                                    ),
                                                    child: Text(row.unitName, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 70, child: Text(row.convQty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                              SizedBox(width: 75, child: Text(row.bomRate.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                              SizedBox(width: 85, child: Text(row.bomAmount.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
                                              SizedBox(width: 155, child: Text(row.bomRemarks.isNotEmpty ? row.bomRemarks : '-', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                                              // ACTION (DELETE ONLY, MATCHING PROJECT MASTER SCREEN)
                                              SizedBox(
                                                width: 65,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(10),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black.withValues(alpha: 0.02),
                                                          blurRadius: 4,
                                                          offset: const Offset(0, 1),
                                                        ),
                                                      ],
                                                    ),
                                                    child: _ActionIconButton(
                                                      icon: Icons.delete_outline_rounded,
                                                      color: const Color(0xFFEF4444),
                                                      hoverBg: const Color(0xFFFEF2F2),
                                                      tooltip: 'Delete Component',
                                                      onPressed: () async {
                                                        final deleted = await _confirmDeleteComponent(idx);
                                                        if (deleted == true) {
                                                          setModalState(() {});
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // MODAL FOOTER
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.insights_rounded, size: 15, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Text('${_subItems.length} Total Sub-Items', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))),
                          const Spacer(),
                          _buildSummaryPill(
                            label: 'TOTAL CONS',
                            value: _totalConsumption.toStringAsFixed(2),
                            color: const Color(0xFF2563EB),
                            bgColor: const Color(0xFFEFF6FF),
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryPill(
                            label: 'TOTAL TOL',
                            value: _totalToleranceQty.toStringAsFixed(2),
                            color: const Color(0xFFD97706),
                            bgColor: const Color(0xFFFEF3C7),
                          ),
                          const SizedBox(width: 8),
                          _buildSummaryPill(
                            label: 'NET QTY',
                            value: _totalNetQty.toStringAsFixed(2),
                            color: const Color(0xFF059669),
                            bgColor: const Color(0xFFECFDF5),
                          ),
                          const SizedBox(width: 14),
                          ElevatedButton(
                            onPressed: () => Navigator.of(modalContext).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Close View', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
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

  Widget _buildSummaryPill({
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PREMIUM FLOATING SCROLLBAR & SMOOTH MOUSE WHEEL WRAPPER
// ============================================================================
class _ModernFormScrollBar extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const _ModernFormScrollBar({
    required this.controller,
    required this.child,
  });

  @override
  State<_ModernFormScrollBar> createState() => _ModernFormScrollBarState();
}

class _ModernFormScrollBarState extends State<_ModernFormScrollBar> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _dragStartY = 0.0;
  double _scrollStartOffset = 0.0;
  double _futurePosition = 0.0;
  bool _isAnimating = false;

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        widget.controller.hasClients &&
        widget.controller.position.hasContentDimensions) {
      GestureBinding.instance.pointerSignalResolver.register(event, (resolvedEvent) {
        final scrollEvent = resolvedEvent as PointerScrollEvent;
        final position = widget.controller.position;
        final currentOffset = widget.controller.offset;

        double base = _isAnimating ? _futurePosition : currentOffset;
        if ((base - currentOffset).abs() > 250.0) {
          base = currentOffset;
        }

        final target = (base + scrollEvent.scrollDelta.dy * 0.85).clamp(
          0.0,
          position.maxScrollExtent,
        );

        _futurePosition = target;
        _isAnimating = true;

        widget.controller.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (mounted) {
            _isAnimating = false;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Listener(
        onPointerSignal: _handlePointerSignal,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;

            return Stack(
              children: [
                // Scrollable Form Content with clean right margin
                Positioned.fill(
                  right: 12,
                  child: widget.child,
                ),

                // Modern Floating Scrollbar Track & Thumb
                Positioned(
                  top: 2,
                  bottom: 2,
                  right: 0,
                  width: 8,
                  child: AnimatedBuilder(
                    animation: widget.controller,
                    builder: (context, child) {
                      if (!widget.controller.hasClients || !widget.controller.position.hasContentDimensions) {
                        return const SizedBox.shrink();
                      }

                      final pos = widget.controller.position;
                      final maxScroll = pos.maxScrollExtent;
                      if (maxScroll <= 0) return const SizedBox.shrink();

                      final trackHeight = totalHeight - 4;
                      final viewport = pos.viewportDimension;
                      final totalContent = viewport + maxScroll;

                      // Proportional thumb height clamped between 32px and 80%
                      final rawThumbHeight = (viewport / totalContent) * trackHeight;
                      final thumbHeight = rawThumbHeight.clamp(32.0, trackHeight * 0.80);

                      // Current thumb position
                      final scrollProgress = (widget.controller.offset / maxScroll).clamp(0.0, 1.0);
                      final maxThumbTop = trackHeight - thumbHeight;
                      final thumbTop = scrollProgress * maxThumbTop;

                      final isActive = _isHovered || _isDragging;

                      return MouseRegion(
                        onEnter: (_) => setState(() => _isHovered = true),
                        onExit: (_) => setState(() => _isHovered = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: (details) {
                            setState(() => _isDragging = true);
                            _dragStartY = details.globalPosition.dy;
                            _scrollStartOffset = widget.controller.offset;
                          },
                          onVerticalDragUpdate: (details) {
                            if (maxThumbTop <= 0) return;
                            final deltaY = details.globalPosition.dy - _dragStartY;
                            final deltaProgress = deltaY / maxThumbTop;
                            final targetOffset = (_scrollStartOffset + deltaProgress * maxScroll).clamp(0.0, maxScroll);
                            widget.controller.jumpTo(targetOffset);
                          },
                          onVerticalDragEnd: (_) {
                            setState(() => _isDragging = false);
                          },
                          onVerticalDragCancel: () {
                            setState(() => _isDragging = false);
                          },
                          child: Container(
                            alignment: Alignment.topCenter,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFF1F5F9) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: thumbTop,
                                  left: isActive ? 1 : 2,
                                  right: isActive ? 1 : 2,
                                  height: thumbHeight,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      gradient: isActive
                                          ? const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFF64748B),
                                                Color(0xFF475569),
                                              ],
                                            )
                                          : const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Color(0xFFCBD5E1),
                                                Color(0xFF94A3B8),
                                              ],
                                            ),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: isActive
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF475569).withValues(alpha: 0.28),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN FLOATING POPOVER DROPDOWN ARCHITECTURE
// ============================================================================

class _BomDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? badgeColor;

  const _BomDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.badgeColor,
  });
}

class _BomModernDropdown<T> extends StatefulWidget {
  final T? value;
  final String hintText;
  final String dropdownTitle;
  final IconData? titleIcon;
  final List<_BomDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FocusNode? focusNode;
  final Color accentColor;
  final Color hoverBorderColor;
  final double height;
  final bool enableSearch;

  const _BomModernDropdown({
    super.key,
    required this.value,
    required this.hintText,
    required this.dropdownTitle,
    this.titleIcon,
    required this.items,
    required this.onChanged,
    this.focusNode,
    this.accentColor = const Color(0xFF2563EB),
    this.hoverBorderColor = const Color(0xFF93C5FD),
    this.height = 28,
    this.enableSearch = false,
  });

  @override
  State<_BomModernDropdown<T>> createState() => _BomModernDropdownState<T>();
}

class _BomModernDropdownState<T> extends State<_BomModernDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _isHovered = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _chevronAnim;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeOutBack,
      ),
    );
    _chevronAnim = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _BomModernDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && _overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isOpen && _overlayEntry != null && mounted) {
          _overlayEntry!.markNeedsBuild();
        }
      });
    }
  }

  @override
  void dispose() {
    _closeMenu(instant: true);
    _animCtrl.dispose();
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    if (_isOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    if (widget.items.isEmpty) return;
    _closeMenu(instant: true);

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - (offset.dy + size.height);

    final bool showSearch = widget.enableSearch || widget.items.length > 5;
    final double headerHeight = 34.0;
    final double searchHeight = showSearch ? 38.0 : 0.0;
    final double itemHeight = 34.0;
    final double totalItemsHeight = widget.items.length * itemHeight;
    const double maxMenuHeight = 240.0;
    final double calculatedHeight = math.min(
      headerHeight + searchHeight + totalItemsHeight + 10.0,
      maxMenuHeight,
    );

    final bool openUpwards = spaceBelow < (calculatedHeight + 12) && offset.dy > calculatedHeight;
    final double offsetY = openUpwards ? -(calculatedHeight + 4) : (size.height + 4);

    final double menuWidth = math.max(size.width, 220.0);
    final double horizontalOffset =
        (offset.dx + menuWidth > screenSize.width - 16) ? -(menuWidth - size.width) : 0.0;

    _searchCtrl.clear();

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return _BomDropdownMenuContent<T>(
          layerLink: _layerLink,
          offsetY: offsetY,
          horizontalOffset: horizontalOffset,
          width: menuWidth,
          openUpwards: openUpwards,
          fadeAnim: _fadeAnim,
          scaleAnim: _scaleAnim,
          maxMenuHeight: maxMenuHeight,
          title: widget.dropdownTitle,
          titleIcon: widget.titleIcon,
          accentColor: widget.accentColor,
          items: widget.items,
          selectedValue: widget.value,
          showSearch: showSearch,
          searchCtrl: _searchCtrl,
          scrollController: _scrollController,
          onDismiss: _closeMenu,
          onSelect: (val) {
            _closeMenu();
            widget.onChanged?.call(val);
          },
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
    _animCtrl.forward(from: 0.0);
  }

  void _closeMenu({bool instant = false}) {
    if (!_isOpen && _overlayEntry == null) return;
    setState(() => _isOpen = false);
    if (instant) {
      if (_overlayEntry != null) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
      _animCtrl.value = 0.0;
    } else {
      _animCtrl.reverse().then((_) {
        if (_overlayEntry != null) {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _BomDropdownItem<T>? selectedItem;
    if (widget.value != null) {
      for (final it in widget.items) {
        if (it.value == widget.value) {
          selectedItem = it;
          break;
        }
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleMenu,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _isOpen
                  ? widget.accentColor.withValues(alpha: 0.04)
                  : (_isHovered ? const Color(0xFFF8FAFC) : Colors.white),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: _isOpen
                    ? widget.accentColor
                    : (_isHovered ? widget.hoverBorderColor : const Color(0xFFCBD5E1)),
                width: _isOpen ? 1.4 : (_isHovered ? 1.2 : 1.0),
              ),
              boxShadow: _isOpen
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.16),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null),
            ),
            child: Row(
              children: [
                if (selectedItem != null) ...[
                  if (selectedItem.icon != null) ...[
                    Icon(
                      selectedItem.icon,
                      size: 13,
                      color: selectedItem.iconColor ?? widget.accentColor,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Expanded(
                    child: Text(
                      selectedItem.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      widget.hintText,
                      style: const TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                RotationTransition(
                  turns: _chevronAnim,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 17,
                    color: _isOpen || _isHovered ? widget.accentColor : const Color(0xFF64748B),
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

class _BomDropdownMenuContent<T> extends StatefulWidget {
  final LayerLink layerLink;
  final double offsetY;
  final double horizontalOffset;
  final double width;
  final bool openUpwards;
  final Animation<double> fadeAnim;
  final Animation<double> scaleAnim;
  final double maxMenuHeight;
  final String title;
  final IconData? titleIcon;
  final Color accentColor;
  final List<_BomDropdownItem<T>> items;
  final T? selectedValue;
  final bool showSearch;
  final TextEditingController searchCtrl;
  final ScrollController scrollController;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelect;

  const _BomDropdownMenuContent({
    super.key,
    required this.layerLink,
    required this.offsetY,
    required this.horizontalOffset,
    required this.width,
    required this.openUpwards,
    required this.fadeAnim,
    required this.scaleAnim,
    required this.maxMenuHeight,
    required this.title,
    this.titleIcon,
    required this.accentColor,
    required this.items,
    required this.selectedValue,
    required this.showSearch,
    required this.searchCtrl,
    required this.scrollController,
    required this.onDismiss,
    required this.onSelect,
  });

  @override
  State<_BomDropdownMenuContent<T>> createState() => _BomDropdownMenuContentState<T>();
}

class _BomDropdownMenuContentState<T> extends State<_BomDropdownMenuContent<T>> {
  String _filter = '';

  @override
  void initState() {
    super.initState();
    widget.searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    widget.searchCtrl.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {
        _filter = widget.searchCtrl.text.trim().toLowerCase();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((it) {
      if (_filter.isEmpty) return true;
      final matchLabel = it.label.toLowerCase().contains(_filter);
      final matchSub = it.subtitle?.toLowerCase().contains(_filter) ?? false;
      return matchLabel || matchSub;
    }).toList();

    return Stack(
      children: [
        // Barrier to dismiss when clicking outside
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => widget.onDismiss(),
            child: const SizedBox.expand(),
          ),
        ),

        // Positioned Dropdown Menu with entrance animation
        Positioned(
          width: widget.width,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: Offset(widget.horizontalOffset, widget.offsetY),
            child: FadeTransition(
              opacity: widget.fadeAnim,
              child: ScaleTransition(
                scale: widget.scaleAnim,
                alignment: widget.openUpwards ? Alignment.bottomCenter : Alignment.topCenter,
                child: Material(
                  elevation: 16,
                  shadowColor: const Color(0xFF0F172A).withValues(alpha: 0.18),
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: widget.maxMenuHeight),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3.5),
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Icon(
                                  widget.titleIcon ?? Icons.format_list_bulleted_rounded,
                                  size: 11,
                                  color: widget.accentColor,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  widget.title.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                    letterSpacing: 0.6,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${widget.items.length} ${widget.items.length == 1 ? "Option" : "Options"}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Optional Search Bar
                        if (widget.showSearch)
                          Container(
                            height: 28,
                            margin: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.search_rounded, size: 13, color: Color(0xFF94A3B8)),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: widget.searchCtrl,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    decoration: const InputDecoration(
                                      hintText: 'Filter options...',
                                      hintStyle: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                                if (widget.searchCtrl.text.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => widget.searchCtrl.clear(),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.close_rounded, size: 12, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Scrollable List of Options
                        Flexible(
                          child: filtered.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.search_off_rounded, size: 20, color: Color(0xFF94A3B8)),
                                      SizedBox(height: 4),
                                      Text(
                                        'No matching options',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : RawScrollbar(
                                  controller: widget.scrollController,
                                  thumbVisibility: true,
                                  interactive: true,
                                  thickness: 4,
                                  radius: const Radius.circular(4),
                                  thumbColor: const Color(0xFF94A3B8),
                                  trackVisibility: true,
                                  trackColor: const Color(0xFFF1F5F9),
                                  trackRadius: const Radius.circular(4),
                                  trackBorderColor: Colors.transparent,
                                  padding: const EdgeInsets.only(right: 2, top: 2, bottom: 2),
                                  minThumbLength: 24,
                                  pressDuration: Duration.zero,
                                  child: Listener(
                                    onPointerSignal: (pointerSignal) {
                                      if (pointerSignal is PointerScrollEvent &&
                                          widget.scrollController.hasClients &&
                                          widget.scrollController.position.hasContentDimensions) {
                                        GestureBinding.instance.pointerSignalResolver.register(pointerSignal, (event) {
                                          final scrollEvent = event as PointerScrollEvent;
                                          final currentOffset = widget.scrollController.offset;
                                          final maxOffset = widget.scrollController.position.maxScrollExtent;
                                          final targetOffset =
                                              (currentOffset + scrollEvent.scrollDelta.dy * 0.75).clamp(0.0, maxOffset);
                                          widget.scrollController.animateTo(
                                            targetOffset,
                                            duration: const Duration(milliseconds: 140),
                                            curve: Curves.easeOutCubic,
                                          );
                                        });
                                      }
                                    },
                                    child: ListView.builder(
                                      controller: widget.scrollController,
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      itemCount: filtered.length,
                                      itemBuilder: (ctx, index) {
                                        final item = filtered[index];
                                        final isSelected = widget.selectedValue == item.value;
                                        return _BomDropdownOptionTile<T>(
                                          item: item,
                                          isSelected: isSelected,
                                          accentColor: widget.accentColor,
                                          onTap: () => widget.onSelect(item.value),
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
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BomDropdownOptionTile<T> extends StatefulWidget {
  final _BomDropdownItem<T> item;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _BomDropdownOptionTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_BomDropdownOptionTile<T>> createState() => _BomDropdownOptionTileState<T>();
}

class _BomDropdownOptionTileState<T> extends State<_BomDropdownOptionTile<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;
    final accent = widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : (_isHovered ? accent.withValues(alpha: 0.07) : Colors.transparent),
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: accent.withValues(alpha: 0.3), width: 1.0)
                : (_isHovered
                    ? Border.all(color: accent.withValues(alpha: 0.15), width: 1.0)
                    : Border.all(color: Colors.transparent, width: 1.0)),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent
                      : (_isHovered ? accent.withValues(alpha: 0.4) : Colors.transparent),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              if (item.icon != null) ...[
                Container(
                  width: 19,
                  height: 19,
                  decoration: BoxDecoration(
                    color: item.badgeColor ??
                        (isSelected
                            ? accent.withValues(alpha: 0.15)
                            : (_isHovered
                                ? accent.withValues(alpha: 0.10)
                                : const Color(0xFFF1F5F9))),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    item.icon,
                    size: 11.5,
                    color: item.iconColor ??
                        (isSelected ? accent : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : (_isHovered ? FontWeight.w700 : FontWeight.w600),
                        color: isSelected ? accent : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: accent,
                  ),
                )
              else if (_isHovered)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 9,
                  color: accent.withValues(alpha: 0.6),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BomDateButton extends StatefulWidget {
  final String dateText;
  final VoidCallback onTap;

  const _BomDateButton({
    required this.dateText,
    required this.onTap,
  });

  @override
  State<_BomDateButton> createState() => _BomDateButtonState();
}

class _BomDateButtonState extends State<_BomDateButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF0FDFA) : Colors.white,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _isHovered ? const Color(0xFF5EEAD4) : const Color(0xFFCBD5E1),
              width: _isHovered ? 1.3 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.dateText,
                  style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.edit_calendar_rounded,
                size: 13,
                color: _isHovered ? const Color(0xFF0F766E) : const Color(0xFF0D9488),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STATEFUL HOVERABLE UNIT PICKER BUTTON (NON-STOCKABLE ITEM MASTER PARITY)
// ============================================================================
class _BomUnitTriggerButton extends StatefulWidget {
  final String? selectedUnitName;
  final VoidCallback onTap;

  const _BomUnitTriggerButton({
    required this.selectedUnitName,
    required this.onTap,
  });

  @override
  State<_BomUnitTriggerButton> createState() => _BomUnitTriggerButtonState();
}

class _BomUnitTriggerButtonState extends State<_BomUnitTriggerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasUnit = widget.selectedUnitName != null && widget.selectedUnitName!.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: _isHovered ? const Color(0xFF0284C7) : const Color(0xFF0284C7).withValues(alpha: 0.4),
              width: _isHovered ? 1.3 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      blurRadius: 5,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                _getUnitIcon(widget.selectedUnitName ?? ''),
                size: 14,
                color: const Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasUnit ? widget.selectedUnitName! : 'Select Unit...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: hasUnit ? FontWeight.w700 : FontWeight.w500,
                    color: hasUnit ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: Color(0xFF0284C7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STATEFUL HOVERABLE UNIT OPTION PICKER CARD (FROM NON-STOCKABLE ITEM MASTER)
// ============================================================================
class _UnitOptionHoverCard extends StatefulWidget {
  final String unitName;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _UnitOptionHoverCard({
    required this.unitName,
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
                  widget.unitName,
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

class _BomLookupEllipsisButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color accentColor;
  final Color bgColor;
  final Color borderColor;

  const _BomLookupEllipsisButton({
    required this.onTap,
    required this.accentColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  State<_BomLookupEllipsisButton> createState() => _BomLookupEllipsisButtonState();
}

class _BomLookupEllipsisButtonState extends State<_BomLookupEllipsisButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isHovered ? widget.accentColor.withValues(alpha: 0.15) : widget.bgColor,
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
            border: Border(left: BorderSide(color: widget.borderColor)),
          ),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 16,
            color: _isHovered ? widget.accentColor : widget.accentColor.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WITH PULSING GLOW EFFECT
// ============================================================================
class _BomAnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const _BomAnimatedSuccessButton({
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
  State<_BomAnimatedSuccessButton> createState() => _BomAnimatedSuccessButtonState();
}

class _BomAnimatedSuccessButtonState extends State<_BomAnimatedSuccessButton> with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _glowAnimation = Tween<double>(begin: 4.0, end: 18.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.status == ButtonStatus.success) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _BomAnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.success && oldWidget.status != ButtonStatus.success) {
      _glowController.repeat(reverse: true);
    } else if (widget.status != ButtonStatus.success && oldWidget.status == ButtonStatus.success) {
      _glowController.stop();
      _glowController.reset();
    }
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
                mainAxisSize: MainAxisSize.min,
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
                  Flexible(
                    child: Text(
                      isLoading ? widget.loadingText : (isSuccess ? widget.successText : widget.idleText),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
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

// ============================================================================
// 100% IDENTICAL BILL OF MATERIAL (BOM) RECEIPT LOGO WIDGET
// (DIRECT ON PLAIN WHITE SCREEN, NO BACKGROUND BOX/BORDERS)
// ============================================================================
class _BomHeaderLogoWidget extends StatelessWidget {
  final double height;
  const _BomHeaderLogoWidget({this.height = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height,
      height: height,
      child: Image.asset(
        'assets/images/bom_receipt_header_logo.png',
        width: height,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(
            size: Size(height, height),
            painter: _BomReceiptLogoFallbackPainter(),
          );
        },
      ),
    );
  }
}

class _BomReceiptLogoFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final borderPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Top Dispenser Slot (Grey)
    final slotRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.05, w * 0.80, h * 0.16),
      const Radius.circular(5),
    );
    final slotPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(slotRect, slotPaint);
    canvas.drawRRect(slotRect, borderPaint);

    // 2. Receipt Paper Body (Periwinkle/Blue)
    final receiptPath = Path();
    receiptPath.moveTo(w * 0.20, h * 0.10);
    receiptPath.lineTo(w * 0.80, h * 0.10);
    receiptPath.lineTo(w * 0.80, h * 0.84);
    // Serrated Zigzag Bottom Edge
    receiptPath.lineTo(w * 0.70, h * 0.94);
    receiptPath.lineTo(w * 0.60, h * 0.84);
    receiptPath.lineTo(w * 0.50, h * 0.94);
    receiptPath.lineTo(w * 0.40, h * 0.84);
    receiptPath.lineTo(w * 0.30, h * 0.94);
    receiptPath.lineTo(w * 0.20, h * 0.84);
    receiptPath.close();

    final receiptPaint = Paint()
      ..color = const Color(0xFF7986CB)
      ..style = PaintingStyle.fill;
    canvas.drawPath(receiptPath, receiptPaint);
    canvas.drawPath(receiptPath, borderPaint);

    // 3. Receipt Details (White header box, lines, dollar watermark)
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.20, w * 0.20, h * 0.12),
      const Radius.circular(2),
    );
    canvas.drawRRect(boxRect, Paint()..color = Colors.white);
    canvas.drawRRect(boxRect, borderPaint..strokeWidth = 1.8);

    // Top Right Lines
    borderPaint.strokeWidth = 2.2;
    canvas.drawLine(Offset(w * 0.55, h * 0.22), Offset(w * 0.70, h * 0.22), borderPaint);
    canvas.drawLine(Offset(w * 0.55, h * 0.30), Offset(w * 0.70, h * 0.30), borderPaint);

    // Subtle horizontal body lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.30, h * 0.42), Offset(w * 0.55, h * 0.42), linePaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.52), Offset(w * 0.55, h * 0.52), linePaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.62), Offset(w * 0.65, h * 0.62), linePaint);
    canvas.drawLine(Offset(w * 0.30, h * 0.72), Offset(w * 0.60, h * 0.72), linePaint);

    // 4. Left Golden Dollar Coin Badge
    final coinCenter = Offset(w * 0.18, h * 0.66);
    final coinRadius = w * 0.16;
    final coinPaint = Paint()
      ..color = const Color(0xFFFFD54F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(coinCenter, coinRadius, coinPaint);
    canvas.drawCircle(coinCenter, coinRadius, borderPaint..strokeWidth = 2.4);

    // Dollar text inside coin
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '\$',
        style: TextStyle(
          color: Color(0xFF263238),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      coinCenter - Offset(textPainter.width / 2, textPainter.height / 2),
    );

    // 5. Right Mint Green Checkmark Badge
    final badgeCenter = Offset(w * 0.82, h * 0.66);
    final badgeRadius = w * 0.16;
    final badgePaint = Paint()
      ..color = const Color(0xFF4DB6AC)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(badgeCenter, badgeRadius, badgePaint);
    canvas.drawCircle(badgeCenter, badgeRadius, borderPaint..strokeWidth = 2.4);

    // Checkmark inside badge
    final checkPath = Path()
      ..moveTo(badgeCenter.dx - badgeRadius * 0.45, badgeCenter.dy)
      ..lineTo(badgeCenter.dx - badgeRadius * 0.1, badgeCenter.dy + badgeRadius * 0.35)
      ..lineTo(badgeCenter.dx + badgeRadius * 0.45, badgeCenter.dy - badgeRadius * 0.35);
    final checkPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED SHOW RECORD BUTTON
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
    return Tooltip(
      message: 'Show BOM Records Lookup',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
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
                    color: _isHovered ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _isHovered ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE),
                      width: _isHovered ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: _isHovered ? 0.22 : 0.04),
                        blurRadius: _isHovered ? _pulseGlowAnim.value : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // MAGNIFYING GLASS SWING & SCALE HOVER ANIMATION
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
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

// ============================================================================
// ANIMATED EXPORT BUTTON
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onEnter(_) {
    setState(() => _isHovered = true);
    _ctrl.repeat();
  }

  void _onExit(_) {
    setState(() => _isHovered = false);
    _ctrl.stop();
    _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Export BOM Records',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
      onEnter: _onEnter,
      onExit: _onExit,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isHovered ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? const Color(0xFF10B981).withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.03),
                blurRadius: _isHovered ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _ctrl,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _ctrl.value * 2 * math.pi,
                    child: child,
                  );
                },
                child: const Icon(
                  Icons.file_download_outlined,
                  size: 15,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Export',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF065F46),
                  letterSpacing: -0.1,
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

// ----------------------------------------------------------------------------
// BOM PROGRESS STEP BAR (COMPACT 2-STEP: JOB vs REGULAR - IMAGE 2 MATCH)
// ----------------------------------------------------------------------------
class _BomStepProgressBar extends StatelessWidget {
  final BomMode activeMode;
  final ValueChanged<BomMode> onModeChanged;

  const _BomStepProgressBar({
    required this.activeMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isJob = activeMode == BomMode.job;
    final bool isRegular = activeMode == BomMode.regular;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // STEP 1: JOB (BMCJ)
        _buildStepNode(
          nodeKey: const Key('bom_step_job'),
          stepNumber: '1',
          title: 'JOB (BMCJ)',
          tooltip: 'Switch to Job Work BOM (BMCJ)',
          isActive: isJob,
          onTap: () => onModeChanged(BomMode.job),
        ),

        // CONNECTOR LINE 1 -> 2
        _buildConnectorLine(isActive: isRegular || isJob),

        // STEP 2: REGULAR (BMCC)
        _buildStepNode(
          nodeKey: const Key('bom_step_regular'),
          stepNumber: '2',
          title: 'REGULAR (BMCC)',
          tooltip: 'Switch to Regular BOM (BMCC)',
          isActive: isRegular,
          onTap: () => onModeChanged(BomMode.regular),
        ),
      ],
    );
  }

  Widget _buildConnectorLine({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, left: 6, right: 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 2.0,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0091FF) : const Color(0xFF7DD3FC),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _buildStepNode({
    required Key nodeKey,
    required String stepNumber,
    required String title,
    required String tooltip,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    // Active step has vivid blue indicator bars (#0091FF)
    // Inactive step has soft sky-blue indicator bars (#BAE6FD)
    final Color barColor = isActive ? const Color(0xFF0091FF) : const Color(0xFFBAE6FD);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: nodeKey,
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Circle Node (Compact Refined Size: 22x22)
              // Active: filled vivid blue with cyan halo glow; Inactive: empty white inside with blue border outline
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? const Color(0xFF0091FF) : Colors.white,
                  border: isActive
                      ? Border.all(
                          color: const Color(0xFFBAE6FD).withValues(alpha: 0.9),
                          width: 1.3,
                        )
                      : Border.all(
                          color: const Color(0xFF0091FF),
                          width: 1.6,
                        ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00A3FF).withValues(alpha: 0.50),
                            blurRadius: 8,
                            spreadRadius: 2.5,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF0091FF),
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),

              const SizedBox(height: 3.5),

              // Dual Horizontal Pill Indicator Bars (Image 2 style)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              const SizedBox(height: 1.8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 12,
                height: 2.6,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),

              const SizedBox(height: 3.5),

              // Text Label
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF0091FF)
                      : const Color(0xFF64748B),
                  letterSpacing: -0.1,
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
// ACTION ICON BUTTON WITH SMOOTH HOVER BACKGROUND
// ============================================================================
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverBg;
  final String tooltip;
  final VoidCallback onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.hoverBg,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONFIRM DELETE DIALOG (COPIED EXACTLY FROM PROJECT MASTER SCREEN)
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

            // 100% IDENTICAL IMAGE 2 VECTOR ILLUSTRATION (Person throwing red files into trash)
            const SizedBox(
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
                    child: _BomAnimatedSuccessButton(
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
// 100% IDENTICAL VECTOR ILLUSTRATION PAINTER (FROM PROJECT MASTER SCREEN)
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
