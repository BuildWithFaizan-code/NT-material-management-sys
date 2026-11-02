import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../issue_manager_models.dart';

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
class IssueManagerAnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const IssueManagerAnimatedExportButton({super.key, required this.onPressed});

  @override
  State<IssueManagerAnimatedExportButton> createState() => _IssueManagerAnimatedExportButtonState();
}

class _IssueManagerAnimatedExportButtonState extends State<IssueManagerAnimatedExportButton>
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
                      color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _isAnimating || _isHovered ? AppColors.secondaryColor : AppColors.primaryColor,
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
        disabledBackgroundColor: isSuccess ? successBackgroundColor : idleBackgroundColor.withValues(alpha: 0.7),
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
class IssueManagerExportModalDialog extends StatefulWidget {
  final List<IssueManagerGridRecord> records;

  const IssueManagerExportModalDialog({super.key, required this.records});

  @override
  State<IssueManagerExportModalDialog> createState() => _IssueManagerExportModalDialogState();
}

class _IssueManagerExportModalDialogState extends State<IssueManagerExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'

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
    _selectedCodes = widget.records.map((r) => r.issueCode).toSet();
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

  List<IssueManagerGridRecord> get _filteredPreviewRecords {
    if (_modalSearchQuery.isEmpty) return widget.records;
    return widget.records.where((r) {
      final codeMatch = r.issueCode.toLowerCase().contains(_modalSearchQuery);
      final deptMatch = r.sourceDeptName.toLowerCase().contains(_modalSearchQuery);
      final modeMatch = r.issueMode.toLowerCase().contains(_modalSearchQuery);
      final remarkMatch = r.remark.toLowerCase().contains(_modalSearchQuery);
      return codeMatch || deptMatch || modeMatch || remarkMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewRecords;
    if (preview.isEmpty) return false;
    return preview.every((r) => _selectedCodes.contains(r.issueCode));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewRecords;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final r in preview) {
          _selectedCodes.remove(r.issueCode);
        }
      } else {
        for (final r in preview) {
          _selectedCodes.add(r.issueCode);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedCodes.isEmpty) {
      return;
    }

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
          .where((r) => _selectedCodes.contains(r.issueCode))
          .toList();

      final stamp = _formatTimestamp();
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'IssueManager_Export_$stamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Issue Manager');
        final excel_pkg.Sheet sheet = excel['Issue Manager'];

        sheet.setColumnWidth(0, 18.0);
        sheet.setColumnWidth(1, 14.0);
        sheet.setColumnWidth(2, 16.0);
        sheet.setColumnWidth(3, 12.0);
        sheet.setColumnWidth(4, 24.0);
        sheet.setColumnWidth(5, 14.0);
        sheet.setColumnWidth(6, 12.0);
        sheet.setColumnWidth(7, 12.0);
        sheet.setColumnWidth(8, 14.0);
        sheet.setColumnWidth(9, 12.0);
        sheet.setColumnWidth(10, 12.0);
        sheet.setColumnWidth(11, 26.0);
        sheet.setColumnWidth(12, 16.0);

        final headers = [
          'Issue Code',
          'Date',
          'Mode',
          'Source',
          'From Department',
          'Machine No.',
          'Spindal',
          'Slip No.',
          'Total Qty',
          'Total Items',
          'Total Pcs',
          'Remark',
          'Created By',
        ];

        sheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

        for (final r in selectedList) {
          sheet.appendRow([
            excel_pkg.TextCellValue(r.issueCode),
            excel_pkg.TextCellValue(_formatDate(r.issueDate)),
            excel_pkg.TextCellValue(r.issueMode),
            excel_pkg.TextCellValue(r.issueSource),
            excel_pkg.TextCellValue(r.sourceDeptName),
            excel_pkg.TextCellValue(r.machineNo.isEmpty ? '*' : r.machineNo),
            excel_pkg.TextCellValue(r.spindal),
            excel_pkg.TextCellValue(r.slipNo.toString()),
            excel_pkg.DoubleCellValue(r.totQty),
            excel_pkg.IntCellValue(r.totItm),
            excel_pkg.DoubleCellValue(r.totPcs),
            excel_pkg.TextCellValue(r.remark),
            excel_pkg.TextCellValue(r.createdBy),
          ]);
        }

        final bytes = excel.encode();
        if (bytes != null) {
          await FileExportHelper.saveAndLaunchFile(
            bytes: bytes,
            fileName: fileName,
          );
        }
      } else {
        // PDF Generation
        final pdf = pw.Document();
        final chunks = <List<IssueManagerGridRecord>>[];
        for (var i = 0; i < selectedList.length; i += 22) {
          chunks.add(selectedList.sublist(i, math.min(i + 22, selectedList.length)));
        }

        final pageHeaders = [
          'Issue Code',
          'Date',
          'Mode',
          'Source',
          'From Dept',
          'Machine',
          'Tot Qty',
          'Items',
          'Pcs',
          'Remark'
        ];

        for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
          final pageRows = chunks[pageIdx];
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(24),
              build: (pw.Context ctx) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Issue Manager Records Report',
                          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
                        ),
                        pw.Text(
                          'Generated: ${_formatDate(DateTime.now())} | Page ${pageIdx + 1} of ${chunks.length}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.TableHelper.fromTextArray(
                      headers: pageHeaders,
                      data: pageRows.map((r) => [
                        r.issueCode,
                        _formatDate(r.issueDate),
                        r.issueMode,
                        r.issueSource,
                        r.sourceDeptName,
                        r.machineNo.isEmpty ? '*' : r.machineNo,
                        r.totQty.toStringAsFixed(2),
                        r.totItm.toString(),
                        r.totPcs.toStringAsFixed(0),
                        r.remark,
                      ]).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.teal800),
                      cellStyle: const pw.TextStyle(fontSize: 8),
                      cellHeight: 22,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.center,
                        2: pw.Alignment.centerLeft,
                        3: pw.Alignment.center,
                        4: pw.Alignment.centerLeft,
                        5: pw.Alignment.center,
                        6: pw.Alignment.centerRight,
                        7: pw.Alignment.center,
                        8: pw.Alignment.center,
                        9: pw.Alignment.centerLeft,
                      },
                    ),
                  ],
                );
              },
            ),
          );
        }

        final pdfBytes = await pdf.save();
        await FileExportHelper.saveAndLaunchFile(
          bytes: pdfBytes,
          fileName: fileName,
        );
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });

        Future.delayed(const Duration(milliseconds: 800), () {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 1040,
        height: 640,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Row(
                children: [
                  // Left Config & Action Panel (5 flex)
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.sim_card_download_outlined, color: Color(0xFF0C3B2E), size: 24),
                              ),
                              const SizedBox(width: 14),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Export Issue Manager',
                                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Select format & download records to your PC',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

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
                                  subtitle: 'Structured sheet with data rows',
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
                                  subtitle: 'Clean printable table document',
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
                                child: ExportAnimatedSuccessButton(
                                  status: _isExporting
                                      ? ExportButtonStatus.loading
                                      : (_isExportSuccess ? ExportButtonStatus.success : ExportButtonStatus.idle),
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

                  // Right Records Preview Panel (7 flex)
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

              // Close Modal Button
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
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? brandColor.withValues(alpha: 0.8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewToolbar() {
    final totalCount = widget.records.length;
    final selectedCount = _selectedCodes.length;

    return Row(
      children: [
        // Search Box
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _modalSearchCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Filter records...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF0C3B2E), width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Select All Checkbox
        InkWell(
          onTap: _toggleSelectAllFiltered,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: _isAllFilteredSelected,
                  onChanged: (_) => _toggleSelectAllFiltered(),
                  activeColor: const Color(0xFF0C3B2E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                const Text('Select All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Count Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0C3B2E).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$selectedCount of $totalCount Selected',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0C3B2E)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final list = _filteredPreviewRecords;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              'No matching records found',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (ctx, idx) {
            final r = list[idx];
            final isChecked = _selectedCodes.contains(r.issueCode);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _selectedCodes.remove(r.issueCode);
                  } else {
                    _selectedCodes.add(r.issueCode);
                  }
                });
              },
              child: Container(
                color: isChecked ? const Color(0xFF0C3B2E).withValues(alpha: 0.03) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: isChecked,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCodes.add(r.issueCode);
                          } else {
                            _selectedCodes.remove(r.issueCode);
                          }
                        });
                      },
                      activeColor: const Color(0xFF0C3B2E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: Text(
                        r.issueCode,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F766E)),
                      ),
                    ),
                    SizedBox(
                      width: 85,
                      child: Text(_formatDate(r.issueDate), style: const TextStyle(fontSize: 11.5)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        r.sourceDeptName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 75,
                      child: Text(
                        r.totQty.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 45,
                      child: Text(
                        '${r.totItm} itms',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
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
