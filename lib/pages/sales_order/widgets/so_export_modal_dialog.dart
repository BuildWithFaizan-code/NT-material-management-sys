import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../sales_order_models.dart';
import 'so_animated_success_button.dart';

// ============================================================================
// 1. ANIMATED EXPORT BUTTON WITH ORBIT LIGHT EFFECT (PROJECT MASTER PARITY)
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isAnimating ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? const Color(0xFF0C3B2E).withValues(alpha: 0.25)
                          : const Color(0xFF0C3B2E).withValues(alpha: _isHovered ? 0.12 : 0.04),
                      blurRadius: _isAnimating || _isHovered ? 10 : 5,
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
                        color: _isHovered ? const Color(0xFF0C3B2E) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Export Data',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _isHovered ? const Color(0xFF0C3B2E) : const Color(0xFF334155),
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
      const Radius.circular(10),
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
        ..color = const Color(0xFF10B981)
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
// 2. 3D MICROSOFT EXCEL BRAND BADGE (100% REPLICA FROM PROJECT MASTER)
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

// ============================================================================
// 3. 3D ADOBE PDF BRAND BADGE (100% REPLICA FROM PROJECT MASTER)
// ============================================================================
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
        colors: [Color(0xFFFCA5A5), Color(0xFF991B1B)],
      ).createShader(Rect.fromLTWH(w * 0.70, 0, w * 0.30, h * 0.30));

    canvas.drawPath(foldPath, foldPaint);

    // Bold Embossed White 'PDF'
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: Colors.white,
          fontSize: h * 0.32,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.10, h * 0.34));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 4. COMPREHENSIVE DUAL-PANE EXPORT MODAL DIALOG (PROJECT MASTER PARITY)
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

        // Header Row Styling
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

        final headers = [
          'SO No', 'Date', 'Customer Name', 'GSTIN', 'Division',
          'Items', 'Qty', 'Gross Amt (₹)', 'Disc (₹)', 'Net Amt (₹)', 'Status'
        ];

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int col = 0; col < headers.length; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        // Data Rows
        for (int row = 0; row < selectedList.length; row++) {
          final so = selectedList[row];
          final rIndex = row + 1;

          sheet.setRowHeight(rIndex, 22.0);
          sheet.appendRow([
            excel_pkg.TextCellValue(so.soNo),
            excel_pkg.TextCellValue(so.soDate.toIso8601String().split('T').first),
            excel_pkg.TextCellValue(so.partyName),
            excel_pkg.TextCellValue(so.gstin),
            excel_pkg.TextCellValue(so.costCenterName),
            excel_pkg.IntCellValue(so.totItm),
            excel_pkg.DoubleCellValue(so.totQty),
            excel_pkg.DoubleCellValue(so.totAmt),
            excel_pkg.DoubleCellValue(so.totDisc),
            excel_pkg.DoubleCellValue(so.netAmt),
            excel_pkg.TextCellValue(so.isRec ? 'Delivered' : (so.approved ? 'Approved' : 'Pending')),
          ]);
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
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
                      pw.Text(
                        'SALES ORDER REGISTER REPORT',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0C3B2E)),
                      ),
                      pw.Text('NEW TECH INFOSOL MMS', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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

        final bytes = await pdfDoc.save();
        await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 650));
        if (mounted) Navigator.of(context).pop();
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
              color: Colors.white.withValues(alpha: 0.95),
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
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Sales Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download records to your PC', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

                            // Side-by-Side Format Cards with 3D Brand Logos
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
                                  child: SoAnimatedSuccessButton(
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

                    // RIGHT COLUMN: Preview & Select Orders (Expanded)
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            _buildPreviewToolbar(),
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
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? brandColor : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? brandColor : const Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewToolbar() {
    return Row(
      children: [
        Checkbox(
          value: _isAllFilteredSelected,
          activeColor: const Color(0xFF0C3B2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: (_) => _toggleSelectAllFiltered(),
        ),
        Text(
          'Select All (${_selectedSoNos.length} of ${widget.orders.length})',
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
        const Spacer(),
        SizedBox(
          width: 220,
          height: 36,
          child: TextField(
            controller: _modalSearchCtrl,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Filter records...',
              hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final preview = _filteredPreviewOrders;

    if (preview.isEmpty) {
      return const Center(child: Text('No orders match filter', style: TextStyle(color: Color(0xFF64748B))));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListView.separated(
        itemCount: preview.length,
        separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, index) {
          final so = preview[index];
          final isSelected = _selectedSoNos.contains(so.soNo);

          return CheckboxListTile(
            value: isSelected,
            activeColor: const Color(0xFF0C3B2E),
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
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    so.partyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
                  ),
                ),
                Text(
                  '₹ ${so.netAmt.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            subtitle: Text(
              'Date: ${so.soDate.toIso8601String().split('T').first} • Division: ${so.costCenterName.isNotEmpty ? so.costCenterName : 'N/A'}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 5. CUSTOMER / DEBTOR DIRECTORY EXPORT MODAL DIALOG (PROJECT MASTER PARITY)
// ============================================================================
class CustomerExportModalDialog extends StatefulWidget {
  final List<CustomerLookup> customers;

  const CustomerExportModalDialog({super.key, required this.customers});

  @override
  State<CustomerExportModalDialog> createState() => _CustomerExportModalDialogState();
}

class _CustomerExportModalDialogState extends State<CustomerExportModalDialog> {
  String _selectedFormat = 'XLSX';
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<int> _selectedCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.customers.map((c) => c.pCode).toSet();
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

  List<CustomerLookup> get _filteredCustomers {
    if (_modalSearchQuery.isEmpty) return widget.customers;
    return widget.customers.where((c) {
      return c.pCode.toString().contains(_modalSearchQuery) ||
          c.pName.toLowerCase().contains(_modalSearchQuery) ||
          c.gstIn.toLowerCase().contains(_modalSearchQuery) ||
          c.state.toLowerCase().contains(_modalSearchQuery) ||
          c.mobile.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final list = _filteredCustomers;
    if (list.isEmpty) return false;
    return list.every((c) => _selectedCodes.contains(c.pCode));
  }

  void _toggleSelectAllFiltered() {
    final list = _filteredCustomers;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final c in list) {
          _selectedCodes.remove(c.pCode);
        }
      } else {
        for (final c in list) {
          _selectedCodes.add(c.pCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _isExportSuccess = false;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
      final selectedList = widget.customers
          .where((c) => _selectedCodes.contains(c.pCode))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'Customer_Directory_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Customers');
        final excel_pkg.Sheet sheet = excel['Customers'];

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

        final headers = ['Code', 'Customer / Debtor Name', 'GSTIN', 'State', 'Mobile', 'Registered Address'];

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int col = 0; col < headers.length; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int row = 0; row < selectedList.length; row++) {
          final c = selectedList[row];
          final rIndex = row + 1;

          sheet.setRowHeight(rIndex, 22.0);
          sheet.appendRow([
            excel_pkg.IntCellValue(c.pCode),
            excel_pkg.TextCellValue(c.pName),
            excel_pkg.TextCellValue(c.gstIn),
            excel_pkg.TextCellValue(c.state),
            excel_pkg.TextCellValue(c.mobile),
            excel_pkg.TextCellValue(c.address),
          ]);
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final pdfDoc = pw.Document();
        pdfDoc.addPage(
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
                      pw.Text(
                        'CUSTOMER / DEBTOR DIRECTORY REPORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0C3B2E')),
                      ),
                      pw.Text(
                        'Total: ${selectedList.length} Customers',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Code', 'Customer Name', 'GSTIN', 'State', 'Mobile', 'Address'],
                  data: selectedList.map((c) => [
                    c.pCode.toString(),
                    c.pName,
                    c.gstIn,
                    c.state,
                    c.mobile,
                    c.address,
                  ]).toList(),
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0C3B2E')),
                  cellHeight: 22,
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ];
            },
          ),
        );

        final bytes = await pdfDoc.save();
        await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
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
              color: Colors.white.withValues(alpha: 0.95),
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
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Customers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download customer master list', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

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
                                  child: SoAnimatedSuccessButton(
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

                    // RIGHT COLUMN: Preview & Select Customers
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _isAllFilteredSelected,
                                  activeColor: const Color(0xFF0C3B2E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (_) => _toggleSelectAllFiltered(),
                                ),
                                Text(
                                  'Select All (${_selectedCodes.length} of ${widget.customers.length})',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: 220,
                                  height: 36,
                                  child: TextField(
                                    controller: _modalSearchCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Filter customers...',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: _filteredCustomers.isEmpty
                                    ? const Center(child: Text('No customers match filter', style: TextStyle(color: Color(0xFF64748B))))
                                    : ListView.separated(
                                        itemCount: _filteredCustomers.length,
                                        separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (context, index) {
                                          final c = _filteredCustomers[index];
                                          final isSelected = _selectedCodes.contains(c.pCode);

                                          return CheckboxListTile(
                                            value: isSelected,
                                            activeColor: const Color(0xFF0C3B2E),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedCodes.add(c.pCode);
                                                } else {
                                                  _selectedCodes.remove(c.pCode);
                                                }
                                              });
                                            },
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEEF2FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '#${c.pCode}',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    c.pName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                  ),
                                                ),
                                                if (c.gstIn.isNotEmpty)
                                                  Text(
                                                    c.gstIn,
                                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              'Mobile: ${c.mobile.isNotEmpty ? c.mobile : 'N/A'} • State: ${c.state.isNotEmpty ? c.state : 'N/A'}',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
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
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? brandColor : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? brandColor : const Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 6. ITEM CATALOG EXPORT MODAL DIALOG (PROJECT MASTER PARITY)
// ============================================================================
class ItemExportModalDialog extends StatefulWidget {
  final List<SalesOrderItemLookup> items;

  const ItemExportModalDialog({super.key, required this.items});

  @override
  State<ItemExportModalDialog> createState() => _ItemExportModalDialogState();
}

class _ItemExportModalDialogState extends State<ItemExportModalDialog> {
  String _selectedFormat = 'XLSX';
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedCodes;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedCodes = widget.items.map((i) => i.iCode).toSet();
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

  List<SalesOrderItemLookup> get _filteredItems {
    if (_modalSearchQuery.isEmpty) return widget.items;
    return widget.items.where((i) {
      return i.iCode.toLowerCase().contains(_modalSearchQuery) ||
          i.iName.toLowerCase().contains(_modalSearchQuery) ||
          i.unitName.toLowerCase().contains(_modalSearchQuery) ||
          i.hsnCode.toLowerCase().contains(_modalSearchQuery) ||
          i.groupName.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final list = _filteredItems;
    if (list.isEmpty) return false;
    return list.every((i) => _selectedCodes.contains(i.iCode));
  }

  void _toggleSelectAllFiltered() {
    final list = _filteredItems;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final i in list) {
          _selectedCodes.remove(i.iCode);
        }
      } else {
        for (final i in list) {
          _selectedCodes.add(i.iCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) return;

    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
      _isExportSuccess = false;
    });

    _exportTimer?.cancel();
    int currentStep = 0;
    _exportTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
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
      final selectedList = widget.items
          .where((i) => _selectedCodes.contains(i.iCode))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'Item_Catalog_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Item Catalog');
        final excel_pkg.Sheet sheet = excel['Item Catalog'];

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

        final headers = ['Item Code', 'Item Name', 'UOM', 'HSN Code', 'Group', 'Stock Bal', 'Rate (₹)'];

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (int col = 0; col < headers.length; col++) {
          sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0)).cellStyle = headerStyle;
        }

        for (int row = 0; row < selectedList.length; row++) {
          final it = selectedList[row];
          final rIndex = row + 1;

          sheet.setRowHeight(rIndex, 22.0);
          sheet.appendRow([
            excel_pkg.TextCellValue(it.iCode),
            excel_pkg.TextCellValue(it.iName),
            excel_pkg.TextCellValue(it.unitName),
            excel_pkg.TextCellValue(it.hsnCode),
            excel_pkg.TextCellValue(it.groupName),
            excel_pkg.DoubleCellValue(it.balQty),
            excel_pkg.DoubleCellValue(it.rate),
          ]);
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
            build: (pw.Context ctx) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'ITEM MASTER CATALOG REPORT',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#0C3B2E')),
                      ),
                      pw.Text(
                        'Total: ${selectedList.length} Items',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['Item Code', 'Item Name', 'UOM', 'HSN Code', 'Group', 'Balance', 'Rate (₹)'],
                  data: selectedList.map((it) => [
                    it.iCode,
                    it.iName,
                    it.unitName,
                    it.hsnCode,
                    it.groupName,
                    it.balQty.toStringAsFixed(2),
                    it.rate.toStringAsFixed(2),
                  ]).toList(),
                  headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
                  headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#0C3B2E')),
                  cellHeight: 22,
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ];
            },
          ),
        );

        final bytes = await pdfDoc.save();
        await FileExportHelper.saveAndLaunchFile(bytes: bytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
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
              color: Colors.white.withValues(alpha: 0.95),
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
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Export Item Catalog', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    SizedBox(height: 2),
                                    Text('Select format & download stock catalog list', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),

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
                                  child: SoAnimatedSuccessButton(
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

                    // RIGHT COLUMN: Preview & Select Items
                    Expanded(
                      flex: 7,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 26, 26, 26),
                        color: const Color(0xFFF8FAFC).withValues(alpha: 0.7),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _isAllFilteredSelected,
                                  activeColor: const Color(0xFF0C3B2E),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (_) => _toggleSelectAllFiltered(),
                                ),
                                Text(
                                  'Select All (${_selectedCodes.length} of ${widget.items.length})',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const Spacer(),
                                SizedBox(
                                  width: 220,
                                  height: 36,
                                  child: TextField(
                                    controller: _modalSearchCtrl,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Filter items...',
                                      hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF0C3B2E)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: _filteredItems.isEmpty
                                    ? const Center(child: Text('No items match filter', style: TextStyle(color: Color(0xFF64748B))))
                                    : ListView.separated(
                                        itemCount: _filteredItems.length,
                                        separatorBuilder: (ctx, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                        itemBuilder: (context, index) {
                                          final it = _filteredItems[index];
                                          final isSelected = _selectedCodes.contains(it.iCode);

                                          return CheckboxListTile(
                                            value: isSelected,
                                            activeColor: const Color(0xFF0C3B2E),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedCodes.add(it.iCode);
                                                } else {
                                                  _selectedCodes.remove(it.iCode);
                                                }
                                              });
                                            },
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEEF2FF),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    it.iCode,
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    it.iName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                                  ),
                                                ),
                                                Text(
                                                  '₹ ${it.rate.toStringAsFixed(2)}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                                ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              'UOM: ${it.unitName.isNotEmpty ? it.unitName : 'N/A'} • HSN: ${it.hsnCode} • Stock: ${it.balQty.toStringAsFixed(1)}',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
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
              children: [
                logoWidget,
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? brandColor : const Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? brandColor : const Color(0xFF0F172A))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
