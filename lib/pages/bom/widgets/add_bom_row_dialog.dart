import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../bom_models.dart';
import '../bom_service.dart';
import 'bom_animated_success_button.dart';
import 'bom_modern_dropdown.dart';
import 'sub_material_lookup_dialog.dart';

/// Medium modal dialog for adding/editing a recipe row / sub-component
/// with all columns compulsory filled and live calculations.
class AddBomRowDialog extends StatefulWidget {
  final String parentItemCode;
  final String bomId;
  final int nextRowIndex;
  final List<BomUnitLookup> units;
  final BomService? bomService;
  final BomSubItemData? existingItem;

  const AddBomRowDialog({
    super.key,
    required this.parentItemCode,
    required this.bomId,
    required this.nextRowIndex,
    required this.units,
    this.bomService,
    this.existingItem,
  });

  @override
  State<AddBomRowDialog> createState() => _AddBomRowDialogState();
}

class _AddBomRowDialogState extends State<AddBomRowDialog> {
  late final BomService _bomService;

  final TextEditingController _materialCodeCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _consCtrl = TextEditingController(text: '1.00');
  final TextEditingController _extraCtrl = TextEditingController(text: '0.00');
  final TextEditingController _sqmCtrl = TextEditingController(text: '0.00');
  final TextEditingController _convQtyCtrl = TextEditingController(text: '1.00');
  final TextEditingController _rateCtrl = TextEditingController(text: '0.00');
  final TextEditingController _remarksCtrl = TextEditingController();

  final FocusNode _materialCodeFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _consFocusNode = FocusNode();
  final FocusNode _extraFocusNode = FocusNode();
  final FocusNode _sqmFocusNode = FocusNode();
  final FocusNode _convQtyFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();
  final FocusNode _remarksFocusNode = FocusNode();

  String _materialType = 'RAW MATERIAL';
  int _selectedUnitCode = 0;
  String _selectedUnitName = '';
  int _itGroupCd = 0;
  String? _validationError;
  ButtonStatus _buttonStatus = ButtonStatus.idle;

  List<BomDropdownItem<String>> _buildMaterialTypeDropdownItems() {
    final Map<String, (IconData, Color, Color, String)> knownTypes = {
      'RAW MATERIAL': (Icons.eco_rounded, const Color(0xFF059669), const Color(0xFFECFDF5), 'Fabrics, yarns & core substrate'),
      'FABRIC': (Icons.texture_rounded, const Color(0xFF059669), const Color(0xFFECFDF5), 'Knitted or woven fabric goods'),
      'PACKING': (Icons.inventory_2_rounded, const Color(0xFF0284C7), const Color(0xFFF0F9FF), 'Cartons, polybags, tags & tape'),
      'ACCESSORIES': (Icons.extension_rounded, const Color(0xFFD97706), const Color(0xFFFFFBEB), 'Buttons, zippers, rivets & trims'),
      'CONSUMABLES': (Icons.opacity_rounded, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), 'Chemicals, threads, adhesives & oils'),
      'WIP': (Icons.precision_manufacturing_rounded, const Color(0xFF0D9488), const Color(0xFFF0FDFA), 'Semi-finished batches & work-in-progress'),
      'GENERAL': (Icons.widgets_rounded, const Color(0xFF475569), const Color(0xFFF8FAFC), 'General components & supplies'),
    };

    final list = <BomDropdownItem<String>>[];
    final current = _materialType.trim().toUpperCase();

    if (current.isNotEmpty && !knownTypes.containsKey(current)) {
      list.add(BomDropdownItem<String>(
        value: _materialType,
        label: _materialType,
        subtitle: 'Custom material classification',
        icon: Icons.category_rounded,
        iconColor: const Color(0xFF0C3B2E),
        badgeColor: const Color(0xFFE6F4EA),
      ));
    }

    knownTypes.forEach((key, val) {
      list.add(BomDropdownItem<String>(
        value: key,
        label: key,
        subtitle: val.$4,
        icon: val.$1,
        iconColor: val.$2,
        badgeColor: val.$3,
      ));
    });

