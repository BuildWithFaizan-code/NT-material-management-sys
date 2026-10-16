import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/utils/file_export_helper.dart';
import '../../../design/app_colors.dart';
import '../so_approval_models.dart';

class SoApprovalExportModalDialog extends StatefulWidget {
  final List<SoApprovalRecord> records;

  const SoApprovalExportModalDialog({super.key, required this.records});

  @override
  State<SoApprovalExportModalDialog> createState() => _SoApprovalExportModalDialogState();
}

class _SoApprovalExportModalDialogState extends State<SoApprovalExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedRowKeys;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedRowKeys = widget.records.map((r) => r.rowKey).toSet();
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

  List<SoApprovalRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final soMatch = r.salOrdNo.toLowerCase().contains(_modalSearchQuery);
      final itemMatch = r.itCode.toLowerCase().contains(_modalSearchQuery) ||
          r.itemName.toLowerCase().contains(_modalSearchQuery);
      final partyMatch = r.partyName.toLowerCase().contains(_modalSearchQuery);
      final deptMatch = r.labName.toLowerCase().contains(_modalSearchQuery);
      final statusMatch = r.status.toLowerCase().contains(_modalSearchQuery);
      return soMatch || itemMatch || partyMatch || deptMatch || statusMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedRowKeys.contains(r.rowKey));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedRowKeys.remove(r.rowKey);
        }
      } else {
        for (final r in preview) {
          _selectedRowKeys.add(r.rowKey);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedRowKeys.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    _exportTimer?.cancel();
    _exportTimer = Timer.periodic(const Duration(milliseconds: 35), (timer) {
      setState(() {
        if (_exportProgress < 0.88) {
          _exportProgress += 0.05;
        } else {
          timer.cancel();
          _generateAndDownloadDocument();
        }
      });
    });
  }

  Future<void> _generateAndDownloadDocument() async {
    final exportRows = widget.records.where((r) => _selectedRowKeys.contains(r.rowKey)).toList();

    try {
      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final sheetName = excel.getDefaultSheet() ?? 'SO_Approval_List';
        final sheet = excel[sheetName];

        final headers = [
          'Sr No',
          'SO No',
          'SO Date',
          'Department',
          'Customer Name',
          'Item Code',
          'Item Description',
          'Qty',
          'Rate',
          'Amount',
          'Cell No',
          'Status',
          'Indent No',
          'Close Remark'
        ];

        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int i = 0; i < exportRows.length; i++) {
          final r = exportRows[i];
          final rowData = [
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(r.salOrdNo),
            excel_pkg.TextCellValue(r.soDate.toIso8601String().split('T').first),
            excel_pkg.TextCellValue(r.labName),
            excel_pkg.TextCellValue(r.partyName),
            excel_pkg.TextCellValue(r.itCode),
            excel_pkg.TextCellValue(r.itemName),
            excel_pkg.DoubleCellValue(r.qty),
            excel_pkg.DoubleCellValue(r.rate),
            excel_pkg.DoubleCellValue(r.amount),
            excel_pkg.TextCellValue(r.cellNo),
            excel_pkg.TextCellValue(r.status),
            excel_pkg.TextCellValue(r.indCode),
            excel_pkg.TextCellValue(r.sodClosRem),
          ];
          sheet.appendRow(rowData);
        }

        final bytes = excel.encode();
        if (bytes != null) {
          final filename = 'Sales_Order_Approval_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          await FileExportHelper.saveAndLaunchFile(
            bytes: bytes,
            fileName: filename,
          );
        }
      } else {
        final pdf = pw.Document();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            header: (context) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SALES ORDER RELEASE / APPROVAL REGISTER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                  pw.Text('Exported: ${DateTime.now().toLocal().toString().split('.')[0]}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ),
            build: (context) => [
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['#', 'SO No', 'Date', 'Dept', 'Customer', 'Item Code', 'Item Name', 'Qty', 'Rate', 'Amount', 'Status'],
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                data: List.generate(exportRows.length, (i) {
                  final r = exportRows[i];
                  return [
                    '${i + 1}',
                    r.salOrdNo,
                    r.soDate.toIso8601String().split('T').first,
                    r.labName,
                    r.partyName,
                    r.itCode,
                    r.itemName,
                    r.qty.toStringAsFixed(1),
                    r.rate.toStringAsFixed(2),
                    r.amount.toStringAsFixed(2),
                    r.status,
                  ];
                }),
              ),
            ],
          ),
        );

        final bytes = await pdf.save();
        final filename = 'Sales_Order_Approval_Export_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await FileExportHelper.saveAndLaunchFile(
          bytes: bytes,
          fileName: filename,
        );
      }

      setState(() {
        _exportProgress = 1.0;
        _isExportSuccess = true;
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop();
      });
    } catch (e) {
      debugPrint('Error generating file: $e');
      setState(() {
        _isExporting = false;
        _exportProgress = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: Container(
          width: 950,
          height: 680,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x260F172A), blurRadius: 32, offset: Offset(0, 16)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Modal Header
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_download_outlined, color: AppColors.brandBlue, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Export Sales Order Approval Register', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Download verified customer orders in structured XLSX or PDF document', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                ),

                // Format Selector Cards & Filter Stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFormatCard(
                          format: 'XLSX',
                          title: 'Microsoft Excel Spreadsheet',
                          subtitle: 'Full raw dataset, column formulas, ready for ERP audit',
                          icon: Icons.table_chart_rounded,
                          accentColor: AppColors.excelGreen,
                          bgColor: AppColors.excelGreenLight,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFormatCard(
                          format: 'PDF',
                          title: 'Adobe PDF Document',
                          subtitle: 'Executive presentation layout, print-ready document',
                          icon: Icons.picture_as_pdf_rounded,
                          accentColor: AppColors.pdfRed,
                          bgColor: AppColors.pdfRedLight,
                        ),
                      ),
                    ],
                  ),
                ),

                // Search & Filter Toolbar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: TextField(
                            controller: _modalSearchCtrl,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              prefixIcon: Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                              hintText: 'Search by Order No, Customer, Item, or Status...',
                              hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      InkWell(
                        onTap: _toggleSelectAllFiltered,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isAllFilteredSelected,
                                onChanged: (_) => _toggleSelectAllFiltered(),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                activeColor: AppColors.brandBlue,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isAllFilteredSelected ? 'Deselect All' : 'Select All',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Preview Table
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            height: 36,
                            color: const Color(0xFFF8FAFC),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: const Row(
                              children: [
                                SizedBox(width: 40, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 110, child: Text('SO NO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 85, child: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                Expanded(flex: 3, child: Text('CUSTOMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                Expanded(flex: 3, child: Text('ITEM NAME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 70, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 90, child: Text('AMOUNT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 80, child: Center(child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
                              ],
                            ),
                          ),

                          // Table Rows
                          Expanded(
                            child: _filteredPreviewRecords.isEmpty
                                ? const Center(
                                    child: Text('No records matched your search query', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                                  )
                                : ListView.separated(
                                    itemCount: _filteredPreviewRecords.length,
                                    separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final item = _filteredPreviewRecords[index];
                                      final isSelected = _selectedRowKeys.contains(item.rowKey);

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedRowKeys.remove(item.rowKey);
                                            } else {
                                              _selectedRowKeys.add(item.rowKey);
                                            }
                                          });
                                        },
                                        child: Container(
                                          height: 38,
                                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 40,
                                                child: Checkbox(
                                                  value: isSelected,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        _selectedRowKeys.add(item.rowKey);
                                                      } else {
                                                        _selectedRowKeys.remove(item.rowKey);
                                                      }
                                                    });
                                                  },
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  activeColor: AppColors.brandBlue,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 110,
                                                child: Text(item.salOrdNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                              ),
                                              SizedBox(
                                                width: 85,
                                                child: Text(item.soDate.toIso8601String().split('T').first, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(item.partyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A))),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Text(item.itemName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
                                              ),
                                              SizedBox(
                                                width: 70,
                                                child: Text(item.qty.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A))),
                                              ),
                                              SizedBox(
                                                width: 90,
                                                child: Text('₹ ${item.amount.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                              ),
                                              SizedBox(
                                                width: 80,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: item.isApproved
                                                          ? const Color(0xFFDCFCE7)
                                                          : (item.isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      item.status,
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: item.isApproved
                                                            ? const Color(0xFF15803D)
                                                            : (item.isRejected ? const Color(0xFFDC2626) : const Color(0xFFB45309)),
                                                      ),
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
                      ),
                    ),
                  ),
                ),

                // Footer Actions & Progress
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${_selectedRowKeys.length} of ${widget.records.length} records selected for export',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: (_isExporting || _selectedRowKeys.isEmpty) ? null : _startExportProcess,
                        icon: _isExporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _isExportSuccess ? Icons.check_circle_rounded : Icons.download_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                        label: Text(
                          _isExportSuccess
                              ? 'Export Complete!'
                              : (_isExporting ? 'Generating (${(_exportProgress * 100).toInt()}%)...' : 'Download $_selectedFormat'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedFormat == 'XLSX' ? AppColors.excelGreen : AppColors.pdfRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
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

  Widget _buildFormatCard({
    required String format,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor.withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: isSelected ? accentColor : const Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                ],
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : const Color(0xFF94A3B8),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
