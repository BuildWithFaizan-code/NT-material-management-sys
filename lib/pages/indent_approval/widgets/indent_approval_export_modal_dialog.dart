import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/utils/file_export_helper.dart';
import '../indent_approval_models.dart';

class IndentApprovalExportModalDialog extends StatefulWidget {
  final List<IndentApprovalRecord> records;

  const IndentApprovalExportModalDialog({super.key, required this.records});

  @override
  State<IndentApprovalExportModalDialog> createState() => _IndentApprovalExportModalDialogState();
}

class _IndentApprovalExportModalDialogState extends State<IndentApprovalExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedIds;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.records.map((r) => r.uniqueId).toSet();
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

  List<IndentApprovalRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final idMatch = r.indCode.toLowerCase().contains(_modalSearchQuery);
      final codeMatch = r.code.toLowerCase().contains(_modalSearchQuery);
      final descMatch = r.itName.toLowerCase().contains(_modalSearchQuery);
      final depMatch = r.labName.toLowerCase().contains(_modalSearchQuery);
      final reqMatch = r.reqNo.toLowerCase().contains(_modalSearchQuery);
      final statusMatch = r.status.toLowerCase().contains(_modalSearchQuery);
      return idMatch || codeMatch || descMatch || depMatch || reqMatch || statusMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedIds.contains(r.uniqueId));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedIds.remove(r.uniqueId);
        }
      } else {
        for (final r in preview) {
          _selectedIds.add(r.uniqueId);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedIds.isEmpty) return;

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
          _exportTimer?.cancel();
          _finalizeExportFile();
        }
      });
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _finalizeExportFile() async {
    final selectedList = widget.records.where((r) => _selectedIds.contains(r.uniqueId)).toList();

    try {
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      if (_selectedFormat == 'XLSX') {
        final fileName = 'INDENT_APPROVAL_$stamp.xlsx';
        final excel = excel_pkg.Excel.createExcel();
        final sheet = excel['INDENT_APPROVAL'];
        excel.setDefaultSheet('INDENT_APPROVAL');

        sheet.setColumnWidth(0, 8.0);  // SR NO
        sheet.setColumnWidth(1, 22.0); // INDENT NO
        sheet.setColumnWidth(2, 14.0); // DATE
        sheet.setColumnWidth(3, 24.0); // DEPARTMENT
        sheet.setColumnWidth(4, 18.0); // ITEM CODE
        sheet.setColumnWidth(5, 34.0); // ITEM DESCRIPTION
        sheet.setColumnWidth(6, 12.0); // QTY
        sheet.setColumnWidth(7, 14.0); // RATE
        sheet.setColumnWidth(8, 16.0); // TOTAL VALUE
        sheet.setColumnWidth(9, 14.0); // STATUS
        sheet.setColumnWidth(10, 16.0); // REQ NO
        sheet.setColumnWidth(11, 16.0); // PROCESS DO

        final cellBorder = excel_pkg.Border(
          borderStyle: excel_pkg.BorderStyle.Thin,
          borderColorHex: excel_pkg.ExcelColor.fromHexString('#CBD5E1'),
        );

        final excel_pkg.CellStyle headerStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0C3B2E'),
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          bold: true,
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder,
          rightBorder: cellBorder,
          topBorder: cellBorder,
          bottomBorder: cellBorder,
        );

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('SR NO'),
          excel_pkg.TextCellValue('INDENT NO'),
          excel_pkg.TextCellValue('DATE'),
          excel_pkg.TextCellValue('DEPARTMENT'),
          excel_pkg.TextCellValue('ITEM CODE'),
          excel_pkg.TextCellValue('ITEM DESCRIPTION'),
          excel_pkg.TextCellValue('QTY'),
          excel_pkg.TextCellValue('RATE (₹)'),
          excel_pkg.TextCellValue('TOTAL VALUE (₹)'),
          excel_pkg.TextCellValue('STATUS'),
          excel_pkg.TextCellValue('REQ NO'),
          excel_pkg.TextCellValue('PROCESS DO / PO'),
        ]);

        for (int col = 0; col < 12; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final r = selectedList[i];
          sheet.appendRow([
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(r.indCode),
            excel_pkg.TextCellValue(_formatDate(r.indDate)),
            excel_pkg.TextCellValue(r.labName),
            excel_pkg.TextCellValue(r.code),
            excel_pkg.TextCellValue(r.itName),
            excel_pkg.DoubleCellValue(r.qty),
            excel_pkg.DoubleCellValue(r.rate),
            excel_pkg.DoubleCellValue(r.totalValue),
            excel_pkg.TextCellValue(r.status),
            excel_pkg.TextCellValue(r.reqNo),
            excel_pkg.TextCellValue(r.processDo),
          ]);
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(
            bytes: fileBytes,
            fileName: fileName,
          );
        }
      } else {
        // PDF Export
        final fileName = 'INDENT_APPROVAL_$stamp.pdf';
        final pdf = pw.Document();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            header: (ctx) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 12),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 1)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('NEWTECH INFOSOL - INDENT APPROVAL REPORT',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0C3B2E'))),
                      pw.Text('Total Exported Records: ${selectedList.length}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text('Generated: ${_formatDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
            build: (ctx) => [
              pw.TableHelper.fromTextArray(
                headers: ['#', 'INDENT NO', 'DATE', 'DEPT', 'CODE', 'ITEM NAME', 'QTY', 'RATE', 'TOTAL', 'STATUS'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final r = entry.value;
                  return [
                    '$idx',
                    r.indCode,
                    _formatDate(r.indDate),
                    r.labName,
                    r.code,
                    r.itName,
                    r.qty.toStringAsFixed(2),
                    r.rate.toStringAsFixed(2),
                    r.totalValue.toStringAsFixed(2),
                    r.status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8.5),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0C3B2E')),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              ),
            ],
          ),
        );

        final pdfBytes = await pdf.save();
        await FileExportHelper.saveAndLaunchFile(
          bytes: pdfBytes,
          fileName: fileName,
        );
      }

      if (mounted) {
        setState(() {
          _exportProgress = 1.0;
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportProgress = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _filteredPreviewRecords;
    final totalCount = widget.records.length;
    final selectedCount = _selectedIds.length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 950,
        height: 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // 1. MODAL HEADER
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.file_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Export Indent Approval Records',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Select records and export in Excel (.xlsx) or PDF format',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // 2. FORMAT SELECTOR CARDS & SEARCH BAR
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Row(
                  children: [
                    // Excel Card
                    _buildFormatCard(
                      format: 'XLSX',
                      label: 'Excel Spreadsheet',
                      subtext: '.xlsx format with complete table rows',
                      assetImage: 'assets/images/3d_excel_logo.png',
                      isSelected: _selectedFormat == 'XLSX',
                    ),
                    const SizedBox(width: 14),
                    // PDF Card
                    _buildFormatCard(
                      format: 'PDF',
                      label: 'PDF Document',
                      subtext: '.pdf printable ledger report layout',
                      assetImage: 'assets/images/3d_pdf_logo.png',
                      isSelected: _selectedFormat == 'PDF',
                    ),
                    const Spacer(),
                    // Search box
                    Container(
                      width: 260,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _modalSearchCtrl,
                              style: const TextStyle(fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Search within records...',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. TABLE SELECTION BAR
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAllFilteredSelected,
                      activeColor: const Color(0xFF0C3B2E),
                      onChanged: (val) => _toggleSelectAllFiltered(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Select All (${preview.length} displayed)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    ),
                    const Spacer(),
                    Text(
                      'Selected $selectedCount of $totalCount Indent Record(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 4. PREVIEW GRID
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      itemCount: preview.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (ctx, i) {
                        final r = preview[i];
                        final isChecked = _selectedIds.contains(r.uniqueId);

                        return Container(
                          height: 38,
                          color: isChecked ? const Color(0xFFF0FDF4) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: const Color(0xFF0C3B2E),
                                onChanged: (val) {
                                  setState(() {
                                    if (isChecked) {
                                      _selectedIds.remove(r.uniqueId);
                                    } else {
                                      _selectedIds.add(r.uniqueId);
                                    }
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              SizedBox(
                                width: 35,
                                child: Text('${i + 1}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ),
                              SizedBox(
                                width: 130,
                                child: Text(r.indCode, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E))),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text(_formatDate(r.indDate), style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(r.labName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 90,
                                child: Text(r.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                child: Text(r.itName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                              ),
                              SizedBox(
                                width: 75,
                                child: Text(r.qty.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                              ),
                              SizedBox(
                                width: 85,
                                child: Text('₹ ${r.totalValue.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 80,
                                child: Text(r.status, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: r.isAppro ? const Color(0xFF10B981) : (r.isReject ? const Color(0xFFDC2626) : const Color(0xFF64748B)))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // 5. FOOTER WITH DOWNLOAD BUTTON
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
                ),
                child: Row(
                  children: [
                    if (_isExporting) ...[
                      SizedBox(
                        width: 160,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Exporting ${(_exportProgress * 100).toInt()}%...',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E))),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _exportProgress,
                              color: const Color(0xFF0C3B2E),
                              backgroundColor: const Color(0xFFE2E8F0),
                              minHeight: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton(
                      onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _isExportSuccess
                          ? const Icon(Icons.check_circle_rounded, size: 16)
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        _isExportSuccess ? 'Exported!' : 'Export Selected ($selectedCount)',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                      onPressed: (_isExporting || selectedCount == 0) ? null : _startExportProcess,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildFormatCard({
    required String format,
    required String label,
    required String subtext,
    required String assetImage,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 250,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEAF5EE) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.2,
          ),
        ),
        child: Row(
          children: [
            Image.asset(
              assetImage,
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (ctx, err, stack) => Icon(
                format == 'XLSX' ? Icons.table_chart_rounded : Icons.picture_as_pdf_rounded,
                color: format == 'XLSX' ? const Color(0xFF107C41) : const Color(0xFFD32F2F),
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(subtext, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Color(0xFF0C3B2E), size: 16),
          ],
        ),
      ),
    );
  }
}
