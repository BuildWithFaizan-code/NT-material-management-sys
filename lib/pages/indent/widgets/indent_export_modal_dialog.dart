import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../../bom/bom_models.dart';
import '../../bom/widgets/bom_animated_success_button.dart';
import '../../bom/widgets/bom_export_modal_dialog.dart';
import '../indent_models.dart';

String _formatIndentDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _formatExportTimestamp() {
  final now = DateTime.now();
  final y = now.year.toString();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  final ss = now.second.toString().padLeft(2, '0');
  return '$y$m${d}_$hh$mm$ss';
}

String _formatExportDateTime(DateTime now) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = now.day.toString().padLeft(2, '0');
  final m = months[now.month - 1];
  final y = now.year.toString();
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  return '$d-$m-$y $hh:$mm';
}

/// 100% Verbatim Parity with Project Master Export Module Dialog
class IndentExportModalDialog extends StatefulWidget {
  final List<IndentHeader> records;

  const IndentExportModalDialog({super.key, required this.records});

  @override
  State<IndentExportModalDialog> createState() => _IndentExportModalDialogState();
}

class _IndentExportModalDialogState extends State<IndentExportModalDialog> {
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
    _selectedRowKeys = widget.records.map((r) => r.indCode).toSet();
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

  List<IndentHeader> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final codeMatch = r.indCode.toLowerCase().contains(_modalSearchQuery);
      final deptMatch = r.deptName.toLowerCase().contains(_modalSearchQuery);
      final storeMatch = r.storeName.toLowerCase().contains(_modalSearchQuery);
      final remarkMatch = r.remark.toLowerCase().contains(_modalSearchQuery);
      final priorityMatch = r.priority.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || deptMatch || storeMatch || remarkMatch || priorityMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedRowKeys.contains(r.indCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedRowKeys.remove(r.indCode);
        }
      } else {
        for (final r in preview) {
          _selectedRowKeys.add(r.indCode);
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
          .where((r) => _selectedRowKeys.contains(r.indCode))
          .toList();

      final timestamp = _formatExportTimestamp();
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'IndentMaster_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Indent Master');
        final excel_pkg.Sheet sheet = excel['Indent Master'];

        // Column widths
        sheet.setColumnWidth(0, 22.0); // INDENT NO
        sheet.setColumnWidth(1, 16.0); // DATE
        sheet.setColumnWidth(2, 28.0); // DEPARTMENT
        sheet.setColumnWidth(3, 26.0); // STORE / LOCATION
        sheet.setColumnWidth(4, 16.0); // PRIORITY
        sheet.setColumnWidth(5, 14.0); // TOTAL ITEMS
        sheet.setColumnWidth(6, 16.0); // TOTAL QTY
        sheet.setColumnWidth(7, 20.0); // TOTAL VALUE
        sheet.setColumnWidth(8, 36.0); // REMARK

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
          excel_pkg.TextCellValue('INDENT NO'),
          excel_pkg.TextCellValue('DATE'),
          excel_pkg.TextCellValue('DEPARTMENT'),
          excel_pkg.TextCellValue('STORE'),
          excel_pkg.TextCellValue('PRIORITY'),
          excel_pkg.TextCellValue('ITEMS'),
          excel_pkg.TextCellValue('TOTAL QTY'),
          excel_pkg.TextCellValue('TOTAL AMT'),
          excel_pkg.TextCellValue('REMARK'),
        ]);

        for (int col = 0; col < 9; col++) {
          final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
          cell.cellStyle = headerStyle;
        }

        for (int i = 0; i < selectedList.length; i++) {
          final r = selectedList[i];
          final rowIdx = i + 1;
          sheet.setRowHeight(rowIdx, 22.0);
          final rowStyle = i.isEven ? evenStyle : oddStyle;

          sheet.appendRow([
            excel_pkg.TextCellValue(r.indCode),
            excel_pkg.TextCellValue(_formatIndentDate(r.indDate)),
            excel_pkg.TextCellValue(r.deptName),
            excel_pkg.TextCellValue(r.storeName),
            excel_pkg.TextCellValue(r.priority),
            excel_pkg.IntCellValue(r.totItem),
            excel_pkg.DoubleCellValue(r.totQty),
            excel_pkg.DoubleCellValue(r.totAmt),
            excel_pkg.TextCellValue(r.remark),
          ]);

          for (int col = 0; col < 9; col++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIdx));
            cell.cellStyle = rowStyle;
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final pdf = pw.Document();
        final nowFormatted = _formatExportDateTime(DateTime.now());

        final tableHeaders = [
          'SrNo', 'Indent No', 'Date', 'Department', 'Store', 'Priority', 'Items', 'Total Qty', 'Total Amt', 'Remark'
        ];

        final tableData = selectedList.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final r = entry.value;
          return [
            idx.toString(),
            r.indCode,
            _formatIndentDate(r.indDate),
            r.deptName,
            r.storeName,
            r.priority,
            r.totItem.toString(),
            r.totQty.toStringAsFixed(2),
            r.totAmt.toStringAsFixed(2),
            r.remark,
          ];
        }).toList();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NEW TECH INFOSOL ERP - INDENT MASTER REPORT',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                    pw.Text('Exported: $nowFormatted', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Total Selected Indents: ${selectedList.length}',
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800)),
                pw.Divider(thickness: 1, color: PdfColors.teal900),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Confidential - For Internal Use Only', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
            build: (context) => [
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              ),
            ],
          ),
        );

        final pdfBytes = await pdf.save();
        await FileExportHelper.saveAndLaunchFile(bytes: pdfBytes, fileName: fileName);
      }

      setState(() {
        _isExporting = false;
        _isExportSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _exportTimer?.cancel();
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 1160,
        height: 690,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                      padding: const EdgeInsets.all(26),
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
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Export Indent Master',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  SizedBox(height: 2),
                                  Text('Select format & download records to your PC',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          const Text('1. Select File Format',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 12),

                          // Side-by-Side Format Cards (With 3D Excel & PDF Logos)
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

                          const SizedBox(height: 24),
                          const Text('2. Output Settings',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              children: [
                                _buildSettingRow(Icons.check_circle_outline, 'Active Location Tag', 'LWHL26_SQL'),
                                const Divider(height: 14, color: Color(0xFFF1F5F9)),
                                _buildSettingRow(Icons.table_rows_outlined, 'Selected Records', '${_selectedRowKeys.length} / ${widget.records.length}'),
                                const Divider(height: 14, color: Color(0xFFF1F5F9)),
                                _buildSettingRow(Icons.security_outlined, 'Access Classification', 'ERP Transaction Audit'),
                              ],
                            ),
                          ),

                          const Spacer(),

                          if (_isExporting) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _exportProgress,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: const Color(0xFF0C3B2E),
                                minHeight: 6,
                              ),
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
                                  child: const Text('Cancel',
                                      style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: BomAnimatedSuccessButton(
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

                  // RIGHT COLUMN: Preview Data Table (flex 7)
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
    );
  }

  Widget _buildSettingRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
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
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? brandColor : const Color(0xFF94A3B8),
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: brandColor,
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: brandColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewTableToolbar() {
    final preview = _filteredPreviewRecords;
    final selectedCount = _selectedRowKeys.length;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _modalSearchCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Search by Indent No, Department, Store, Remark...',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_modalSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => _modalSearchCtrl.clear(),
                    child: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          icon: Icon(_isAllFilteredSelected ? Icons.deselect : Icons.select_all, size: 15),
          label: Text(_isAllFilteredSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11.5)),
          onPressed: _toggleSelectAllFiltered,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0C3B2E),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFDCFCE7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Text(
            '$selectedCount / ${preview.length} Selected',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final preview = _filteredPreviewRecords;

    if (preview.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list_off, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            const Text('No indent records match the preview filter.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 800),
                child: DataTable(
                  headingRowHeight: 38,
                  dataRowMinHeight: 34,
                  dataRowMaxHeight: 36,
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Select', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Indent No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Department', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Store', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total Qty', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Total Amt', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Remark', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ],
                  rows: preview.map((r) {
                    final isSelected = _selectedRowKeys.contains(r.indCode);
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedRowKeys.add(r.indCode);
                          } else {
                            _selectedRowKeys.remove(r.indCode);
                          }
                        });
                      },
                      cells: [
                        DataCell(
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF0C3B2E),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedRowKeys.add(r.indCode);
                                } else {
                                  _selectedRowKeys.remove(r.indCode);
                                }
                              });
                            },
                          ),
                        ),
                        DataCell(Text(r.indCode, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold))),
                        DataCell(Text(_formatIndentDate(r.indDate), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(r.deptName, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(r.storeName, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(r.priority, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(r.totItem.toString(), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(r.totQty.toStringAsFixed(2), style: const TextStyle(fontSize: 11))),
                        DataCell(Text('₹ ${r.totAmt.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)))),
                        DataCell(Text(r.remark, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
