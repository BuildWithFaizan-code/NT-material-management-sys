import 'dart:async';
import '../utils/file_export_helper.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../design/app_colors.dart';
import '../services/capital_consumable_master_service.dart';

enum ButtonStatus { idle, loading, success, error }
enum ExportFormat { excel, pdf }

class CapitalConsumableMasterPage extends StatefulWidget {
  const CapitalConsumableMasterPage({super.key});

  @override
  State<CapitalConsumableMasterPage> createState() => _CapitalConsumableMasterPageState();
}

class _CapitalConsumableMasterPageState extends State<CapitalConsumableMasterPage> {
  final CapitalConsumableMasterService _service = CapitalConsumableMasterService();

  // Data state
  List<CapitalConsumableItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Form state
  bool _isEditing = false;
  int _formCode = 1;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _prefixCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _prefixFocusNode = FocusNode();

  // Search state (Focus-Isolated)
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Directory Category Tab Filter: 'ALL', 'CAPITAL', 'CONSUMABLE'
  String _activeTabFilter = 'ALL';

  // Selected row state
  int? _selectedRowCode;

  // Recently saved & updated entry glow state (4-second Strategy)
  int? _recentlySavedCode;
  int? _recentlyUpdatedCode;
  Timer? _glowTimer;

  // In-Button Micro-Animation Feedback States (Zero External Banners)
  ButtonStatus _saveStatus = ButtonStatus.idle;
  final ButtonStatus _deleteStatus = ButtonStatus.idle;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _glowTimer?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _nameCtrl.dispose();
    _prefixCtrl.dispose();
    _nameFocusNode.dispose();
    _prefixFocusNode.dispose();
    super.dispose();
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
      final list = await _service.getItems();
      final nextCode = await _service.getNextCode();

      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
        if (!_isEditing) {
          _formCode = nextCode;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load items: $e';
      });
    }
  }

  List<CapitalConsumableItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) {
      return i.code.toString().contains(_searchQuery) ||
          i.name.toLowerCase().contains(_searchQuery) ||
          i.prefixSeries.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<CapitalConsumableItem> get _capitalItems {
    return _filteredItems.where((i) {
      final series = i.prefixSeries.toUpperCase();
      final name = i.name.toUpperCase();
      return series.startsWith('CP') || name.contains('MACHINE') || name.contains('PRESS') || name.contains('CUTTER') || name.contains('CAPITAL');
    }).toList();
  }

  List<CapitalConsumableItem> get _consumableItems {
    return _filteredItems.where((i) {
      final series = i.prefixSeries.toUpperCase();
      final name = i.name.toUpperCase();
      return series.startsWith('CS') || name.contains('OIL') || name.contains('THREAD') || name.contains('BLADE') || name.contains('CONSUMABLE');
    }).toList();
  }

  List<CapitalConsumableItem> get _displayTabItems {
    if (_activeTabFilter == 'CAPITAL') return _capitalItems;
    if (_activeTabFilter == 'CONSUMABLE') return _consumableItems;
    return _filteredItems;
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _nameCtrl.clear();
      _prefixCtrl.clear();
      _selectedRowCode = null;
      _saveStatus = ButtonStatus.idle;
    });
    _service.getNextCode().then((nextCode) {
      if (mounted) {
        setState(() => _formCode = nextCode);
      }
    });
  }

  void _editItem(CapitalConsumableItem item) {
    setState(() {
      _isEditing = true;
      _formCode = item.code;
      _nameCtrl.text = item.name;
      _prefixCtrl.text = item.prefixSeries;
      _selectedRowCode = item.code;
      _saveStatus = ButtonStatus.idle;
    });
    _nameFocusNode.requestFocus();
  }

  Future<void> _submitForm() async {
    final String name = _nameCtrl.text.trim();
    final String prefix = _prefixCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _saveStatus = ButtonStatus.error);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
      });
      return;
    }

    setState(() => _saveStatus = ButtonStatus.loading);

    try {
      final item = CapitalConsumableItem(
        code: _formCode,
        name: name.toUpperCase(),
        prefixSeries: prefix.toUpperCase(),
      );
      bool ok = false;
      final wasEditing = _isEditing;
      final savedCode = _formCode;
      if (_isEditing) {
        ok = await _service.updateItem(item);
      } else {
        ok = await _service.insertItem(item);
      }

      if (!mounted) return;

      if (ok) {
        setState(() {
          _saveStatus = ButtonStatus.success;
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

        await _loadInitialData();
        _clearForm();

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
        });
      } else {
        setState(() => _saveStatus = ButtonStatus.error);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveStatus = ButtonStatus.error);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
      });
    }
  }

  Future<void> _deleteItem(CapitalConsumableItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteItem(item.code);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      await _loadInitialData();
      if (_isEditing && _formCode == item.code) {
        _clearForm();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CapitalConsumableExportModalDialog(items: _items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0), // Compact padding for smaller overall look
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            children: [
              // ── 1. TOP ACTION & SEARCH HEADER BAR ───────────────────────────
              _buildTopHeaderBar(),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      // ── 2. QUICK-ENTRY DECK (Category select button REMOVED) ─────
                      _buildTopCommandEntryDeck(),

                      const SizedBox(height: 12),

                      // ── 3. COMPACT TABLE DIRECTORY WITH PILL SEGMENTED TABS ───
                      Expanded(
                        child: _buildTableDirectoryDeck(),
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

  // ============================================================================
  // ── 1. TOP HEADER BAR (IMAGE 3 FIX: Description replaced with Active Pills below heading)
  // ============================================================================
  Widget _buildTopHeaderBar() {
    final capCount = _capitalItems.length;
    final consCount = _consumableItems.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Header Logo Badge (Direct Image, No Box/Border — Ambient Glow Only)
          const _AwesomeCapConsLogo(size: 58),
          const SizedBox(width: 12),

          // Title & Active KPI Pills Arranged Neatly Below Heading (Image 3 Fix)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Capital / Consumable Master',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 3),

              // KPI Badges Placed Neatly Below Heading (No Description Stutter)
              Row(
                children: [
                  // Capital Metric KPI Pill (Emerald Green)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$capCount Capital Assets',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Consumables Metric KPI Pill (Amber Orange)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD97706),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$consCount Consumables',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Focus-Isolated Search Control (Compact height)
          SizedBox(
            width: 210,
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 15, color: Color(0xFF0D9488)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchCtrl.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Animated Export Button
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // ============================================================================
  // ── 2. QUICK-ENTRY DECK (Category select button REMOVED for clean UI)
  // ============================================================================
  Widget _buildTopCommandEntryDeck() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deck Section Title with Royal Indigo Badge
          Row(
            children: [
          // Entry Deck Logo — plain image, no box/border
          if (_isEditing)
            _buildNaturalLogoBadge(
              icon: Icons.edit_note_rounded,
              bgColor: const Color(0xFFFEF3C7),
              iconColor: const Color(0xFFD97706),
              size: 24,
              iconSize: 14,
            )
          else
            Image.asset(
              'assets/images/quick_entry_deck_logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          const SizedBox(width: 8),
          Text(
            _isEditing ? 'Edit Item Record' : 'Entry Deck',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
              const Spacer(),
              if (_isEditing)
                InkWell(
                  onTap: _clearForm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.close_rounded, size: 12, color: Color(0xFF64748B)),
                        SizedBox(width: 3),
                        Text('Cancel Edit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Inline Input Row (Category button removed)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Field 1: Code Pill Box
              SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldHeader('Code', Icons.pin, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
                    const SizedBox(height: 4),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        '#$_formCode',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Field 2: Capital / Consumable Name
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldHeader('Capital / Consumable Name', Icons.inventory_2, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _nameCtrl,
                        focusNode: _nameFocusNode,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.inventory_2_outlined, size: 15, color: Color(0xFF10B981)),
                          hintText: 'e.g. INDUSTRIAL SEWING MACHINES',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Field 3: Prefix Series
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldHeader('Prefix Series', Icons.numbers, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _prefixCtrl,
                        focusNode: _prefixFocusNode,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.numbers, size: 15, color: Color(0xFFD97706)),
                          hintText: 'e.g. CP01, CS01',
                          hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Form Action Buttons (Reset & Save)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Row(
                  children: [
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _clearForm,
                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                        label: const Text('Reset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: AnimatedSuccessButton(
                        status: _saveStatus,
                        onPressed: _submitForm,
                        idleText: _isEditing ? 'Update' : 'Save Item',
                        loadingText: 'Saving...',
                        successText: 'Saved!',
                        errorText: 'Failed',
                        idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                        idleBackgroundColor: AppColors.secondaryColor,
                        successBackgroundColor: const Color(0xFF10B981),
                        height: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldHeader(String label, IconData icon, Color iconColor, Color bgColor) {
    return Row(
      children: [
        _buildNaturalLogoBadge(
          icon: icon,
          bgColor: bgColor,
          iconColor: iconColor,
          size: 18,
          iconSize: 11,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // ============================================================================
  // ── 3. COMPACT TABLE DIRECTORY WITH PILL SEGMENTED TABS (Replacing Cards)
  // ============================================================================
  Widget _buildTableDirectoryDeck() {
    final displayList = _displayTabItems;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Column(
        children: [
          // Toolbar with Pill Segmented Category Tabs
          Row(
            children: [
              // Inventory Items Table Logo — Direct on plain screen, no box or border
              Image.asset(
                'assets/images/inventory_items_table_logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
              const SizedBox(width: 10),
              const Text(
                'Inventory Items Table',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),

              const Spacer(),

              // ── Fluid Stepper Filter Tabs ──────────────────────────────────
              _CapConsStepperTabBar(
                activeFilter: _activeTabFilter,
                allCount: _filteredItems.length,
                capitalCount: _capitalItems.length,
                consumableCount: _consumableItems.length,
                onChanged: (key) => setState(() => _activeTabFilter = key),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Compact High-Density Table View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C3B2E)))
                : (_errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)))
                    : (displayList.isEmpty ? _buildEmptyState() : _buildCompactDataTable(displayList))),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ── BEAUTIFUL COMPACT DATA TABLE WITH LOGOS AND COLOUR BADGES
  // ============================================================================
  Widget _buildCompactDataTable(List<CapitalConsumableItem> list) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // ── Department-Master Style Column Header Bar ────────────────
            Container(
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Row(
                children: [
                  // Code Header (Indigo)
                  SizedBox(
                    width: 90,
                    child: Row(
                      children: [
                        Icon(Icons.pin_rounded, size: 12, color: Color(0xFF6366F1)),
                        SizedBox(width: 4),
                        Text('CODE', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  // Name Header (Emerald)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 12, color: Color(0xFF10B981)),
                        SizedBox(width: 4),
                        Text('CAPITAL / CONSUMABLE NAME', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  // Prefix Series Header (Teal)
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        Icon(Icons.numbers_rounded, size: 12, color: Color(0xFF0D9488)),
                        SizedBox(width: 4),
                        Text('PREFIX SERIES', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  // Category Header (Amber)
                  SizedBox(
                    width: 130,
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text('CATEGORY', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  // Actions Header (Slate)
                  SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.settings_outlined, size: 11, color: Color(0xFF64748B)),
                        SizedBox(width: 3),
                        Text('ACTIONS', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Table Body ListView
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: list.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 2),
                itemBuilder: (ctx, idx) {
                  final item = list[idx];
                  return _CapitalConsumableTableRowWidget(
                    key: ValueKey('cap_item_${item.code}'),
                    item: item,
                    index: idx,
                    isSelected: _selectedRowCode == item.code,
                    isNewGlow: _recentlySavedCode == item.code,
                    isUpdateGlow: _recentlyUpdatedCode == item.code,
                    isDeleting: _selectedRowCode == item.code && _deleteStatus == ButtonStatus.loading,
                    onEdit: () => _editItem(item),
                    onDelete: () => _deleteItem(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF94A3B8)),
          SizedBox(height: 6),
          Text('No capital / consumable records found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  // Clean Natural Coloured Logo Badge Helper
  Widget _buildNaturalLogoBadge({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    double size = 24,
    double iconSize = 13,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}

// ============================================================================
// ── FLUID ANIMATED STEPPER FILTER TAB BAR
// Pill BUTTONS connected by a fluid animated progress rail underneath
// ============================================================================
class _CapConsStepperTabBar extends StatefulWidget {
  final String activeFilter;
  final int allCount;
  final int capitalCount;
  final int consumableCount;
  final ValueChanged<String> onChanged;

  const _CapConsStepperTabBar({
    required this.activeFilter,
    required this.allCount,
    required this.capitalCount,
    required this.consumableCount,
    required this.onChanged,
  });

  @override
  State<_CapConsStepperTabBar> createState() => _CapConsStepperTabBarState();
}

class _CapConsStepperTabBarState extends State<_CapConsStepperTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progressAnim;

  static const List<String> _keys = ['ALL', 'CAPITAL', 'CONSUMABLE'];

  // Multi-tone gradients for high-fluidity visual aesthetic
  static const List<List<Color>> _gradients = [
    [Color(0xFF6366F1), Color(0xFF4F46E5)], // ALL — Vibrant Royal Indigo
    [Color(0xFF10B981), Color(0xFF059669)], // CAPITAL — Lush Emerald Jade
    [Color(0xFFF59E0B), Color(0xFFD97706)], // CONSUMABLE — Glowing Warm Amber
  ];

  int get _activeIndex => _keys.indexOf(widget.activeFilter).clamp(0, 2);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    final init = _activeIndex / 2.0;
    _progressAnim = Tween<double>(begin: init, end: init).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(_CapConsStepperTabBar old) {
    super.didUpdateWidget(old);
    if (old.activeFilter != widget.activeFilter) {
      _progressAnim = Tween<double>(
        begin: _progressAnim.value,
        end: _activeIndex / 2.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _label(int i) {
    switch (i) {
      case 0: return 'All (${widget.allCount})';
      case 1: return 'Capital (${widget.capitalCount})';
      default: return 'Consumables (${widget.consumableCount})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (ctx, _) {
        // Fluid connector fill ratios
        final double leftFill  = (_progressAnim.value * 2.0).clamp(0.0, 1.0);
        final double rightFill = ((_progressAnim.value * 2.0) - 1.0).clamp(0.0, 1.0);

        // Fluid liquid connector line with rounded ends and dynamic glow
        Widget connector(double fill, List<Color> fromGrad, List<Color> toGrad) {
          final Color startColor = fromGrad.first;
          final Color endColor = toGrad.first;

          return SizedBox(
            width: 22,
            height: 5.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Subtle translucent background rail
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Fluid liquid fill
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fill,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [startColor, endColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: fill > 0.05
                            ? [
                                BoxShadow(
                                  color: Color.lerp(startColor, endColor, fill)!.withValues(alpha: 0.55 * fill),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildBtn(0),
            const SizedBox(width: 3),
            connector(leftFill, _gradients[0], _gradients[1]),
            const SizedBox(width: 3),
            _buildBtn(1),
            const SizedBox(width: 3),
            connector(rightFill, _gradients[1], _gradients[2]),
            const SizedBox(width: 3),
            _buildBtn(2),
          ],
        );
      },
    );
  }

  Widget _buildBtn(int i) {
    final isSelected = i == _activeIndex;
    final isPassed = i < _activeIndex;
    final grad = _gradients[i];
    final primaryColor = grad.first;

    // Active & passed buttons stay in rich solid color gradient with white text
    // Unreached buttons stay colored with soft translucent pastel tint & colored text
    final List<Color> bgColors = (isSelected || isPassed)
        ? grad
        : [primaryColor.withValues(alpha: 0.12), grad.last.withValues(alpha: 0.08)];

    final Color textColor = (isSelected || isPassed)
        ? Colors.white
        : primaryColor;

    final Border? border = (isSelected || isPassed)
        ? null
        : Border.all(color: primaryColor.withValues(alpha: 0.30), width: 1.2);

    return GestureDetector(
      onTap: () => widget.onChanged(_keys[i]),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: border,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.42),
                    blurRadius: 9,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  )
                ]
              : (isPassed
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.22),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      )
                    ]
                  : []),
        ),
        child: Text(
          _label(i),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3D CASH & COINS CAPITAL / CONSUMABLE HEADER LOGO
// Direct on plain screen — no background borders or box container
// Minimal ambient glow for clarity and visual depth
// ============================================================================
class _AwesomeCapConsLogo extends StatelessWidget {
  final double size;
  const _AwesomeCapConsLogo({this.size = 58.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle ambient glow layer — no box, purely optical
          Positioned(
            bottom: 2,
            left: size * 0.1,
            right: size * 0.05,
            child: Container(
              height: size * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(4, 2),
                  ),
                ],
              ),
            ),
          ),
          // The actual crisp 3D cash & coins image
          Image.asset(
            'assets/images/capital_consumable_master_logo.png',
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
// ============================================================================
// 100% IDENTICAL ANIMATED EXPORT BUTTON (PROJECT MASTER STYLE)
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
// 100% IDENTICAL EXPORT PANEL MODAL DIALOG (OPERATOR MASTER STYLE)
// ============================================================================
class _CapitalConsumableExportModalDialog extends StatefulWidget {
  final List<CapitalConsumableItem> items;
  const _CapitalConsumableExportModalDialog({required this.items});

  @override
  State<_CapitalConsumableExportModalDialog> createState() => _CapitalConsumableExportModalDialogState();
}

class _CapitalConsumableExportModalDialogState extends State<_CapitalConsumableExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.items.map((i) => i.code).toSet();
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

  List<CapitalConsumableItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      final codeStr = i.code.toString();
      final nameStr = i.name.toLowerCase();
      final seriesStr = i.prefixSeries.toLowerCase();
      return codeStr.contains(_modalSearchQuery) ||
          nameStr.contains(_modalSearchQuery) ||
          seriesStr.contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.code));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.code);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.code);
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
        .where((i) => _selectedCodes.contains(i.code))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

      if (_selectedFormat == 'XLSX') {
        final fileName = 'Capital_Consumable_Master_$timeStamp.xlsx';
        final bytes = _generateExcelBytes(selectedList);
        if (bytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
        }
      } else {
        final fileName = 'Capital_Consumable_Master_$timeStamp.pdf';
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

  List<int>? _generateExcelBytes(List<CapitalConsumableItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Capital Consumable Master');
    final excel_pkg.Sheet sheet = excel['Capital Consumable Master'];

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
    sheet.setColumnWidth(2, 20.0);

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('ITEM CODE'),
      excel_pkg.TextCellValue('ITEM NAME'),
      excel_pkg.TextCellValue('PREFIX SERIES'),
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
        excel_pkg.IntCellValue(item.code),
        excel_pkg.TextCellValue(item.name),
        excel_pkg.TextCellValue(item.prefixSeries),
      ]);

      for (int col = 0; col < 3; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<CapitalConsumableItem> records) async {
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
                  'CAPITAL / CONSUMABLE MASTER DIRECTORY',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
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
            headers: ['ITEM CODE', 'ITEM NAME', 'PREFIX SERIES'],
            data: records.map((i) => [
              '#${i.code}',
              i.name,
              i.prefixSeries,
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
                                Text('Export Capital / Consumable', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                hintText: 'Search items...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.5)),
                prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.secondaryColor),
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
              'No capital / consumable records found',
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
                  Expanded(child: Text('ITEM NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 100, child: Text('PREFIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedCodes.contains(item.code);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.code);
                        } else {
                          _selectedCodes.add(item.code);
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
                                    _selectedCodes.add(item.code);
                                  } else {
                                    _selectedCodes.remove(item.code);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${item.code}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bodyText),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              item.prefixSeries,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
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
        colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFBE123C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final glossPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(0, h * 0.85)
      ..close();

    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawPath(glossPath, glossPaint);

    final ribbonPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..cubicTo(w * 0.25, h * 0.45, w * 0.42, h * 0.22, w * 0.52, h * 0.22)
      ..cubicTo(w * 0.62, h * 0.22, w * 0.78, h * 0.52, w * 0.78, h * 0.72)
      ..cubicTo(w * 0.70, h * 0.60, w * 0.58, h * 0.45, w * 0.48, h * 0.55)
      ..cubicTo(w * 0.38, h * 0.65, w * 0.28, h * 0.72, w * 0.22, h * 0.72);

    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;

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
// ANIMATED SUCCESS BUTTON WITH INTEGRATED LOADING/SUCCESS/SHAKE (NO TOASTS)
// ============================================================================
class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final String errorText;
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
    this.errorText = 'Error',
    required this.idleIcon,
    required this.idleBackgroundColor,
    required this.successBackgroundColor,
    this.height = 36,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void didUpdateWidget(AnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.error && oldWidget.status != ButtonStatus.error) {
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = widget.status == ButtonStatus.loading;
    final bool isSuccess = widget.status == ButtonStatus.success;
    final bool isError = widget.status == ButtonStatus.error;

    final Color bgColor = isSuccess
        ? widget.successBackgroundColor
        : (isError
            ? const Color(0xFFEF4444)
            : (isLoading ? widget.idleBackgroundColor.withValues(alpha: 0.85) : widget.idleBackgroundColor));

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: InkWell(
            onTap: isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: isError ? const Color(0xFFDC2626) : Colors.transparent,
                  width: isError ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 6,
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
                    else if (isError)
                      const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.white)
                    else
                      Icon(widget.idleIcon, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      isLoading
                          ? widget.loadingText
                          : (isSuccess
                              ? widget.successText
                              : (isError ? widget.errorText : widget.idleText)),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
// ANIMATED CAPITAL CONSUMABLE TABLE ROW WIDGET (DEPARTMENT MASTER HOVER PARITY)
// ============================================================================
class _CapitalConsumableTableRowWidget extends StatefulWidget {
  final CapitalConsumableItem item;
  final int index;
  final bool isSelected;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CapitalConsumableTableRowWidget({
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
  State<_CapitalConsumableTableRowWidget> createState() => _CapitalConsumableTableRowWidgetState();
}

class _CapitalConsumableTableRowWidgetState extends State<_CapitalConsumableTableRowWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isNewGlow = widget.isNewGlow;
    final isUpdateGlow = widget.isUpdateGlow;
    final isGlowing = isNewGlow || isUpdateGlow;
    final isSelected = widget.isSelected;
    final bool isConsumable = item.prefixSeries.toUpperCase().startsWith('CS') ||
        item.name.toUpperCase().contains('OIL') ||
        item.name.toUpperCase().contains('THREAD');

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
                  width: 90,
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
                          '#${item.code}',
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

                // 🏭 Name Cell with Vibrant Gradient Logo
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isConsumable
                                ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                                : [const Color(0xFF0D9488), const Color(0xFF10B981)],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isConsumable ? Icons.opacity_rounded : Icons.precision_manufacturing_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                // 🏷️ Prefix Series Cell (Teal Tag Pill)
                SizedBox(
                  width: 140,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: item.prefixSeries.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFF99F6E4)),
                            ),
                            child: Text(
                              'Series: ${item.prefixSeries}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                            ),
                          )
                        : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                ),

                // ⚡ Category Tag Cell (Capital vs Consumable)
                SizedBox(
                  width: 130,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isConsumable ? const Color(0xFFFEF3C7) : const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: isConsumable ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isConsumable ? Icons.opacity_rounded : Icons.bolt, size: 9, color: isConsumable ? const Color(0xFFD97706) : const Color(0xFF059669)),
                          const SizedBox(width: 3),
                          Text(
                            isConsumable ? 'CONSUMABLE' : 'CAPITAL',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isConsumable ? const Color(0xFFD97706) : const Color(0xFF059669)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ⚡ Inline Actions Cell (Department Master Parity Buttons)
                SizedBox(
                  width: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CapitalConsumableActionButton(
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF10B981),
                        tooltip: 'Edit Item',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 6),
                      widget.isDeleting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                              ),
                            )
                          : _CapitalConsumableActionButton(
                              icon: Icons.delete_outline_rounded,
                              color: const Color(0xFFEF4444),
                              tooltip: 'Delete Item',
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
class _CapitalConsumableActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _CapitalConsumableActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_CapitalConsumableActionButton> createState() => _CapitalConsumableActionButtonState();
}

class _CapitalConsumableActionButtonState extends State<_CapitalConsumableActionButton> {
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

