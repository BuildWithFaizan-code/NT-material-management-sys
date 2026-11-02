import 'dart:async';
import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import 'stock_transfer_models.dart';
import 'stock_transfer_service.dart';
import 'widgets/stock_transfer_wizard_dialog.dart';
import 'widgets/stock_transfer_export_modal_dialog.dart';

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class StockTransferPage extends StatefulWidget {
  const StockTransferPage({super.key});

  @override
  State<StockTransferPage> createState() => _StockTransferPageState();
}

class _StockTransferPageState extends State<StockTransferPage> {
  final StockTransferService _service = StockTransferService();

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();

  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedModeFilter = 'All';

  // Glowing Strategy (4-second Strategy)
  String? _recentlySavedCode;
  String? _recentlyUpdatedCode;
  Timer? _glowTimer;

  // Table Horizontal Scroll Navigation State
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  bool _isLoading = true;
  String? _errorMessage;
  List<StockTransferGridRecord> _records = [];
  int _totalCount = 0;
  int _currentPage = 1;
  final int _pageSize = 25;

  Timer? _debounce;
  String? _lastCreatedCode;

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
    _searchCtrl.dispose();
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
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
    final newOffset = (_horizontalScrollCtrl.offset - 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 350.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _triggerGlow(String code, bool isUpdate) {
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

    _loadRecords();
  }

  Widget _buildFloatingArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            child: Icon(icon, size: 22, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.fetchTransfers(
        fromDate: _fromDate,
        toDate: _toDate,
        search: _searchCtrl.text.trim(),
        issueMode: _selectedModeFilter == 'All' ? null : _selectedModeFilter,
        page: _currentPage,
        pageSize: _pageSize,
      );

      if (mounted) {
        setState(() {
          _records = res.records;
          _totalCount = res.totalCount;
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _currentPage = 1);
      _loadRecords();
    });
  }

  Future<void> _selectDateRange() async {
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
        _currentPage = 1;
      });
      _loadRecords();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _currentPage = 1;
    });
    _loadRecords();
  }

  void _openNewEntryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StockTransferWizardDialog(
        service: _service,
        onSaved: (code, isUpdate) {
          _triggerGlow(code, isUpdate);
        },
      ),
    );
  }

  Future<void> _openEditDialog(String code) async {
    try {
      final detail = await _service.fetchTransferByCode(code);
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => StockTransferWizardDialog(
          service: _service,
          initialTransfer: detail,
          editCode: code,
          onSaved: (savedCode, isUpdate) {
            _triggerGlow(savedCode, isUpdate);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load transfer for editing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete Stock Transfer "$code"?\n\n'
          'This will purge associated double-entry stock registers in STOCKREGNEW and automatically restore all deducted balances in ITEMMST.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteTransfer(code);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stock Transfer $code deleted and inventory restored successfully.'),
              backgroundColor: const Color(0xFF0F766E),
            ),
          );
          _loadRecords();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete transfer: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _openExportDialog() {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No records available to export.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => StockTransferExportModalDialog(records: _records),
    );
  }

  Future<void> _viewDetails(String issueCode) async {
    try {
      final detail = await _service.fetchTransferByCode(issueCode);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => _StockTransferDetailsModal(
          detail: detail,
          formatDate: _formatDate,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load details: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = (_totalCount / _pageSize).ceil().clamp(1, 9999);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.swap_horiz, color: Color(0xFF0F766E), size: 24),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issue Manager — Stock Transfer',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage inter-warehouse and inter-department inventory movements, double-entry ledgers & transfers.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),

                // Export Button
                OutlinedButton.icon(
                  onPressed: _openExportDialog,
                  icon: const Icon(Icons.file_download_outlined, size: 18),
                  label: const Text('Export Records', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),

                // New Entry Button (Project Master Style)
                ElevatedButton.icon(
                  onPressed: _openNewEntryDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Entry', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Filter Toolbar Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search by Issue Code, Remark, Plant, Store...',
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Issue Mode Selector
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedModeFilter,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                        icon: const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF64748B)),
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Modes')),
                          DropdownMenuItem(value: 'Stock Transfer', child: Text('Stock Transfer')),
                          DropdownMenuItem(value: 'To Department', child: Text('To Department')),
                          DropdownMenuItem(value: 'To WIP', child: Text('To WIP')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _selectedModeFilter) {
                            setState(() {
                              _selectedModeFilter = val;
                              _currentPage = 1;
                            });
                            _loadRecords();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Date Range Selector
                  InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.date_range, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(
                            _fromDate != null && _toDate != null
                                ? '${_formatDate(_fromDate!)} - ${_formatDate(_toDate!)}'
                                : 'Select Date Range',
                            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)),
                          ),
                          if (_fromDate != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _clearDateFilter,
                              child: const Icon(Icons.close, size: 14, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Left / Right Navigation Scroll Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
                          tooltip: 'Scroll Table Left',
                          onPressed: _scrollLeft,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                        ),
                        Container(height: 16, width: 1, color: const Color(0xFFE2E8F0)),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF475569)),
                          tooltip: 'Scroll Table Right',
                          onPressed: _scrollRight,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Refresh Button
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF64748B)),
                    tooltip: 'Refresh Records',
                    onPressed: _loadRecords,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main Table Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline, size: 36, color: Colors.red),
                                      const SizedBox(height: 10),
                                      Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                                      const SizedBox(height: 10),
                                      ElevatedButton(onPressed: _loadRecords, child: const Text('Retry')),
                                    ],
                                  ),
                                )
                              : _records.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                                          const SizedBox(height: 10),
                                          Text('No stock transfer records found.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      children: [
                                        Scrollbar(
                                          controller: _horizontalScrollCtrl,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                        controller: _horizontalScrollCtrl,
                                        scrollDirection: Axis.horizontal,
                                        child: Scrollbar(
                                          controller: _verticalScrollCtrl,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _verticalScrollCtrl,
                                            scrollDirection: Axis.vertical,
                                            child: DataTable(
                                              headingRowHeight: 40,
                                              dataRowMinHeight: 40,
                                              dataRowMaxHeight: 44,
                                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                              columns: const [
                                                DataColumn(label: Text('Issue Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Source Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Source Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Plant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Pcs/Box', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Remark', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Created By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                              ],
                                              rows: List.generate(_records.length, (idx) {
                                                final r = _records[idx];
                                                final isNewGlow = r.issueCode == _recentlySavedCode;
                                                final isUpdateGlow = r.issueCode == _recentlyUpdatedCode;
                                                final isGlowing = isNewGlow || isUpdateGlow;
                                                final glowColor = isUpdateGlow ? const Color(0xFFF59E0B) : const Color(0xFF10B981);
                                                final isRecent = r.issueCode == _lastCreatedCode;

                                                return DataRow(
                                                  color: WidgetStateProperty.resolveWith<Color>((states) {
                                                    if (isGlowing) return glowColor.withValues(alpha: 0.14);
                                                    if (isRecent) return const Color(0xFFECFDF5);
                                                    return idx.isEven ? Colors.white : const Color(0xFFFAFAFA);
                                                  }),
                                                  cells: [
                                                    DataCell(
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            r.issueCode,
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                              color: isGlowing ? glowColor : const Color(0xFF0F766E),
                                                            ),
                                                          ),
                                                          if (isNewGlow) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFF10B981),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ] else if (isUpdateGlow) ...[
                                                            const SizedBox(width: 6),
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFF59E0B),
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: const Text('UPDATED', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      onTap: () => _viewDetails(r.issueCode),
                                                    ),
                                                    DataCell(Text(_formatDate(r.issueDate), style: const TextStyle(fontSize: 12))),
                                                    DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          r.issueMode,
                                                          style: const TextStyle(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF334155),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: r.issueSource == 'Requisition'
                                                              ? const Color(0xFFEFF6FF)
                                                              : const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          r.issueSource,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: r.issueSource == 'Requisition'
                                                                ? const Color(0xFF1E40AF)
                                                                : const Color(0xFF334155),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Text(r.sourceStoreName, style: const TextStyle(fontSize: 12))),
                                                    DataCell(Text(r.sourceDeptName, style: const TextStyle(fontSize: 12))),
                                                    DataCell(Text(r.plantName, style: const TextStyle(fontSize: 12))),
                                                    DataCell(Text('${r.totItm}', style: const TextStyle(fontSize: 12))),
                                                    DataCell(Text(r.totPcs.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                                                    DataCell(
                                                      Text(
                                                        r.totQty.toStringAsFixed(2),
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                                      ),
                                                    ),
                                                    DataCell(Text(r.remark.isNotEmpty ? r.remark : '-', style: const TextStyle(fontSize: 11.5))),
                                                    DataCell(Text(r.createdBy, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                                                    DataCell(
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF0F766E)),
                                                            tooltip: 'View Transfer Details',
                                                            onPressed: () => _viewDetails(r.issueCode),
                                                            splashRadius: 16,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                                                            tooltip: 'Edit Transfer',
                                                            onPressed: () => _openEditDialog(r.issueCode),
                                                            splashRadius: 16,
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                                            tooltip: 'Delete Transfer',
                                                            onPressed: () => _confirmDelete(r.issueCode),
                                                            splashRadius: 16,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_canScrollLeft)
                                      Positioned(
                                        left: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: _buildFloatingArrowButton(
                                            icon: Icons.chevron_left_rounded,
                                            onTap: _scrollLeft,
                                            tooltip: 'Scroll left',
                                          ),
                                        ),
                                      ),
                                    if (_canScrollRight)
                                      Positioned(
                                        right: 8,
                                        top: 0,
                                        bottom: 0,
                                        child: Center(
                                          child: _buildFloatingArrowButton(
                                            icon: Icons.chevron_right_rounded,
                                            onTap: _scrollRight,
                                            tooltip: 'Scroll right',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                    ),

                    // Pagination Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Page $_currentPage of $totalPages ($_totalCount transfers)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left, size: 20),
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() => _currentPage--);
                                        _loadRecords();
                                      }
                                    : null,
                                splashRadius: 18,
                              ),
                              Text('$_currentPage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(
                                icon: const Icon(Icons.chevron_right, size: 20),
                                onPressed: _currentPage < totalPages
                                    ? () {
                                        setState(() => _currentPage++);
                                        _loadRecords();
                                      }
                                    : null,
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
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
}


class _StockTransferDetailsModal extends StatefulWidget {
  final StockTransferDetail detail;
  final String Function(DateTime) formatDate;

  const _StockTransferDetailsModal({
    required this.detail,
    required this.formatDate,
  });

  @override
  State<_StockTransferDetailsModal> createState() => _StockTransferDetailsModalState();
}

class _StockTransferDetailsModalState extends State<_StockTransferDetailsModal> {
  final ScrollController _horizontalScrollCtrl = ScrollController();
  final ScrollController _verticalScrollCtrl = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = true;

  @override
  void initState() {
    super.initState();
    _horizontalScrollCtrl.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  @override
  void dispose() {
    _horizontalScrollCtrl.removeListener(_updateScrollButtons);
    _horizontalScrollCtrl.dispose();
    _verticalScrollCtrl.dispose();
    super.dispose();
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
    final newOffset = (_horizontalScrollCtrl.offset - 300.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollRight() {
    if (!_horizontalScrollCtrl.hasClients) return;
    final newOffset = (_horizontalScrollCtrl.offset + 300.0).clamp(
      0.0,
      _horizontalScrollCtrl.position.maxScrollExtent,
    );
    _horizontalScrollCtrl.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildFloatingArrowButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: const Color(0xFF0F766E)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = (screenWidth * 0.85).clamp(700.0, 1050.0);
    final dialogHeight = (screenHeight * 0.85).clamp(450.0, 720.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock Transfer: ${widget.detail.header.issueCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Date: ${widget.formatDate(widget.detail.header.issueDate)} | Mode: ${widget.detail.header.issueMode} | Source: ${widget.detail.header.issueSource} | Store: ${widget.detail.header.sourceStoreName} | Plant: ${widget.detail.header.plantName}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: Colors.white),
                          tooltip: 'Scroll Table Left',
                          onPressed: _scrollLeft,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                        ),
                        Container(height: 14, width: 1, color: Colors.white24),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white),
                          tooltip: 'Scroll Table Right',
                          onPressed: _scrollRight,
                          visualDensity: VisualDensity.compact,
                          splashRadius: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Table with Dual-Axis and Floating Navigation Arrows
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Stack(
                    children: [
                      Scrollbar(
                        controller: _horizontalScrollCtrl,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScrollCtrl,
                          scrollDirection: Axis.horizontal,
                          child: Scrollbar(
                            controller: _verticalScrollCtrl,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _verticalScrollCtrl,
                              scrollDirection: Axis.vertical,
                              child: DataTable(
                                headingRowHeight: 36,
                                dataRowMinHeight: 34,
                                dataRowMaxHeight: 36,
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                                columns: const [
                                  DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Req Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Item Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Item Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('To Store', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('To Dept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                ],
                                rows: widget.detail.lines.map((l) {
                                  return DataRow(cells: [
                                    DataCell(Text('${l.srNo}', style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.reqCode, style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.itemCode, style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.itemName, style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.toStoreName, style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.toDeptName, style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.issueQty.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(l.rate.toStringAsFixed(3), style: const TextStyle(fontSize: 12))),
                                    DataCell(Text((l.issueQty * l.rate).toStringAsFixed(2), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_canScrollLeft)
                        Positioned(
                          left: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _buildFloatingArrowButton(
                              icon: Icons.chevron_left_rounded,
                              onTap: _scrollLeft,
                              tooltip: 'Scroll left',
                            ),
                          ),
                        ),
                      if (_canScrollRight)
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _buildFloatingArrowButton(
                              icon: Icons.chevron_right_rounded,
                              onTap: _scrollRight,
                              tooltip: 'Scroll right',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  Text('Total Items: ${widget.detail.lines.length}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF475569))),
                  const SizedBox(width: 20),
                  Text('Total Qty: ${widget.detail.header.totQty.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF0F766E))),
                  const SizedBox(width: 20),
                  Text('Total Value: ₹ ${widget.detail.lines.fold(0.0, (acc, l) => acc + (l.issueQty * l.rate)).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B))),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
