import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import 'material_return_models.dart';
import 'material_return_service.dart';
import 'widgets/material_return_export_modal_dialog.dart';
import 'widgets/material_return_wizard_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class MaterialReturnPage extends StatefulWidget {
  const MaterialReturnPage({super.key});

  @override
  State<MaterialReturnPage> createState() => _MaterialReturnPageState();
}

class _MaterialReturnPageState extends State<MaterialReturnPage> {
  final MaterialReturnService _service = MaterialReturnService();

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedModeFilter = 'All';

  // Glowing Strategy (4-second Amber Glow from Project Master)
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  Timer? _glowTimer;

  // Selected row
  String? _selectedRowCode;

  // In-page feedback notification banner state
  String? _notificationMessage;
  bool _notificationIsError = false;
  Timer? _notificationTimer;

  // Table Horizontal Scroll Navigation State
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  bool _isLoading = true;
  String? _errorMessage;
  List<MaterialReturnGridRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 25;

  Timer? _debounce;

  static const List<String> _modeFilterOptions = [
    'All',
    'From Department',
    'To Supplier',
    'To Customer',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _glowTimer?.cancel();
    _notificationTimer?.cancel();
    _searchCtrl.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = false}) {
    setState(() {
      _notificationMessage = message;
      _notificationIsError = isError;
    });
    _notificationTimer?.cancel();
    _notificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _notificationMessage = null);
      }
    });
  }

  void _updateScrollButtons() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final maxScroll = _horizontalScrollCtrl.position.maxScrollExtent;
    final offset = _horizontalScrollCtrl.offset;
    final canLeft = offset > 10;
    final canRight = offset < maxScroll - 10;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollLeft() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset - 350.0).clamp(0.0, _horizontalScrollCtrl.position.maxScrollExtent);
    _horizontalScrollCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 350.0).clamp(0.0, _horizontalScrollCtrl.position.maxScrollExtent);
    _horizontalScrollCtrl.animateTo(newOffset, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _loadRecords({int page = 1}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = page;
    });

    try {
      final res = await _service.fetchRecords(
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
        fromDate: _fromDate,
        toDate: _toDate,
        returnMode: _selectedModeFilter,
        page: page,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _records = res.records;
          _totalCount = res.totalCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _loadRecords(page: 1);
    });
  }

  void _openNewEntryWizard() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => MaterialReturnWizardDialog(
        service: _service,
        onSaved: (code, isUpdate) {
          _triggerGlow(code, isUpdate: isUpdate);
          _loadRecords(page: 1);
        },
      ),
    );
  }

  Future<void> _openEditEntryWizard(String code) async {
    try {
      final detail = await _service.fetchByCode(code);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (ctx) => MaterialReturnWizardDialog(
          service: _service,
          editCode: code,
          initialDetail: detail,
          onSaved: (savedCode, isUpdate) {
            _triggerGlow(savedCode, isUpdate: true);
            _loadRecords(page: _currentPage);
          },
        ),
      );
    } catch (e) {
      _showNotification('Failed to load entry for editing: $e', isError: true);
    }
  }

  Future<void> _openViewEntryModal(String code) async {
    try {
      final detail = await _service.fetchByCode(code);
      if (!mounted) return;
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (ctx) => _MaterialReturnViewModal(detail: detail),
      );
    } catch (e) {
      _showNotification('Failed to load return details: $e', isError: true);
    }
  }

  Future<void> _handleDelete(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => _DeleteConfirmModal(code: code),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final ok = await _service.deleteReturn(code);
        if (ok && mounted) {
          _showNotification('Return $code deleted successfully. Stock reversed and logged in DAYBOOK.');
          _loadRecords(page: _currentPage);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showNotification('Delete failed: $e', isError: true);
        }
      }
    }
  }

  void _triggerGlow(String code, {required bool isUpdate}) {
    setState(() {
      if (isUpdate) {
        _recentlyUpdatedCode = code;
        _recentlySavedCode = null;
      } else {
        _recentlySavedCode = code;
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
  }

  void _openExportModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => MaterialReturnExportModalDialog(records: _records),
    );
  }

  // Live KPI metrics from current record set
  double get _kpiTotalQty => _records.fold(0.0, (acc, r) => acc + r.totQty);
  int get _kpiTotalItems => _records.fold(0, (acc, r) => acc + r.totItm);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header Bar
            _buildTopActionBar(),

            // In-page feedback notification banner
            if (_notificationMessage != null) ...[
              const SizedBox(height: 12),
              _buildNotificationBanner(),
            ],

            const SizedBox(height: 18),

            // 2. KPI Summary Gauges
            _buildKpiGauges(),

            const SizedBox(height: 18),

            // 3. Filter & Search Toolbar
            _buildFilterToolbar(),

            const SizedBox(height: 14),

            // 4. Main Corporate Master Table (Aligned Department Master Layout)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      // Table Data Viewport
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryColor))
                            : _errorMessage != null
                                ? Center(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)))
                                : _records.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No material return records found for this filter.',
                                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
                                        ),
                                      )
                                    : Stack(
                                        children: [
                                          LayoutBuilder(
                                            builder: (context, constraints) {
                                              const double baseWidth = 1348.0;
                                              final double tableWidth = math.max(constraints.maxWidth, baseWidth);
                                              final double extraWidth = tableWidth - baseWidth;
                                              final double col5Width = 220.0 + (extraWidth * 0.6);
                                              final double col8Width = 180.0 + (extraWidth * 0.4);

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
                                                        // Synchronized Table Header (Department Master Design)
                                                        _buildTableHeader(col5Width: col5Width, col8Width: col8Width),

                                                        // Table Body Data Rows
                                                        Expanded(
                                                          child: Scrollbar(
                                                            controller: _verticalScrollCtrl,
                                                            thumbVisibility: true,
                                                            child: ListView.separated(
                                                              controller: _verticalScrollCtrl,
                                                              physics: const AlwaysScrollableScrollPhysics(),
                                                              cacheExtent: 400,
                                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                                              itemCount: _records.length,
                                                              separatorBuilder: (ctx, idx) => const SizedBox(height: 2),
                                                              itemBuilder: (context, idx) {
                                                                final r = _records[idx];
                                                                final isGlowing = r.retCode == _recentlySavedCode ||
                                                                    r.retCode == _recentlyUpdatedCode;
                                                                final isSelected = r.retCode == _selectedRowCode;

                                                                return _AnimatedMaterialReturnRow(
                                                                  key: ValueKey<String>(r.retCode),
                                                                  r: r,
                                                                  idx: idx,
                                                                  isGlowing: isGlowing,
                                                                  isSelected: isSelected,
                                                                  col5Width: col5Width,
                                                                  col8Width: col8Width,
                                                                  onTap: () => setState(() => _selectedRowCode = r.retCode),
                                                                  onView: () => _openViewEntryModal(r.retCode),
                                                                  onEdit: () => _openEditEntryWizard(r.retCode),
                                                                  onDelete: () => _handleDelete(r.retCode),
                                                                );
                                                              },
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

                                          // Floating Left Scroll Arrow
                                          if (_canScrollLeft)
                                            Positioned(
                                              left: 12,
                                              top: 80,
                                              bottom: 60,
                                              child: Center(
                                                child: _buildFloatingScrollButton(Icons.arrow_back_ios_new_rounded, _scrollLeft),
                                              ),
                                            ),

                                          // Floating Right Scroll Arrow
                                          if (_canScrollRight)
                                            Positioned(
                                              right: 12,
                                              top: 80,
                                              bottom: 60,
                                              child: Center(
                                                child: _buildFloatingScrollButton(Icons.arrow_forward_ios_rounded, _scrollRight),
                                              ),
                                            ),
                                        ],
                                      ),
                      ),

                      // Table Pagination Bar
                      _buildPaginationBar(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.assignment_return_rounded, color: AppColors.secondaryColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Material Return (From / To)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Transaction → Issue → Material Return From/To • Real-time stockregnew incrementation',
                style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Export Button (100% Project Master Animated Button)
        MaterialReturnAnimatedExportButton(onPressed: _openExportModal),

        const SizedBox(width: 14),

        // "+ New Entry" Button (Project Master Colors & Glow)
        ElevatedButton.icon(
          onPressed: _openNewEntryWizard,
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Text(
            'New Entry',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGauges() {
    return Row(
      children: [
        _buildKpiCard('Total Return Records', '$_totalCount Records', Icons.description_outlined, const Color(0xFF0C3B2E)),
        const SizedBox(width: 16),
        _buildKpiCard('Total Quantity Returned', '${_kpiTotalQty.toStringAsFixed(2)} Units', Icons.scale_rounded, const Color(0xFF2563EB)),
        const SizedBox(width: 16),
        _buildKpiCard('Total Items Dispatched', '$_kpiTotalItems Lines', Icons.view_in_ar_rounded, const Color(0xFFD97706)),
        const SizedBox(width: 16),
        _buildKpiCard('Inventory Movement', 'stockregnew (Positive)', Icons.trending_up_rounded, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: TextStyle(fontSize: 11, color: AppColors.slateMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Row(
      children: [
        // Search Input
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                hintText: 'Search by Return Code, Party, Operator, Remark...',
                hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Mode Filter Dropdown
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedModeFilter,
              items: _modeFilterOptions.map((m) {
                return DropdownMenuItem(
                  value: m,
                  child: Text(
                    m == 'All' ? 'All Return Modes' : m,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedModeFilter = val);
                  _loadRecords(page: 1);
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Date Range Picker Action
        OutlinedButton.icon(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              initialDateRange: _fromDate != null && _toDate != null
                  ? DateTimeRange(start: _fromDate!, end: _toDate!)
                  : null,
            );
            if (picked != null) {
              setState(() {
                _fromDate = picked.start;
                _toDate = picked.end;
              });
              _loadRecords(page: 1);
            }
          },
          icon: const Icon(Icons.date_range_outlined, size: 16, color: Color(0xFF475569)),
          label: Text(
            _fromDate != null && _toDate != null
                ? '${_formatDate(_fromDate!)} - ${_formatDate(_toDate!)}'
                : 'Filter by Date',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        if (_fromDate != null || _toDate != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
            tooltip: 'Clear Date Filter',
            onPressed: () {
              setState(() {
                _fromDate = null;
                _toDate = null;
              });
              _loadRecords(page: 1);
            },
          ),
        ],

        const Spacer(),

        // Refresh Button
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.secondaryColor, size: 20),
          tooltip: 'Refresh Records',
          onPressed: () => _loadRecords(page: _currentPage),
        ),
      ],
    );
  }

  Widget _buildNotificationBanner() {
    final isError = _notificationIsError;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _notificationMessage!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isError ? const Color(0xFF991B1B) : const Color(0xFF166534),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 16, color: isError ? const Color(0xFF991B1B) : const Color(0xFF166534)),
            onPressed: () => setState(() => _notificationMessage = null),
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader({required double col5Width, required double col8Width}) {
    return Container(
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9), // Corporate Slate matching Department Master
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          // Col 1: SR NO
          const SizedBox(
            width: 45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tag_rounded, size: 12, color: Color(0xFF6366F1)),
                SizedBox(width: 3),
                Text('SR', style: _tblHdrStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 2: RETURN CODE
          const SizedBox(
            width: 135,
            child: Row(
              children: [
                Icon(Icons.confirmation_number_outlined, size: 12, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Flexible(child: Text('RETURN CODE', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 3: DATE
          const SizedBox(
            width: 90,
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFFF59E0B)),
                SizedBox(width: 4),
                Flexible(child: Text('DATE', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 4: RETURN MODE
          const SizedBox(
            width: 125,
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, size: 12, color: Color(0xFF06B6D4)),
                SizedBox(width: 4),
                Flexible(child: Text('RETURN MODE', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 5: RETURN TO / BY
          SizedBox(
            width: col5Width,
            child: const Row(
              children: [
                Icon(Icons.business_outlined, size: 12, color: Color(0xFF8B5CF6)),
                SizedBox(width: 4),
                Flexible(child: Text('RETURN TO / BY', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 6: TOTAL QTY
          const SizedBox(
            width: 95,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.scale_rounded, size: 12, color: Color(0xFF2563EB)),
                SizedBox(width: 4),
                Flexible(child: Text('TOTAL QTY', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 7: ITEMS
          const SizedBox(
            width: 65,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.view_in_ar_rounded, size: 12, color: Color(0xFFD97706)),
                SizedBox(width: 4),
                Flexible(child: Text('ITEMS', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 8: REMARK
          SizedBox(
            width: col8Width,
            child: const Row(
              children: [
                Icon(Icons.notes_rounded, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 4),
                Flexible(child: Text('REMARK', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 9: OPERATOR
          const SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF475569)),
                SizedBox(width: 4),
                Flexible(child: Text('OPERATOR', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 10: LOCATION
          const SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFF43F5E)),
                SizedBox(width: 3),
                Flexible(child: Text('LOC', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Col 11: ACTIONS
          const SizedBox(
            width: 95,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_outlined, size: 12, color: Color(0xFF64748B)),
                SizedBox(width: 3),
                Flexible(child: Text('ACTIONS', style: _tblHdrStyle, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = (_totalCount / _pageSize).ceil();

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            'Showing ${((_currentPage - 1) * _pageSize) + 1} - ${(_currentPage * _pageSize).clamp(0, _totalCount)} of $_totalCount records',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            color: _currentPage > 1 ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
            onPressed: _currentPage > 1 ? () => _loadRecords(page: _currentPage - 1) : null,
          ),
          Text(
            'Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            color: _currentPage < totalPages ? AppColors.secondaryColor : const Color(0xFFCBD5E1),
            onPressed: _currentPage < totalPages ? () => _loadRecords(page: _currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingScrollButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 16, color: AppColors.secondaryColor),
        onPressed: onPressed,
        splashRadius: 20,
      ),
    );
  }
}

// ============================================================================
// VIEW DETAIL MODAL
// ============================================================================
class _MaterialReturnViewModal extends StatelessWidget {
  final MaterialReturnDetail detail;

  const _MaterialReturnViewModal({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      child: Container(
        width: 1060,
        height: 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, color: AppColors.secondaryColor, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Material Return: ${detail.retCode}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header details
                      Row(
                        children: [
                          _buildDetailField('Date', _formatDate(detail.retDate)),
                          _buildDetailField('Mode', detail.retMode),
                          _buildDetailField('Return To / By', detail.retToName),
                          _buildDetailField('Source', detail.source),
                          _buildDetailField('Operator', detail.operatorName),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Line Items (Returned Material)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      // Table of lines
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Container(
                              height: 36,
                              color: const Color(0xFF0C3B2E),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: const Row(
                                children: [
                                  SizedBox(width: 40, child: Text('#', style: _viewModalTblHdrStyle)),
                                  SizedBox(width: 100, child: Text('Item Code', style: _viewModalTblHdrStyle)),
                                  Expanded(flex: 3, child: Text('Item Name', style: _viewModalTblHdrStyle)),
                                  SizedBox(width: 80, child: Text('Qty', textAlign: TextAlign.right, style: _viewModalTblHdrStyle)),
                                  SizedBox(width: 80, child: Text('Rate', textAlign: TextAlign.right, style: _viewModalTblHdrStyle)),
                                  SizedBox(width: 100, child: Text('Amount', textAlign: TextAlign.right, style: _viewModalTblHdrStyle)),
                                  SizedBox(width: 100, child: Text('Net Amount', textAlign: TextAlign.right, style: _viewModalTblHdrStyle)),
                                ],
                              ),
                            ),
                            ...detail.lines.asMap().entries.map((e) {
                              final l = e.value;
                              return Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: e.key % 2 == 0 ? Colors.white : const Color(0xFFF8FAFC),
                                  border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 40, child: Text('${l.srNo}', style: const TextStyle(fontSize: 11.5))),
                                    SizedBox(width: 100, child: Text(l.itemCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.secondaryColor))),
                                    Expanded(flex: 3, child: Text(l.itemName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 80, child: Text(l.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    SizedBox(width: 80, child: Text(l.rate.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                    SizedBox(width: 100, child: Text('₹${l.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                                    SizedBox(width: 100, child: Text('₹${l.netAmt.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (detail.remark.isNotEmpty)
                        Text('Remark: ${detail.remark}', style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Text('Total Items: ${detail.totItm} | Total Qty: ${detail.totQty.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryColor),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

// ============================================================================
// DELETE CONFIRMATION MODAL
// ============================================================================
class _DeleteConfirmModal extends StatelessWidget {
  final String code;

  const _DeleteConfirmModal({required this.code});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 12),
          const Text('Delete Material Return?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Text(
        'Are you sure you want to delete return document $code?\n\n'
        '• Inventory added by this return will be deducted back from ITEMMST.\n'
        '• The stock ledger row in stockregnew will be permanently removed.\n'
        '• Audit action will be logged in DAYBOOK as DELETE.\n\n'
        'This action is atomic and irreversible.',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Delete Return', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ============================================================================
// ANIMATED MATERIAL RETURN ROW WIDGET (Department Master Design Parity)
// ============================================================================
class _AnimatedMaterialReturnRow extends StatefulWidget {
  final MaterialReturnGridRecord r;
  final int idx;
  final bool isGlowing;
  final bool isSelected;
  final double col5Width;
  final double col8Width;
  final VoidCallback onTap;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnimatedMaterialReturnRow({
    super.key,
    required this.r,
    required this.idx,
    required this.isGlowing,
    required this.isSelected,
    required this.col5Width,
    required this.col8Width,
    required this.onTap,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AnimatedMaterialReturnRow> createState() => _AnimatedMaterialReturnRowState();
}

class _AnimatedMaterialReturnRowState extends State<_AnimatedMaterialReturnRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final isGlowing = widget.isGlowing;
    final isSelected = widget.isSelected;
    const glowColor = Color(0xFFF59E0B); // Amber glow from Project Master

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.004 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
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
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isGlowing
                    ? glowColor
                    : (isSelected
                        ? AppColors.secondaryColor
                        : (_isHovered ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0))),
                width: isGlowing ? 2.0 : (_isHovered || isSelected ? 1.4 : 1.0),
              ),
              boxShadow: isGlowing
                  ? [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (_isHovered
                      ? [
                          BoxShadow(
                            color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.015),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ]),
            ),
            child: Row(
              children: [
                // Col 1: SR
                SizedBox(
                  width: 45,
                  child: Center(
                    child: Text(
                      '${widget.idx + 1}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 2: RETURN CODE
                SizedBox(
                  width: 135,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.secondaryColor.withValues(alpha: 0.2), width: 0.8),
                      ),
                      child: Text(
                        r.retCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.secondaryColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 3: DATE
                SizedBox(
                  width: 90,
                  child: Text(
                    _formatDate(r.retDate),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 4: RETURN MODE
                SizedBox(
                  width: 125,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
                      ),
                      child: Text(
                        r.retMode,
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 5: RETURN TO / BY
                SizedBox(
                  width: widget.col5Width,
                  child: Tooltip(
                    message: r.retToName.isNotEmpty ? r.retToName : 'No Party/Dept Specified',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      r.retToName.isNotEmpty ? r.retToName : '-',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 6: TOTAL QTY
                SizedBox(
                  width: 95,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                      ),
                      child: Text(
                        r.totQty.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 7: ITEMS
                SizedBox(
                  width: 65,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 0.8),
                      ),
                      child: Text(
                        '${r.totItm}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 8: REMARK
                SizedBox(
                  width: widget.col8Width,
                  child: Tooltip(
                    message: r.remark.isNotEmpty ? r.remark : 'No Remark',
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(
                      r.remark.isEmpty ? '-' : r.remark,
                      style: TextStyle(
                        fontSize: 11,
                        color: r.remark.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        fontStyle: r.remark.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 9: OPERATOR
                SizedBox(
                  width: 110,
                  child: Text(
                    r.operatorName.isEmpty ? '-' : r.operatorName,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: r.operatorName.isEmpty ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),

                // Col 10: LOCATION
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Text(
                      r.location.isEmpty ? '-' : r.location,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Col 11: ACTIONS
                SizedBox(
                  width: 95,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF2563EB)),
                        tooltip: 'View Details',
                        onPressed: widget.onView,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFFD97706)),
                        tooltip: 'Edit Return',
                        onPressed: widget.onEdit,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                        tooltip: 'Delete Return',
                        onPressed: widget.onDelete,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        padding: EdgeInsets.zero,
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

const TextStyle _tblHdrStyle = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  color: Color(0xFF475569), // Department Master slate header text color
  letterSpacing: 0.3,
);

const TextStyle _viewModalTblHdrStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: Colors.white,
);

