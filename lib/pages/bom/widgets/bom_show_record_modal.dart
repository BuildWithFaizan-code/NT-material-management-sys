import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bom_models.dart';
import '../bom_service.dart';
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
  final ValueChanged<BomRecordSummary> onSelect;
  final VoidCallback? onExport;

  const BomShowRecordModal({
    super.key,
    required this.bomService,
    required this.initialMode,
    this.recentlySavedId,
    this.glowingBomId,
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

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _selectedModeFilter = 'ALL';

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

        final targetId = widget.recentlySavedId ?? widget.glowingBomId;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('BOM $bomId deleted successfully.'),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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

                // 2. SEARCH BAR & FILTRATION ROW
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      // SEARCH INPUT
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              hintText: 'Type to live filter by BOM ID, FG Code, Description, Plant, Dept, PO #...',
                              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF0C3B2E)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF0C3B2E), width: 1.8)),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // MODE FILTER TABS (ALL / JOB / REGULAR)
                      Container(
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildModeFilterTab('ALL', 'All Modes'),
                            _buildModeFilterTab('JOB', 'JOB (BMCJ)', color: const Color(0xFF0C3B2E)),
                            _buildModeFilterTab('REGULAR', 'REGULAR (BMCC)', color: const Color(0xFF0C3B2E)),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      // STATUS FILTER SEGMENT
                      Container(
                        height: 38,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _buildStatusFilterTab('ALL', 'All Status'),
                            _buildStatusFilterTab('OPEN', 'OPEN', color: const Color(0xFF0C3B2E)),
                            _buildStatusFilterTab('BLOCKED', 'BLOCKED', color: const Color(0xFFDC2626)),
                          ],
                        ),
                      ),

                      if (widget.onExport != null) ...[
                        const SizedBox(width: 10),
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
                              color: isSelected ? const Color(0xFF0C3B2E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0C3B2E).withValues(alpha: 0.25),
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

                const SizedBox(height: 8),

                // 4. DATA TABLE (RESPONSIVE & FULLY VISIBLE)
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF0C3B2E)),
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
                                const double minTableWidth = 1680.0;
                                final double tableWidth = math.max(constraints.maxWidth, minTableWidth);

                                return Scrollbar(
                                  controller: _horizontalScrollCtrl,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollCtrl,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      child: Column(
                                        children: [
                                          // Table Header Row
                                          Container(
                                            height: 42,
                                            color: const Color(0xFFF8FAFC),
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: const Row(
                                              children: [
                                                // BOM ID
                                                SizedBox(
                                                  width: 155,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.fingerprint_rounded, size: 13, color: Color(0xFF64748B)),
                                                      SizedBox(width: 5),
                                                      Text('BOM ID', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),

                                                // DATE
                                                SizedBox(
                                                  width: 105,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF64748B)),
                                                      SizedBox(width: 5),
                                                      Text('DATE', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),

                                                // TYPE
                                                SizedBox(
                                                  width: 120,
                                                  child: Center(
                                                    child: Text('TYPE', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                  ),
                                                ),

                                                // FINISHED GOOD CODE
                                                SizedBox(
                                                  width: 190,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.qr_code_2_rounded, size: 13, color: Color(0xFF64748B)),
                                                      SizedBox(width: 5),
                                                      Text('FG CODE', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),

                                                // DESCRIPTION
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(right: 12),
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.inventory_2_outlined, size: 13, color: Color(0xFF64748B)),
                                                        SizedBox(width: 5),
                                                        Flexible(
                                                          child: Text(
                                                            'FG DESCRIPTION',
                                                            style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3),
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
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.storefront_rounded, size: 13, color: Color(0xFF64748B)),
                                                      SizedBox(width: 5),
                                                      Text('PLANT', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),

                                                // DEPARTMENT
                                                SizedBox(
                                                  width: 155,
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.business_rounded, size: 13, color: Color(0xFF64748B)),
                                                      SizedBox(width: 5),
                                                      Text('DEPARTMENT', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                    ],
                                                  ),
                                                ),

                                                // QTY
                                                SizedBox(
                                                  width: 95,
                                                  child: Padding(
                                                    padding: EdgeInsets.only(right: 8),
                                                    child: Text('BASE QTY', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3), textAlign: TextAlign.right),
                                                  ),
                                                ),

                                                // PO #
                                                SizedBox(
                                                  width: 95,
                                                  child: Center(
                                                    child: Text('PO #', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3)),
                                                  ),
                                                ),

                                                // STATUS
                                                SizedBox(
                                                  width: 85,
                                                  child: Center(child: Text('STATUS', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3))),
                                                ),

                                                // COMPONENTS COUNT
                                                SizedBox(
                                                  width: 105,
                                                  child: Center(child: Text('COMPONENTS', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3))),
                                                ),

                                                // ACTIONS
                                                SizedBox(
                                                  width: 120,
                                                  child: Center(child: Text('ACTION', style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 10.5, letterSpacing: 0.3))),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const Divider(height: 1, color: Color(0xFFE2E8F0)),

                                          // ListView Rows
                                          Expanded(
                                            child: ListView.separated(
                                              controller: _tableScrollCtrl,
                                              itemCount: filtered.length,
                                              separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                              itemBuilder: (ctx, idx) {
                                                final item = filtered[idx];
                                                final isDeleting = _deletingId == item.bomId;
                                                final isHighlighted = idx == _highlightedIndex;
                                                final isGlow = widget.recentlySavedId == item.bomId ||
                                                    widget.glowingBomId == item.bomId;

                                                return _BomRecordLookupRow(
                                                  item: item,
                                                  formattedDate: _formatDate(item.bomDate),
                                                  idx: idx,
                                                  isHighlighted: isHighlighted,
                                                  isGlow: isGlow,
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

  Widget _buildModeFilterTab(String modeKey, String label, {Color? color}) {
    final isSelected = _selectedModeFilter == modeKey;
    final tabColor = color ?? const Color(0xFF475569);

    return InkWell(
      onTap: () => setState(() {
        _selectedModeFilter = modeKey;
        _highlightedIndex = 0;
      }),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? tabColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusFilterTab(String statusKey, String label, {Color? color}) {
    final isSelected = _selectedStatusFilter == statusKey;
    final tabColor = color ?? const Color(0xFF0F172A);

    return InkWell(
      onTap: () => setState(() {
        _selectedStatusFilter = statusKey;
        _highlightedIndex = 0;
      }),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? (color?.withValues(alpha: 0.12) ?? const Color(0xFFE2E8F0)) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? tabColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

/// Standalone row item for BOM Show Record table
class _BomRecordLookupRow extends StatefulWidget {
  final BomRecordSummary item;
  final String formattedDate;
  final int idx;
  final bool isHighlighted;
  final bool isGlow;
  final bool isDeleting;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _BomRecordLookupRow({
    required this.item,
    required this.formattedDate,
    required this.idx,
    required this.isHighlighted,
    required this.isGlow,
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

    Color rowBg = widget.idx.isEven ? Colors.white : const Color(0xFFFAFAFA);
    if (widget.isHighlighted || _isHovered) {
      rowBg = const Color(0xFFF1F5F9);
    } else if (widget.isGlow) {
      rowBg = const Color(0xFFE6F4EA);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: rowBg,
          border: widget.isGlow
              ? Border.all(color: const Color(0xFF0C3B2E), width: 1.5)
              : (widget.isHighlighted
                  ? Border.all(color: const Color(0xFF0C3B2E), width: 1.2)
                  : null),
        ),
        child: InkWell(
          onTap: widget.onSelect,
          child: Row(
            children: [
              // BOM ID
              SizedBox(
                width: 155,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          isJob ? 'BMCJ' : 'BMCC',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.bomId,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0C3B2E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // DATE
              SizedBox(
                width: 105,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    widget.formattedDate,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                  ),
                ),
              ),

              // TYPE BADGE
              SizedBox(
                width: 120,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Tooltip(
                      message: item.bomType,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          item.bomType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // FG CODE
              SizedBox(
                width: 190,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    item.iCode,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // DESCRIPTION
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: item.description,
                    child: Text(
                      item.description,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // PLANT
              SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: item.strName.isNotEmpty ? item.strName : 'Plant #${item.strCode}',
                    child: Text(
                      item.strName.isNotEmpty ? item.strName : 'Plant #${item.strCode}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // DEPARTMENT
              SizedBox(
                width: 155,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Tooltip(
                    message: item.depName.isNotEmpty ? item.depName : 'Dept #${item.depCode}',
                    child: Text(
                      item.depName.isNotEmpty ? item.depName : 'Dept #${item.depCode}',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // QTY & UQC
              SizedBox(
                width: 95,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${item.qty.toStringAsFixed(0)} ${item.unitName}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                ),
              ),

              // PO #
              SizedBox(
                width: 95,
                child: Center(
                  child: Text(
                    item.bomPo.isNotEmpty ? item.bomPo : '-',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // STATUS BADGE
              SizedBox(
                width: 85,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isOpen ? const Color(0xFFE6F4EA) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isOpen ? const Color(0xFFA7D7B5) : const Color(0xFFFECACA)),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isOpen ? const Color(0xFF0C3B2E) : const Color(0xFF991B1B),
                      ),
                    ),
                  ),
                ),
              ),

              // COMPONENTS COUNT PILL
              SizedBox(
                width: 105,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.layers_outlined, size: 12, color: Color(0xFF475569)),
                        const SizedBox(width: 4),
                        Text(
                          '${item.subItemCount} Items',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ACTIONS (SELECT & DELETE)
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onSelect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        elevation: 0,
                      ),
                      child: const Text('Select', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    widget.isDeleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626)),
                          )
                        : (widget.item.status.trim().toUpperCase() == 'APPROVED'
                            ? const Tooltip(
                                message: 'Locked (Approved) — Cannot delete',
                                child: Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                                ),
                              )
                            : IconButton(
                                onPressed: widget.onDelete,
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                splashRadius: 13,
                                padding: EdgeInsets.zero,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(24, 24),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                tooltip: 'Delete BOM',
                              )),
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

/// Standardized Delete Confirmation Dialog matching Group Master
class _ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteDialog({
    required this.title,
    required this.message,
    required this.onDelete,
  });

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
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
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
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await onDelete();
                      if (context.mounted) {
                        Navigator.of(context).pop(ok);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