    return list;
  }

  List<BomDropdownItem<int>> _buildUnitDropdownItems() {
    final list = <BomDropdownItem<int>>[];
    for (final u in widget.units) {
      list.add(BomDropdownItem<int>(
        value: u.unitCode,
        label: u.unitName,
        subtitle: 'Code: ${u.unitCode}',
        icon: Icons.straighten_rounded,
        iconColor: const Color(0xFF0C3B2E),
        badgeColor: const Color(0xFFE6F4EA),
      ));
    }

    if (_selectedUnitCode > 0 && !widget.units.any((u) => u.unitCode == _selectedUnitCode)) {
      list.insert(
        0,
        BomDropdownItem<int>(
          value: _selectedUnitCode,
          label: _selectedUnitName.isNotEmpty ? _selectedUnitName : 'Unit #$_selectedUnitCode',
          subtitle: 'Code: $_selectedUnitCode',
          icon: Icons.straighten_rounded,
          iconColor: const Color(0xFF0C3B2E),
          badgeColor: const Color(0xFFE6F4EA),
        ),
      );
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    _bomService = widget.bomService ?? BomService();

    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _materialCodeCtrl.text = item.iCode;
      _descriptionCtrl.text = item.description;
      _materialType = item.materialType.isNotEmpty ? item.materialType : 'RAW MATERIAL';
      _selectedUnitCode = item.unitCode;
      _selectedUnitName = item.unitName;
      _itGroupCd = item.itGroupCd;
      _consCtrl.text = item.bomCons.toStringAsFixed(2);
      _extraCtrl.text = item.bomExtra.toStringAsFixed(2);
      _sqmCtrl.text = item.sqm.toStringAsFixed(2);
      _convQtyCtrl.text = item.convQty.toStringAsFixed(2);
      _rateCtrl.text = item.bomRate.toStringAsFixed(2);
      _remarksCtrl.text = item.bomRemarks;
    } else {
      if (widget.units.isNotEmpty) {
        _selectedUnitCode = widget.units.first.unitCode;
        _selectedUnitName = widget.units.first.unitName;
      }
    }

    _consCtrl.addListener(_onFieldChanged);
    _extraCtrl.addListener(_onFieldChanged);
    _rateCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _consCtrl.removeListener(_onFieldChanged);
    _extraCtrl.removeListener(_onFieldChanged);
    _rateCtrl.removeListener(_onFieldChanged);

    _materialCodeCtrl.dispose();
    _descriptionCtrl.dispose();
    _consCtrl.dispose();
    _extraCtrl.dispose();
    _sqmCtrl.dispose();
    _convQtyCtrl.dispose();
    _rateCtrl.dispose();
    _remarksCtrl.dispose();

    _materialCodeFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _consFocusNode.dispose();
    _extraFocusNode.dispose();
    _sqmFocusNode.dispose();
    _convQtyFocusNode.dispose();
    _rateFocusNode.dispose();
    _remarksFocusNode.dispose();
    super.dispose();
  }

  double get _cons => double.tryParse(_consCtrl.text.trim()) ?? 0.0;
  double get _extra => double.tryParse(_extraCtrl.text.trim()) ?? 0.0;
  double get _sqm => double.tryParse(_sqmCtrl.text.trim()) ?? 0.0;
  double get _convQty => double.tryParse(_convQtyCtrl.text.trim()) ?? 1.0;
  double get _rate => double.tryParse(_rateCtrl.text.trim()) ?? 0.0;
  double get _tolQty => (_cons * (_extra / 100.0));
  double get _netQty => _cons + _tolQty;
  double get _amount => _netQty * _rate;

  Future<void> _openItemLookup() async {
    final picked = await showDialog<ComponentLookupItem>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SubMaterialLookupDialog(
        parentItemCode: widget.parentItemCode,
        initialQuery: _materialCodeCtrl.text.trim(),
        bomService: _bomService,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _materialCodeCtrl.text = picked.iCode;
        _descriptionCtrl.text = picked.itName;
        if (picked.materialType.isNotEmpty) {
          _materialType = picked.materialType;
        }
        _itGroupCd = picked.catCode;
        _selectedUnitCode = picked.unitCode;
        _selectedUnitName = picked.unitName;
        if (picked.convQty > 0) {
          _convQtyCtrl.text = picked.convQty.toStringAsFixed(2);
        }
        _validationError = null;
      });

      _consFocusNode.requestFocus();
      _consCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _consCtrl.text.length);
    }
  }

  void _handleSubmit() {
    final code = _materialCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _validationError = 'Material Code is compulsory! Select or enter item code.');
      _materialCodeFocusNode.requestFocus();
      return;
    }

    final desc = _descriptionCtrl.text.trim();
    if (desc.isEmpty) {
      setState(() => _validationError = 'Material Description is compulsory!');
      _descriptionFocusNode.requestFocus();
      return;
    }

    if (_cons <= 0) {
      setState(() => _validationError = 'Consumption must be greater than 0.00!');
      _consFocusNode.requestFocus();
      return;
    }

    if (_selectedUnitCode <= 0 && _selectedUnitName.isEmpty) {
      setState(() => _validationError = 'Unit of Measure (UOM) is compulsory!');
      return;
    }

    final rowNumber = widget.existingItem?.bomsCode ?? '${widget.nextRowIndex}';

    final resultItem = BomSubItemData(
      bomsId: widget.bomId,
      bomsCode: rowNumber,
      itGroupCd: _itGroupCd,
      iCode: code,
      description: desc,
      materialType: _materialType,
      qty: _netQty,
      unitCode: _selectedUnitCode,
      unitName: _selectedUnitName.isNotEmpty ? _selectedUnitName : 'PCS',
      sqm: _sqm,
      bomCons: _cons,
      bomExtra: _extra,
      bomTolQty: _tolQty,
      bomTotQty: _netQty,
      convQty: _convQty > 0 ? _convQty : 1.0,
      bomRate: _rate,
      bomAmount: _amount,
      bomRemarks: _remarksCtrl.text.trim(),
      bomGsm: widget.existingItem?.bomGsm ?? 0.0,
      bomFabPhoto: widget.existingItem?.bomFabPhoto ?? '',
      bomShade: widget.existingItem?.bomShade ?? '',
      bomSizeDet: widget.existingItem?.bomSizeDet ?? '',
      bomDesNo: (widget.existingItem?.bomDesNo.isNotEmpty == true)
          ? widget.existingItem!.bomDesNo
          : widget.parentItemCode,
    );

    setState(() {
      _validationError = null;
      _buttonStatus = ButtonStatus.success;
    });

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) {
        Navigator.of(context).pop(resultItem);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0C3B2E);
    const primaryBg = Color(0xFFE6F4EA);
    const primaryBorder = Color(0xFFA7F3D0);
    final isEditing = widget.existingItem != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 700,
            constraints: const BoxConstraints(maxHeight: 640),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. DIALOG HEADER
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primaryBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: primaryBorder),
                        ),
                        child: Icon(
                          isEditing ? Icons.edit_note_rounded : Icons.post_add_rounded,
                          size: 20,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  isEditing ? 'Edit Recipe Row #${widget.existingItem!.bomsCode}' : 'Add Recipe Row / Sub-Component',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (widget.parentItemCode.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBFDBFE)),
                                    ),
                                    child: Text(
                                      'FG: ${widget.parentItemCode}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Fill all compulsory recipe specifications to add this component row to the BOM',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        splashRadius: 18,
                        tooltip: 'Close (Esc)',
                      ),
                    ],
                  ),
                ),

                // 2. SCROLLABLE FORM BODY
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // VALIDATION ERROR ALERT
                        if (_validationError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _validationError!,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // CARD SECTION 1: MATERIAL IDENTITY
                        _buildSectionCard(
                          title: '1. MATERIAL & COMPONENT IDENTIFICATION',
                          icon: Icons.category_rounded,
                          accentColor: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // MATERIAL CODE (WITH LOOKUP TRIGGER)
                                  Expanded(
                                    flex: 6,
                                    child: _buildFormField(
                                      label: 'MATERIAL CODE *',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _materialCodeCtrl,
                                          focusNode: _materialCodeFocusNode,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: 'Enter code or click [...]',
                                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                            suffixIcon: Tooltip(
                                              message: 'Lookup from ITEMMST (Query 6)',
                                              child: InkWell(
                                                onTap: _openItemLookup,
                                                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                                child: Container(
                                                  margin: const EdgeInsets.all(3),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: const Color(0xFFBFDBFE)),
                                                  ),
                                                  child: const Icon(Icons.more_horiz_rounded, size: 16, color: Color(0xFF2563EB)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // MATERIAL TYPE
                                  Expanded(
                                    flex: 4,
                                    child: _buildFormField(
                                      label: 'MATERIAL TYPE *',
                                      child: BomModernDropdown<String>(
                                        value: _materialType.isNotEmpty ? _materialType : 'RAW MATERIAL',
                                        hintText: 'Select Material Type...',
                                        dropdownTitle: 'MATERIAL TYPE',
                                        titleIcon: Icons.category_rounded,
                                        accentColor: const Color(0xFF0C3B2E),
                                        hoverBorderColor: const Color(0xFFA7F3D0),
                                        height: 34,
                                        borderRadius: 8,
                                        items: _buildMaterialTypeDropdownItems(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _materialType = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // DESCRIPTION
                                  Expanded(
                                    flex: 7,
                                    child: _buildFormField(
                                      label: 'MATERIAL DESCRIPTION *',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _descriptionCtrl,
                                          focusNode: _descriptionFocusNode,
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                          decoration: InputDecoration(
                                            hintText: 'Component description / title',
                                            hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // UNIT / UOM
                                  Expanded(
                                    flex: 3,
                                    child: _buildFormField(
                                      label: 'UOM *',
                                      child: BomModernDropdown<int>(
                                        value: widget.units.any((u) => u.unitCode == _selectedUnitCode)
                                            ? _selectedUnitCode
                                            : (widget.units.isNotEmpty ? widget.units.first.unitCode : null),
                                        hintText: 'Select UOM...',
                                        dropdownTitle: 'UNIT OF MEASURE (UOM)',
                                        titleIcon: Icons.straighten_rounded,
                                        accentColor: const Color(0xFF0C3B2E),
                                        hoverBorderColor: const Color(0xFFA7F3D0),
                                        height: 34,
                                        borderRadius: 8,
                                        enableSearch: widget.units.length > 4,
                                        items: _buildUnitDropdownItems(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedUnitCode = val;
                                              final match = widget.units.firstWhere((u) => u.unitCode == val);
                                              _selectedUnitName = match.unitName;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // CARD SECTION 2: RECIPE SPECIFICATIONS & CONSUMPTION
                        _buildSectionCard(
                          title: '2. RECIPE QUANTITIES & SPECIFICATIONS',
                          icon: Icons.calculate_rounded,
                          accentColor: const Color(0xFF0D9488),
                          bgColor: const Color(0xFFF0FDFA),
                          borderColor: const Color(0xFF99F6E4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  // CONSUMPTION (COMPULSORY)
                                  Expanded(
                                    child: _buildFormField(
                                      label: 'CONSUMPTION (CONS.) *',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _consCtrl,
                                          focusNode: _consFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: '1.00',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // EXTRA / TOLERANCE %
                                  Expanded(
                                    child: _buildFormField(
                                      label: 'TOLERANCE (+/- %)',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _extraCtrl,
                                          focusNode: _extraFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: '0.00%',
                                            suffixText: '%',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // SQM
                                  Expanded(
                                    child: _buildFormField(
                                      label: 'SQM',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _sqmCtrl,
                                          focusNode: _sqmFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: '0.00',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // CONV QTY
                                  Expanded(
                                    child: _buildFormField(
                                      label: 'CONV FACTOR',
                                      child: SizedBox(
                                        height: 34,
                                        child: TextField(
                                          controller: _convQtyCtrl,
                                          focusNode: _convQtyFocusNode,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: '1.00',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // LIVE CALCULATION PILLS
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF99F6E4)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildPillSummary(
                                      label: 'TOL QTY',
                                      value: _tolQty.toStringAsFixed(2),
                                      color: const Color(0xFFD97706),
                                      icon: Icons.add_circle_outline_rounded,
                                    ),
                                    Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                                    _buildPillSummary(
                                      label: 'NET TOTAL QTY',
                                      value: '${_netQty.toStringAsFixed(2)} $_selectedUnitName',
                                      color: const Color(0xFF0C3B2E),
                                      icon: Icons.check_circle_rounded,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // CARD SECTION 3: COSTING & REMARKS
                        _buildSectionCard(
                          title: '3. COSTING & REMARKS',
                          icon: Icons.attach_money_rounded,
                          accentColor: const Color(0xFFEA580C),
                          bgColor: const Color(0xFFFFF7ED),
                          borderColor: const Color(0xFFFED7AA),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // UNIT RATE
                              Expanded(
                                flex: 3,
                                child: _buildFormField(
                                  label: 'UNIT RATE',
                                  child: SizedBox(
                                    height: 34,
                                    child: TextField(
                                      controller: _rateCtrl,
                                      focusNode: _rateFocusNode,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      decoration: InputDecoration(
                                        hintText: '0.00',
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5)),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // TOTAL AMOUNT (COMPUTED)
                              Expanded(
                                flex: 3,
                                child: _buildFormField(
                                  label: 'TOTAL AMOUNT',
                                  child: Container(
                                    height: 34,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      _amount.toStringAsFixed(2),
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // REMARKS
                              Expanded(
                                flex: 6,
                                child: _buildFormField(
                                  label: 'REMARKS',
                                  child: SizedBox(
                                    height: 34,
                                    child: TextField(
                                      controller: _remarksCtrl,
                                      focusNode: _remarksFocusNode,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                                      decoration: InputDecoration(
                                        hintText: 'Optional notes for this component...',
                                        hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFEA580C), width: 1.5)),
                                      ),
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
                ),

                // 3. DIALOG FOOTER ACTIONS
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 10),
                      BomAnimatedSuccessButton(
                        status: _buttonStatus,
                        onPressed: _handleSubmit,
                        idleText: isEditing ? 'Save Changes' : 'Add Row to Recipe',
                        loadingText: isEditing ? 'Saving Changes...' : 'Adding Row...',
                        successText: isEditing ? 'Changes Saved!' : 'Row Added!',
                        idleIcon: isEditing ? Icons.save_rounded : Icons.add_rounded,
                        idleBackgroundColor: primaryColor,
                        successBackgroundColor: const Color(0xFF10B981),
                        height: 38,
                        borderRadius: BorderRadius.circular(8),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
                child: Icon(icon, size: 12, color: accentColor),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accentColor, letterSpacing: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildPillSummary({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    bool isBold = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
            Text(
              value,
              style: TextStyle(fontSize: isBold ? 12 : 11, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ],
    );
  }
}
