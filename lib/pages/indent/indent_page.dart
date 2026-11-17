import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import '../bom/bom_models.dart';
import '../bom/widgets/bom_animated_success_button.dart';
import 'indent_models.dart';
import 'indent_service.dart';
import 'widgets/indent_export_modal_dialog.dart';
import 'widgets/indent_wizard_dialog.dart';

String _formatIndentDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Main Screen with Department Master Glassmorphism & Project Master Glow Strategy
class IndentPage extends StatefulWidget {
  const IndentPage({super.key});

  @override
  State<IndentPage> createState() => _IndentPageState();
}

class _IndentPageState extends State<IndentPage> with TickerProviderStateMixin {
  final IndentService _service = IndentService();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();

  Timer? _searchDebounce;
  bool _isLoading = false;
  String? _errorMessage;

  List<IndentHeader> _indents = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 25;

  DateTime? _fromDate;
  DateTime? _toDate;

  // New & Update Entry Glow Strategy (from Project Master)
  String? _glowingIndCode;
  bool _isGlowingEdit = false;
  Timer? _glowTimer;

  @override
  void initState() {
    super.initState();
    _loadIndents();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _searchDebounce?.cancel();
    _glowTimer?.cancel();
    super.dispose();
  }

  void _triggerGlow(String indCode, {bool isEdit = false}) {
    _glowTimer?.cancel();
    setState(() {
      _glowingIndCode = indCode;
      _isGlowingEdit = isEdit;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tableScrollCtrl.hasClients) {
        final idx = _indents.indexWhere((i) => i.indCode == indCode);
        if (idx != -1) {
          final targetOffset = (idx * 40.0) - 80.0;
          _tableScrollCtrl.animateTo(
            targetOffset.clamp(0.0, _tableScrollCtrl.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    _glowTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _glowingIndCode = null;
          _isGlowingEdit = false;
        });
      }
    });
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _currentPage = 1);
      _loadIndents();
    });
  }

  Future<void> _loadIndents({String? newlySavedCode, bool isEdit = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.fetchIndents(
        search: _searchCtrl.text.trim(),
        fromDate: _fromDate,
        toDate: _toDate,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _indents = res.items;
          _totalCount = res.totalCount;
          _isLoading = false;
        });

        if (newlySavedCode != null && newlySavedCode.isNotEmpty) {
          _triggerGlow(newlySavedCode, isEdit: isEdit);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('ApiException: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _openNewEntryDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => IndentWizardDialog(
        service: _service,
        onSaved: () {
          _loadIndents();
        },
      ),
    );
  }

  Future<void> _openEditEntryDialog(IndentHeader indent) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF0C3B2E)),
        ),
      ),
    );

    try {
      final full = await _service.fetchIndentByCode(indent.indCode);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (full == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text('Could not fetch details for indent ${indent.indCode}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => IndentWizardDialog(
          service: _service,
          initialIndent: full,
          onSaved: () {
            _loadIndents(newlySavedCode: indent.indCode, isEdit: true);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString().replaceAll('ApiException: ', '')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteIndent(IndentHeader indent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ConfirmDeleteDialog(
        title: 'Delete Indent Voucher?',
        message: 'Are you sure you want to delete indent "${indent.indCode}"? Any linked requisitions will be released.',
        onDelete: () async {
          await _service.deleteIndent(indent.indCode);
        },
      ),
    );

    if (confirmed == true && mounted) {
      _loadIndents();
    }
  }

  void _openExportDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => IndentExportModalDialog(records: _indents),
    );
  }

  // Header Metrics Calculations
  int get _todayCount {
    final now = DateTime.now();
    return _indents.where((i) => i.indDate.year == now.year && i.indDate.month == now.month && i.indDate.day == now.day).length;
  }

  double get _totalAggregateAmount {
    return _indents.fold(0.0, (acc, i) => acc + i.totAmt);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 1. TOP HEADER BAR WITH KPI GAUGE CARDS (DEPARTMENT MASTER STYLE)
                  _buildTopHeaderBar(),
                  const SizedBox(height: 14),

                  // 2. TOOLBAR WITH SEARCH, FILTERS, ORBIT EXPORT & NEW ENTRY BUTTON
                  _buildTopToolbar(),
                  const SizedBox(height: 12),

                  // 3. MAIN CORPORATE DATA TABLE (COMPACT 38PX ROWS)
                  Expanded(
                    child: _buildMainTableContainer(),
                  ),
                  const SizedBox(height: 10),

                  // 4. PAGINATION FOOTER
                  _buildPaginationFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER BAR (DEPARTMENT MASTER MATCH)
  // ============================================================================
  Widget _buildTopHeaderBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title & Icon
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF0C3B2E).withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.note_alt_outlined, color: Color(0xFF0C3B2E), size: 26),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Create Indent (Indent Master)',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF000000),
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Manage plant material indents, store locations & inventory indents',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Modern Circular KPI Gauge Cards
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderKpiCard(
                    label: 'TOTAL INDENTS',
                    value: '$_totalCount',
                    progress: _totalCount > 0 ? 0.8 : 0.0,
                    gradientColors: const [Color(0xFF2563EB), Color(0xFF06B6D4)],
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderKpiCard(
                    label: 'TODAY INDENTS',
                    value: '$_todayCount',
                    progress: _todayCount > 0 ? 0.6 : 0.0,
                    gradientColors: const [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                  ),
                  const SizedBox(width: 10),
                  _buildHeaderKpiCard(
                    label: 'TOTAL VALUE',
                    value: '₹ ${_totalAggregateAmount.toStringAsFixed(0)}',
                    progress: _totalAggregateAmount > 0 ? 0.9 : 0.0,
                    gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderKpiCard({
    required String label,
    required String value,
    required double progress,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 120,
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradientColors.first.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3.2,
                  backgroundColor: gradientColors.first.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(gradientColors.first),
                ),
                Icon(Icons.trending_up_rounded, size: 14, color: gradientColors.first),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: gradientColors.first),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. TOP TOOLBAR
  // ============================================================================
  Widget _buildTopToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
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
          // Search Input Field
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: 'Search by Indent No, Department, Store, Remark...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchCtrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                      child: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Date Filter Pill
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(
              _fromDate == null
                  ? 'All Dates'
                  : '${_formatIndentDate(_fromDate!)} - ${_formatIndentDate(_toDate ?? DateTime.now())}',
              style: const TextStyle(fontSize: 12),
            ),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
                initialDateRange: _fromDate != null && _toDate != null
                    ? DateTimeRange(start: _fromDate!, end: _toDate!)
                    : null,
              );
              if (range != null) {
                setState(() {
                  _fromDate = range.start;
                  _toDate = range.end;
                  _currentPage = 1;
                });
                _loadIndents();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.neutralDark,
              side: BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),

          if (_fromDate != null) ...[
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.grey),
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                  _currentPage = 1;
                });
                _loadIndents();
              },
              tooltip: 'Clear Date Filter',
            ),
          ],
          const SizedBox(width: 10),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Color(0xFF475569)),
            onPressed: _loadIndents,
            tooltip: 'Refresh Records',
          ),
          const SizedBox(width: 8),

          // Orbit Animated Export Button (Project Master 3D Logo / Orbit Style)
          IndentAnimatedExportButton(onPressed: _openExportDialog),
          const SizedBox(width: 12),

          // New Entry Button (Exact Project Master Styling)
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Entry', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            onPressed: _openNewEntryDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0C3B2E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 3. MAIN CORPORATE DATA TABLE (COMPACT 38PX ROWS)
  // ============================================================================
  Widget _buildMainTableContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // COLUMN HEADER ROW (SLATE / FOREST THEME)
            Container(
              height: 36,
              color: const Color(0xFF0C3B2E),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(width: 45, child: Text('SRNO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 140, child: Text('INDENT NO', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 95, child: Text('DATE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('DEPARTMENT', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('LOCATION / STORE', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 90, child: Text('PRIORITY', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 65, child: Text('ITEMS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 85, child: Text('TOTAL QTY', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 110, child: Text('TOTAL AMT', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  Expanded(flex: 4, child: Text('REMARK', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                  SizedBox(width: 95, child: Text('ACTIONS', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            // ROWS LIST
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0C3B2E)),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                              const SizedBox(height: 8),
                              Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                              const SizedBox(height: 12),
                              ElevatedButton(onPressed: _loadIndents, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _indents.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 10),
                                  const Text('No indent entries found.',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  const Text('Click "+ New Entry" to create your first indent voucher.',
                                      style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _tableScrollCtrl,
                              itemCount: _indents.length,
                              itemBuilder: (ctx, idx) {
                                final item = _indents[idx];
                                final isGlowing = _glowingIndCode == item.indCode;
                                final isGlowingEdit = isGlowing && _isGlowingEdit;
                                final isGlowingNew = isGlowing && !_isGlowingEdit;
                                final isEven = idx.isEven;

                                return _AnimatedIndentRow(
                                  key: ValueKey<String>(item.indCode),
                                  index: idx + 1,
                                  item: item,
                                  isEven: isEven,
                                  isGlowingNew: isGlowingNew,
                                  isGlowingEdit: isGlowingEdit,
                                  onEdit: () => _openEditEntryDialog(item),
                                  onDelete: () => _confirmDeleteIndent(item),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 4. PAGINATION FOOTER
  // ============================================================================
  Widget _buildPaginationFooter() {
    final totalPages = (_totalCount / _pageSize).ceil();
    final startIdx = _totalCount == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIdx = (_currentPage * _pageSize).clamp(0, _totalCount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(
            'Showing $startIdx-$endIdx of $_totalCount Indent Records',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() => _currentPage--);
                    _loadIndents();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Previous', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _currentPage < totalPages
                ? () {
                    setState(() => _currentPage++);
                    _loadIndents();
                  }
                : null,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Next', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED ROW WIDGET WITH PROJECT MASTER GLOW STRATEGY
// ============================================================================
class _AnimatedIndentRow extends StatefulWidget {
  final int index;
  final IndentHeader item;
  final bool isEven;
  final bool isGlowingNew;
  final bool isGlowingEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedIndentRow({
    super.key,
    required this.index,
    required this.item,
    required this.isEven,
    required this.isGlowingNew,
    required this.isGlowingEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedIndentRow> createState() => _AnimatedIndentRowState();
}

class _AnimatedIndentRowState extends State<_AnimatedIndentRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isGlowing = widget.isGlowingNew || widget.isGlowingEdit;
    final glowColor = widget.isGlowingEdit ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    Color getPriorityColor(String p) {
      switch (p.toUpperCase()) {
        case 'URGENT':
          return const Color(0xFFDC2626);
        case 'HIGH':
          return const Color(0xFFF59E0B);
        case 'LOW':
          return const Color(0xFF64748B);
        default:
          return const Color(0xFF0F766E);
      }
    }

    final priorityColor = getPriorityColor(item.priority);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedScale(
          scale: _isHovered ? 1.003 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isGlowing
                  ? glowColor.withValues(alpha: 0.12)
                  : (_isHovered
                      ? const Color(0xFFEFF6FF)
                      : (widget.isEven ? Colors.white : const Color(0xFFF8FAFC))),
              border: isGlowing
                  ? Border.all(color: glowColor, width: 1.5)
                  : Border(
                      bottom: BorderSide(
                        color: _isHovered ? const Color(0xFFBFDBFE) : const Color(0xFFF1F5F9),
                      ),
                    ),
            ),
            child: Row(
              children: [
                // SRNO
                SizedBox(
                  width: 45,
                  child: Text('${widget.index}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ),

                // INDENT NO
                SizedBox(
                  width: 140,
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_long_rounded, size: 13, color: Color(0xFF0C3B2E)),
                      const SizedBox(width: 4),
                      Text(
                        item.indCode,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                      ),
                    ],
                  ),
                ),

                // DATE
                SizedBox(
                  width: 95,
                  child: Text(_formatIndentDate(item.indDate), style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                ),

                // DEPARTMENT
                Expanded(
                  flex: 3,
                  child: Text(
                    item.deptName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                  ),
                ),

                // STORE
                Expanded(
                  flex: 3,
                  child: Text(
                    item.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                  ),
                ),

                // PRIORITY
                SizedBox(
                  width: 90,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.priority,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor),
                    ),
                  ),
                ),

                // ITEMS
                SizedBox(
                  width: 65,
                  child: Text('${item.totItem}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),

                // TOTAL QTY
                SizedBox(
                  width: 85,
                  child: Text(item.totQty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                ),

                // TOTAL AMT
                SizedBox(
                  width: 110,
                  child: Text(
                    '₹ ${item.totAmt.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                  ),
                ),

                // REMARK
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      item.remark,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ),

                // ACTIONS (UPDATE & DELETE)
                SizedBox(
                  width: 95,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ActionIconButton(
                        icon: Icons.edit_outlined,
                        color: const Color(0xFF0C3B2E),
                        hoverBg: const Color(0xFF0C3B2E).withValues(alpha: 0.12),
                        tooltip: 'Edit / Update Indent',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 8),
                      _ActionIconButton(
                        icon: Icons.delete_outline,
                        color: const Color(0xFFDC2626),
                        hoverBg: const Color(0xFFDC2626).withValues(alpha: 0.12),
                        tooltip: 'Delete Indent',
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

// ============================================================================
// STANDARDIZED DELETE CONFIRMATION DIALOG
// ============================================================================
class _ConfirmDeleteDialog extends StatefulWidget {
  final String title;
  final String message;
  final Future<void> Function() onDelete;

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
  String? _errorMessage;

  Future<void> _handleDelete() async {
    setState(() {
      _status = ButtonStatus.loading;
      _errorMessage = null;
    });

    try {
      await widget.onDelete();
      if (mounted) {
        setState(() => _status = ButtonStatus.success);
      }
      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = ButtonStatus.idle;
          _errorMessage = e.toString().replaceAll('ApiException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                ),
              ),
            ],
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
                    idleIcon: Icons.delete_outline,
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
// ANIMATED EXPORT BUTTON (CIRCULATING LIGHT EDGE ORBIT - PROJECT MASTER STYLE)
// ============================================================================
class IndentAnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const IndentAnimatedExportButton({super.key, required this.onPressed});

  @override
  State<IndentAnimatedExportButton> createState() => _IndentAnimatedExportButtonState();
}

class _IndentAnimatedExportButtonState extends State<IndentAnimatedExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _IndentOrbitButtonBorderPainter(
                progress: _controller.value,
                isHovered: _isHovered,
              ),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _isHovered ? const Color(0xFFEAF5EE) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 16,
                      color: _isHovered ? const Color(0xFF0C3B2E) : const Color(0xFF334155),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: _isHovered ? const Color(0xFF0C3B2E) : const Color(0xFF334155),
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

class _IndentOrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;

  _IndentOrbitButtonBorderPainter({required this.progress, required this.isHovered});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Base subtle border
    final basePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, basePaint);

    // Orbit circulating light beam
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;
    final beamLength = length * 0.28;
    final startDistance = (progress * length) % length;
    final endDistance = startDistance + beamLength;

    Path extractPath;
    if (endDistance <= length) {
      extractPath = metric.extractPath(startDistance, endDistance);
    } else {
      extractPath = metric.extractPath(startDistance, length)
        ..addPath(metric.extractPath(0, endDistance - length), Offset.zero);
    }

    final orbitPaint = Paint()
      ..color = const Color(0xFF0C3B2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 2.2 : 1.8;

    canvas.drawPath(extractPath, orbitPaint);
  }

  @override
  bool shouldRepaint(covariant _IndentOrbitButtonBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isHovered != isHovered;
  }
}
