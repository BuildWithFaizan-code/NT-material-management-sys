import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../design/app_colors.dart';
import '../services/makers_master_service.dart';
import '../utils/file_export_helper.dart';

enum ButtonStatus { idle, loading, success, error }
enum ExportFormat { excel, pdf }

class MakersMasterPage extends StatefulWidget {
  const MakersMasterPage({super.key});

  @override
  State<MakersMasterPage> createState() => _MakersMasterPageState();
}

class _MakersMasterPageState extends State<MakersMasterPage> {
  final MakersMasterService _service = MakersMasterService();

  // Data state
  List<MakersMasterItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Form state
  bool _isEditing = false;
  int _formMakerCode = 1;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _prefixCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _prefixFocusNode = FocusNode();

  // Search state (Focus-Isolated)
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Selected card state
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
      final list = await _service.getMakers();
      final nextCode = await _service.getNextMakerCode();

      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
        if (!_isEditing) {
          _formMakerCode = nextCode;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load makers: $e';
      });
    }
  }

  List<MakersMasterItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) {
      return i.makerCode.toString().contains(_searchQuery) ||
          i.makerName.toLowerCase().contains(_searchQuery) ||
          i.prefixSeries.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _nameCtrl.clear();
      _prefixCtrl.clear();
      _saveStatus = ButtonStatus.idle;
    });
    _service.getNextMakerCode().then((nextCode) {
      if (mounted) {
        setState(() => _formMakerCode = nextCode);
      }
    });
  }

  void _editItem(MakersMasterItem item) {
    setState(() {
      _isEditing = true;
      _formMakerCode = item.makerCode;
      _nameCtrl.text = item.makerName;
      _prefixCtrl.text = item.prefixSeries;
      _selectedRowCode = item.makerCode;
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
      final item = MakersMasterItem(
        makerCode: _formMakerCode,
        makerName: name.toUpperCase(),
        prefixSeries: prefix.toUpperCase(),
      );
      final savedCode = _formMakerCode;
      final wasEditing = _isEditing;

      bool ok = false;
      if (_isEditing) {
        ok = await _service.updateMaker(item);
      } else {
        ok = await _service.insertMaker(item);
      }

      if (!mounted) return;

      if (ok) {
        setState(() {
          _saveStatus = ButtonStatus.success;
          _selectedRowCode = savedCode;
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

  Future<void> _deleteItem(MakersMasterItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteMaker(item.makerCode);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      await _loadInitialData();
      if (_isEditing && _formMakerCode == item.makerCode) {
        _clearForm();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MakersExportModalDialog(items: _items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredItems;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // ── TOP ACTION & SEARCH HEADER BAR ─────────────────────────────
              _buildTopHeaderBar(),

              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // ── MAIN DUAL SCREEN WORKSTATION (LEFT FORM BOX & RIGHT CARDS BOX)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LEFT SCREEN BOX: CURVY FORM CARD (360px Wide) ─────
                      SizedBox(
                        width: 360,
                        child: _buildLeftFormBox(),
                      ),

                      const SizedBox(width: 16),

                      // ── RIGHT SCREEN BOX: CURVY DIRECTORY CARDS PANE ──────
                      Expanded(
                        child: _buildRightDirectoryBox(list),
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
  // ── TOP HEADER BAR
  // ============================================================================
  Widget _buildTopHeaderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Header Logo Badge
          const _AwesomeMakersLogo(size: 40),
          const SizedBox(width: 14),

          // Clean Title & Subtitle Header Layout
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Makers Master',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manufacturing Location & Vendor Directory',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Focus-Isolated Search Control
          SizedBox(
            width: 230,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search makers...',
                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search, size: 17, color: Color(0xFF0D9488)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 15, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            _searchCtrl.clear();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 100% Identical Animated Export Button
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // ============================================================================
  // ── LEFT SCREEN BOX: CURVY FORM CARD (360px Wide)
  // ============================================================================
  Widget _buildLeftFormBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title with Enhanced 3D Badge & Realistic Assembly Logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isEditing ? const Color(0xFFFDE68A) : const Color(0xFFDDD6FE),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isEditing ? const Color(0xFFD97706) : const Color(0xFF7C3AED)).withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2.5),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/create_maker_location_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const _AssemblyLineFallbackVector(size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _isEditing ? 'Edit Maker Location' : 'Create New Maker Location',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 🔢 FIELD 1: Maker Code
          _buildFieldHeader('Maker Code', Icons.pin, const Color(0xFF2563EB), const Color(0xFFDBEAFE)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(Icons.style_outlined, size: 15, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  '#$_formMakerCode',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF1E40AF)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('AUTO-ID', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 🏭 FIELD 2: Maker Name
          _buildFieldHeader('Maker Name', Icons.precision_manufacturing, const Color(0xFF10B981), const Color(0xFFD1FAE5)),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: TextField(
              controller: _nameCtrl,
              focusNode: _nameFocusNode,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.precision_manufacturing, size: 16, color: Color(0xFF10B981)),
                hintText: 'e.g. RUDRA FABRICS',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 🏷️ FIELD 3: Prefix Series
          _buildFieldHeader('Prefix Series', Icons.numbers, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: TextField(
              controller: _prefixCtrl,
              focusNode: _prefixFocusNode,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.numbers, size: 16, color: Color(0xFFD97706)),
                hintText: 'e.g. 01, MK',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD97706), width: 1.8)),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Form Action Buttons (NO EXTERNAL BANNER NOTIFICATIONS)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.restart_alt_rounded, size: 15),
                    label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AnimatedSuccessButton(
                  status: _saveStatus,
                  onPressed: _submitForm,
                  idleText: _isEditing ? 'Update Maker' : 'Save Maker',
                  loadingText: 'Saving...',
                  successText: 'Saved!',
                  errorText: 'Failed',
                  idleIcon: _isEditing ? Icons.check_rounded : Icons.save_rounded,
                  idleBackgroundColor: AppColors.secondaryColor,
                  successBackgroundColor: const Color(0xFF10B981),
                  height: 42,
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
          size: 22,
          iconSize: 13,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
        ),
      ],
    );
  }

  // ============================================================================
  // ── RIGHT SCREEN BOX: CLEAN & PROFESSIONAL DIRECTORY TABLE PANE (DEPARTMENT MASTER PARITY)
  // ============================================================================
  Widget _buildRightDirectoryBox(List<MakersMasterItem> list) {
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
          // Table Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/makers_directory_sheet_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const _YellowRobotFallbackVector(size: 24),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Makers Directory Sheet',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${list.length} Records',
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

          // Responsive Table Body Grid
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Column(
                children: [
                  // Column Header Bar
                  Container(
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 65,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tag_rounded, size: 12, color: Color(0xFF6366F1)),
                              SizedBox(width: 3),
                              Text(
                                'CODE',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 5),
                              Text(
                                'MAKER NAME',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_rounded, size: 12, color: Color(0xFFF59E0B)),
                              SizedBox(width: 5),
                              Text(
                                'SERIES',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
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
                              Text(
                                'ACTIONS',
                                style: TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Data Rows List
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: AppColors.secondaryColor),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : list.isEmpty
                                ? _buildEmptyState()
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    itemCount: list.length,
                                    separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                                    itemBuilder: (ctx, idx) {
                                      final item = list[idx];
                                      final isSelected = _selectedRowCode == item.makerCode;

                                      return _AnimatedMakerRow(
                                        key: ValueKey<int>(item.makerCode),
                                        item: item,
                                        isSelected: isSelected,
                                        isNewGlow: _recentlySavedCode == item.makerCode,
                                        isUpdateGlow: _recentlyUpdatedCode == item.makerCode,
                                        onTap: () {
                                          setState(() {
                                            _selectedRowCode = item.makerCode;
                                          });
                                        },
                                        onDoubleTap: () => _editItem(item),
                                        onEdit: () => _editItem(item),
                                        onDelete: () => _deleteItem(item),
                                        isDeleting: _selectedRowCode == item.makerCode && _deleteStatus == ButtonStatus.loading,
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          Icon(Icons.search_off_rounded, size: 32, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text('No maker records found', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  // Clean Natural Coloured Logo Badge Helper
  Widget _buildNaturalLogoBadge({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    double size = 26,
    double iconSize = 15,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );
  }
}

// ============================================================================
// ── ANIMATED MAKER ROW WIDGET (100% DEPARTMENT MASTER TABLE STYLE + GLOW STRATEGY)
// ============================================================================
class _AnimatedMakerRow extends StatefulWidget {
  final MakersMasterItem item;
  final bool isSelected;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isDeleting;

  const _AnimatedMakerRow({
    super.key,
    required this.item,
    required this.isSelected,
    this.isNewGlow = false,
    this.isUpdateGlow = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
    required this.onDelete,
    required this.isDeleting,
  });

  @override
  State<_AnimatedMakerRow> createState() => _AnimatedMakerRowState();
}

class _AnimatedMakerRowState extends State<_AnimatedMakerRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isSelected = widget.isSelected;

    Color bgColor = isSelected
        ? AppColors.secondaryColor.withValues(alpha: 0.08)
        : (_isHovered ? const Color(0xFFF0FDF4) : Colors.white);

    Color borderColor = isSelected
        ? AppColors.secondaryColor
        : (_isHovered ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0));

    List<BoxShadow> shadows = _isHovered
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
          ];

    if (widget.isNewGlow) {
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
    } else if (widget.isUpdateGlow) {
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
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.006 : 1.0,
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
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: _isHovered || isSelected || widget.isNewGlow || widget.isUpdateGlow ? 1.6 : 1.0,
                  ),
                  boxShadow: shadows,
                ),
                child: Row(
                  children: [
                    // Cell 1: CODE BADGE (# Code)
                    SizedBox(
                      width: 65,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: widget.isNewGlow
                                  ? const Color(0xFF10B981)
                                  : widget.isUpdateGlow
                                      ? const Color(0xFFF59E0B)
                                      : isSelected || _isHovered
                                          ? (_isHovered ? const Color(0xFF16A34A) : AppColors.secondaryColor)
                                          : const Color(0xFF6366F1).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (widget.isNewGlow || widget.isUpdateGlow || isSelected || _isHovered)
                                    ? Colors.transparent
                                    : const Color(0xFF6366F1).withValues(alpha: 0.22),
                                width: 1.0,
                              ),
                              boxShadow: widget.isNewGlow
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                        blurRadius: 6,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ]
                                  : widget.isUpdateGlow
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                            blurRadius: 6,
                                            offset: const Offset(0, 1.5),
                                          ),
                                        ]
                                      : isSelected || _isHovered
                                          ? [
                                              BoxShadow(
                                                color: (_isHovered ? const Color(0xFF16A34A) : AppColors.secondaryColor)
                                                    .withValues(alpha: 0.32),
                                                blurRadius: 5,
                                                offset: const Offset(0, 1.5),
                                              ),
                                            ]
                                          : null,
                            ),
                            child: Text(
                              '#${item.makerCode}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: (widget.isNewGlow || widget.isUpdateGlow || isSelected || _isHovered)
                                    ? Colors.white
                                    : const Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cell 2: MAKER NAME
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.makerName,
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

                    // Cell 3: SERIES TAG
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.prefixSeries.isNotEmpty ? 'SERIES ${item.prefixSeries}' : '-',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutralDark.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Cell 4: ACTIONS (Edit & Delete Buttons - 100% Department Master style)
                    SizedBox(
                      width: 75,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ActionButton(
                            icon: Icons.edit_rounded,
                            color: const Color(0xFF10B981),
                            tooltip: 'Edit Maker',
                            onPressed: widget.onEdit,
                          ),
                          const SizedBox(width: 4),
                          widget.isDeleting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                                )
                              : _ActionButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: const Color(0xFFEF4444),
                                  tooltip: 'Delete Maker',
                                  onPressed: widget.onDelete,
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Glow Pill Badges
              if (widget.isNewGlow)
                Positioned(
                  top: -6,
                  right: 85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.45),
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
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
                        ),
                      ],
                    ),
                  ),
                ),
              if (widget.isUpdateGlow)
                Positioned(
                  top: -6,
                  right: 85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
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
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
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
// ── ACTION BUTTON WIDGET (100% DEPARTMENT MASTER STYLE)
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
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _isHovered ? widget.color.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: IconButton(
            icon: Icon(
              widget.icon,
              size: 13.5,
              color: _isHovered ? widget.color : widget.color.withValues(alpha: 0.8),
            ),
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
// STYLISH AWESOME MAKERS MASTER HEADER LOGO (PLAIN LOGO WITH SUBTLE GLOW)
// ============================================================================
class _AwesomeMakersLogo extends StatelessWidget {
  final double size;
  const _AwesomeMakersLogo({this.size = 40.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
            blurRadius: 8,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/makers_master_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const _RoboticArmFallbackVector();
        },
      ),
    );
  }
}

class _RoboticArmFallbackVector extends StatelessWidget {
  const _RoboticArmFallbackVector();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RoboticArmPainter(),
    );
  }
}

class _RoboticArmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blackOutline = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final darkBasePaint = Paint()..color = const Color(0xFF334155);
    final pinkPaint = Paint()..color = const Color(0xFFF472B6);
    final yellowPaint = Paint()..color = const Color(0xFFFBBF24);
    final cyanPaint = Paint()..color = const Color(0xFF38BDF8);
    final lightBluePaint = Paint()..color = const Color(0xFFE2E8F0);
    final innerCyanPaint = Paint()..color = const Color(0xFFE0F2FE);

    // Bottom Base Plate
    final baseRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.88, w * 0.84, h * 0.09),
      Radius.circular(w * 0.03),
    );
    canvas.drawRRect(baseRect, darkBasePaint);
    canvas.drawRRect(baseRect, blackOutline);

    // Pink Accent Strip
    final pinkStrip = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.14, h * 0.82, w * 0.72, h * 0.06),
      Radius.circular(w * 0.02),
    );
    canvas.drawRRect(pinkStrip, pinkPaint);
    canvas.drawRRect(pinkStrip, blackOutline);

    // Main Base Stand Body
    final baseBody = Path()
      ..moveTo(w * 0.20, h * 0.82)
      ..lineTo(w * 0.20, h * 0.65)
      ..cubicTo(w * 0.20, h * 0.58, w * 0.35, h * 0.56, w * 0.42, h * 0.62)
      ..lineTo(w * 0.65, h * 0.75)
      ..lineTo(w * 0.68, h * 0.82)
      ..close();
    canvas.drawPath(baseBody, darkBasePaint);
    canvas.drawPath(baseBody, blackOutline);

    // Yellow Accent Box
    final yellowBox = Rect.fromLTWH(w * 0.20, h * 0.68, w * 0.12, h * 0.14);
    canvas.drawRect(yellowBox, yellowPaint);
    canvas.drawRect(yellowBox, blackOutline);

    // Lower Slanted Arm Link
    final lowerArm = Path()
      ..moveTo(w * 0.16, h * 0.24)
      ..lineTo(w * 0.54, h * 0.52)
      ..lineTo(w * 0.42, h * 0.65)
      ..lineTo(w * 0.10, h * 0.32)
      ..close();
    canvas.drawPath(lowerArm, lightBluePaint);
    canvas.drawPath(lowerArm, blackOutline);

    // Upper Arm Link
    final upperArm = Path()
      ..moveTo(w * 0.24, h * 0.08)
      ..lineTo(w * 0.80, h * 0.14)
      ..lineTo(w * 0.78, h * 0.26)
      ..lineTo(w * 0.24, h * 0.22)
      ..close();
    canvas.drawPath(upperArm, lightBluePaint);
    canvas.drawPath(upperArm, blackOutline);

    // Top Right Wrist Connector & Pink Claw
    final wristStem = Rect.fromLTWH(w * 0.74, h * 0.22, w * 0.10, h * 0.14);
    canvas.drawRect(wristStem, lightBluePaint);
    canvas.drawRect(wristStem, blackOutline);

    final clawPath = Path()
      ..moveTo(w * 0.68, h * 0.34)
      ..lineTo(w * 0.68, h * 0.52)
      ..lineTo(w * 0.76, h * 0.52)
      ..lineTo(w * 0.76, h * 0.42)
      ..lineTo(w * 0.84, h * 0.42)
      ..lineTo(w * 0.84, h * 0.52)
      ..lineTo(w * 0.92, h * 0.52)
      ..lineTo(w * 0.92, h * 0.34)
      ..close();
    canvas.drawPath(clawPath, pinkPaint);
    canvas.drawPath(clawPath, blackOutline);

    // Shoulder Joint (Top Left)
    final shoulderCenter = Offset(w * 0.24, h * 0.17);
    canvas.drawCircle(shoulderCenter, w * 0.14, cyanPaint);
    canvas.drawCircle(shoulderCenter, w * 0.14, blackOutline);
    canvas.drawCircle(shoulderCenter, w * 0.07, innerCyanPaint);
    canvas.drawCircle(shoulderCenter, w * 0.07, blackOutline);

    // Wrist Joint (Top Right)
    final wristCenter = Offset(w * 0.80, h * 0.16);
    canvas.drawCircle(wristCenter, w * 0.10, cyanPaint);
    canvas.drawCircle(wristCenter, w * 0.10, blackOutline);
    canvas.drawCircle(wristCenter, w * 0.05, innerCyanPaint);
    canvas.drawCircle(wristCenter, w * 0.05, blackOutline);

    // Elbow/Lower Joint
    final elbowCenter = Offset(w * 0.48, h * 0.58);
    canvas.drawCircle(elbowCenter, w * 0.13, cyanPaint);
    canvas.drawCircle(elbowCenter, w * 0.06, innerCyanPaint);
    canvas.drawCircle(elbowCenter, w * 0.06, blackOutline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _YellowRobotFallbackVector extends StatelessWidget {
  final double size;
  const _YellowRobotFallbackVector({this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _YellowRobotPainter(),
      ),
    );
  }
}

