import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';
import '../bom_service.dart';
import 'bom_animated_success_button.dart';
import 'bom_export_modal_dialog.dart';

/// "SHOW RECORD" LOOKUP MODAL FOR BILL OF MATERIALS
/// Cloned directly from Group Master's _GroupMasterRecordLookupModal architecture
/// with 100% ERP styling parity, A-Z alphabet bar, live filter, keyboard navigation,
/// and instant dual-pane state population.
class BomShowRecordModal extends StatefulWidget {
  final BomService bomService;
  final BomMode initialMode;
  final String? recentlySavedId;
  final String? glowingBomId;
  final bool isGlowingEdit;
  final ValueChanged<BomRecordSummary> onSelect;
  final VoidCallback? onExport;

  const BomShowRecordModal({
    super.key,
    required this.bomService,
    required this.initialMode,
    this.recentlySavedId,
    this.glowingBomId,
    this.isGlowingEdit = false,
    required this.onSelect,
    this.onExport,
  });

  @override
  State<BomShowRecordModal> createState() => _BomShowRecordModalState();
}

class _BomShowRecordModalState extends State<BomShowRecordModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  String _selectedModeFilter = 'ALL'; // 'ALL', 'JOB', 'REGULAR'
  String _selectedStatusFilter = 'ALL'; // 'ALL', 'OPEN', 'BLOCKED'

  int _highlightedIndex = 0;
  bool _isLoading = true;
  String? _deletingId;
  List<BomRecordSummary> _records = [];
  Timer? _debounce;
  String? _activeGlowingId;
  bool _isGlowingEdit = false;
  Timer? _glowTimer;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _selectedModeFilter = 'ALL';

    final targetGlowId = widget.recentlySavedId ?? widget.glowingBomId;
    if (targetGlowId != null && targetGlowId.isNotEmpty) {
      _activeGlowingId = targetGlowId;
      _isGlowingEdit = widget.isGlowingEdit;
      _glowTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _activeGlowingId = null;
          });
        }
      });
    }

    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
            _highlightedIndex = 0;
          });
        }
      });
    });

    _loadRecords();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    _keyboardFocusNode.dispose();
    _debounce?.cancel();
    _glowTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.bomService.fetchBomRecords();
      if (mounted) {
        setState(() {
          _records = list;
          _isLoading = false;
        });

        final targetId = _activeGlowingId;
        if (targetId != null && targetId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final filtered = _filteredRecords;
            final idx = filtered.indexWhere((r) => r.bomId.toUpperCase() == targetId.toUpperCase());
            if (idx >= 0) {
              setState(() => _highlightedIndex = idx);
              if (_tableScrollCtrl.hasClients) {
                final double targetOffset = math.max(0.0, (idx * 46.0) - 80.0);
                _tableScrollCtrl.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                );
              }
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<BomRecordSummary> get _filteredRecords {
    List<BomRecordSummary> list = List.from(_records);

    // 1. Mode Filter (ALL / JOB / REGULAR)
    if (_selectedModeFilter != 'ALL') {
      list = list.where((r) => r.bomType.toUpperCase() == _selectedModeFilter.toUpperCase()).toList();
    }

    // 2. Status Filter (ALL / OPEN / BLOCKED)
    if (_selectedStatusFilter != 'ALL') {
      list = list.where((r) => r.status.toUpperCase() == _selectedStatusFilter.toUpperCase()).toList();
    }

    // 3. Text Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) {
        return r.bomId.toLowerCase().contains(_searchQuery) ||
            r.iCode.toLowerCase().contains(_searchQuery) ||
            r.description.toLowerCase().contains(_searchQuery) ||
            r.strName.toLowerCase().contains(_searchQuery) ||
            r.depName.toLowerCase().contains(_searchQuery) ||
            r.bomPo.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 4. Alphabet Filter
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((r) {
          final first = r.description.trim().isNotEmpty ? r.description.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        final targetAlpha = _selectedAlphabet.toLowerCase();
        list = list.where((r) {
          final descStr = r.description.trim().toLowerCase();
          final codeStr = r.iCode.trim().toLowerCase();
          final idStr = r.bomId.trim().toLowerCase();
          return descStr.startsWith(targetAlpha) ||
              codeStr.startsWith(targetAlpha) ||
              idStr.startsWith(targetAlpha);
        }).toList();
      }
    }

    // Sort by Date descending, then ID descending
    list.sort((a, b) {
      final dateComp = b.bomDate.compareTo(a.bomDate);
      if (dateComp != 0) return dateComp;
      return b.bomId.compareTo(a.bomId);
    });

    return list;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final filtered = _filteredRecords;
    if (filtered.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_highlightedIndex < filtered.length - 1) {
        setState(() => _highlightedIndex++);
        _scrollToHighlighted();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_highlightedIndex > 0) {
        setState(() => _highlightedIndex--);
        _scrollToHighlighted();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_highlightedIndex >= 0 && _highlightedIndex < filtered.length) {
        _selectRecord(filtered[_highlightedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToHighlighted() {
    if (_tableScrollCtrl.hasClients) {
      final double targetOffset = math.max(0.0, (_highlightedIndex * 46.0) - 80.0);
      _tableScrollCtrl.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  void _panTable(double offsetDelta) {
    if (!_horizontalScrollCtrl.hasClients) return;
    final current = _horizontalScrollCtrl.offset;
    final maxExtent = _horizontalScrollCtrl.position.maxScrollExtent;
    final target = (current + offsetDelta).clamp(0.0, maxExtent);
    _horizontalScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectRecord(BomRecordSummary item) {
    widget.onSelect(item);
    Navigator.of(context).pop();
  }

  Future<void> _handleDelete(String bomId) async {
    final targetRecord = _records.cast<BomRecordSummary?>().firstWhere(
      (r) => r?.bomId.trim().toUpperCase() == bomId.trim().toUpperCase(),
      orElse: () => null,
    );
    if (targetRecord != null && targetRecord.status.trim().toUpperCase() == 'APPROVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete an approved BOM record.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _ConfirmDeleteDialog(
        title: 'Delete BOM Record?',
        message: 'Are you sure you want to permanently delete BOM "$bomId"? This action cannot be undone.',
        onDelete: () async {
          setState(() => _deletingId = bomId);
          final ok = await widget.bomService.deleteBom(bomId);
          setState(() => _deletingId = null);
          return ok;
        },
      ),
    );

    if (confirmed == true && mounted) {
      widget.bomService.clearRecordsCache();
      setState(() {
        _records.removeWhere((r) => r.bomId.trim().toUpperCase() == bomId.trim().toUpperCase());
        if (_highlightedIndex >= _filteredRecords.length && _filteredRecords.isNotEmpty) {
          _highlightedIndex = _filteredRecords.length - 1;
        }
      });
    }
  }

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(screenWidth * 0.96, 1720.0);
    final dialogHeight = math.min(screenHeight * 0.92, 820.0);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          constraints: const BoxConstraints(minWidth: 800, minHeight: 480),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 12),
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
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.manage_search_rounded, color: Color(0xFF0C3B2E), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Bill of Materials (BOM) Record',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 10),

                      // Count Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFA7D7B5)),
                        ),
                        child: Text(
                          '${filtered.length} / ${_records.length} Records',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
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
                              '↑/↓ navigate | Enter select | Esc close',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        splashRadius: 18,
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close (Esc)',
                      ),
                    ],
                  ),
                ),

                // 2. SEARCH BAR & FILTRATION ROW (WITH CONNECTED STEPPER NODE BARS)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Row(
                    children: [
                      // ULTRA-MODERN FROSTED GLASSMORPHISM SEARCH BAR
                      Expanded(
                        child: _BomGlassSearchBar(
                          controller: _searchCtrl,
                          hintText: 'Type to live filter by BOM ID, FG Code, Description, Plant, Dept, PO #...',
                          onClear: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      ),

                      const SizedBox(width: 14),

                      // 1. MODE FILTER CONNECTED STEPPER BAR (ROYAL BLUE / SKY BLUE / PURPLE)
                      _ConnectedStepperBar<String>(
                        selectedValue: _selectedModeFilter,
                        onSelected: (val) {
                          setState(() {
                            _selectedModeFilter = val;
                            _highlightedIndex = 0;
                          });
                        },
                        items: const [
                          _ConnectedStepperItem(
                            value: 'ALL',
                            label: 'ALL MODES',
                            stepNumber: '1',
                            activeColor: Color(0xFF2563EB),
                            glowColor: Color(0xFF60A5FA),
                            containerBgColor: Color(0xFFEFF6FF),
                            containerBorderColor: Color(0xFFBFDBFE),
                          ),
                          _ConnectedStepperItem(
                            value: 'JOB',
                            label: 'JOB (BMCJ)',
                            stepNumber: '2',
                            activeColor: Color(0xFF0284C7),
                            glowColor: Color(0xFF38BDF8),
                            containerBgColor: Color(0xFFF0F9FF),
                            containerBorderColor: Color(0xFFBAE6FD),
                          ),
                          _ConnectedStepperItem(
                            value: 'REGULAR',
                            label: 'REGULAR (BMCC)',
                            stepNumber: '3',
                            activeColor: Color(0xFF7C3AED),
                            glowColor: Color(0xFFA855F7),
                            containerBgColor: Color(0xFFFAF5FF),
                            containerBorderColor: Color(0xFFDDD6FE),
                          ),
                        ],
                      ),

                      const SizedBox(width: 12),

                      // 2. STATUS FILTER CONNECTED STEPPER BAR (AMBER GOLD / EMERALD GREEN / CRIMSON RED)
                      _ConnectedStepperBar<String>(
                        selectedValue: _selectedStatusFilter,
                        onSelected: (val) {
                          setState(() {
                            _selectedStatusFilter = val;
                            _highlightedIndex = 0;
                          });
                        },
                        items: const [
                          _ConnectedStepperItem(
                            value: 'ALL',
                            label: 'ALL STATUS',
                            stepNumber: '1',
                            activeColor: Color(0xFFD97706),
                            glowColor: Color(0xFFFBBF24),
                            containerBgColor: Color(0xFFFFFBEB),
                            containerBorderColor: Color(0xFFFDE68A),
                          ),
                          _ConnectedStepperItem(
                            value: 'OPEN',
                            label: 'OPEN',
                            stepNumber: '2',
                            activeColor: Color(0xFF059669),
                            glowColor: Color(0xFF34D399),
                            containerBgColor: Color(0xFFECFDF5),
                            containerBorderColor: Color(0xFFA7D7B5),
                          ),
                          _ConnectedStepperItem(
                            value: 'BLOCKED',
                            label: 'BLOCKED',
                            stepNumber: '3',
                            activeColor: Color(0xFFDC2626),
                            glowColor: Color(0xFFF87171),
                            containerBgColor: Color(0xFFFEF2F2),
                            containerBorderColor: Color(0xFFFECACA),
                          ),
                        ],
                      ),

                      if (widget.onExport != null) ...[
                        const SizedBox(width: 12),
                        Tooltip(
                          message: 'Export BOM Records',
                          child: BomAnimatedExportButton(
                            onPressed: widget.onExport!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. ALPHABETICAL A TO Z FILTRATION BAR & PAN CONTROLS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Alphabet Horizontal Filter
                      Expanded(
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
                                onTap: () => setState(() {
                                  _selectedAlphabet = alpha;
                                  _highlightedIndex = 0;
                                }),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: alpha == 'ALL' ? 12 : 9,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF059669) : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF059669).withValues(alpha: 0.25),
                                              blurRadius: 4,
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

                      const SizedBox(width: 12),

                      // Pan Table Columns (Round Arrow Circles - Replaces bottom scrollbar)
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.table_chart_outlined, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 4),
                            const Text(
                              'COLUMNS',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.4),
                            ),
                            const SizedBox(width: 6),
                            _PanCircleButton(
                              icon: Icons.chevron_left_rounded,
                              tooltip: 'Pan columns left',
                              onPressed: () => _panTable(-320.0),
                            ),
                            const SizedBox(width: 5),
                            _PanCircleButton(
                              icon: Icons.chevron_right_rounded,
                              tooltip: 'Pan columns right',
                              onPressed: () => _panTable(320.0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 4. DATA TABLE (RESPONSIVE & FULLY VISIBLE, NO BOTTOM SCROLLBAR)
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF059669)),
                              SizedBox(height: 12),
                              Text('Loading registered BOM records...', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                            ],
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 44, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No BOM records match your filter criteria',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Try changing search keyword, alphabet, or mode tab',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                const double minTableWidth = 1760.0;
                                final double tableWidth = math.max(constraints.maxWidth, minTableWidth);

                                return SingleChildScrollView(
                                  controller: _horizontalScrollCtrl,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: Column(
                                      children: [
                                        // Table Header Row with Vector Icons & Natural Color Accents (100% Group Master Parity)
                                        Container(
                                          height: 38,
                                          color: const Color(0xFFF8FAFC),
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: const Row(
                                            children: [
                                              // BOM ID
                                              SizedBox(
                                                width: 165,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.fingerprint_rounded, size: 13, color: Color(0xFF2563EB)),
                                                      SizedBox(width: 4),
                                                      Text('BOM ID', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // DATE
                                              SizedBox(
                                                width: 105,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF4F46E5)),
                                                      SizedBox(width: 4),
                                                      Text('DATE', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // TYPE
                                              SizedBox(
                                                width: 160,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.layers_rounded, size: 13, color: Color(0xFF7C3AED)),
                                                      SizedBox(width: 4),
                                                      Text('TYPE', style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // FINISHED GOOD CODE
                                              SizedBox(
                                                width: 190,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF0D9488)),
                                                      SizedBox(width: 4),
                                                      Text('FG CODE', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // DESCRIPTION
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 12),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.category_rounded, size: 13, color: Color(0xFF059669)),
                                                      SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          'FG DESCRIPTION',
                                                          style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // PLANT / STORE
                                              SizedBox(
                                                width: 160,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF0284C7)),
                                                      SizedBox(width: 4),
                                                      Text('PLANT', style: TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // DEPARTMENT
                                              SizedBox(
                                                width: 155,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.domain_rounded, size: 13, color: Color(0xFF8B5CF6)),
                                                      SizedBox(width: 4),
                                                      Text('DEPARTMENT', style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),
                                              ),

                                              // BASE QTY
                                              SizedBox(
                                                width: 95,
                                                child: Padding(
                                                  padding: EdgeInsets.only(right: 8),
                                                  child: Text(
                                                    'BASE QTY',
                                                    style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                    textAlign: TextAlign.right,
                                                  ),
                                                ),
                                              ),

                                              // PO #
                                              SizedBox(
                                                width: 95,
                                                child: Center(
                                                  child: Text(
                                                    'PO #',
                                                    style: TextStyle(color: Color(0xFFEA580C), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                  ),
                                                ),
                                              ),

                                              // STATUS
                                              SizedBox(
                                                width: 90,
                                                child: Center(
                                                  child: Text(
                                                    'STATUS',
                                                    style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                  ),
                                                ),
                                              ),

                                              // COMPONENTS
                                              SizedBox(
                                                width: 110,
                                                child: Center(
                                                  child: Text(
                                                    'RECIPE ITEMS',
                                                    style: TextStyle(color: Color(0xFF0891B2), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                  ),
                                                ),
                                              ),

                                              // ACTIONS
                                              SizedBox(
                                                width: 85,
                                                child: Center(
                                                  child: Text(
                                                    'ACTIONS',
                                                    style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.3),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                        // ListView Rows
                                        Expanded(
                                          child: ListView.separated(
                                            controller: _tableScrollCtrl,
                                            padding: EdgeInsets.zero,
                                            itemCount: filtered.length,
                                            separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                            itemBuilder: (ctx, idx) {
                                              final item = filtered[idx];
                                              final isDeleting = _deletingId == item.bomId;
                                              final isHighlighted = idx == _highlightedIndex;
                                              final isGlow = _activeGlowingId != null &&
                                                  _activeGlowingId!.toUpperCase() == item.bomId.toUpperCase();

                                              return _BomRecordLookupRow(
                                                item: item,
                                                formattedDate: _formatDate(item.bomDate),
                                                idx: idx,
                                                isHighlighted: isHighlighted,
                                                isGlow: isGlow,
                                                isGlowingEdit: _isGlowingEdit,
                                                isDeleting: isDeleting,
                                                onSelect: () => _selectRecord(item),
                                                onDelete: () => _handleDelete(item.bomId),
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
      ),
    );
  }

}

// ============================================================================
// ULTRA-MODERN FROSTED GLASSMORPHISM SEARCH BAR WIDGET
// ============================================================================
class _BomGlassSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onClear;

  const _BomGlassSearchBar({
    required this.controller,
    required this.hintText,
    required this.onClear,
  });

  @override
  State<_BomGlassSearchBar> createState() => _BomGlassSearchBarState();
}

class _BomGlassSearchBarState extends State<_BomGlassSearchBar> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant _BomGlassSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 42,
            decoration: BoxDecoration(
              // Translucent frosted glass surface gradient
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isFocused
                    ? [
                        Colors.white.withValues(alpha: 0.98),
                        const Color(0xFFF0FDF4).withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.92),
                      ]
                    : _isHovered
                        ? [
                            Colors.white.withValues(alpha: 0.95),
                            const Color(0xFFF8FAFC).withValues(alpha: 0.78),
                            const Color(0xFFF1F5F9).withValues(alpha: 0.58),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.88),
                            const Color(0xFFF8FAFC).withValues(alpha: 0.68),
                            const Color(0xFFF1F5F9).withValues(alpha: 0.45),
                          ],
                stops: const [0.0, 0.48, 1.0],
              ),
              borderRadius: BorderRadius.circular(22),
              // Specular glass perimeter border
              border: Border.all(
                color: _isFocused
                    ? const Color(0xFF059669).withValues(alpha: 0.75)
                    : _isHovered
                        ? const Color(0xFF10B981).withValues(alpha: 0.48)
                        : const Color(0xFFCBD5E1).withValues(alpha: 0.75),
                width: _isFocused ? 1.6 : 1.2,
              ),
              boxShadow: [
                // Soft ambient diffuse drop shadow
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: _isFocused ? 0.08 : (_isHovered ? 0.05 : 0.03)),
                  blurRadius: _isFocused ? 14 : 9,
                  offset: const Offset(0, 3),
                ),
                // Specular top-left light catch reflection
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.95),
                  blurRadius: 2,
                  offset: const Offset(-1.5, -1.5),
                  spreadRadius: 0.5,
                ),
                // Bottom-right subtle glass edge refraction
                BoxShadow(
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.12),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
                // Luminous emerald focus glow aura
                if (_isFocused)
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.24),
                    blurRadius: 15,
                    spreadRadius: 1.8,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 6),
                // Frosted Glass Magnifying Lens Badge
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isFocused
                          ? [
                              const Color(0xFFD1FAE5),
                              const Color(0xFFA7F3D0).withValues(alpha: 0.8),
                            ]
                          : _isHovered
                              ? [
                                  const Color(0xFFE6F4EA),
                                  const Color(0xFFF0FDF4).withValues(alpha: 0.9),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.92),
                                  const Color(0xFFF1F5F9).withValues(alpha: 0.7),
                                ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isFocused
                          ? const Color(0xFF059669).withValues(alpha: 0.40)
                          : Colors.white.withValues(alpha: 0.95),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFocused
                            ? const Color(0xFF059669).withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.search_rounded,
                      size: 16.5,
                      color: _isFocused ? const Color(0xFF059669) : const Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Search Input Text Field
                Expanded(
                  child: Focus(
                    onFocusChange: (focus) => setState(() => _isFocused = focus),
                    child: TextField(
                      controller: widget.controller,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                        letterSpacing: 0.1,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),

                // Trailing Indicators and Clear Action
                if (hasText) ...[
                  // Live Filtering Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5).withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFA7F3D0).withValues(alpha: 0.85),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5.5,
                          height: 5.5,
                          decoration: const BoxDecoration(
                            color: Color(0xFF059669),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Frosted Circular Clear Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onClear,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9).withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CONNECTED STEPPER BAR COMPONENT (MATCHING REFERENCE IMAGE 3 PARITY)
// ============================================================================

class _ConnectedStepperItem<T> {
  final T value;
  final String label;
  final String stepNumber;
  final Color activeColor;
  final Color glowColor;
  final Color? containerBgColor;
  final Color? containerBorderColor;

  const _ConnectedStepperItem({
    required this.value,
    required this.label,
    required this.stepNumber,
    required this.activeColor,
    required this.glowColor,
    this.containerBgColor,
    this.containerBorderColor,
  });
}

class _ConnectedStepperBar<T> extends StatelessWidget {
  final List<_ConnectedStepperItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onSelected;

  const _ConnectedStepperBar({
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedItem = items.firstWhere(
      (it) => it.value == selectedValue,
      orElse: () => items.first,
    );
    final bgColor = selectedItem.containerBgColor ?? selectedItem.activeColor.withValues(alpha: 0.08);
    final borderColor = selectedItem.containerBorderColor ?? selectedItem.activeColor.withValues(alpha: 0.28);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: selectedItem.glowColor.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Horizontal connecting line between step circles
            final prevItemIndex = index ~/ 2;
            final nextItemIndex = prevItemIndex + 1;
            final isConnectedActive = items[prevItemIndex].value == selectedValue ||
                items[nextItemIndex].value == selectedValue;
            final activeColor = items[prevItemIndex].value == selectedValue
                ? items[prevItemIndex].activeColor
                : items[nextItemIndex].activeColor;

            return Container(
              width: 18,
              height: 2.2,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isConnectedActive
                    ? activeColor.withValues(alpha: 0.55)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }

          final itemIndex = index ~/ 2;
          final item = items[itemIndex];
          final isSelected = item.value == selectedValue;

          return InkWell(
            onTap: () => onSelected(item.value),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Step Circle Node with Halo Glow
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? item.activeColor : Colors.white,
                      border: Border.all(
                        color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        width: isSelected ? 2.0 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: item.glowColor.withValues(alpha: 0.65),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                              BoxShadow(
                                color: item.glowColor.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Center(
                      child: Text(
                        item.stepNumber,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // 2. Underline Step Dashes (Exact Parity with Reference Image)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 16,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: isSelected ? item.activeColor : const Color(0xFFCBD5E1).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 11,
                    height: 1.8,
                    decoration: BoxDecoration(
                      color: isSelected ? item.activeColor.withValues(alpha: 0.8) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),

                  const SizedBox(height: 3),

                  // 3. Step Label
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? item.activeColor : const Color(0xFF64748B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ============================================================================
// PAN CIRCLE BUTTON (PAN TABLE LEFT / RIGHT INSTEAD OF BOTTOM SCROLLBAR)
// ============================================================================

class _PanCircleButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PanCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_PanCircleButton> createState() => _PanCircleButtonState();
}

class _PanCircleButtonState extends State<_PanCircleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered ? const Color(0xFFECFDF5) : Colors.white,
              border: Border.all(
                color: _isHovered ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                width: 1.2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 16,
                color: _isHovered ? const Color(0xFF059669) : const Color(0xFF334155),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// STANDALONE ROW ITEM FOR BOM SHOW RECORD TABLE (100% GROUP MASTER PARITY)
// ============================================================================

class _BomRecordLookupRow extends StatefulWidget {
  final BomRecordSummary item;
  final String formattedDate;
  final int idx;
  final bool isHighlighted;
  final bool isGlow;
  final bool isGlowingEdit;
  final bool isDeleting;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _BomRecordLookupRow({
    required this.item,
    required this.formattedDate,
    required this.idx,
    required this.isHighlighted,
    required this.isGlow,
    this.isGlowingEdit = false,
    required this.isDeleting,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  State<_BomRecordLookupRow> createState() => _BomRecordLookupRowState();
}

class _BomRecordLookupRowState extends State<_BomRecordLookupRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isJob = item.bomType.toUpperCase() == 'JOB';
    final isOpen = item.status.toUpperCase() == 'OPEN';
    final isGlowing = widget.isGlow;
    final isGlowingEdit = widget.isGlowingEdit;

    final glowColor = isGlowingEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    Color rowBgColor;
    Color? rowBorderColor;
    List<BoxShadow> rowShadows = [];

    if (isGlowing) {
      rowBgColor = glowColor.withValues(alpha: 0.12);
      rowBorderColor = glowColor;
      rowShadows = [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.40),
          blurRadius: 10,
          spreadRadius: 1.5,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (widget.isHighlighted || _isHovered) {
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
      rowBgColor = widget.idx % 2 == 0 ? const Color(0xFFFAFAFA) : Colors.white;
    }

    final rawPrefix = item.bomId.contains('/')
        ? item.bomId.split('/').first.trim().toUpperCase()
        : (item.bomId.length >= 4 ? item.bomId.substring(0, 4).toUpperCase() : (isJob ? 'BMCJ' : 'BMCC'));
    final String bomPrefix = rawPrefix.isNotEmpty ? rawPrefix : (isJob ? 'BMCJ' : 'BMCC');

    Color badgeBg;
    Color badgeBorder;
    Color badgeChipColor;
    Color badgeTextColor;

    if (bomPrefix == 'BMCJ' || bomPrefix == 'BMBS') {
      badgeChipColor = const Color(0xFF2563EB);
      badgeBg = const Color(0xFFEFF6FF);
      badgeBorder = const Color(0xFFBFDBFE);
      badgeTextColor = const Color(0xFF1D4ED8);
    } else if (bomPrefix == 'BMBR') {
      badgeChipColor = const Color(0xFFD97706);
      badgeBg = const Color(0xFFFEF3C7);
      badgeBorder = const Color(0xFFFDE68A);
      badgeTextColor = const Color(0xFFB45309);
    } else if (bomPrefix == 'BMCC') {
      badgeChipColor = const Color(0xFF7C3AED);
      badgeBg = const Color(0xFFF5F3FF);
      badgeBorder = const Color(0xFFDDD6FE);
      badgeTextColor = const Color(0xFF6D28D9);
    } else {
      badgeChipColor = isJob ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);
      badgeBg = isJob ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF);
      badgeBorder = isJob ? const Color(0xFFBFDBFE) : const Color(0xFFDDD6FE);
      badgeTextColor = isJob ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: rowBgColor,
          border: rowBorderColor != null
              ? Border.all(color: rowBorderColor, width: isGlowing ? 2.0 : 1.0)
              : null,
          boxShadow: rowShadows,
        ),
        child: InkWell(
          onTap: widget.onSelect,
          child: Row(
            children: [
              // 1. BOM ID (Pill Badge with Prefix Chip & Custom Color)
              SizedBox(
                width: 165,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: badgeBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: badgeChipColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  bomPrefix,
                                  style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  item.bomId,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: badgeTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isGlowing) ...[
                        const SizedBox(width: 4),
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
              ),

              // 2. DATE
              SizedBox(
                width: 105,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.formattedDate,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                  ),
                ),
              ),

              // 3. TYPE (Soft Pill Badge)
              SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isJob ? const Color(0xFFEFF6FF) : const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isJob ? const Color(0xFFBFDBFE) : const Color(0xFFDDD6FE),
                          width: 0.8,
                        ),
                      ),
                      child: Tooltip(
                        message: item.bomType,
                        child: Text(
                          item.bomType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isJob ? const Color(0xFF1D4ED8) : const Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. FG CODE
              SizedBox(
                width: 190,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    item.iCode,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 5. FG DESCRIPTION
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: item.description,
                    child: Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: (widget.isGlow || _isHovered) ? FontWeight.w800 : FontWeight.w600,
                        color: widget.isGlow ? const Color(0xFF047857) : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // 6. PLANT
              SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: item.strName.isNotEmpty ? item.strName : 'Plant #${item.strCode}',
                    child: Text(
                      item.strName.isNotEmpty ? item.strName : 'Plant #${item.strCode}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // 7. DEPARTMENT
              SizedBox(
                width: 155,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: item.depName.isNotEmpty ? item.depName : 'Dept #${item.depCode}',
                    child: Text(
                      item.depName.isNotEmpty ? item.depName : 'Dept #${item.depCode}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // 8. BASE QTY
              SizedBox(
                width: 95,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${item.qty.toStringAsFixed(0)} ${item.unitName}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                  ),
                ),
              ),

              // 9. PO #
              SizedBox(
                width: 95,
                child: Center(
                  child: Text(
                    item.bomPo.isNotEmpty ? item.bomPo : '-',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: item.bomPo.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                      color: item.bomPo.isNotEmpty ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // 10. STATUS BADGE
              SizedBox(
                width: 90,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? const Color(0xFFECFDF5)
                          : (item.status.toUpperCase() == 'APPROVED' ? const Color(0xFFEFF6FF) : const Color(0xFFFEF2F2)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOpen
                            ? const Color(0xFFA7D7B5)
                            : (item.status.toUpperCase() == 'APPROVED' ? const Color(0xFFBFDBFE) : const Color(0xFFFECACA)),
                      ),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isOpen
                            ? const Color(0xFF059669)
                            : (item.status.toUpperCase() == 'APPROVED' ? const Color(0xFF2563EB) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
                ),
              ),

              // 11. COMPONENTS COUNT PILL
              SizedBox(
                width: 110,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCFBF1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF99F6E4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_rounded, size: 11, color: Color(0xFF0F766E)),
                        const SizedBox(width: 4),
                        Text(
                          '${item.subItemCount} Items',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 12. ACTIONS (Clean Buttons, No Outer Box)
              SizedBox(
                width: 85,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ActionIconButton(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF059669),
                        hoverBg: const Color(0xFFECFDF5),
                        tooltip: 'Edit BOM',
                        onPressed: widget.onSelect,
                      ),
                      const SizedBox(width: 4),
                      widget.isDeleting
                          ? const SizedBox(
                              width: 26,
                              height: 26,
                              child: Padding(
                                padding: EdgeInsets.all(5.0),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                              ),
                            )
                          : (widget.item.status.trim().toUpperCase() == 'APPROVED'
                              ? const Tooltip(
                                  message: 'Locked (Approved) — Cannot delete',
                                  child: Padding(
                                    padding: EdgeInsets.all(5.0),
                                    child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                                  ),
                                )
                              : _ActionIconButton(
                                  icon: Icons.delete_outline_rounded,
                                  color: const Color(0xFFEF4444),
                                  hoverBg: const Color(0xFFFEF2F2),
                                  tooltip: 'Delete BOM',
                                  onPressed: widget.onDelete,
                                )),
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

/// Standardized Delete Confirmation Dialog matching Group Master
class _ConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.onDelete,
  });

  @override
  State<_ConfirmDeleteDialog> createState() => _ConfirmDeleteDialogState();
}

class _ConfirmDeleteDialogState extends State<_ConfirmDeleteDialog> {
  ButtonStatus _status = ButtonStatus.idle;

  Future<void> _handleDelete() async {
    setState(() => _status = ButtonStatus.loading);
    final ok = await widget.onDelete();
    if (ok) {
      if (mounted) {
        setState(() => _status = ButtonStatus.success);
      }
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      if (mounted) {
        setState(() => _status = ButtonStatus.idle);
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 28, color: Color(0xFFDC2626)),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _status == ButtonStatus.loading || _status == ButtonStatus.success
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BomAnimatedSuccessButton(
                    status: _status,
                    onPressed: _handleDelete,
                    idleText: 'Delete',
                    loadingText: 'Deleting...',
                    successText: 'Deleted!',
                    idleIcon: Icons.delete_rounded,
                    idleBackgroundColor: const Color(0xFFDC2626),
                    successBackgroundColor: const Color(0xFFEF4444),
                    height: 38,
                    borderRadius: BorderRadius.circular(8),
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
// SLEEK ACTION BUTTON WITH HOVER STATE ANIMATION (MATCHING PROJECT MASTER)
// ============================================================================
class _ActionIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color hoverBg;
  final String tooltip;
  final VoidCallback? onPressed;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    required this.hoverBg,
    required this.tooltip,
    this.onPressed,
  });

  @override
  State<_ActionIconButton> createState() => _ActionIconButtonState();
}

class _ActionIconButtonState extends State<_ActionIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;
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
              color: (_isHovered && isEnabled) ? widget.hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: isEnabled ? widget.color : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}
