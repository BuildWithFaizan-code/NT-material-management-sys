import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/utils/file_export_helper.dart';
import '../bom_models.dart';
import '../bom_followup_models.dart';
import 'bom_export_modal_dialog.dart';

/// BOM Followup / Close Screen Export Modal Dialog
/// Reuses 100% of the Project Master & BOM Export Modal design language,
/// 3D brand badges, column layout, micro-interactions, and byte-stream generation.
class BomFollowupExportModalDialog extends StatefulWidget {
  final List<BomFollowupRecord> records;

  const BomFollowupExportModalDialog({super.key, required this.records});

  @override
  State<BomFollowupExportModalDialog> createState() => _BomFollowupExportModalDialogState();
}

class _BomFollowupExportModalDialogState extends State<BomFollowupExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedBomIds;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedBomIds = widget.records.map((r) => r.bomId).toSet();
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

  List<BomFollowupRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final idMatch = r.bomId.toLowerCase().contains(_modalSearchQuery);
      final codeMatch = r.materialCode.toLowerCase().contains(_modalSearchQuery);
      final descMatch = r.materialName.toLowerCase().contains(_modalSearchQuery);
      final branchMatch = r.branch.toLowerCase().contains(_modalSearchQuery);
      final depMatch = r.department.toLowerCase().contains(_modalSearchQuery);
      final divMatch = r.division.toLowerCase().contains(_modalSearchQuery);
      final userMatch = r.user.toLowerCase().contains(_modalSearchQuery);
      return idMatch || codeMatch || descMatch || branchMatch || depMatch || divMatch || userMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedBomIds.contains(r.bomId));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedBomIds.remove(r.bomId);
        }
      } else {
        for (final r in preview) {
          _selectedBomIds.add(r.bomId);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedBomIds.isEmpty) return;

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
          _finalizeExportFile();
        }
      });
    });
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateTime(DateTime? d) {
    if (d == null) return '-';
    final date = _formatDate(d);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  Future<void> _finalizeExportFile() async {
    final selectedList = widget.records.where((r) => _selectedBomIds.contains(r.bomId)).toList();

    try {
      final now = DateTime.now();
      final stamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

      if (_selectedFormat == 'XLSX') {
        final fileName = 'BOM_FOLLOWUP_EXPORT_$stamp.xlsx';
        final excel = excel_pkg.Excel.createExcel();
        final sheet = excel['BOM_FOLLOWUP'];
        excel.setDefaultSheet('BOM_FOLLOWUP');

        // Column widths
        sheet.setColumnWidth(0, 8.0); // SR NO
        sheet.setColumnWidth(1, 20.0); // BOM ID
        sheet.setColumnWidth(2, 14.0); // DATE
        sheet.setColumnWidth(3, 26.0); // DEPARTMENT
        sheet.setColumnWidth(4, 24.0); // BRANCH
        sheet.setColumnWidth(5, 24.0); // DIVISION
        sheet.setColumnWidth(6, 36.0); // MATERIAL NAME
        sheet.setColumnWidth(7, 24.0); // MATERIAL CODE
        sheet.setColumnWidth(8, 12.0); // QTY
        sheet.setColumnWidth(9, 12.0); // STATUS
        sheet.setColumnWidth(10, 22.0); // DT & TIME
        sheet.setColumnWidth(11, 14.0); // USER
        sheet.setColumnWidth(12, 14.0); // RATE
        sheet.setColumnWidth(13, 10.0); // UQC

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

        final excel_pkg.CellStyle evenStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#F8FAFC'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
          leftBorder: cellBorder,
          rightBorder: cellBorder,
          topBorder: cellBorder,
          bottomBorder: cellBorder,
        );

        final excel_pkg.CellStyle oddStyle = excel_pkg.CellStyle(
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
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
          excel_pkg.TextCellValue('BOM ID'),
          excel_pkg.TextCellValue('DATE'),
          excel_pkg.TextCellValue('DEPARTMENT'),
          excel_pkg.TextCellValue('BRANCH'),
          excel_pkg.TextCellValue('DIVISION'),
          excel_pkg.TextCellValue('MATERIAL NAME'),
          excel_pkg.TextCellValue('MATERIAL CODE'),
          excel_pkg.TextCellValue('QTY'),
          excel_pkg.TextCellValue('STATUS'),
          excel_pkg.TextCellValue('DT & TIME'),
          excel_pkg.TextCellValue('USER'),
          excel_pkg.TextCellValue('RATE'),
          excel_pkg.TextCellValue('UQC'),
        ]);

        for (int col = 0; col < 14; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final r = selectedList[i];
          final style = (i % 2 == 0) ? evenStyle : oddStyle;
          final int rIdx = i + 1;

          sheet.setRowHeight(rIdx, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(i + 1),
            excel_pkg.TextCellValue(r.bomId),
            excel_pkg.TextCellValue(_formatDate(r.bomDate)),
            excel_pkg.TextCellValue(r.department),
            excel_pkg.TextCellValue(r.branch),
            excel_pkg.TextCellValue(r.division),
            excel_pkg.TextCellValue(r.materialName),
            excel_pkg.TextCellValue(r.materialCode),
            excel_pkg.DoubleCellValue(r.qty),
            excel_pkg.TextCellValue(r.status),
            excel_pkg.TextCellValue(_formatDateTime(r.dtAndTime)),
            excel_pkg.TextCellValue(r.user),
            excel_pkg.DoubleCellValue(r.rate),
            excel_pkg.TextCellValue(r.uqc),
          ]);

          for (int col = 0; col < 14; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        final fileName = 'BOM_FOLLOWUP_EXPORT_$stamp.pdf';
        final pdfDoc = pw.Document();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            maxPages: 1000,
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'BILL OF MATERIAL FOLLOW UP / CLOSE REPORT',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF0C3B2E),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Verified Open Bill of Material Records',
                          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Export Date: ${_formatDateTime(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Total Records: ${selectedList.length}',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF0C3B2E)),
                pw.SizedBox(height: 6),
              ],
            ),
            footer: (context) => pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ),
            build: (context) => [
              pw.TableHelper.fromTextArray(
                headers: [
                  'SR',
                  'BOM ID',
                  'DATE',
                  'DEPARTMENT',
                  'BRANCH',
                  'DIVISION',
                  'MATERIAL NAME',
                  'CODE',
                  'QTY',
                  'STATUS',
                  'USER',
                  'RATE',
                  'UQC',
                ],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  return [
                    '${idx + 1}',
                    r.bomId,
                    _formatDate(r.bomDate),
                    r.department,
                    r.branch,
                    r.division,
                    r.materialName,
                    r.materialCode,
                    r.qty.toStringAsFixed(3),
                    r.status,
                    r.user,
                    r.rate.toStringAsFixed(2),
                    r.uqc,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 7.0),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerLeft,
                  6: pw.Alignment.centerLeft,
                  7: pw.Alignment.centerLeft,
                  8: pw.Alignment.centerRight,
                  9: pw.Alignment.center,
                  10: pw.Alignment.center,
                  11: pw.Alignment.centerRight,
                  12: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAFC)),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              ),
            ],
          ),
        );
        final pdfBytes = await pdfDoc.save();
        await FileExportHelper.saveAndLaunchFile(bytes: pdfBytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));
        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint('Export BOM Followup failed: $e\n$stack');
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: (MediaQuery.of(context).size.width * 0.85).clamp(980.0, 1180.0),
            height: 610,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT COLUMN: Format Selector & Options (370px)
                    SizedBox(
                      width: 370,
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF5EE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.file_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Export BOM Followup',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Download active follow up records',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text(
                              'EXPORT FORMAT',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF94A3B8),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Excel format card
                            _buildFormatTile(
                              formatKey: 'XLSX',
                              title: 'Microsoft Excel (.xlsx)',
                              description: 'Formatted spreadsheet with styling & headers',
                              logo: const Excel3DBrandLogoWidget(size: 38),
                            ),
                            const SizedBox(height: 10),

                            // PDF format card
                            _buildFormatTile(
                              formatKey: 'PDF',
                              title: 'Adobe PDF (.pdf)',
                              description: 'Vector-sharp print ready table document',
                              logo: const Pdf3DBrandLogoWidget(size: 38),
                            ),

                            const Spacer(),

                            // Export summary information
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF0C3B2E)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${_selectedBomIds.length} of ${widget.records.length} records selected for export.',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Action button
                            SizedBox(
                              width: double.infinity,
                              child: AnimatedSuccessButton(
                                status: _isExportSuccess
                                    ? ButtonStatus.success
                                    : (_isExporting ? ButtonStatus.loading : ButtonStatus.idle),
                                onPressed: (_selectedBomIds.isEmpty || _isExporting) ? null : _startExportProcess,
                                idleText: 'Download ${_selectedFormat == 'XLSX' ? 'Excel' : 'PDF'}',
                                loadingText: 'Generating $_selectedFormat...',
                                successText: 'Export Complete!',
                                idleIcon: Icons.download_rounded,
                                idleBackgroundColor: const Color(0xFF0C3B2E),
                                successBackgroundColor: const Color(0xFF10B981),
                                height: 44,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    Container(width: 1, color: const Color(0xFFE2E8F0)),

                    // RIGHT COLUMN: Preview & Record Selection
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Select Records to Include',
                                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Showing ${_filteredPreviewRecords.length} records',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                // Search bar inside export dialog
                                Container(
                                  width: 250,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: TextField(
                                    controller: _modalSearchCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search records...',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.only(top: 0, bottom: 8),
                                      suffixIcon: _modalSearchQuery.isNotEmpty
                                          ? IconButton(
                                              icon: const Icon(Icons.clear, size: 14),
                                              onPressed: () => _modalSearchCtrl.clear(),
                                              padding: EdgeInsets.zero,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Select All bar
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: _isAllFilteredSelected,
                                    activeColor: const Color(0xFF0C3B2E),
                                    onChanged: (_) => _toggleSelectAllFiltered(),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isAllFilteredSelected ? 'Deselect All Filtered' : 'Select All Filtered',
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_selectedBomIds.length} Selected',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Record list preview
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ListView.separated(
                                    itemCount: _filteredPreviewRecords.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, idx) {
                                      final item = _filteredPreviewRecords[idx];
                                      final isSelected = _selectedBomIds.contains(item.bomId);

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedBomIds.remove(item.bomId);
                                            } else {
                                              _selectedBomIds.add(item.bomId);
                                            }
                                          });
                                        },
                                        hoverColor: const Color(0xFFF8FAFC),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: isSelected,
                                                activeColor: const Color(0xFF0C3B2E),
                                                onChanged: (_) {
                                                  setState(() {
                                                    if (isSelected) {
                                                      _selectedBomIds.remove(item.bomId);
                                                    } else {
                                                      _selectedBomIds.add(item.bomId);
                                                    }
                                                  });
                                                },
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                visualDensity: VisualDensity.compact,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          item.bomId,
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            fontFamily: 'monospace',
                                                            color: Color(0xFF0C3B2E),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFECFDF5),
                                                            borderRadius: BorderRadius.circular(4),
                                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                                          ),
                                                          child: Text(
                                                            item.status,
                                                            style: const TextStyle(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: Color(0xFF065F46),
                                                            ),
                                                          ),
                                                        ),
                                                        const Spacer(),
                                                        Text(
                                                          _formatDate(item.bomDate),
                                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      item.materialName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Code: ${item.materialCode}',
                                                          style: const TextStyle(
                                                            fontSize: 10.5,
                                                            fontFamily: 'monospace',
                                                            color: Color(0xFF64748B),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            'Dept: ${item.department}',
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          '${item.qty.toStringAsFixed(1)} ${item.uqc}',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF0F172A),
                                                          ),
                                                        ),
                                                      ],
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Top Right Close Button
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                    tooltip: 'Close',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatTile({
    required String formatKey,
    required String title,
    required String description,
    required Widget logo,
  }) {
    final isSelected = _selectedFormat == formatKey;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0C3B2E) : const Color(0xFFCBD5E1),
                  width: isSelected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