class _YellowRobotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blackStroke = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final yellowPaint = Paint()..color = const Color(0xFFFBBF24);
    final pinkPaint = Paint()..color = const Color(0xFFF472B6);
    final cyanPaint = Paint()..color = const Color(0xFF38BDF8);
    final darkTrack = Paint()..color = const Color(0xFF334155);
    final whitePaint = Paint()..color = Colors.white;

    // Tank Track Base
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.74, w * 0.80, h * 0.20),
      Radius.circular(w * 0.10),
    );
    canvas.drawRRect(track, darkTrack);
    canvas.drawRRect(track, blackStroke);

    // Track Wheels
    canvas.drawCircle(Offset(w * 0.26, h * 0.84), w * 0.06, whitePaint);
    canvas.drawCircle(Offset(w * 0.26, h * 0.84), w * 0.06, blackStroke);
    canvas.drawCircle(Offset(w * 0.50, h * 0.84), w * 0.06, whitePaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.84), w * 0.06, blackStroke);
    canvas.drawCircle(Offset(w * 0.74, h * 0.84), w * 0.06, whitePaint);
    canvas.drawCircle(Offset(w * 0.74, h * 0.84), w * 0.06, blackStroke);

    // Robot Yellow Dome Body
    final bodyPath = Path()
      ..moveTo(w * 0.28, h * 0.74)
      ..lineTo(w * 0.28, h * 0.35)
      ..cubicTo(w * 0.28, h * 0.15, w * 0.72, h * 0.15, w * 0.72, h * 0.35)
      ..lineTo(w * 0.72, h * 0.74)
      ..close();
    canvas.drawPath(bodyPath, yellowPaint);
    canvas.drawPath(bodyPath, blackStroke);

    // Visor Screen (Cyan)
    final visor = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.26, w * 0.32, h * 0.18),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(visor, cyanPaint);
    canvas.drawRRect(visor, blackStroke);

    // Antenna
    canvas.drawLine(Offset(w * 0.50, h * 0.15), Offset(w * 0.50, h * 0.05), blackStroke);
    canvas.drawCircle(Offset(w * 0.50, h * 0.04), w * 0.04, cyanPaint);
    canvas.drawCircle(Offset(w * 0.50, h * 0.04), w * 0.04, blackStroke);

    // Left & Right Pink Arms with Claws
    final leftArm = Path()
      ..moveTo(w * 0.28, h * 0.55)
      ..cubicTo(w * 0.12, h * 0.55, w * 0.12, h * 0.30, w * 0.22, h * 0.25);
    canvas.drawPath(leftArm, blackStroke);

    final rightArm = Path()
      ..moveTo(w * 0.72, h * 0.55)
      ..cubicTo(w * 0.88, h * 0.55, w * 0.88, h * 0.30, w * 0.78, h * 0.25);
    canvas.drawPath(rightArm, blackStroke);

    // Left Claw (Pink)
    canvas.drawCircle(Offset(w * 0.20, h * 0.25), w * 0.06, pinkPaint);
    canvas.drawCircle(Offset(w * 0.20, h * 0.25), w * 0.06, blackStroke);

    // Right Claw (Pink)
    canvas.drawCircle(Offset(w * 0.80, h * 0.25), w * 0.06, pinkPaint);
    canvas.drawCircle(Offset(w * 0.80, h * 0.25), w * 0.06, blackStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AssemblyLineFallbackVector extends StatelessWidget {
  final double size;
  const _AssemblyLineFallbackVector({this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AssemblyLinePainter(),
      ),
    );
  }
}

