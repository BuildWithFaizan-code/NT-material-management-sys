import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../po_advance_models.dart';
import '../po_advance_service.dart';
import 'po_advance_export_modal_dialog.dart';

// ============================================================================
// MASTER "SHOW RECORD" LOOKUP MODAL (GROUP MASTER MIRROR)
// ============================================================================

class PoAdvanceRecordLookupModal extends StatefulWidget {
  final List<PoAdvanceHistoryRecord> records;
  final PoAdvanceService service;
  final int? recentlySavedId;
  final int? glowingPoId;
  final ValueChanged<PoAdvanceHistoryRecord> onSelect;
  final Future<void> Function() onRefreshNeeded;

  const PoAdvanceRecordLookupModal({
    super.key,
    required this.records,
    required this.service,
    this.recentlySavedId,
    this.glowingPoId,
    required this.onSelect,
    required this.onRefreshNeeded,
  });

  @override
  State<PoAdvanceRecordLookupModal> createState() => _PoAdvanceRecordLookupModalState();
}

class _PoAdvanceRecordLookupModalState extends State<PoAdvanceRecordLookupModal> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _tableScrollCtrl = ScrollController();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _searchQuery = '';
  String _selectedAlphabet = 'ALL';
  late List<PoAdvanceHistoryRecord> _localRecords;
  int _focusedIndex = 0;
  Timer? _debounce;

  static const List<String> _alphabets = [
    'ALL', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '#'
  ];

  @override
  void initState() {
    super.initState();
    _localRecords = List.from(widget.records);
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        if (mounted) {
          setState(() {
            _searchQuery = _searchCtrl.text.trim().toLowerCase();
            _focusedIndex = 0;
          });
        }
      });
    });

    final targetId = widget.recentlySavedId ?? widget.glowingPoId;
    if (targetId != null && targetId > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final list = _filteredAndSorted;
        final idx = list.indexWhere((r) => r.poId == targetId);
        if (idx >= 0) {
          setState(() => _focusedIndex = idx);
          if (_tableScrollCtrl.hasClients) {
            final double targetOffset = math.max(0.0, (idx * 38.0) - 80.0);
            _tableScrollCtrl.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tableScrollCtrl.dispose();
    _keyboardFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  List<PoAdvanceHistoryRecord> get _filteredAndSorted {
    List<PoAdvanceHistoryRecord> list = List.from(_localRecords);

    // 1. Text Search Filter
    if (_searchQuery.isNotEmpty) {
      list = list.where((r) {
        return r.poNo.toLowerCase().contains(_searchQuery) ||
            r.partyName.toLowerCase().contains(_searchQuery) ||
            r.chequeNo.toLowerCase().contains(_searchQuery) ||
            r.appRemark.toLowerCase().contains(_searchQuery) ||
            r.appEMode.toLowerCase().contains(_searchQuery) ||
            r.appUsrName.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    // 2. Alphabet Filter (Mirroring Group Master parity)
    if (_selectedAlphabet != 'ALL') {
      if (_selectedAlphabet == '#') {
        list = list.where((r) {
          final first = r.partyName.trim().isNotEmpty ? r.partyName.trim()[0] : '';
          return RegExp(r'[^a-zA-Z]').hasMatch(first);
        }).toList();
      } else {
        list = list.where((r) {
          final party = r.partyName.trim().toLowerCase();
          final po = r.poNo.trim().toLowerCase();
          final alpha = _selectedAlphabet.toLowerCase();
          return party.startsWith(alpha) || po.startsWith(alpha);
        }).toList();
      }
    }

    // Sort by Voucher Date desc, PoId desc
    list.sort((a, b) {
      if (a.appDt != null && b.appDt != null) {
        final cmp = b.appDt!.compareTo(a.appDt!);
        if (cmp != 0) return cmp;
      }
      return b.poId.compareTo(a.poId);
    });

    return list;
  }

  void _handleSelectRecord(PoAdvanceHistoryRecord record) {
    widget.onSelect(record);
    Navigator.of(context).pop();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final list = _filteredAndSorted;
    if (list.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (_focusedIndex < list.length - 1) {
        setState(() => _focusedIndex++);
        _scrollToFocusedIndex();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_focusedIndex > 0) {
        setState(() => _focusedIndex--);
        _scrollToFocusedIndex();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_focusedIndex >= 0 && _focusedIndex < list.length) {
        _handleSelectRecord(list[_focusedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToFocusedIndex() {
    if (!_tableScrollCtrl.hasClients) return;
    final double targetOffset = math.max(0.0, (_focusedIndex * 38.0) - 100.0);
    _tableScrollCtrl.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  Future<void> _handleDelete(PoAdvanceHistoryRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => _ConfirmDeleteAdvanceDialog(
        record: record,
        onDelete: () async {
          return await widget.service.deleteAdvance(record.poId);
        },
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _localRecords.removeWhere((r) => r.poId == record.poId);
      });
      await widget.onRefreshNeeded();
    }
  }

  void _openModalExport(List<PoAdvanceHistoryRecord> exportList) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PoAdvanceExportModalDialog(
        records: exportList,
        poNo: exportList.isNotEmpty ? exportList.first.poNo : 'ALL',
        partyName: exportList.isNotEmpty ? exportList.first.partyName : 'All Suppliers',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAndSorted;
    final totalDisbursed = list.fold<double>(0.0, (sum, r) => sum + r.appAmt);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          width: 1350,
          height: 670,
          constraints: const BoxConstraints(maxWidth: 1400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              children: [
                // 1. TOP HEADER BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0C3B2E), Color(0xFF1D5A46)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0C3B2E).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Purchase Order Advance Records',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Text(
                                  '${list.length} OF ${_localRecords.length} ENTRIES',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF047857),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Double click, select row, or press Enter to load advance entry into active form',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Quick Export Button
                      OutlinedButton.icon(
                        onPressed: list.isEmpty ? null : () => _openModalExport(list),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0C3B2E),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: const Size(0, 34),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 15),
                        label: const Text('Export Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                      const SizedBox(width: 10),

                      // Close Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        tooltip: 'Close Modal (Esc)',
                      ),
                    ],
                  ),
                ),

                // 2. SEARCH BAR & ALPHABET STRIP
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  color: Colors.white,
                  child: Row(
                    children: [
                      // Search Field
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              hintText: 'Search by PO Number, Supplier Name, Cheque No, Remarks, User...',
                              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF64748B)),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF64748B)),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Total Amount Disbursed KPI pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.payments_rounded, size: 15, color: Color(0xFF047857)),
                            const SizedBox(width: 6),
                            const Text('Disbursed: ', style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                            Text(
                              '₹${totalDisbursed.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Alphabet Filter Strip (100% Group Master Parity)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    border: Border(
                      top: BorderSide(color: Color(0xFFE2E8F0)),
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _alphabets.map((letter) {
                      final isSelected = _selectedAlphabet == letter;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlphabet = letter;
                              _focusedIndex = 0;
                            });
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF0C3B2E) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // 3. MASTER DATA GRID HEADER
                Container(
                  height: 34,
                  color: const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    children: [
                      SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 120, child: Text('PO NUMBER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 80, child: Text('PO DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      Expanded(flex: 3, child: Text('SUPPLIER / PARTY NAME', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 85, child: Text('VOUCHER DT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 75, child: Text('MODE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 100, child: Text('CHEQUE/REF', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 80, child: Text('CHQ DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 95, child: Align(alignment: Alignment.centerRight, child: Text('ADV. AMT (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))))),
                      SizedBox(width: 75, child: Align(alignment: Alignment.centerRight, child: Text('LESS (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))))),
                      Expanded(flex: 2, child: Text('REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 75, child: Text('USER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)))),
                      SizedBox(width: 65, child: Center(child: Text('ACTIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF334155))))),
                    ],
                  ),
                ),

                // 4. MASTER DATA GRID BODY
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 42, color: Colors.grey.withValues(alpha: 0.4)),
                              const SizedBox(height: 8),
                              const Text(
                                'No matching purchase order advance records found',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try clearing search or selecting "ALL" in the alphabet strip',
                                style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: _tableScrollCtrl,
                          itemCount: list.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, idx) {
                            final r = list[idx];
                            final isSelected = idx == _focusedIndex;
                            final isGlowing = widget.recentlySavedId == r.poId || widget.glowingPoId == r.poId;

                            final poDateStr = r.poDate != null
                                ? '${r.poDate!.day.toString().padLeft(2, '0')}/${r.poDate!.month.toString().padLeft(2, '0')}/${r.poDate!.year}'
                                : '-';
                            final appDtStr = r.appDt != null
                                ? '${r.appDt!.day.toString().padLeft(2, '0')}/${r.appDt!.month.toString().padLeft(2, '0')}/${r.appDt!.year}'
                                : '-';
                            final chqDateStr = r.appMDate != null
                                ? '${r.appMDate!.day.toString().padLeft(2, '0')}/${r.appMDate!.month.toString().padLeft(2, '0')}/${r.appMDate!.year}'
                                : '-';

                            Color rowBgColor;
                            if (isGlowing) {
                              rowBgColor = const Color(0xFFDCFCE7);
                            } else if (isSelected) {
                              rowBgColor = const Color(0xFFEFF6FF);
                            } else {
                              rowBgColor = idx % 2 == 0 ? Colors.white : const Color(0xFFFAFAFA);
                            }

                            return InkWell(
                              onTap: () {
                                setState(() => _focusedIndex = idx);
                              },
                              onDoubleTap: () => _handleSelectRecord(r),
                              child: Container(
                                height: 38,
                                color: rowBgColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    SizedBox(width: 32, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        r.poNo,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 80, child: Text(poDateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF475569)))),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        r.partyName,
                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 85, child: Text(appDtStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)))),
                                    SizedBox(width: 75, child: Text(r.appEMode.isNotEmpty ? r.appEMode : 'Direct', style: const TextStyle(fontSize: 11, color: Color(0xFF475569)), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 100, child: Text(r.chequeNo.isNotEmpty ? r.chequeNo : '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)), overflow: TextOverflow.ellipsis)),
                                    SizedBox(width: 80, child: Text(chqDateStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)))),
                                    SizedBox(
                                      width: 95,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '₹${r.appAmt.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 75,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          '₹${r.appLess.toStringAsFixed(2)}',
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        r.appRemark.isNotEmpty ? r.appRemark : '-',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 75,
                                      child: Text(
                                        r.appUsrName.isNotEmpty ? r.appUsrName : 'ADMIN',
                                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 65,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          // Select / Load Button
                                          InkWell(
                                            onTap: () => _handleSelectRecord(r),
                                            borderRadius: BorderRadius.circular(6),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Delete Button
                                          InkWell(
                                            onTap: () => _handleDelete(r),
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

                // 5. FOOTER SUMMARY BAR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tip: Use Arrow keys to navigate, press Enter to load row, or double click',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      Row(
                        children: [
                          Text(
                            'Showing ${list.length} Records  |  Total Advance: ',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                          ),
                          Text(
                            '₹${totalDisbursed.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF047857)),
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
      ),
    );
  }
}

// ============================================================================
// DELETE CONFIRMATION DIALOG WITH DATE LOCK SAFETY
// ============================================================================

class _ConfirmDeleteAdvanceDialog extends StatefulWidget {
  final PoAdvanceHistoryRecord record;
  final Future<bool> Function() onDelete;

  const _ConfirmDeleteAdvanceDialog({
    required this.record,
    required this.onDelete,
  });

  @override
  State<_ConfirmDeleteAdvanceDialog> createState() => _ConfirmDeleteAdvanceDialogState();
}

class _ConfirmDeleteAdvanceDialogState extends State<_ConfirmDeleteAdvanceDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _executeDelete() async {
    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onDelete();
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isDeleting = false;
          _errorMessage = 'Failed to delete advance record.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Void Advance Payment?',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'This will permanently delete the transaction from ledger records',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _detailRow('PO Number', widget.record.poNo),
                  const SizedBox(height: 4),
                  _detailRow('Supplier', widget.record.partyName),
                  const SizedBox(height: 4),
                  _detailRow('Disbursed Amount', '₹${widget.record.appAmt.toStringAsFixed(2)}', isBold: true),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isDeleting ? null : _executeDelete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 1,
                    ),
                    child: _isDeleting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: isBold ? const Color(0xFF047857) : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
