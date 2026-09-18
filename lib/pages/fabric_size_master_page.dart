import 'dart:async';
import '../utils/file_export_helper.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../design/app_colors.dart';
import '../services/fabric_size_master_service.dart';

enum ButtonStatus { idle, loading, success, error }
enum ExportFormat { excel, pdf }

class FabricSizeMasterPage extends StatefulWidget {
  const FabricSizeMasterPage({super.key});

  @override
  State<FabricSizeMasterPage> createState() => _FabricSizeMasterPageState();
}

class _FabricSizeMasterPageState extends State<FabricSizeMasterPage> {
  final FabricSizeMasterService _service = FabricSizeMasterService();

  // Data state
  List<FabricSizeItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Form state
  bool _isEditing = false;
  int _formSizeCode = 1;
  final TextEditingController _nameCtrl = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  // Search state (Focus-Isolated)
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Selected card state
  int? _selectedRowCode;

  // In-Button Micro-Animation Feedback States (Zero External Banners)
  ButtonStatus _saveStatus = ButtonStatus.idle;
  final ButtonStatus _deleteStatus = ButtonStatus.idle;

  // Entry Glow Strategy (4-second auto-fade)
  int? _recentlySavedCode;    // newly added → emerald glow
  int? _recentlyUpdatedCode;  // recently updated → amber glow
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _nameCtrl.dispose();
    _nameFocusNode.dispose();
    _glowTimer?.cancel();
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
      final list = await _service.getFabricSizes();
      final nextCode = await _service.getNextSizeCode();

      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
        if (!_isEditing) {
          _formSizeCode = nextCode;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load fabric sizes: $e';
      });
    }
  }

  List<FabricSizeItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((i) {
      return i.sizeCode.toString().contains(_searchQuery) ||
          i.sizeName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _clearForm() {
    setState(() {
      _isEditing = false;
      _nameCtrl.clear();
      _selectedRowCode = null;
      _saveStatus = ButtonStatus.idle;
    });
    _service.getNextSizeCode().then((nextCode) {
      if (mounted) {
        setState(() => _formSizeCode = nextCode);
      }
    });
  }

  void _editItem(FabricSizeItem item) {
    setState(() {
      _isEditing = true;
      _formSizeCode = item.sizeCode;
      _nameCtrl.text = item.sizeName;
      _selectedRowCode = item.sizeCode;
      _saveStatus = ButtonStatus.idle;
    });
    _nameFocusNode.requestFocus();
  }

  Future<void> _submitForm() async {
    final String name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _saveStatus = ButtonStatus.error);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _saveStatus = ButtonStatus.idle);
      });
      return;
    }

    setState(() => _saveStatus = ButtonStatus.loading);

    try {
      final bool isEditingNow = _isEditing;
      final int savedCode = _formSizeCode;
      final item = FabricSizeItem(sizeCode: savedCode, sizeName: name.toUpperCase());
      bool ok = false;
      if (isEditingNow) {
        ok = await _service.updateFabricSize(item);
      } else {
        ok = await _service.insertFabricSize(item);
      }

      if (!mounted) return;

      if (ok) {
        setState(() => _saveStatus = ButtonStatus.success);
        await _loadInitialData();
        _clearForm();

        // ── Entry Glow Strategy ──────────────────────────────────────────────
        _glowTimer?.cancel();
        setState(() {
          if (isEditingNow) {
            _recentlyUpdatedCode = savedCode;
            _recentlySavedCode = null;
          } else {
            _recentlySavedCode = savedCode;
            _recentlyUpdatedCode = null;
          }
        });
        _glowTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _recentlySavedCode = null;
              _recentlyUpdatedCode = null;
            });
          }
        });
        // ────────────────────────────────────────────────────────────────────

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

  Future<void> _deleteItem(FabricSizeItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        onDelete: () async {
          final ok = await _service.deleteFabricSize(item.sizeCode);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      await _loadInitialData();
      if (_isEditing && _formSizeCode == item.sizeCode) {
        _clearForm();
      }
    }
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _FabricSizeExportModalDialog(items: _items),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredItems;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _buildCompactHeaderBox(),
                const SizedBox(height: 10),
                _buildCompactFormBox(),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        ..._buildCompactCardGridSlivers(list),
        const SliverPadding(padding: EdgeInsets.only(bottom: 10.0)),
      ],
    );
  }

  // ============================================================================
  // ── COMPACT STYLISH HEADER BOX WITH UNIQUE ACCENTS & METRICS
  // ============================================================================
  Widget _buildCompactHeaderBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Awesome Image 2 Logo Badge
          const _AwesomeFabricSizeLogo(size: 44),
          const SizedBox(width: 12),

          // Title & Description
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Fabric Size Master',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Metric KPI Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
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
                          '${_items.length} Active Sizes',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              const Text(
                'Garment & Textile Dimension Standards',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
            ],
          ),

          const Spacer(),

          // Focus-Isolated Search Control (🔍)
          SizedBox(
            width: 215,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search sizes...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF0D9488)),
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

          // 100% Identical Animated Export Button
          _AnimatedExportButton(onPressed: _openExportModal),
        ],
      ),
    );
  }

  // ============================================================================
  // ── TOP BOX: SLEEK & COMPACT FORM CARD (UP BOX)
  // ============================================================================
  Widget _buildCompactFormBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!_isEditing)
                const _CreateNewFabricSizeLogoWidget(size: 26)
              else
                _buildNaturalLogoBadge(
                  icon: Icons.edit_note_rounded,
                  bgColor: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  size: 26,
                  iconSize: 15,
                ),
              const SizedBox(width: 8),
              Text(
                _isEditing ? 'Edit Fabric Size' : 'Create New Fabric Size',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Inline Compact Form Row
          Row(
            children: [
              // 🔢 Size Code Field
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Size Code:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Text(
                      '#$_formSizeCode',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF0369A1)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // 📏 Size Name Field
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _nameCtrl,
                    focusNode: _nameFocusNode,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. MEDIUM, XL, 38, 40, FREE SIZE',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Action Buttons
              SizedBox(
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: _clearForm,
                  icon: const Icon(Icons.restart_alt_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 118,
                child: AnimatedSuccessButton(
                  status: _saveStatus,
                  onPressed: _submitForm,
                  idleText: _isEditing ? 'Update' : 'Save Size',
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
        ],
      ),
    );
  }

  // ============================================================================
  // ── BOTTOM BOX: COMPACT CARD GRID BOX (DOWN BOX - NEAT & SLEEK CARDS)
  // ============================================================================
  List<Widget> _buildCompactCardGridSlivers(List<FabricSizeItem> list) {
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        sliver: SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const _FabricSizeDirectoryLogoWidget(size: 26),
                const SizedBox(width: 8),
                const Text(
                  'FABRIC SIZE DIRECTORY',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten_rounded, size: 12, color: Color(0xFF475569)),
                      const SizedBox(width: 4),
                      Text('Total: ${_items.length}', style: const TextStyle(color: Color(0xFF475569), fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFA7F3D0))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text('Showing: ${list.length}', style: const TextStyle(color: Color(0xFF059669), fontSize: 10.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (_isLoading)
        SliverToBoxAdapter(child: SizedBox(height: 110, child: Center(child: CircularProgressIndicator(color: Color(0xFF0C3B2E)))))
      else if (_errorMessage != null)
        SliverToBoxAdapter(child: SizedBox(height: 110, child: Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)))))
      else if (list.isEmpty)
        SliverToBoxAdapter(child: _buildEmptyState())
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid.builder(
            itemCount: list.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 150,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (ctx, idx) {
              final item = list[idx];
              final bool isSelected = _selectedRowCode == item.sizeCode;
              final bool isDeleting = _selectedRowCode == item.sizeCode && _deleteStatus == ButtonStatus.loading;
              final bool isNewGlow = _recentlySavedCode == item.sizeCode;
              final bool isUpdateGlow = _recentlyUpdatedCode == item.sizeCode;
              return _UniqueFabricSizeGridCard(
                item: item,
                isSelected: isSelected,
                isDeleting: isDeleting,
                isNewGlow: isNewGlow,
                isUpdateGlow: isUpdateGlow,
                onEdit: () => _editItem(item),
                onDelete: () => _deleteItem(item),
              );
            },
          ),
        ),
    ];
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      width: double.infinity,
      alignment: Alignment.center,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'No fabric sizes found',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

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
// ── UNIQUE FABRIC SIZE GRID CARD WIDGET (PROJECT MASTER 100% UI PARITY)
// ============================================================================
class _UniqueFabricSizeGridCard extends StatefulWidget {
  final FabricSizeItem item;
  final bool isSelected;
  final bool isDeleting;
  final bool isNewGlow;
  final bool isUpdateGlow;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UniqueFabricSizeGridCard({
    required this.item,
    required this.isSelected,
    required this.isDeleting,
    required this.isNewGlow,
    required this.isUpdateGlow,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_UniqueFabricSizeGridCard> createState() => _UniqueFabricSizeGridCardState();
}

class _UniqueFabricSizeGridCardState extends State<_UniqueFabricSizeGridCard> {
  bool _isHovered = false;

  Widget _buildUniqueFabricSizeEmblem(String sizeName, int sizeCode) {
    IconData iconData;
    List<Color> gradientColors;
    Color shadowColor;
    final nameUpper = sizeName.trim().toUpperCase();

    if (nameUpper.contains('SMALL') || nameUpper == 'S') {
      iconData = Icons.content_cut_rounded;
      gradientColors = const [Color(0xFF2563EB), Color(0xFF3B82F6), Color(0xFF06B6D4)];
      shadowColor = const Color(0xFF2563EB);
    } else if (nameUpper.contains('MEDIUM') || nameUpper == 'M') {
      iconData = Icons.square_foot_rounded;
      gradientColors = const [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)];
      shadowColor = const Color(0xFF059669);
    } else if (nameUpper.contains('LARGE') || nameUpper == 'L') {
      iconData = Icons.fit_screen_rounded;
      gradientColors = const [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFD946EF)];
      shadowColor = const Color(0xFF7C3AED);
    } else if (nameUpper.contains('FREE') || nameUpper.contains('FS') || nameUpper.contains('XL')) {
      iconData = Icons.auto_awesome_rounded;
      gradientColors = const [Color(0xFFD97706), Color(0xFFF59E0B), Color(0xFFFBBF24)];
      shadowColor = const Color(0xFFD97706);
    } else {
      iconData = Icons.texture_rounded;
      gradientColors = const [Color(0xFF0891B2), Color(0xFF06B6D4), Color(0xFF38BDF8)];
      shadowColor = const Color(0xFF0891B2);
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.32),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          iconData,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onEdit,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -3.0 : 0.0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isNewGlow
                ? const Color(0xFFECFDF5)
                : widget.isUpdateGlow
                    ? const Color(0xFFFFFBEB)
                    : widget.isSelected
                        ? const Color(0xFFF0FDF4)
                        : (_isHovered ? Colors.white : const Color(0xFFFAFAFC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isNewGlow
                  ? const Color(0xFF10B981)
                  : widget.isUpdateGlow
                      ? const Color(0xFFF59E0B)
                      : widget.isSelected
                          ? const Color(0xFF10B981)
                          : (_isHovered ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
              width: (widget.isNewGlow || widget.isUpdateGlow) ? 2.0 : (widget.isSelected ? 1.8 : (_isHovered ? 1.5 : 1.0)),
            ),
            boxShadow: widget.isNewGlow
                ? [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.30),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : widget.isUpdateGlow
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
                          blurRadius: 18,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : widget.isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.22),
                              blurRadius: 14,
                              spreadRadius: 1.5,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : (_isHovered
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.13),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 5),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1),
                                ),
                              ]),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Top Holographic Gradient Accent Bar
              Positioned(
                top: -10,
                left: 10,
                right: 10,
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isNewGlow
                          ? const [Color(0xFF10B981), Color(0xFF34D399), Color(0xFF6EE7B7)]
                          : widget.isUpdateGlow
                              ? const [Color(0xFFF59E0B), Color(0xFFFBBF24), Color(0xFFFDE68A)]
                              : _isHovered
                                  ? const [Color(0xFF2563EB), Color(0xFF4F46E5), Color(0xFF06B6D4), Color(0xFFD946EF)]
                                  : const [Color(0xFF818CF8), Color(0xFFC7D2FE), Color(0xFF93C5FD)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: (widget.isNewGlow || widget.isUpdateGlow || _isHovered)
                        ? [
                            BoxShadow(
                              color: widget.isNewGlow
                                  ? const Color(0xFF10B981).withValues(alpha: 0.55)
                                  : widget.isUpdateGlow
                                      ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                                      : const Color(0xFF2563EB).withValues(alpha: 0.55),
                              blurRadius: 8,
                              spreadRadius: 1.0,
                            ),
                          ]
                        : [],
                  ),
                ),
              ),

              // Main Card Contents Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Code Tag Chip + Action Capsule
                  Row(
                    children: [
                      // Code Chip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFC7D2FE), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.style_outlined, size: 12, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 4),
                            Text(
                              'Code #${widget.item.sizeCode}',
                              style: const TextStyle(
                                color: Color(0xFF4F46E5),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1FAE5),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF047857)),
                              SizedBox(width: 3),
                              Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      // Inline Glow Badge (NEWLY ADDED / RECENTLY UPDATED)
                      if (widget.isNewGlow || widget.isUpdateGlow) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: widget.isNewGlow ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: [
                              BoxShadow(
                                color: (widget.isNewGlow ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.40),
                                blurRadius: 6,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: Text(
                            widget.isNewGlow ? '✦ NEW' : '⚡ UPDATED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),

                      // Action Capsule Container
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ActionIconButton(
                              icon: Icons.edit_outlined,
                              color: const Color(0xFF2563EB),
                              hoverBg: const Color(0xFFEFF6FF),
                              tooltip: 'Edit Fabric Size',
                              onPressed: widget.onEdit,
                            ),
                            const SizedBox(width: 3),
                            widget.isDeleting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Padding(
                                      padding: EdgeInsets.all(3.0),
                                      child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFFEF4444)),
                                    ),
                                  )
                                : _ActionIconButton(
                                    icon: Icons.delete_outline_rounded,
                                    color: const Color(0xFFEF4444),
                                    hoverBg: const Color(0xFFFEF2F2),
                                    tooltip: 'Delete Fabric Size',
                                    onPressed: widget.onDelete,
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Center Body: Dynamic Emblem + Size Name
                  Row(
                    children: [
                      _buildUniqueFabricSizeEmblem(widget.item.sizeName, widget.item.sizeCode),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.sizeName,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            height: 1.2,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Bottom Footer: Fabric Spec Tag + Standard Verified Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.straighten_rounded,
                              color: Color(0xFF475569),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SPEC #${widget.item.sizeCode}',
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_rounded, size: 10, color: Color(0xFF059669)),
                            SizedBox(width: 3),
                            Text(
                              'STANDARD SIZE',
                              style: TextStyle(
                                color: Color(0xFF047857),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: _isHovered ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.icon,
              size: 13.5,
              color: _isHovered ? widget.color : widget.color.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STYLISH AWESOME 3D FABRIC SIZE MASTER HEADER LOGO
// ============================================================================
// ============================================================================
// FABRIC SIZE MASTER HEADER LOGO (100% IDENTICAL TO IMAGE 2 WITH COOL GLOW)
// ============================================================================
class _AwesomeFabricSizeLogo extends StatelessWidget {
  final double size;
  const _AwesomeFabricSizeLogo({this.size = 48.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle Ambient Glow (Toned down for clean, professional look)
          Container(
            width: size * 0.7,
            height: size * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5277).withValues(alpha: 0.14),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
                BoxShadow(
                  color: const Color(0xFF9333EA).withValues(alpha: 0.10),
                  blurRadius: 12,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          // 100% Identical Vector Graphic Painter for Image 2 Fabric Roll Logo
          CustomPaint(
            size: Size(size, size),
            painter: const _FabricRollImage2Painter(),
          ),
        ],
      ),
    );
  }
}

class _FabricRollImage2Painter extends CustomPainter {
  const _FabricRollImage2Painter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Paints
    final Paint fabricFillPaint = Paint()
      ..color = const Color(0xFFFF6584) // Vibrant Pink / Magenta
      ..style = PaintingStyle.fill;

    final Paint innerCorePaint = Paint()
      ..color = const Color(0xFFD81B60) // Darker Crimson Core
      ..style = PaintingStyle.fill;

    final Paint flowerPaint = Paint()
      ..color = const Color(0xFFFFD166) // Warm Golden Yellow
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = const Color(0xFF0F172A) // Thick Dark Navy / Indigo Outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. UNROLLED FABRIC SHEET PATH (Right Side)
    final Path sheetPath = Path()
      ..moveTo(w * 0.42, h * 0.20)
      ..cubicTo(w * 0.52, h * 0.16, w * 0.70, h * 0.26, w * 0.85, h * 0.26)
      ..lineTo(w * 0.85, h * 0.85)
      ..cubicTo(w * 0.70, h * 0.85, w * 0.52, h * 0.75, w * 0.42, h * 0.78)
      ..close();

    canvas.drawPath(sheetPath, fabricFillPaint);
    canvas.drawPath(sheetPath, strokePaint);

    // 2. ROLLED FABRIC CYLINDER BODY (Left Side)
    final Path cylinderPath = Path()
      ..moveTo(w * 0.18, h * 0.22)
      ..lineTo(w * 0.18, h * 0.74)
      ..arcToPoint(
        Offset(w * 0.52, h * 0.74),
        radius: Radius.elliptical(w * 0.17, h * 0.11),
        clockwise: false,
      )
      ..lineTo(w * 0.52, h * 0.22)
      ..arcToPoint(
        Offset(w * 0.18, h * 0.22),
        radius: Radius.elliptical(w * 0.17, h * 0.11),
        clockwise: true,
      )
      ..close();

    canvas.drawPath(cylinderPath, fabricFillPaint);
    canvas.drawPath(cylinderPath, strokePaint);

    // 3. TOP ROLLED OVAL OPENING & INNER CORE
    final Rect topOvalRect = Rect.fromLTWH(w * 0.18, h * 0.11, w * 0.34, h * 0.22);
    canvas.drawOval(topOvalRect, fabricFillPaint);
    canvas.drawOval(topOvalRect, strokePaint);

    final Rect innerCoreRect = Rect.fromLTWH(w * 0.28, h * 0.17, w * 0.14, h * 0.10);
    canvas.drawOval(innerCoreRect, innerCorePaint);
    canvas.drawOval(innerCoreRect, strokePaint);

    // 4. PRINTED FLORAL PATTERN MOTIFS (Yellow 4-petal flowers)
    _drawFlowerMotif(canvas, Offset(w * 0.30, h * 0.40), w * 0.05, flowerPaint);
    _drawFlowerMotif(canvas, Offset(w * 0.40, h * 0.62), w * 0.045, flowerPaint);
    _drawFlowerMotif(canvas, Offset(w * 0.70, h * 0.40), w * 0.055, flowerPaint);
    _drawFlowerMotif(canvas, Offset(w * 0.72, h * 0.70), w * 0.05, flowerPaint);
    _drawFlowerMotif(canvas, Offset(w * 0.56, h * 0.54), w * 0.04, flowerPaint);
  }

  void _drawFlowerMotif(Canvas canvas, Offset center, double r, Paint paint) {
    // 4-petal flower shape
    canvas.drawCircle(center + Offset(-r * 0.6, 0), r, paint);
    canvas.drawCircle(center + Offset(r * 0.6, 0), r, paint);
    canvas.drawCircle(center + Offset(0, -r * 0.6), r, paint);
    canvas.drawCircle(center + Offset(0, r * 0.6), r, paint);
    canvas.drawCircle(center, r * 0.7, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 100% IDENTICAL ANIMATED EXPORT BUTTON
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
// 100% IDENTICAL EXPORT PANEL MODAL DIALOG (OPERATOR MASTER STYLE)
// ============================================================================
class _FabricSizeExportModalDialog extends StatefulWidget {
  final List<FabricSizeItem> items;
  const _FabricSizeExportModalDialog({required this.items});

  @override
  State<_FabricSizeExportModalDialog> createState() => _FabricSizeExportModalDialogState();
}

class _FabricSizeExportModalDialogState extends State<_FabricSizeExportModalDialog> {
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
    _selectedCodes = widget.items.map((i) => i.sizeCode).toSet();
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

  List<FabricSizeItem> get _filteredPreviewItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      final codeStr = i.sizeCode.toString();
      final nameStr = i.sizeName.toLowerCase();
      return codeStr.contains(_modalSearchQuery) || nameStr.contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final filtered = _filteredPreviewItems;
    if (filtered.isEmpty) return false;
    return filtered.every((i) => _selectedCodes.contains(i.sizeCode));
  }

  void _toggleSelectAllFiltered() {
    final filtered = _filteredPreviewItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (var i in filtered) {
          _selectedCodes.remove(i.sizeCode);
        }
      } else {
        for (var i in filtered) {
          _selectedCodes.add(i.sizeCode);
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
        .where((i) => _selectedCodes.contains(i.sizeCode))
        .toList();

    try {
      final String timeStamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);

      if (_selectedFormat == 'XLSX') {
        final fileName = 'Fabric_Size_Master_$timeStamp.xlsx';
        final bytes = _generateExcelBytes(selectedList);
        if (bytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
        }
      } else {
        final fileName = 'Fabric_Size_Master_$timeStamp.pdf';
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

  List<int>? _generateExcelBytes(List<FabricSizeItem> records) {
    final excel = excel_pkg.Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    excel.rename(defaultSheet, 'Fabric Size Master');
    final excel_pkg.Sheet sheet = excel['Fabric Size Master'];

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

    sheet.setRowHeight(0, 26.0);
    sheet.appendRow([
      excel_pkg.TextCellValue('SIZE CODE'),
      excel_pkg.TextCellValue('SIZE NAME'),
    ]);

    for (int col = 0; col < 2; col++) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (int i = 0; i < records.length; i++) {
      final item = records[i];
      final style = (i % 2 == 0) ? evenStyle : oddStyle;
      final int rIdx = i + 1;

      sheet.setRowHeight(rIdx, 22.0);
      sheet.appendRow([
        excel_pkg.IntCellValue(item.sizeCode),
        excel_pkg.TextCellValue(item.sizeName),
      ]);

      for (int col = 0; col < 2; col++) {
        sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
      }
    }

    return excel.save();
  }

  Future<List<int>> _generatePdfBytes(List<FabricSizeItem> records) async {
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
                  'FABRIC SIZE MASTER DIRECTORY',
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
            headers: ['SIZE CODE', 'SIZE NAME'],
            data: records.map((i) => [
              '#${i.sizeCode}',
              i.sizeName,
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
                                    Text('Export Fabric Size Master', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                hintText: 'Search sizes...',
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
              'No fabric size records found',
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
                  Expanded(child: Text('SIZE NAME', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final item = previewList[idx];
                  final isSelected = _selectedCodes.contains(item.sizeCode);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCodes.remove(item.sizeCode);
                        } else {
                          _selectedCodes.add(item.sizeCode);
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
                                    _selectedCodes.add(item.sizeCode);
                                  } else {
                                    _selectedCodes.remove(item.sizeCode);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              '${item.sizeCode}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.sizeName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.bodyText),
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

    // Background Crimson Gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF43F5E), Color(0xFFE11D48), Color(0xFFBE123C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Subtle gloss diagonal
    final glossPath = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.85, 0)
      ..lineTo(0, h * 0.85)
      ..close();

    final glossPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawPath(glossPath, glossPaint);

    // White Adobe Ribbon Curve
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

    // PDF text at bottom
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
// ANIMATED SUCCESS BUTTON WITH INTEGRATED LOADING/SUCCESS/SHAKE
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

// ============================================================================
// ── CREATE NEW FABRIC SIZE LOGO WIDGET (IMAGE 2 DESIGN PARITY)
// ============================================================================
class _CreateNewFabricSizeLogoWidget extends StatelessWidget {
  final double size;
  const _CreateNewFabricSizeLogoWidget({this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.20),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: const _CreateNewDocumentPlusPainter(),
      ),
    );
  }
}

class _CreateNewDocumentPlusPainter extends CustomPainter {
  const _CreateNewDocumentPlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Document Sheet Dimensions
    final docLeft = w * 0.15;
    final docTop = h * 0.10;
    final docWidth = w * 0.65;
    final docHeight = h * 0.80;
    final foldSize = w * 0.20;

    // 1. Document Sheet Path with Top-Left Fold
    final docPath = Path()
      ..moveTo(docLeft + foldSize, docTop)
      ..lineTo(docLeft + docWidth, docTop)
      ..lineTo(docLeft + docWidth, docTop + docHeight)
      ..lineTo(docLeft, docTop + docHeight)
      ..lineTo(docLeft, docTop + foldSize)
      ..close();

    // Document Base Gradient (Sky Light Blue)
    final docGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFF0F9FF),
        Color(0xFFE0F2FE),
        Color(0xFFBAE6FD),
      ],
    );
    canvas.drawPath(
      docPath,
      Paint()
        ..shader = docGradient.createShader(Rect.fromLTWH(docLeft, docTop, docWidth, docHeight))
        ..style = PaintingStyle.fill,
    );

    // Document Border
    canvas.drawPath(
      docPath,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // 2. Fold Flap (Top-Left Corner)
    final foldFlap = Path()
      ..moveTo(docLeft, docTop + foldSize)
      ..lineTo(docLeft + foldSize, docTop + foldSize)
      ..lineTo(docLeft + foldSize, docTop)
      ..close();

    canvas.drawPath(
      foldFlap,
      Paint()..color = const Color(0xFF7DD3FC),
    );
    canvas.drawPath(
      foldFlap,
      Paint()
        ..color = const Color(0xFF0284C7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 3. Document Text Lines (4 horizontal lines)
    final linePaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6;

    final lineLeft = docLeft + docWidth * 0.20;
    final lineRight = docLeft + docWidth * 0.80;
    final lineTopStart = docTop + docHeight * 0.28;
    final lineSpacing = docHeight * 0.12;

    for (int i = 0; i < 4; i++) {
      final y = lineTopStart + (i * lineSpacing);
      final currentLineRight = (i == 3) ? docLeft + docWidth * 0.55 : lineRight;
      canvas.drawLine(Offset(lineLeft, y), Offset(currentLineRight, y), linePaint);
    }

    // 4. Red Circular Badge at Bottom-Right
    final badgeCenter = Offset(docLeft + docWidth * 0.85, docTop + docHeight * 0.82);
    final badgeRadius = w * 0.22;

    // Badge Shadow Glow
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()
        ..color = const Color(0xFFE11D48).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Badge Gradient (Vibrant Crimson Red)
    final badgeGradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFB7185),
        Color(0xFFE11D48),
        Color(0xFFBE123C),
      ],
    );
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()..shader = badgeGradient.createShader(Rect.fromCircle(center: badgeCenter, radius: badgeRadius)),
    );

    // Badge Border
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 5. Golden Plus Sign inside Badge
    final plusPaint = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;

    final armLen = badgeRadius * 0.48;
    // Horizontal line
    canvas.drawLine(
      Offset(badgeCenter.dx - armLen, badgeCenter.dy),
      Offset(badgeCenter.dx + armLen, badgeCenter.dy),
      plusPaint,
    );
    // Vertical line
    canvas.drawLine(
      Offset(badgeCenter.dx, badgeCenter.dy - armLen),
      Offset(badgeCenter.dx, badgeCenter.dy + armLen),
      plusPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ── FABRIC SIZE DIRECTORY LOGO WIDGET (PARITY WITH DIRECTORY SERVER ICON)
// ============================================================================
class _FabricSizeDirectoryLogoWidget extends StatelessWidget {
  final double size;
  const _FabricSizeDirectoryLogoWidget({this.size = 28.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: 1.5,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.20),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: const _FabricSizeDirectoryPainter(),
      ),
    );
  }
}

class _FabricSizeDirectoryPainter extends CustomPainter {
  const _FabricSizeDirectoryPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blueStroke = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final blueFillLight = Paint()
      ..color = const Color(0xFF93C5FD)
      ..style = PaintingStyle.fill;

    final whiteFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final ledFillLight = Paint()
      ..color = const Color(0xFF60A5FA)
      ..style = PaintingStyle.fill;

    final ledFillWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final slotBluePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final slotWhitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Rack proportions
    final rackLeft = w * 0.05;
    final rackRight = w * 0.80;
    final rackWidth = rackRight - rackLeft;
    final drawerHeight = h * 0.25;
    final cornerRadius = Radius.circular(w * 0.08);

    // 1. TOP DRAWER
    final topRect = Rect.fromLTWH(rackLeft, h * 0.08, rackWidth, drawerHeight);
    final topRRect = RRect.fromRectAndRadius(topRect, cornerRadius);
    canvas.drawRRect(topRRect, whiteFill);
    canvas.drawRRect(topRRect, blueStroke);

    // Top Drawer LEDs (2 circles)
    final topLedCenter1 = Offset(rackLeft + rackWidth * 0.16, topRect.top + drawerHeight / 2);
    final topLedCenter2 = Offset(rackLeft + rackWidth * 0.32, topRect.top + drawerHeight / 2);
    final ledRadius = drawerHeight * 0.20;

    canvas.drawCircle(topLedCenter1, ledRadius, ledFillLight);
    canvas.drawCircle(topLedCenter1, ledRadius, blueStroke);
    canvas.drawCircle(topLedCenter2, ledRadius, ledFillLight);
    canvas.drawCircle(topLedCenter2, ledRadius, blueStroke);

    // Top Drawer Slots (4 vertical lines)
    final slotTop = topRect.top + drawerHeight * 0.22;
    final slotBottom = topRect.bottom - drawerHeight * 0.22;
    final slotXStart = rackLeft + rackWidth * 0.50;
    final slotSpacing = rackWidth * 0.10;

    for (int i = 0; i < 4; i++) {
      final x = slotXStart + (i * slotSpacing);
      canvas.drawLine(Offset(x, slotTop), Offset(x, slotBottom), slotBluePaint);
    }

    // 2. MIDDLE DRAWER
    final midRect = Rect.fromLTWH(rackLeft, h * 0.36, rackWidth, drawerHeight);
    final midRRect = RRect.fromRectAndRadius(midRect, cornerRadius);
    canvas.drawRRect(midRRect, blueFillLight);
    canvas.drawRRect(midRRect, blueStroke);

    // Middle Drawer LEDs
    final midLedCenter1 = Offset(rackLeft + rackWidth * 0.16, midRect.top + drawerHeight / 2);
    final midLedCenter2 = Offset(rackLeft + rackWidth * 0.32, midRect.top + drawerHeight / 2);

    canvas.drawCircle(midLedCenter1, ledRadius, ledFillWhite);
    canvas.drawCircle(midLedCenter1, ledRadius, blueStroke);
    canvas.drawCircle(midLedCenter2, ledRadius, ledFillWhite);
    canvas.drawCircle(midLedCenter2, ledRadius, blueStroke);

    // Middle Drawer Slots (4 vertical white lines)
    final midSlotTop = midRect.top + drawerHeight * 0.22;
    final midSlotBottom = midRect.bottom - drawerHeight * 0.22;

    for (int i = 0; i < 4; i++) {
      final x = slotXStart + (i * slotSpacing);
      canvas.drawLine(Offset(x, midSlotTop), Offset(x, midSlotBottom), slotWhitePaint);
    }

    // 3. BOTTOM DRAWER
    final botRect = Rect.fromLTWH(rackLeft, h * 0.64, rackWidth, drawerHeight);
    final botRRect = RRect.fromRectAndRadius(botRect, cornerRadius);
    canvas.drawRRect(botRRect, whiteFill);
    canvas.drawRRect(botRRect, blueStroke);

    // Bottom Drawer LEDs
    final botLedCenter1 = Offset(rackLeft + rackWidth * 0.16, botRect.top + drawerHeight / 2);
    final botLedCenter2 = Offset(rackLeft + rackWidth * 0.32, botRect.top + drawerHeight / 2);

    canvas.drawCircle(botLedCenter1, ledRadius, ledFillLight);
    canvas.drawCircle(botLedCenter1, ledRadius, blueStroke);
    canvas.drawCircle(botLedCenter2, ledRadius, ledFillLight);
    canvas.drawCircle(botLedCenter2, ledRadius, blueStroke);

    // Bottom Drawer Slots (2 vertical lines on left side before badge)
    final botSlotTop = botRect.top + drawerHeight * 0.22;
    final botSlotBottom = botRect.bottom - drawerHeight * 0.22;

    for (int i = 0; i < 2; i++) {
      final x = slotXStart + (i * slotSpacing);
      canvas.drawLine(Offset(x, botSlotTop), Offset(x, botSlotBottom), slotBluePaint);
    }

    // 4. OVERLAY CIRCLE BADGE (Bottom-Right)
    final badgeCenter = Offset(w * 0.74, h * 0.68);
    final badgeRadius = w * 0.23;

    // Badge Shadow
    canvas.drawCircle(
      badgeCenter,
      badgeRadius,
      Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Badge Circle
    canvas.drawCircle(badgeCenter, badgeRadius, whiteFill);
    canvas.drawCircle(badgeCenter, badgeRadius, blueStroke);

    // Inside Badge: Bar Chart
    final chartBaseY = badgeCenter.dy + badgeRadius * 0.40;
    final chartLeftX = badgeCenter.dx - badgeRadius * 0.55;
    final chartRightX = badgeCenter.dx + badgeRadius * 0.55;

    // Baseline
    canvas.drawLine(Offset(chartLeftX, chartBaseY), Offset(chartRightX, chartBaseY), slotBluePaint);

    // 4 Vertical Bars
    final barSpacing = (chartRightX - chartLeftX) / 3;
    final barHeights = [
      badgeRadius * 0.40, // Bar 1 (Short)
      badgeRadius * 0.85, // Bar 2 (Tall)
      badgeRadius * 0.55, // Bar 3 (Medium)
      badgeRadius * 0.75, // Bar 4 (Tall)
    ];

    for (int i = 0; i < 4; i++) {
      final bx = chartLeftX + (i * barSpacing);
      final bTop = chartBaseY - barHeights[i];
      canvas.drawLine(Offset(bx, chartBaseY), Offset(bx, bTop), slotBluePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