class _AssemblyLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blackStroke = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final purpleFill = Paint()..color = const Color(0xFFC084FC);
    final darkTrack = Paint()..color = const Color(0xFF475569);
    final redGear = Paint()..color = const Color(0xFFF87171);
    final whiteFill = Paint()..color = Colors.white;

    // Bottom Conveyor Track
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.78, w * 0.90, h * 0.16),
      Radius.circular(w * 0.08),
    );
    canvas.drawRRect(track, darkTrack);
    canvas.drawRRect(track, blackStroke);

    // Inner Purple Belt
    final belt = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.83, w * 0.80, h * 0.07),
      Radius.circular(w * 0.035),
    );
    canvas.drawRRect(belt, purpleFill);

    // Gear 1 (Left)
    final gear1Center = Offset(w * 0.28, h * 0.60);
    canvas.drawCircle(gear1Center, w * 0.18, redGear);
    canvas.drawCircle(gear1Center, w * 0.18, blackStroke);
    canvas.drawCircle(gear1Center, w * 0.07, whiteFill);
    canvas.drawCircle(gear1Center, w * 0.07, blackStroke);

    // Gear 2 (Right)
    final gear2Center = Offset(w * 0.70, h * 0.60);
    canvas.drawCircle(gear2Center, w * 0.18, redGear);
    canvas.drawCircle(gear2Center, w * 0.18, blackStroke);
    canvas.drawCircle(gear2Center, w * 0.07, whiteFill);
    canvas.drawCircle(gear2Center, w * 0.07, blackStroke);

    // Top Purple Rail & Overhead Claw
    final rail = Rect.fromLTWH(w * 0.05, h * 0.08, w * 0.90, h * 0.06);
    canvas.drawRect(rail, purpleFill);
    canvas.drawRect(rail, blackStroke);

    // Claw Body
    final clawMount = Offset(w * 0.70, h * 0.18);
    canvas.drawCircle(clawMount, w * 0.10, darkTrack);
    canvas.drawCircle(clawMount, w * 0.10, blackStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ============================================================================
// ANIMATED EXPORT BUTTON WITH CIRCULATING LIGHT EDGE ORBIT (PROJECT MASTER IDENTICAL)
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
class _MakersExportModalDialog extends StatefulWidget {
  final List<MakersMasterItem> items;
  const _MakersExportModalDialog({required this.items});

  @override
  State<_MakersExportModalDialog> createState() => _MakersExportModalDialogState();
}

class _MakersExportModalDialogState extends State<_MakersExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.makerCode).toSet();
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

  List<MakersMasterItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      final codeStr = i.makerCode.toString();
      final nameStr = i.makerName.toLowerCase();
      final seriesStr = i.prefixSeries.toLowerCase();
      return codeStr.contains(_modalSearchQuery) ||
          nameStr.contains(_modalSearchQuery) ||
          seriesStr.contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.makerCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.makerCode);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.makerCode);
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
        .where((i) => _selectedCodes.contains(i.makerCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final String fileName = _selectedFormat == 'XLSX'
          ? 'Makers_Master_$timeStamp.xlsx'
          : 'Makers_Master_$timeStamp.pdf';

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

  List<int>? _generateExcelBytes(List<MakersMasterItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Makers Master');
    final excel_pkg.Sheet sheet = excel['Makers Master'];

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
      excel_pkg.TextCellValue('MAKER CODE'),
      excel_pkg.TextCellValue('MAKER NAME'),
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
        excel_pkg.IntCellValue(item.makerCode),
        excel_pkg.TextCellValue(item.makerName),
        excel_pkg.TextCellValue(item.prefixSeries),
      ]);

      for (int col = 0; col < 3; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<MakersMasterItem> records) async {
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
                  'MAKERS MASTER DIRECTORY',
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
            headers: ['MAKER CODE', 'MAKER NAME', 'PREFIX SERIES'],
            data: records.map((i) => [
              '#${i.makerCode}',
              i.makerName,
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
                                    Text('Export Makers Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                hintText: 'Search makers...',
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
              'No maker records found',
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
                  Expanded(child: Text('MAKER NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
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
                  final isSelected = _selectedCodes.contains(item.makerCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.makerCode);
                        } else {
                          _selectedCodes.add(item.makerCode);
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
                                    _selectedCodes.add(item.makerCode);
                                  } else {
                                    _selectedCodes.remove(item.makerCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${item.makerCode}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.makerName,
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
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
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
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isError ? const Color(0xFFDC2626) : Colors.transparent,
                  width: isError ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else if (isSuccess)
                      const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white)
                    else if (isError)
                      const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.white)
                    else
                      Icon(widget.idleIcon, size: 15, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      isLoading
                          ? widget.loadingText
                          : (isSuccess
                              ? widget.successText
                              : (isError ? widget.errorText : widget.idleText)),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
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

