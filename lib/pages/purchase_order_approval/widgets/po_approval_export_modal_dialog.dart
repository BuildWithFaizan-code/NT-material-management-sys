import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/utils/file_export_helper.dart';
import '../../../design/app_colors.dart';
import '../po_approval_models.dart';

class PoApprovalExportModalDialog extends StatefulWidget {
  final List<PoApprovalRecord> records;

  const PoApprovalExportModalDialog({super.key, required this.records});

  @override
  State<PoApprovalExportModalDialog> createState() => _PoApprovalExportModalDialogState();
}

class _PoApprovalExportModalDialogState extends State<PoApprovalExportModalDialog> {
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

  List<PoApprovalRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final poMatch = r.purOrdNo.toLowerCase().contains(_modalSearchQuery);
      final itemMatch = r.itCode.toLowerCase().contains(_modalSearchQuery) ||
          r.itemName.toLowerCase().contains(_modalSearchQuery);
      final partyMatch = r.partyName.toLowerCase().contains(_modalSearchQuery);
      final deptMatch = r.department.toLowerCase().contains(_modalSearchQuery);
      final plantMatch = r.plant.toLowerCase().contains(_modalSearchQuery);
      final statusMatch = r.status.toLowerCase().contains(_modalSearchQuery);
      return poMatch || itemMatch || partyMatch || deptMatch || plantMatch || statusMatch;
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
        final sheetName = excel.getDefaultSheet() ?? 'PO_Approval_List';
        final sheet = excel[sheetName];

