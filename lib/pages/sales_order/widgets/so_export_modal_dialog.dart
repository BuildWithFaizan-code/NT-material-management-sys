import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../sales_order_models.dart';

// ============================================================================
// 1. ANIMATED EXPORT BUTTON WITH ORBIT EFFECT
// ============================================================================
class SoAnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const SoAnimatedExportButton({super.key, required this.onPressed});

  @override
  State<SoAnimatedExportButton> createState() => _SoAnimatedExportButtonState();
}

class _SoAnimatedExportButtonState extends State<SoAnimatedExportButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  bool _isHovered = false;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrl.reset();
        if (mounted) {
          setState(() => _isAnimating = false);
        }
        widget.onPressed();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _triggerClickOrbit() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _triggerClickOrbit,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final progress = _ctrl.value;

            return CustomPaint(
              painter: _SoOrbitButtonBorderPainter(
                progress: progress,
                isHovered: _isHovered,
                isAnimating: _isAnimating,
              ),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAnimating ? AppColors.secondaryColor : AppColors.divider,
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? AppColors.secondaryColor.withOpacity(0.3)
                          : AppColors.secondaryColor.withOpacity(_isHovered ? 0.18 : 0.05),
                      blurRadius: _isAnimating || _isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: progress * 6.283185307179586,
                      child: Icon(
                        Icons.file_download_outlined,
                        size: 17,
                        color: _isHovered ? AppColors.secondaryColor : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Export Data',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? AppColors.secondaryColor : AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SoOrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;
  final bool isAnimating;

  _SoOrbitButtonBorderPainter({
    required this.progress,
    required this.isHovered,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isAnimating && !isHovered) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );

    if (isAnimating) {
      final path = Path()..addRRect(rrect);
      final pms = path.computeMetrics().toList();
      if (pms.isEmpty) return;
      final pm = pms.first;
      final totalLen = pm.length;

      final headDist = (progress * totalLen) % totalLen;
      const tailLength = 48.0;

      final startDist = (headDist - tailLength) < 0 ? 0.0 : headDist - tailLength;
      final seg = pm.extractPath(startDist, headDist);

      final paint = Paint()
        ..color = AppColors.secondaryColor
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(seg, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoOrbitButtonBorderPainter old) =>
      old.progress != progress || old.isHovered != isHovered || old.isAnimating != isAnimating;
}

// ============================================================================
// 2. 3D FORMAT BADGES (EXCEL & PDF)
// ============================================================================
class So3DExcelBadge extends StatelessWidget {
  final double size;
  const So3DExcelBadge({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1D6F42),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D6F42).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'XLS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class So3DPdfBadge extends StatelessWidget {
  final double size;
  const So3DPdfBadge({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'PDF',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: size * 0.32,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. EXPORT MODAL DIALOG
// ============================================================================
class SoExportModalDialog extends StatefulWidget {
  final List<SalesOrderHeader> orders;

  const SoExportModalDialog({super.key, required this.orders});

  @override
  State<SoExportModalDialog> createState() => _SoExportModalDialogState();
}

class _SoExportModalDialogState extends State<SoExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedSoNos;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedSoNos = widget.orders.map((o) => o.soNo).toSet();
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

  List<SalesOrderHeader> get _filteredPreviewOrders {
    if (_modalSearchQuery.isEmpty) return widget.orders;
    return widget.orders.where((o) {
      final noMatch = o.soNo.toLowerCase().contains(_modalSearchQuery);
      final partyMatch = o.partyName.toLowerCase().contains(_modalSearchQuery);
      final costCenterMatch = o.costCenterName.toLowerCase().contains(_modalSearchQuery);
      return noMatch || partyMatch || costCenterMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewOrders;
    if (preview.isEmpty) return false;
    return preview.every((o) => _selectedSoNos.contains(o.soNo));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewOrders;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final o in preview) {
          _selectedSoNos.remove(o.soNo);
        }
      } else {
        for (final o in preview) {
          _selectedSoNos.add(o.soNo);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedSoNos.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _isExportSuccess = false;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
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
        _finalizeExport();
      }
    });
  }

  Future<void> _finalizeExport() async {
    try {
      final selectedList = widget.orders
          .where((o) => _selectedSoNos.contains(o.soNo))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'SalesOrder_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Sales Orders');
        final excel_pkg.Sheet sheet = excel['Sales Orders'];

        // Header Row
        final headers = [
          'SO No', 'Date', 'Customer Name', 'GSTIN', 'Division',
          'Items', 'Qty', 'Gross Amt (₹)', 'Disc (₹)', 'Net Amt (₹)', 'Status'
        ];

        for (int col = 0; col < headers.length; col++) {
          final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
          cell.value = excel_pkg.TextCellValue(headers[col]);
          cell.cellStyle = excel_pkg.CellStyle(bold: true);
        }

        // Data Rows
        for (int row = 0; row < selectedList.length; row++) {
          final so = selectedList[row];
          final rIndex = row + 1;

          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.soNo);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.soDate.toIso8601String().split('T').first);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.partyName);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.gstin);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.costCenterName);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rIndex))
              .value = excel_pkg.IntCellValue(so.totItm);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rIndex))
              .value = excel_pkg.DoubleCellValue(so.totQty);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rIndex))
              .value = excel_pkg.DoubleCellValue(so.totAmt);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rIndex))
              .value = excel_pkg.DoubleCellValue(so.totDisc);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rIndex))
              .value = excel_pkg.DoubleCellValue(so.netAmt);
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rIndex))
              .value = excel_pkg.TextCellValue(so.isRec ? 'Delivered' : (so.approved ? 'Approved' : 'Pending'));
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final doc = pw.Document();
        doc.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context ctx) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SALES ORDERS REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Exported: ${DateTime.now().toIso8601String().split('T').first}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  context: ctx,
                  headers: ['SO No', 'Date', 'Customer Name', 'Division', 'Items', 'Qty', 'Net Amt (₹)', 'Status'],
                  data: selectedList.map((so) => [
                    so.soNo,
                    so.soDate.toIso8601String().split('T').first,
                    so.partyName,
                    so.costCenterName,
                    so.totItm.toString(),
                    so.totQty.toStringAsFixed(1),
                    so.netAmt.toStringAsFixed(2),
                    so.isRec ? 'Delivered' : (so.approved ? 'Approved' : 'Pending'),
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                ),
              ];
            },
          ),
        );

        final bytes = await doc.save();
        await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.75).clamp(650.0, 920.0);
    final dialogHeight = (size.height * 0.8).clamp(500.0, 700.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildFormatSelector(),
            _buildSearchAndSelectBar(),
            Expanded(child: _buildPreviewTable()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.sidebarBackground.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.download_rounded, color: AppColors.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Sales Orders',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Select format and target orders to generate formatted reports',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          const Text(
            'Export Format: ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          // Excel option
          InkWell(
            onTap: () => setState(() => _selectedFormat = 'XLSX'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedFormat == 'XLSX' ? AppColors.primaryColor.withOpacity(0.1) : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedFormat == 'XLSX' ? AppColors.primaryColor : AppColors.divider,
                  width: _selectedFormat == 'XLSX' ? 1.5 : 1.0,
                ),
              ),
              child: const Row(
                children: [
                  So3DExcelBadge(size: 26),
                  SizedBox(width: 10),
                  Text('Excel Spreadsheet (.xlsx)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // PDF option
          InkWell(
            onTap: () => setState(() => _selectedFormat = 'PDF'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedFormat == 'PDF' ? AppColors.primaryColor.withOpacity(0.1) : AppColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedFormat == 'PDF' ? AppColors.primaryColor : AppColors.divider,
                  width: _selectedFormat == 'PDF' ? 1.5 : 1.0,
                ),
              ),
              child: const Row(
                children: [
                  So3DPdfBadge(size: 26),
                  SizedBox(width: 10),
                  Text('PDF Document (.pdf)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndSelectBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _isAllFilteredSelected,
            onChanged: (_) => _toggleSelectAllFiltered(),
          ),
          Text(
            'Select All (${_selectedSoNos.length} of ${widget.orders.length} selected)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const Spacer(),
          SizedBox(
            width: 250,
            height: 34,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Filter by SO No, Party...',
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.divider)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    final preview = _filteredPreviewOrders;

    if (preview.isEmpty) {
      return const Center(
        child: Text('No orders match your filter', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: preview.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider.withOpacity(0.3)),
      itemBuilder: (context, index) {
        final so = preview[index];
        final isSelected = _selectedSoNos.contains(so.soNo);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedSoNos.add(so.soNo);
              } else {
                _selectedSoNos.remove(so.soNo);
              }
            });
          },
          dense: true,
          title: Row(
            children: [
              Text(
                so.soNo,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  so.partyName,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ),
              Text(
                '₹ ${so.netAmt.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          subtitle: Text(
            'Date: ${so.soDate.toIso8601String().split('T').first} • Items: ${so.totItm} • Qty: ${so.totQty}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.5))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExporting) ...[
            LinearProgressIndicator(value: _exportProgress, backgroundColor: AppColors.divider, color: AppColors.secondaryColor),
            const SizedBox(height: 10),
            Text('Generating $_selectedFormat file (${(_exportProgress * 100).toInt()}%)...', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _selectedSoNos.isEmpty || _isExporting ? null : _startExportProcess,
                icon: Icon(
                  _isExportSuccess ? Icons.check_circle_rounded : Icons.download_rounded,
                  size: 16,
                ),
                label: Text(
                  _isExportSuccess
                      ? 'Downloaded!'
                      : (_isExporting ? 'Exporting...' : 'Export ${_selectedSoNos.length} Orders'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isExportSuccess ? AppColors.success : AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
