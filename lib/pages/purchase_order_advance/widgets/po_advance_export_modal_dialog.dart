import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:newtechmms/utils/file_export_helper.dart';
import '../../../design/app_colors.dart';
import '../../bom/bom_models.dart' show ButtonStatus;
import '../po_advance_models.dart';

// ============================================================================
// EXPORT MODAL DIALOG (PROJECT MASTER VERBATIM MIRROR)
// ============================================================================

enum ExportFormat { excel, pdf }

class PoAdvanceExportModalDialog extends StatefulWidget {
  final List<PoAdvanceHistoryRecord> records;
  final String poNo;
  final String partyName;

  const PoAdvanceExportModalDialog({
    super.key,
    required this.records,
    required this.poNo,
    required this.partyName,
  });

  @override
  State<PoAdvanceExportModalDialog> createState() => _PoAdvanceExportModalDialogState();
}

class _PoAdvanceExportModalDialogState extends State<PoAdvanceExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedIds;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.records.map((r) => r.poId).toSet();
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

  List<PoAdvanceHistoryRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final poMatch = r.poNo.toLowerCase().contains(_modalSearchQuery);
      final partyMatch = r.partyName.toLowerCase().contains(_modalSearchQuery);
      final modeMatch = r.appEMode.toLowerCase().contains(_modalSearchQuery);
      final chequeMatch = r.chequeNo.toLowerCase().contains(_modalSearchQuery);
      final remarkMatch = r.appRemark.toLowerCase().contains(_modalSearchQuery);
      return poMatch || partyMatch || modeMatch || chequeMatch || remarkMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedIds.contains(r.poId));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedIds.remove(r.poId);
        }
      } else {
        for (final r in preview) {
          _selectedIds.add(r.poId);
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
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      final progress = (currentStep / 10.0).clamp(0.0, 1.0);
      setState(() {
        _exportProgress = progress;
      });

      if (progress >= 1.0) {
        timer.cancel();
        _generateAndDownloadFile();
      }
    });
  }

  Future<void> _generateAndDownloadFile() async {
    try {
      final exportData = widget.records.where((r) => _selectedIds.contains(r.poId)).toList();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'PO_Advance_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final sheetName = 'PO Advance History';
        final sheet = excel[sheetName];
        excel.setDefaultSheet(sheetName);

        // Header Styling
        final headerStyle = excel_pkg.CellStyle(
          fontFamily: excel_pkg.getFontFamily(excel_pkg.FontFamily.Arial),
          bold: true,
          fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
          backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#0C3B2E'),
          horizontalAlign: excel_pkg.HorizontalAlign.Center,
          verticalAlign: excel_pkg.VerticalAlign.Center,
        );

        final headers = [
          '#',
          'PO Number',
          'PO Date',
          'Supplier / Party Name',
          'Voucher Date',
          'Payment Mode',
          'Cheque / Ref No.',
          'Cheque Date',
          'Advance Amount (₹)',
          'Less / Deductions (₹)',
          'Remarks / Narration',
          'Created By User',
        ];

        for (int col = 0; col < headers.length; col++) {
          final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
          cell.value = excel_pkg.TextCellValue(headers[col]);
          cell.cellStyle = headerStyle;
        }

        // Data Rows
        for (int i = 0; i < exportData.length; i++) {
          final r = exportData[i];
          final poDateStr = r.poDate != null
              ? '${r.poDate!.day.toString().padLeft(2, '0')}/${r.poDate!.month.toString().padLeft(2, '0')}/${r.poDate!.year}'
              : '-';
          final appDtStr = r.appDt != null
              ? '${r.appDt!.day.toString().padLeft(2, '0')}/${r.appDt!.month.toString().padLeft(2, '0')}/${r.appDt!.year}'
              : '-';
          final chqDateStr = r.appMDate != null
              ? '${r.appMDate!.day.toString().padLeft(2, '0')}/${r.appMDate!.month.toString().padLeft(2, '0')}/${r.appMDate!.year}'
              : '-';

          final rowData = [
            (i + 1).toString(),
            r.poNo,
            poDateStr,
            r.partyName,
            appDtStr,
            r.appEMode.isNotEmpty ? r.appEMode : 'Direct',
            r.chequeNo.isNotEmpty ? r.chequeNo : '-',
            chqDateStr,
            r.appAmt.toStringAsFixed(2),
            r.appLess.toStringAsFixed(2),
            r.appRemark.isNotEmpty ? r.appRemark : '-',
            r.appUsrName.isNotEmpty ? r.appUsrName : 'ADMIN',
          ];

          for (int col = 0; col < rowData.length; col++) {
            final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: i + 1));
            cell.value = excel_pkg.TextCellValue(rowData[col]);
          }
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Report Generation
        final pdfDoc = pw.Document();
        final fontRegular = pw.Font.helvetica();
        final fontBold = pw.Font.helveticaBold();

        pdfDoc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(20),
            build: (pw.Context ctx) {
              return [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'NEW TECH INFOSOL - PURCHASE ORDER ADVANCE STATEMENT',
                          style: pw.TextStyle(font: fontBold, fontSize: 13, color: PdfColors.teal900),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Supplier: ${widget.partyName}  |  PO: ${widget.poNo}',
                          style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Exported on: ${DateTime.now().toString().split('.')[0]}',
                      style: pw.TextStyle(font: fontRegular, fontSize: 8.5, color: PdfColors.grey600),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0C3B2E)),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 7.5),
                  cellHeight: 22,
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.center,
                    5: pw.Alignment.center,
                    6: pw.Alignment.centerLeft,
                    7: pw.Alignment.centerRight,
                    8: pw.Alignment.centerRight,
                    9: pw.Alignment.centerLeft,
                    10: pw.Alignment.center,
                  },
                  headers: [
                    '#',
                    'PO Number',
                    'PO Date',
                    'Supplier',
                    'Voucher Dt',
                    'Mode',
                    'Cheque No',
                    'Adv Amt (INR)',
                    'Less (INR)',
                    'Remarks',
                    'User',
                  ],
                  data: exportData.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    final poDtStr = r.poDate != null ? '${r.poDate!.day}/${r.poDate!.month}/${r.poDate!.year}' : '-';
                    final appDtStr = r.appDt != null ? '${r.appDt!.day}/${r.appDt!.month}/${r.appDt!.year}' : '-';

                    return [
                      (idx + 1).toString(),
                      r.poNo,
                      poDtStr,
                      r.partyName,
                      appDtStr,
                      r.appEMode.isNotEmpty ? r.appEMode : 'Direct',
                      r.chequeNo.isNotEmpty ? r.chequeNo : '-',
                      r.appAmt.toStringAsFixed(2),
                      r.appLess.toStringAsFixed(2),
                      r.appRemark.isNotEmpty ? r.appRemark : '-',
                      r.appUsrName.isNotEmpty ? r.appUsrName : 'ADMIN',
                    ];
                  }).toList(),
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Records: ${exportData.length}   |   Total Disbursed: INR ${exportData.fold<double>(0.0, (s, r) => s + r.appAmt).toStringAsFixed(2)}',
                      style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.teal900),
                    ),
                  ],
                ),
              ];
            },
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

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _filteredPreviewRecords;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 1080,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 36,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export PO Advance',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Select format & download records to your PC',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          const Text(
                            '1. Select File Format',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),

                          // Side-by-Side Format Cards (With 3D Excel & PDF Brand Logos)
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
                                child: _AnimatedDownloadButton(
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

                  // RIGHT COLUMN: Preview Table & Selection
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 24, 24),
                      color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                      child: Column(
                        children: [
                          // Table Toolbar
                          Row(
                            children: [
                              Checkbox(
                                value: _isAllFilteredSelected,
                                onChanged: (_) => _toggleSelectAllFiltered(),
                                activeColor: AppColors.primaryColor,
                                visualDensity: VisualDensity.compact,
                              ),
                              Text(
                                'Selected (${_selectedIds.length} of ${widget.records.length})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: 240,
                                height: 34,
                                child: TextField(
                                  controller: _modalSearchCtrl,
                                  style: const TextStyle(fontSize: 11.5),
                                  decoration: InputDecoration(
                                    hintText: 'Filter records...',
                                    hintStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 15, color: Color(0xFF64748B)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Preview Table Header
                          Container(
                            height: 32,
                            color: const Color(0xFFE2E8F0),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: const Row(
                              children: [
                                SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 110, child: Text('PO NUMBER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                Expanded(child: Text('SUPPLIER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 75, child: Text('DATE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                                SizedBox(width: 90, child: Align(alignment: Alignment.centerRight, child: Text('ADV. AMT (₹)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569))))),
                              ],
                            ),
                          ),

                          // Preview Table Body
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: preview.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No matching records',
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: preview.length,
                                      separatorBuilder: (ctx, idx) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                                      itemBuilder: (ctx, idx) {
                                        final r = preview[idx];
                                        final isSelected = _selectedIds.contains(r.poId);
                                        final dateStr = r.appDt != null
                                            ? '${r.appDt!.day.toString().padLeft(2, '0')}/${r.appDt!.month.toString().padLeft(2, '0')}/${r.appDt!.year}'
                                            : '-';

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedIds.remove(r.poId);
                                              } else {
                                                _selectedIds.add(r.poId);
                                              }
                                            });
                                          },
                                          child: Container(
                                            height: 36,
                                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Row(
                                              children: [
                                                Checkbox(
                                                  value: isSelected,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        _selectedIds.add(r.poId);
                                                      } else {
                                                        _selectedIds.remove(r.poId);
                                                      }
                                                    });
                                                  },
                                                  activeColor: AppColors.primaryColor,
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                SizedBox(
                                                  width: 100,
                                                  child: Text(
                                                    r.poNo,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    r.partyName,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 75,
                                                  child: Text(dateStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                                                ),
                                                SizedBox(
                                                  width: 90,
                                                  child: Align(
                                                    alignment: Alignment.centerRight,
                                                    child: Text(
                                                      '₹${r.appAmt.toStringAsFixed(2)}',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
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
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Close Button (Top Right)
              Positioned(
                top: 14,
                right: 14,
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
            color: isSelected ? brandColor : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: brandColor.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            logoWidget,
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isSelected ? brandColor : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMATED SUCCESS DOWNLOAD BUTTON
// ============================================================================

class _AnimatedDownloadButton extends StatelessWidget {
  final ButtonStatus status;
  final VoidCallback onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const _AnimatedDownloadButton({
    required this.status,
    required this.onPressed,
    required this.idleText,
    required this.loadingText,
    required this.successText,
    required this.idleIcon,
    required this.idleBackgroundColor,
    required this.successBackgroundColor,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLoading = status == ButtonStatus.loading;
    final bool isSuccess = status == ButtonStatus.success;
    final Color bgColor = isSuccess
        ? successBackgroundColor
        : (isLoading ? idleBackgroundColor.withValues(alpha: 0.85) : idleBackgroundColor);

    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: bgColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              else if (isSuccess)
                const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white)
              else
                Icon(idleIcon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
              Text(
                isLoading ? loadingText : (isSuccess ? successText : idleText),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// AUTHENTIC 3D VECTOR BRAND LOGO WIDGETS (EXACT PROJECT MASTER PARITY)
// ============================================================================

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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F6C36), Color(0xFF107C41), Color(0xFF1F9A55)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

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

    final linePaint = Paint()
      ..color = const Color(0xFF107C41).withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

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

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'X',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.60,
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

    textPainter.paint(canvas, Offset(w * 0.09, h * 0.10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF3B30), Color(0xFFD32F2F), Color(0xFF8E0000)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

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

    final ribbonPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    final ribbonPath = Path();
    ribbonPath.moveTo(w * 0.22, h * 0.72);
    ribbonPath.cubicTo(w * 0.22, h * 0.38, w * 0.48, h * 0.35, w * 0.50, h * 0.55);
    ribbonPath.cubicTo(w * 0.52, h * 0.75, w * 0.78, h * 0.72, w * 0.78, h * 0.42);

    canvas.drawPath(ribbonPath, ribbonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
