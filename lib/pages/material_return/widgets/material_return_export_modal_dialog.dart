import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../material_return_models.dart';

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

String _formatTimestamp() {
  final now = DateTime.now();
  final y = now.year.toString();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final min = now.minute.toString().padLeft(2, '0');
  return '$y$m${d}_$h$min';
}

// ============================================================================
// 1. ANIMATED ORBITING EXPORT BUTTON (100% PROJECT MASTER CODE)
// ============================================================================
class MaterialReturnAnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const MaterialReturnAnimatedExportButton({super.key, required this.onPressed});

  @override
  State<MaterialReturnAnimatedExportButton> createState() =>
      _MaterialReturnAnimatedExportButtonState();
}

class _MaterialReturnAnimatedExportButtonState
    extends State<MaterialReturnAnimatedExportButton>
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
              painter: _OrbitButtonBorderPainter(
                progress: progress,
                isHovered: _isHovered,
                isAnimating: _isAnimating,
              ),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isAnimating ? AppColors.secondaryColor : AppColors.divider,
                    width: _isAnimating ? 1.4 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isAnimating
                          ? AppColors.secondaryColor.withValues(alpha: 0.3)
                          : AppColors.secondaryColor.withValues(alpha: _isHovered ? 0.18 : 0.05),
                      blurRadius: _isAnimating || _isHovered ? 12 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 16,
                      color: _isAnimating || _isHovered
                          ? AppColors.secondaryColor
                          : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isAnimating || _isHovered
                            ? AppColors.secondaryColor
                            : AppColors.primaryColor,
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

class _OrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;
  final bool isAnimating;

  _OrbitButtonBorderPainter({
    required this.progress,
    required this.isHovered,
    required this.isAnimating,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isAnimating || progress <= 0.0 || progress >= 1.0) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics().first;
    final totalLen = metrics.length;
    final beamLen = totalLen * 0.35;

    final start = progress * totalLen;
    final end = (start + beamLen) % totalLen;

    Path extractPath;
    if (start + beamLen <= totalLen) {
      extractPath = metrics.extractPath(start, start + beamLen);
    } else {
      extractPath = metrics.extractPath(start, totalLen);
      extractPath.addPath(metrics.extractPath(0, end), Offset.zero);
    }

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF25D366).withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF0C3B2E).withValues(alpha: 0.2),
          const Color(0xFF25D366),
          const Color(0xFF10B981),
          Colors.white,
        ],
        stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
      ).createShader(rect);

    canvas.drawPath(extractPath, glowPaint);
    canvas.drawPath(extractPath, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitButtonBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.isAnimating != isAnimating;
  }
}

