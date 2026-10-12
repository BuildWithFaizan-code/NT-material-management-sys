import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../po_advance_models.dart';

/// Modal dialog displaying "History of Advance Payment for Selected PO"
/// Allows users to inspect and select existing advance disbursements to load into the form.
class PoAdvanceHistoryModal extends StatefulWidget {
  final String poNo;
  final String partyName;
  final List<PoAdvanceHistoryRecord> records;
  final bool isLoading;
  final double netAmt;
  final double totGiv;
  final double pendingAmt;
  final int? selectedRecordId;
  final ValueChanged<PoAdvanceHistoryRecord> onSelectRecord;
  final Future<void> Function(PoAdvanceHistoryRecord) onDeleteRecord;

  const PoAdvanceHistoryModal({
    super.key,
    required this.poNo,
    required this.partyName,
    required this.records,
    this.isLoading = false,
    this.netAmt = 0.0,
    this.totGiv = 0.0,
    this.pendingAmt = 0.0,
    this.selectedRecordId,
    required this.onSelectRecord,
    required this.onDeleteRecord,
  });

  @override
  State<PoAdvanceHistoryModal> createState() => _PoAdvanceHistoryModalState();
}

class _PoAdvanceHistoryModalState extends State<PoAdvanceHistoryModal> {
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

  List<PoAdvanceHistoryRecord> get _filteredRecords {
    if (_searchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final dateStr = r.appDt != null
          ? '${r.appDt!.day.toString().padLeft(2, '0')}/${r.appDt!.month.toString().padLeft(2, '0')}/${r.appDt!.year}'
          : '';
      return r.chequeNo.toLowerCase().contains(_searchQuery) ||
          r.appRemark.toLowerCase().contains(_searchQuery) ||
          r.appEMode.toLowerCase().contains(_searchQuery) ||
          r.appAmt.toString().contains(_searchQuery) ||
          dateStr.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredRecords;
    final totalFiltered = list.fold<double>(0.0, (sum, r) => sum + r.appAmt);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 1050,
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

                // 2. SUMMARY METRICS STRIP
                _buildMetricsStrip(),

                // 3. SEARCH BAR (IF MULTIPLE ENTRIES)
                if (widget.records.length > 2) _buildSearchBar(),

                // 4. DATA TABLE
                Expanded(
                  child: widget.isLoading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : (list.isEmpty
                          ? _buildEmptyState()
                          : _buildTable(list)),
                ),

                // 5. FOOTER SUMMARY BAR
                _buildFooter(totalFiltered, list.length),
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
                colors: [Color(0xFF0C3B2E), Color(0xFF1D5A46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.history_edu_rounded, size: 18, color: Colors.white),
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
                      'History Of Advance Payment For Selected PO',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'PO: ${widget.poNo.isNotEmpty ? widget.poNo : "None Selected"}',
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
              '${widget.records.length} Entries Recorded',
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

  Widget _buildMetricsStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          _buildMetricPill('PO NET TOTAL', widget.netAmt, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
          const SizedBox(width: 12),
          _buildMetricPill('ADVANCE GIVEN', widget.totGiv, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
          const SizedBox(width: 12),
          _buildMetricPill('PENDING BALANCE', widget.pendingAmt, widget.pendingAmt >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626), widget.pendingAmt >= 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2)),
          const Spacer(),
          const Text(
            'Click "SELECT" or tap any row to load into form',
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
            hintText: 'Search by Cheque No, Date, Payment Mode, or Remarks...',
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

  Widget _buildTable(List<PoAdvanceHistoryRecord> list) {
    return Column(
      children: [
        // Table Header Row
        Container(
          height: 32,
          color: const Color(0xFFF1F5F9),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 50, child: Text('ID', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 80, child: Text('DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 85, child: Text('MODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 110, child: Text('CHEQUE/REF', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 80, child: Text('CHQ DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              Expanded(child: Text('REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
              SizedBox(width: 110, child: Align(alignment: Alignment.centerRight, child: Text('ADV. AMT (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
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
              final r = list[idx];
              final isSelected = widget.selectedRecordId == r.poId;
              final dateStr = r.appDt != null
                  ? '${r.appDt!.day.toString().padLeft(2, '0')}/${r.appDt!.month.toString().padLeft(2, '0')}/${r.appDt!.year}'
                  : '-';
              final chqDateStr = r.appMDate != null
                  ? '${r.appMDate!.day.toString().padLeft(2, '0')}/${r.appMDate!.month.toString().padLeft(2, '0')}/${r.appMDate!.year}'
                  : '-';

              return InkWell(
                onTap: () {
                  widget.onSelectRecord(r);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 38,
                  color: isSelected
                      ? const Color(0xFFECFDF5)
                      : (idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                      SizedBox(
                        width: 50,
                        child: Text(
                          '#${r.poId}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? const Color(0xFF047857) : AppColors.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 80, child: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                      SizedBox(width: 85, child: Text(r.appEMode.isNotEmpty ? r.appEMode : 'Direct', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 110, child: Text(r.chequeNo.isNotEmpty ? r.chequeNo : '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)), overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 80, child: Text(chqDateStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))),
                      Expanded(child: Text(r.appRemark.isNotEmpty ? r.appRemark : '-', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis)),
                      SizedBox(
                        width: 110,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '₹${r.appAmt.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // SELECT BUTTON PILL
                            ElevatedButton(
                              onPressed: () {
                                widget.onSelectRecord(r);
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? const Color(0xFF047857) : AppColors.primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: const Size(0, 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Text(
                                isSelected ? 'LOADED' : 'SELECT',
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // DELETE BUTTON
                            InkWell(
                              onTap: () async {
                                await widget.onDeleteRecord(r);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              ),
                            ),
                          ],
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
          Icon(Icons.payments_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.35)),
          const SizedBox(height: 8),
          Text(
            widget.poNo.isEmpty
                ? 'No Purchase Order is currently selected.'
                : 'No prior advance payments recorded for ${widget.poNo}.',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          const Text(
            'New payments recorded on the main screen will appear here.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(double totalFiltered, int count) {
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
              const Text('Total Advances for this PO: ', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              Text(
                '₹${totalFiltered.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
              ),
              const SizedBox(width: 8),
              Text('($count entries)', style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
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
