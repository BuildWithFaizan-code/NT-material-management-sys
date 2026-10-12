import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../po_advance_models.dart';

/// Modal dialog displaying "Total Advance For Party (All POs)"
/// Allows users to review all purchase orders for the selected supplier
/// and select a PO to instantly populate into the advance entry form.
class PoAdvancePartySummaryModal extends StatefulWidget {
  final int partyCode;
  final String partyName;
  final List<PoAdvancePartySummary> summaries;
  final bool isLoading;
  final String? currentSelectedPoNo;
  final ValueChanged<String> onSelectPo;

  const PoAdvancePartySummaryModal({
    super.key,
    required this.partyCode,
    required this.partyName,
    required this.summaries,
    this.isLoading = false,
    this.currentSelectedPoNo,
    required this.onSelectPo,
  });

  @override
  State<PoAdvancePartySummaryModal> createState() => _PoAdvancePartySummaryModalState();
}

class _PoAdvancePartySummaryModalState extends State<PoAdvancePartySummaryModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchCtrl.text.trim().toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PoAdvancePartySummary> get _filteredSummaries {
    if (_searchQuery.isEmpty) return widget.summaries;
    return widget.summaries.where((s) {
      final dateStr = s.poDate != null
          ? '${s.poDate!.day.toString().padLeft(2, '0')}/${s.poDate!.month.toString().padLeft(2, '0')}/${s.poDate!.year}'
          : '';
      return s.poNo.toLowerCase().contains(_searchQuery) ||
          s.appBAmt.toString().contains(_searchQuery) ||
          s.totalAdv.toString().contains(_searchQuery) ||
          dateStr.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredSummaries;
    final totalPoNet = list.fold<double>(0.0, (sum, s) => sum + s.appBAmt);
    final totalAdvance = list.fold<double>(0.0, (sum, s) => sum + s.totalAdv);
    final totalPending = totalPoNet - totalAdvance;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 1020,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. MODAL HEADER
                _buildHeader(),

                // 2. METRICS STRIP
                _buildMetricsStrip(totalPoNet, totalAdvance, totalPending),

                // 3. SEARCH BAR (IF MULTIPLE ITEMS)
                if (widget.summaries.length > 2) _buildSearchBar(),

                // 4. DATA TABLE
                Expanded(
                  child: widget.isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : (list.isEmpty
                          ? _buildEmptyState()
                          : _buildTable(list)),
                ),

                // 5. FOOTER SUMMARY BAR
                _buildFooter(totalPoNet, totalAdvance, totalPending, list.length),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Total Advance For Party (All POs)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    if (widget.partyCode > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          'ID: ${widget.partyCode}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        ),
                      ),
                  ],
                ),
                if (widget.partyName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Supplier: ${widget.partyName}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Text(
              '${widget.summaries.length} POs Found',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsStrip(double totalPoNet, double totalAdvance, double totalPending) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildMetricPill('AGGREGATE PO NET', totalPoNet, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
          const SizedBox(width: 12),
          _buildMetricPill('TOTAL ADVANCES PAID', totalAdvance, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          const SizedBox(width: 12),
          _buildMetricPill(
            'TOTAL PENDING',
            totalPending,
            totalPending >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
            totalPending >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
          ),
          const Spacer(),
          const Text(
            'Click "SELECT PO" or tap any row to load into form',
            style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, double val, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          Text(
            '₹${val.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: SizedBox(
        height: 34,
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: 'Search by PO Number or Amount...',
            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 14),
                    onPressed: () => _searchCtrl.clear(),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(List<PoAdvancePartySummary> list) {
    return Column(
      children: [
        // Table Header Row
        Container(
          height: 32,
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              SizedBox(width: 36, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(flex: 3, child: Text('PO NUMBER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 100, child: Text('PO DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 140, child: Align(alignment: Alignment.centerRight, child: Text('PO NET AMT (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
              SizedBox(width: 140, child: Align(alignment: Alignment.centerRight, child: Text('TOTAL ADV (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
              SizedBox(width: 140, child: Align(alignment: Alignment.centerRight, child: Text('PENDING (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
              SizedBox(width: 110, child: Center(child: Text('ACTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
            ],
          ),
        ),

        // Table Rows
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (ctx, idx) {
              final s = list[idx];
              final isCurrent = widget.currentSelectedPoNo != null &&
                  widget.currentSelectedPoNo!.trim().toUpperCase() == s.poNo.trim().toUpperCase();
              final dateStr = s.poDate != null
                  ? '${s.poDate!.day.toString().padLeft(2, '0')}/${s.poDate!.month.toString().padLeft(2, '0')}/${s.poDate!.year}'
                  : '-';
              final pending = s.appBAmt - s.totalAdv;

              return InkWell(
                onTap: () {
                  widget.onSelectPo(s.poNo);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 38,
                  color: isCurrent
                      ? const Color(0xFFEFF6FF)
                      : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(width: 36, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Text(
                              s.poNo,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? const Color(0xFF1D4ED8) : const Color(0xFF0F172A),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDBEAFE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(width: 100, child: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                      SizedBox(
                        width: 140,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₹${s.appBAmt.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₹${s.totalAdv.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 140,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₹${pending.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: pending <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onSelectPo(s.poNo);
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrent ? const Color(0xFF1D4ED8) : AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              minimumSize: const Size(0, 24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            child: Text(
                              isCurrent ? 'ACTIVE PO' : 'SELECT PO',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.35)),
          const SizedBox(height: 8),
          Text(
            widget.partyName.isEmpty
                ? 'No Supplier / Party is currently selected.'
                : 'No purchase order advance records found for ${widget.partyName}.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select an approved supplier on the main screen to see their POs.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double totalPoNet, double totalAdvance, double totalPending, int count) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Party Totals ($count POs): ',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const Text('Net: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(
                '₹${totalPoNet.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
              ),
              const SizedBox(width: 10),
              const Text('Adv: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(
                '₹${totalAdvance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
              ),
              const SizedBox(width: 10),
              const Text('Bal: ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              Text(
                '₹${totalPending.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: totalPending <= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: const Size(0, 30),
            ),
            child: const Text('Close', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