// ============================================================================
// 2. 3D BRAND LOGOS (EXCEL & PDF CUSTOM PAINTERS - 100% PROJECT MASTER CODE)
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

    final foldShadow = Path()
      ..moveTo(w * 0.70, h * 0.30)
      ..lineTo(w, h * 0.30)
      ..lineTo(w * 0.70, h * 0.40)
      ..close();
    canvas.drawPath(foldShadow, Paint()..color = Colors.black.withValues(alpha: 0.25));

    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.45), glossPaint);

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
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0.8, 0.8),
              blurRadius: 1.5,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(w * 0.22, h * 0.15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 3. ANIMATED SUCCESS BUTTON FOR EXPORT MODAL
// ============================================================================
enum ExportButtonStatus { idle, loading, success, error }

class ExportAnimatedSuccessButton extends StatelessWidget {
  final ExportButtonStatus status;
  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final double height;

  const ExportAnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Exporting...',
    this.successText = 'Exported!',
    this.idleIcon = Icons.file_download_outlined,
    this.idleBackgroundColor = const Color(0xFF0C3B2E),
    this.successBackgroundColor = const Color(0xFF10B981),
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = status == ExportButtonStatus.loading;
    final isSuccess = status == ExportButtonStatus.success;

    return ElevatedButton(
      onPressed: (isLoading || isSuccess) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSuccess ? successBackgroundColor : idleBackgroundColor,
        disabledBackgroundColor:
            isSuccess ? successBackgroundColor : idleBackgroundColor.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
        minimumSize: Size(0, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else if (isSuccess)
            const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white)
          else
            Icon(idleIcon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            isLoading
                ? loadingText
                : isSuccess
                    ? successText
                    : idleText,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. MAIN EXPORT MODAL DIALOG (100% PARITY WITH PROJECT MASTER EXPORT)
// ============================================================================
class MaterialReturnExportModalDialog extends StatefulWidget {
  final List<MaterialReturnGridRecord> records;

  const MaterialReturnExportModalDialog({super.key, required this.records});

  @override
  State<MaterialReturnExportModalDialog> createState() => _MaterialReturnExportModalDialogState();
}

class _MaterialReturnExportModalDialogState extends State<MaterialReturnExportModalDialog> {
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
    _selectedCodes = widget.records.map((r) => r.retCode).toSet();
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

  List<MaterialReturnGridRecord> get _filteredRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      return r.retCode.toLowerCase().contains(_modalSearchQuery) ||
          r.retToName.toLowerCase().contains(_modalSearchQuery) ||
          r.retMode.toLowerCase().contains(_modalSearchQuery) ||
          r.remark.toLowerCase().contains(_modalSearchQuery) ||
          r.operatorName.toLowerCase().contains(_modalSearchQuery);
    }).toList();
  }

  Future<void> _handleExport() async {
    final exportList =
        widget.records.where((r) => _selectedCodes.contains(r.retCode)).toList();

    if (exportList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one return entry to export.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isExporting = true;
      _isExportSuccess = false;
      _exportProgress = 0.1;
    });

    _exportTimer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_exportProgress < 0.88) {
          _exportProgress += 0.08;
        }
      });
    });

    try {
      if (_selectedFormat == 'XLSX') {
        await _generateExcel(exportList);
      } else {
        await _generatePdf(exportList);
      }

      _exportTimer?.cancel();
      if (mounted) {
        setState(() {
          _exportProgress = 1.0;
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      _exportTimer?.cancel();
      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _generateExcel(List<MaterialReturnGridRecord> list) async {
    final excel = excel_pkg.Excel.createExcel();
    final sheetName = 'Material Returns';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    // Title Row
    sheet.appendRow([
      excel_pkg.TextCellValue('NT-MMS MATERIAL RETURN FROM/TO EXPORT REPORT'),
    ]);
    sheet.appendRow([
      excel_pkg.TextCellValue('Generated on: ${_formatDate(DateTime.now())} | Total Records: ${list.length}'),
    ]);
    sheet.appendRow([excel_pkg.TextCellValue('')]);

    // Table Header
    sheet.appendRow([
      excel_pkg.TextCellValue('Sr No'),
      excel_pkg.TextCellValue('Return Code'),
      excel_pkg.TextCellValue('Return Date'),
      excel_pkg.TextCellValue('Return Mode'),
      excel_pkg.TextCellValue('Return To / By'),
      excel_pkg.TextCellValue('Total Qty'),
      excel_pkg.TextCellValue('Total Items'),
      excel_pkg.TextCellValue('Remark'),
      excel_pkg.TextCellValue('Operator'),
      excel_pkg.TextCellValue('Location'),
    ]);

    double totalQtySum = 0;
    int totalItemsSum = 0;

    for (var i = 0; i < list.length; i++) {
      final r = list[i];
      totalQtySum += r.totQty;
      totalItemsSum += r.totItm;

      sheet.appendRow([
        excel_pkg.IntCellValue(i + 1),
        excel_pkg.TextCellValue(r.retCode),
        excel_pkg.TextCellValue(_formatDate(r.retDate)),
        excel_pkg.TextCellValue(r.retMode),
        excel_pkg.TextCellValue(r.retToName),
        excel_pkg.DoubleCellValue(r.totQty),
        excel_pkg.IntCellValue(r.totItm),
        excel_pkg.TextCellValue(r.remark),
        excel_pkg.TextCellValue(r.operatorName),
        excel_pkg.TextCellValue(r.location),
      ]);
    }

    sheet.appendRow([
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue('TOTAL'),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
      excel_pkg.DoubleCellValue(totalQtySum),
      excel_pkg.IntCellValue(totalItemsSum),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
      excel_pkg.TextCellValue(''),
    ]);

    final bytes = excel.save();
    if (bytes != null) {
      await FileExportHelper.saveAndLaunchFile(
        bytes: bytes,
        fileName: 'Material_Returns_${_formatTimestamp()}.xlsx',
      );
    }
  }

  Future<void> _generatePdf(List<MaterialReturnGridRecord> list) async {
    final pdf = pw.Document();

    final headers = [
      '#',
      'Return Code',
      'Date',
      'Mode',
      'Return To / By',
      'Qty',
      'Itm',
      'Remark',
      'Operator',
    ];

    double totalQtySum = 0;
    int totalItemsSum = 0;

    final data = list.asMap().entries.map((entry) {
      final i = entry.key + 1;
      final r = entry.value;
      totalQtySum += r.totQty;
      totalItemsSum += r.totItm;

      return [
        i.toString(),
        r.retCode,
        _formatDate(r.retDate),
        r.retMode,
        r.retToName,
        r.totQty.toStringAsFixed(2),
        r.totItm.toString(),
        r.remark,
        r.operatorName,
      ];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NT-MMS ERP — MATERIAL RETURN FROM/TO',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('0C3B2E'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Generated: ${_formatDate(DateTime.now())} | Total Records: ${list.length}',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('E8F5E9'),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'LWHL24_SQL',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('0C3B2E'),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('0C3B2E'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              columnWidths: {
                0: const pw.FixedColumnWidth(24),
                1: const pw.FixedColumnWidth(85),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(75),
                4: const pw.FlexColumnWidth(2.0),
                5: const pw.FixedColumnWidth(50),
                6: const pw.FixedColumnWidth(30),
                7: const pw.FlexColumnWidth(1.5),
                8: const pw.FixedColumnWidth(65),
              },
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F9FAFB'),
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL SUMMARY',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Row(
                    children: [
                      pw.Text(
                        'Total Qty: ${totalQtySum.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(width: 24),
                      pw.Text(
                        'Total Items: $totalItemsSum',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await FileExportHelper.saveAndLaunchFile(
      bytes: bytes,
      fileName: 'Material_Returns_${_formatTimestamp()}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final allSelected = filtered.isNotEmpty && filtered.every((r) => _selectedCodes.contains(r.retCode));
    final someSelected = filtered.any((r) => _selectedCodes.contains(r.retCode));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 820,
        height: 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_outlined, color: AppColors.primaryColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Export Material Return Records',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose export format, filter rows, and download instant reporting.',
                          style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: AppColors.slateMuted,
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // Format Selection Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: const Color(0xFFF8FAFC),
              child: Row(
                children: [
                  const Text(
                    'Select Format:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                  ),
                  const SizedBox(width: 16),
                  _buildFormatCard('XLSX', 'Microsoft Excel', const Excel3DBrandLogoWidget(size: 34)),
                  const SizedBox(width: 14),
                  _buildFormatCard('PDF', 'Adobe PDF Document', const Pdf3DBrandLogoWidget(size: 34)),
                  const Spacer(),
                  Text(
                    '${_selectedCodes.length} of ${widget.records.length} selected',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.secondaryColor),
                  ),
                ],
              ),
            ),

            // Search Bar & Select All
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _modalSearchCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                          hintText: 'Search by Return Code, Party, Operator, Remark...',
                          hintStyle: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.secondaryColor, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          for (final r in filtered) {
                            _selectedCodes.remove(r.retCode);
                          }
                        } else {
                          for (final r in filtered) {
                            _selectedCodes.add(r.retCode);
                          }
                        }
                      });
                    },
                    icon: Icon(
                      allSelected
                          ? Icons.check_box_rounded
                          : (someSelected ? Icons.indeterminate_check_box_rounded : Icons.check_box_outline_blank_rounded),
                      size: 16,
                      color: AppColors.secondaryColor,
                    ),
                    label: Text(
                      allSelected ? 'Deselect All' : 'Select All',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      side: BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),

            // Records Selection List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching records found.',
                        style: TextStyle(color: AppColors.slateMuted, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
                      itemBuilder: (context, idx) {
                        final r = filtered[idx];
                        final isSelected = _selectedCodes.contains(r.retCode);

                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedCodes.remove(r.retCode);
                              } else {
                                _selectedCodes.add(r.retCode);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.secondaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedCodes.add(r.retCode);
                                      } else {
                                        _selectedCodes.remove(r.retCode);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r.retCode,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.secondaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  _formatDate(r.retDate),
                                  style: TextStyle(fontSize: 12, color: AppColors.slateMuted),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    r.retToName,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primaryColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r.retMode,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Qty: ${r.totQty.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryColor),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Items: ${r.totItm}',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.slateMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Progress Bar if exporting
            if (_isExporting)
              LinearProgressIndicator(
                value: _exportProgress,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondaryColor),
                minHeight: 4,
              ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Text(
                    'Selected for Export: ${_selectedCodes.length} documents',
                    style: TextStyle(fontSize: 12.5, color: AppColors.slateMuted, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      foregroundColor: AppColors.slateMuted,
                    ),
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: ExportAnimatedSuccessButton(
                      status: _isExportSuccess
                          ? ExportButtonStatus.success
                          : (_isExporting ? ExportButtonStatus.loading : ExportButtonStatus.idle),
                      onPressed: _handleExport,
                      idleText: 'Download $_selectedFormat',
                      loadingText: 'Generating...',
                      successText: 'Downloaded!',
                      idleIcon: Icons.download_rounded,
                      idleBackgroundColor: AppColors.primaryColor,
                      successBackgroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatCard(String format, String label, Widget logo) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: () => setState(() => _selectedFormat = format),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.secondaryColor : AppColors.divider,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.secondaryColor.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            logo,
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  format,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.secondaryColor : AppColors.primaryColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: AppColors.slateMuted),
                ),
              ],
            ),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.secondaryColor),
          ],
        ),
      ),
    );
  }
}
