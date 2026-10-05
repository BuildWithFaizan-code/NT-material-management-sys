import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/design/app_colors.dart';
import 'package:newtechmms/utils/file_export_helper.dart';
import 'package:newtechmms/pages/bom/bom_models.dart';

// ============================================================================
// COMPREHENSIVE BOM EXPORT MODAL DIALOG (PROJECT MASTER PARITY)
// ============================================================================
class BomExportModalDialog extends StatefulWidget {
  final List<BomRecordSummary> records;

  const BomExportModalDialog({super.key, required this.records});

  @override
  State<BomExportModalDialog> createState() => _BomExportModalDialogState();
}

class _BomExportModalDialogState extends State<BomExportModalDialog> {
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

  List<BomRecordSummary> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final idMatch = r.bomId.toLowerCase().contains(_modalSearchQuery);
      final codeMatch = r.iCode.toLowerCase().contains(_modalSearchQuery);
      final descMatch = r.description.toLowerCase().contains(_modalSearchQuery);
      final strMatch = r.strName.toLowerCase().contains(_modalSearchQuery);
      final depMatch = r.depName.toLowerCase().contains(_modalSearchQuery);
      final poMatch = r.bomPo.toLowerCase().contains(_modalSearchQuery);
      final typeMatch = r.bomType.toLowerCase().contains(_modalSearchQuery);
      final statusMatch = r.status.toLowerCase().contains(_modalSearchQuery);
      return idMatch || codeMatch || descMatch || strMatch || depMatch || poMatch || typeMatch || statusMatch;
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
    if (_selectedBomIds.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final double progress = (currentStep / 20.0).clamp(0.0, 1.0);

      setState(() {
        _exportProgress = progress;
      });

      if (progress >= 1.0) {
        timer.cancel();
        _finalizeFileAndComplete();
      }
    });
  }

  Future<void> _finalizeFileAndComplete() async {
    try {
      final selectedList = widget.records
          .where((r) => _selectedBomIds.contains(r.bomId))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'BOM_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Bill of Materials');
        final excel_pkg.Sheet sheet = excel['Bill of Materials'];

        // Set generous column widths
        sheet.setColumnWidth(0, 10.0); // SR NO
        sheet.setColumnWidth(1, 22.0); // BOM ID
        sheet.setColumnWidth(2, 16.0); // DATE
        sheet.setColumnWidth(3, 14.0); // TYPE
        sheet.setColumnWidth(4, 24.0); // FG CODE
        sheet.setColumnWidth(5, 38.0); // FG DESCRIPTION
        sheet.setColumnWidth(6, 22.0); // PLANT / STORE
        sheet.setColumnWidth(7, 20.0); // DEPARTMENT
        sheet.setColumnWidth(8, 18.0); // PO #
        sheet.setColumnWidth(9, 14.0); // BASE QTY
        sheet.setColumnWidth(10, 12.0); // UOM
        sheet.setColumnWidth(11, 14.0); // STATUS
        sheet.setColumnWidth(12, 16.0); // COMPONENTS

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
          excel_pkg.TextCellValue('TYPE'),
          excel_pkg.TextCellValue('FG CODE'),
          excel_pkg.TextCellValue('FG DESCRIPTION'),
          excel_pkg.TextCellValue('PLANT / STORE'),
          excel_pkg.TextCellValue('DEPARTMENT'),
          excel_pkg.TextCellValue('PO #'),
          excel_pkg.TextCellValue('BASE QTY'),
          excel_pkg.TextCellValue('UOM'),
          excel_pkg.TextCellValue('STATUS'),
          excel_pkg.TextCellValue('COMPONENTS'),
        ]);

        for (int col = 0; col < 13; col++) {
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
            excel_pkg.TextCellValue('${r.bomDate.day.toString().padLeft(2, '0')}/${r.bomDate.month.toString().padLeft(2, '0')}/${r.bomDate.year}'),
            excel_pkg.TextCellValue(r.bomType),
            excel_pkg.TextCellValue(r.iCode),
            excel_pkg.TextCellValue(r.description),
            excel_pkg.TextCellValue(r.strName),
            excel_pkg.TextCellValue(r.depName),
            excel_pkg.TextCellValue(r.bomPo.isNotEmpty ? r.bomPo : '-'),
            excel_pkg.DoubleCellValue(r.qty),
            excel_pkg.TextCellValue(r.unitName),
            excel_pkg.TextCellValue(r.status),
            excel_pkg.IntCellValue(r.subItemCount),
          ]);

          for (int col = 0; col < 13; col++) {
            sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rIdx)).cellStyle = style;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        final pdfDoc = pw.Document();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            maxPages: 1000,
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BILL OF MATERIALS (BOM) REGISTER REPORT',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF0C3B2E),
                      ),
                    ),
                    pw.Text(
                      'NEW TECH INFOSOL MMS',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Total Records: ${selectedList.length}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Exported on: ${DateTime.now().toString().split('.')[0]}',
                      style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(thickness: 1, color: const PdfColor.fromInt(0xFF0C3B2E)),
                pw.SizedBox(height: 8),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by New Tech MMS', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
            build: (context) => [
              pw.TableHelper.fromTextArray(
                headers: ['SR', 'BOM ID', 'DATE', 'TYPE', 'FG CODE', 'FG DESCRIPTION', 'PLANT', 'DEPT', 'PO #', 'QTY', 'UOM', 'STATUS'],
                data: selectedList.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final r = entry.value;
                  final dStr = '${r.bomDate.day.toString().padLeft(2, '0')}/${r.bomDate.month.toString().padLeft(2, '0')}/${r.bomDate.year}';
                  return [
                    '${idx + 1}',
                    r.bomId,
                    dStr,
                    r.bomType,
                    r.iCode,
                    r.description,
                    r.strName,
                    r.depName,
                    r.bomPo.isNotEmpty ? r.bomPo : '-',
                    '${r.qty}',
                    r.unitName,
                    r.status,
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8.0),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerLeft,
                  5: pw.Alignment.centerLeft,
                  6: pw.Alignment.centerLeft,
                  7: pw.Alignment.centerLeft,
                  8: pw.Alignment.center,
                  9: pw.Alignment.centerRight,
                  10: pw.Alignment.center,
                  11: pw.Alignment.center,
                },
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.6),
                  1: const pw.FlexColumnWidth(1.8),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.0),
                  4: const pw.FlexColumnWidth(2.0),
                  5: const pw.FlexColumnWidth(3.4),
                  6: const pw.FlexColumnWidth(1.8),
                  7: const pw.FlexColumnWidth(1.8),
                  8: const pw.FlexColumnWidth(1.3),
                  9: const pw.FlexColumnWidth(0.9),
                  10: const pw.FlexColumnWidth(0.8),
                  11: const pw.FlexColumnWidth(1.0),
                },
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                ),
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

        // Quick 650ms delay for user to see the animated checkmark directly on the button
        await Future.delayed(const Duration(milliseconds: 650));

        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      debugPrint('Export BOM failed: $e\n$stack');
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
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 920,
            height: 610,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.93),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.98), width: 1.8),
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
                    // LEFT COLUMN: Format Selector & Options (440px)
                    SizedBox(
                      width: 440,
                      child: Container(
                        color: const Color(0xFFF8FAFC),
                        padding: const EdgeInsets.all(24),
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
                                  child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Export Bill of Materials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      SizedBox(height: 2),
                                      Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards (With Big 3D Excel & PDF Brand Logos)
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSideBySideCard(
                                    formatKey: 'XLSX',
                                    title: 'Excel (.xlsx)',
                                    subtitle: 'Structured sheet with zebra rows',
                                    logoWidget: const Excel3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFF2E7D32),
                                    bgColor: const Color(0xFFEAF5EE),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildSideBySideCard(
                                    formatKey: 'PDF',
                                    title: 'PDF (.pdf)',
                                    subtitle: 'Clean printable report document',
                                    logoWidget: const Pdf3DBrandLogoWidget(size: 42),
                                    brandColor: const Color(0xFFC62828),
                                    bgColor: const Color(0xFFFFEBEE),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(),

                            if (_isExporting) ...[
                              LinearProgressIndicator(
                                value: _exportProgress,
                                backgroundColor: AppColors.divider,
                                color: const Color(0xFF0C3B2E),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Generating Export File... ${(_exportProgress * 100).toInt()}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSuccessButton(
                                    status: _isExporting
                                        ? ButtonStatus.loading
                                        : (_isExportSuccess ? ButtonStatus.success : ButtonStatus.idle),
                                    onPressed: _startExportProcess,
                                    idleText: 'Download File',
                                    loadingText: 'Exporting...',
                                    successText: 'Exported!',
                                    idleIcon: Icons.file_download_outlined,
                                    idleBackgroundColor: const Color(0xFF0C3B2E),
                                    successBackgroundColor: const Color(0xFF10B981),
                                    height: 44,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.divider),
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            _buildPreviewTableToolbar(),
                            const SizedBox(height: 14),
                            Expanded(child: _buildPreviewDataTable()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      hoverColor: Colors.black.withValues(alpha: 0.12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.neutralDark, size: 18),
                    tooltip: 'Close Modal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideBySideCard({
    required String formatKey,
    required String title,
    required String subtitle,
    required Widget logoWidget,
    required Color brandColor,
    required Color bgColor,
  }) {
    final isSelected = _selectedFormat == formatKey;

    return InkWell(
      onTap: _isExporting ? null : () => setState(() => _selectedFormat = formatKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: isSelected ? brandColor : Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? brandColor : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTableToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search records...',
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.neutralDark.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppColors.secondaryColor),
                suffixIcon: _modalSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () => _modalSearchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _toggleSelectAllFiltered,
          borderRadius: BorderRadius.circular(6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _isAllFilteredSelected,
                onChanged: (val) => _toggleSelectAllFiltered(),
                activeColor: AppColors.secondaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              const Text(
                'Select All',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_selectedBomIds.length} of ${widget.records.length} selected',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
        const SizedBox(width: 38),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final previewList = _filteredPreviewRecords;
    if (previewList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: AppColors.neutralDark.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'No BOM records found',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.neutralDark.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              height: 40,
              color: const Color(0xFF0C3B2E),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
                  SizedBox(width: 36, child: Text('SEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 110, child: Text('BOM ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  SizedBox(width: 70, child: Text('TYPE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(child: Text('FG CODE & DESCRIPTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.left)),
                  SizedBox(width: 90, child: Text('STATUS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: previewList.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
                itemBuilder: (ctx, idx) {
                  final r = previewList[idx];
                  final isSelected = _selectedBomIds.contains(r.bomId);
                  final isJob = r.bomType.toUpperCase() == 'JOB';

                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedBomIds.remove(r.bomId);
                        } else {
                          _selectedBomIds.add(r.bomId);
                        }
                      });
                    },
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.white,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Checkbox(
                              value: isSelected,
                              activeColor: AppColors.secondaryColor,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedBomIds.add(r.bomId);
                                  } else {
                                    _selectedBomIds.remove(r.bomId);
                                  }
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 110,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isJob ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isJob ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0)),
                              ),
                              child: Text(
                                r.bomId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                  fontFamily: 'monospace',
                                  color: isJob ? const Color(0xFF2563EB) : const Color(0xFF059669),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 64,
                            child: Text(
                              r.bomType,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isJob ? const Color(0xFF2563EB) : const Color(0xFF059669),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.description,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  r.iCode,
                                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.neutralDark.withValues(alpha: 0.6)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.status.toUpperCase() == 'OPEN' ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: r.status.toUpperCase() == 'OPEN' ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA)),
                                ),
                                child: Text(
                                  r.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: r.status.toUpperCase() == 'OPEN' ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
    );
  }
}

// ============================================================================
// AUTHENTIC 3D VECTOR BRAND LOGO WIDGETS (PROJECT MASTER PARITY)
// ============================================================================

/// Authentic 3D Microsoft Excel Brand Badge Logo
class Excel3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Excel3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF107C41).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Excel3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Excel3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Dark to medium Excel green)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Right side 3D Grid Panel (Lighter green sheet with white grid cells)
    final sheetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
      ).createShader(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h), Radius.circular(w * 0.08)),
      sheetPaint,
    );

    // Grid lines
    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    // Horizontal grid lines
    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);

    // Vertical grid line
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    // 3D Elevated Left Block (Dark Green Front Plate)
    final platePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)));

    // Shadow under left plate
    canvas.drawPath(
      platePath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    final plateGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF185ABD), Color(0xFF107C41), Color(0xFF0E5C2F)],
        stops: [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h), Radius.circular(w * 0.18)),
      plateGradient,
    );

    // Gloss highlight on top of plate
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w * 0.52, h * 0.4), Radius.circular(w * 0.18)),
      glossPaint,
    );

    // Bold Embossed White 'X'
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.62,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(1, 1.5),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.09, h * 0.08));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Authentic 3D Adobe PDF Brand Badge Logo
class Pdf3DBrandLogoWidget extends StatelessWidget {
  final double size;
  const Pdf3DBrandLogoWidget({super.key, this.size = 42.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE11D48).withValues(alpha: 0.38),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Pdf3DLogoPainter(),
        ),
      ),
    );
  }
}