        final headers = [
          'Sr No',
          'PO No',
          'PO Date',
          'Ref No',
          'Department',
          'Plant',
          'Supplier',
          'Item Code',
          'Item Description',
          'Shade',
          'PO Qty',
          'Inward Qty',
          'Balance Qty',
          'Rate',
          'Amount',
          'Freight',
          'Status',
          'Process DO',
          'Indent No',
          'Close Remark'
        ];

        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int i = 0; i < exportRows.length; i++) {
          final r = exportRows[i];
          final rowData = [
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(r.purOrdNo),
            excel_pkg.TextCellValue('${r.poDate.day.toString().padLeft(2, '0')}/${r.poDate.month.toString().padLeft(2, '0')}/${r.poDate.year}'),
            excel_pkg.TextCellValue(r.refNo),
            excel_pkg.TextCellValue(r.department),
            excel_pkg.TextCellValue(r.plant),
            excel_pkg.TextCellValue(r.partyName),
            excel_pkg.TextCellValue(r.itCode),
            excel_pkg.TextCellValue(r.itemName),
            excel_pkg.TextCellValue(r.shade),
            excel_pkg.DoubleCellValue(r.poQty),
            excel_pkg.DoubleCellValue(r.inwardQty),
            excel_pkg.DoubleCellValue(r.balanceQty),
            excel_pkg.DoubleCellValue(r.rate),
            excel_pkg.DoubleCellValue(r.amount),
            excel_pkg.DoubleCellValue(r.freight),
            excel_pkg.TextCellValue(r.status),
            excel_pkg.TextCellValue(r.processDo ?? '-'),
            excel_pkg.TextCellValue(r.indCode),
            excel_pkg.TextCellValue(r.podClosRem),
          ];
          sheet.appendRow(rowData);
        }

        final bytes = excel.encode();
        if (bytes != null) {
          final dateStr = DateTime.now().toIso8601String().substring(0, 10);
          await FileExportHelper.saveAndLaunchFile(
            bytes: bytes,
            fileName: 'PO_Release_Approval_$dateStr.xlsx',
          );
        }
      } else {
        // PDF Export
        final pdf = pw.Document();
        final font = pw.Font.helvetica();
        final fontBold = pw.Font.helveticaBold();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context ctx) => [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Purchase Order Approval & Release Register',
                        style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.Text('Date: ${DateTime.now().toString().substring(0, 10)}',
                        style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: [
                  '#',
                  'PO No',
                  'Date',
                  'Department',
                  'Supplier',
                  'Item Name',
                  'PO Qty',
                  'Bal Qty',
                  'Rate',
                  'Amount',
                  'Status'
                ],
                data: exportRows.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    idx.toString(),
                    r.purOrdNo,
                    '${r.poDate.day}/${r.poDate.month}/${r.poDate.year}',
                    r.department,
                    r.partyName,
                    r.itemName,
                    r.poQty.toStringAsFixed(2),
                    r.balanceQty.toStringAsFixed(2),
                    r.rate.toStringAsFixed(2),
                    r.amount.toStringAsFixed(2),
                    r.status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: pw.TextStyle(font: font, fontSize: 7.5),
                cellAlignment: pw.Alignment.centerLeft,
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
              ),
            ],
          ),
        );

        final bytes = await pdf.save();
        final dateStr = DateTime.now().toIso8601String().substring(0, 10);
        await FileExportHelper.saveAndLaunchFile(
          bytes: bytes,
          fileName: 'PO_Release_Approval_$dateStr.pdf',
        );
      }

      setState(() {
        _exportProgress = 1.0;
        _isExportSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewList = _filteredPreviewRecords;
    final totalCount = widget.records.length;
    final selectedCount = _selectedRowKeys.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Center(
        child: Container(
          width: 880,
          constraints: const BoxConstraints(maxHeight: 660),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.tableBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: AppColors.tableHeaderBg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_download_outlined, color: AppColors.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Purchase Order Approval Data',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.neutralDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exporting $selectedCount of $totalCount rows in $_selectedFormat format',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 20),
                    ),
                  ],
                ),
              ),

              // Format Selectors (Excel & PDF)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedFormat = 'XLSX'),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedFormat == 'XLSX'
                                ? const Color(0xFF107C41).withValues(alpha: 0.08)
                                : AppColors.surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedFormat == 'XLSX'
                                  ? const Color(0xFF107C41)
                                  : AppColors.tableBorder,
                              width: _selectedFormat == 'XLSX' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/excel_icon_3d.png',
                                width: 34,
                                height: 34,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 30),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Excel Spreadsheet (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.neutralDark)),
                                  SizedBox(height: 2),
                                  Text('All columns & financial formulas', style: TextStyle(fontSize: 10.5, color: AppColors.slateMuted)),
                                ],
                              ),
                              const Spacer(),
                              if (_selectedFormat == 'XLSX')
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF107C41), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedFormat = 'PDF'),
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedFormat == 'PDF'
                                ? const Color(0xFFDC2626).withValues(alpha: 0.08)
                                : AppColors.surfaceColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedFormat == 'PDF'
                                  ? const Color(0xFFDC2626)
                                  : AppColors.tableBorder,
                              width: _selectedFormat == 'PDF' ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/pdf_icon_3d.png',
                                width: 34,
                                height: 34,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 30),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PDF Document (.pdf)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.neutralDark)),
                                  SizedBox(height: 2),
                                  Text('Landscape format with borders', style: TextStyle(fontSize: 10.5, color: AppColors.slateMuted)),
                                ],
                              ),
                              const Spacer(),
                              if (_selectedFormat == 'PDF')
                                const Icon(Icons.check_circle_rounded, color: Color(0xFFDC2626), size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search & Select All Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAllFilteredSelected,
                      onChanged: (val) => _toggleSelectAllFiltered(),
                      activeColor: AppColors.primaryColor,
                    ),
                    const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _modalSearchCtrl,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Filter preview records...',
                            hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
                            prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.slateMuted),
                            filled: true,
                            fillColor: AppColors.tableRowHover,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Preview List
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.tableBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      itemCount: previewList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.tableBorder),
                      itemBuilder: (ctx, index) {
                        final r = previewList[index];
                        final isSelected = _selectedRowKeys.contains(r.rowKey);

                        return Container(
                          color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedRowKeys.remove(r.rowKey);
                                    } else {
                                      _selectedRowKeys.add(r.rowKey);
                                    }
                                  });
                                },
                                activeColor: AppColors.primaryColor,
                              ),
                              SizedBox(
                                width: 130,
                                child: Text(r.purOrdNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(r.partyName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                child: Text('${r.itCode} - ${r.itemName}', style: const TextStyle(fontSize: 11, color: AppColors.neutralDark), overflow: TextOverflow.ellipsis),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text('Qty: ${r.poQty.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.isApproved
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : (r.isClosed
                                          ? const Color(0xFF64748B).withValues(alpha: 0.12)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: r.isApproved
                                        ? const Color(0xFF047857)
                                        : (r.isClosed ? const Color(0xFF334155) : const Color(0xFFB45309)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Progress indicator during export
              if (_isExporting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: LinearProgressIndicator(
                    value: _exportProgress,
                    backgroundColor: AppColors.tableBorder,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  ),
                ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: AppColors.tableHeaderBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border(top: BorderSide(color: AppColors.tableBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.tableBorder),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.slateMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                      ),
                      onPressed: _isExporting || _selectedRowKeys.isEmpty ? null : _startExportProcess,
                      icon: const Icon(Icons.download_rounded, color: Colors.white, size: 16),
                      label: Text(
                        _isExportSuccess ? 'Downloaded!' : (_isExporting ? 'Generating...' : 'Export $selectedCount Rows'),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
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
}