class _Pdf3DLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Background Gradient (Deep Red Adobe gradient)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF3B30), Color(0xFFD32F2F), Color(0xFF8E0000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // 3D Folded Top Right Corner
    final foldPath = Path()
      ..moveTo(w * 0.70, 0)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.30)
      ..close();

    final foldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)],
      ).createShader(Rect.fromLTWH(w * 0.70, 0, w * 0.30, h * 0.30));

    canvas.drawPath(foldPath, foldPaint);

    // Fold Shadow
    final foldShadow = Path()
      ..moveTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.40)
      ..close();
    canvas.drawPath(foldShadow, Paint()..color = Colors.black.withValues(alpha: 0.25));

    // Gloss Highlight Header
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), glossPaint);

    // Authentic Adobe Ribbon Curve / 'PDF' Text Badge
    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final ribbonPath = Path();
    ribbonPath.moveTo(w * 0.22, h * 0.72);
    ribbonPath.cubicTo(w * 0.22, h * 0.38, w * 0.48, h * 0.35, w * 0.50, h * 0.55);
    ribbonPath.cubicTo(w * 0.52, h * 0.75, w * 0.78, h * 0.72, w * 0.78, h * 0.42);

    canvas.drawPath(
      ribbonPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawPath(ribbonPath, ribbonPaint);

    // PDF text at top
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.26,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.10, h * 0.08));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// ANIMATED SUCCESS BUTTON WIDGET (PROJECT MASTER PARITY)
// ============================================================================
enum ButtonStatus { idle, loading, success }

class AnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const AnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Processing...',
    this.successText = 'Success!',
    this.idleIcon = Icons.save_rounded,
    this.idleBackgroundColor = const Color(0xFF0C3B2E),
    this.successBackgroundColor = const Color(0xFF10B981),
    this.height = 44,
  });

  @override
  State<AnimatedSuccessButton> createState() => _AnimatedSuccessButtonState();
}

class _AnimatedSuccessButtonState extends State<AnimatedSuccessButton>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeOut));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeInOut));

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));

    if (widget.status == ButtonStatus.success) {
      _triggerSuccess();
    }
  }

  void _triggerSuccess() {
    _checkController.forward(from: 0.0);
    _rippleController.forward(from: 0.0);
    _glowController.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(covariant AnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status && widget.status == ButtonStatus.success) {
      _triggerSuccess();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.status == ButtonStatus.success;
    final isLoading = widget.status == ButtonStatus.loading;

    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _rippleController, _glowController]),
      builder: (context, child) {
        return Transform.scale(
          scale: isSuccess ? _bounceAnimation.value : 1.0,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: isSuccess
                  ? [
                      BoxShadow(
                        color: widget.successBackgroundColor.withValues(alpha: 0.4 * _glowAnimation.value),
                        blurRadius: 16 * _glowAnimation.value,
                        spreadRadius: 2 * _glowAnimation.value,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSuccess && _rippleAnimation.value > 0)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.successBackgroundColor.withValues(alpha: 1.0 - _rippleAnimation.value),
                          width: 3 * _rippleAnimation.value,
                        ),
                      ),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isLoading ? null : widget.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? widget.successBackgroundColor : widget.idleBackgroundColor,
                    disabledBackgroundColor: widget.idleBackgroundColor.withValues(alpha: 0.7),
                    foregroundColor: Colors.white,
                    elevation: isSuccess ? 4 : 0,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(widget.loadingText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      ] else if (isSuccess) ...[
                        Transform.scale(
                          scale: _scaleAnimation.value,
                          child: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(widget.successText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      ] else ...[
                        Icon(widget.idleIcon, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(widget.idleText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
