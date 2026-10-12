import 'dart:async';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../design/app_colors.dart';
import '../../../utils/file_export_helper.dart';
import '../purchase_order_models.dart';
import 'po_animated_success_button.dart';

// ============================================================================
// 1. ANIMATED EXPORT BUTTON WITH CIRCULATING LIGHT EDGE ORBIT
// ============================================================================
class PoAnimatedExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  const PoAnimatedExportButton({super.key, required this.onPressed});

  @override
  State<PoAnimatedExportButton> createState() => _PoAnimatedExportButtonState();
}

class _PoAnimatedExportButtonState extends State<PoAnimatedExportButton>
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
              painter: _PoOrbitButtonBorderPainter(
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

class _PoOrbitButtonBorderPainter extends CustomPainter {
  final double progress;
  final bool isHovered;
  final bool isAnimating;

  _PoOrbitButtonBorderPainter({
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
      ..color = AppColors.success.withValues(alpha: 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3.0);

    final beamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          AppColors.primaryColor.withValues(alpha: 0.2),
          AppColors.success,
          AppColors.secondaryColor,
          AppColors.surfaceColor,
        ],
        stops: const [0.0, 0.4, 0.7, 0.9, 1.0],
      ).createShader(rect);

    canvas.drawPath(extractPath, glowPaint);
    canvas.drawPath(extractPath, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _PoOrbitButtonBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.isAnimating != isAnimating;
  }
}

// ============================================================================
// 2. 3D BRAND LOGO WIDGETS (EXCEL & PDF)
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
            color: AppColors.excelGreen.withValues(alpha: 0.38),
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
        colors: [AppColors.primaryColor, AppColors.excelGreen, AppColors.secondaryColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    final sheetPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.excelGreenLight, AppColors.successLight],
      ).createShader(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.42, 0, w * 0.58, h), Radius.circular(w * 0.08)),
      sheetPaint,
    );

    final linePaint = Paint()
      ..color = AppColors.excelGreen.withValues(alpha: 0.35)
      ..strokeWidth = w * 0.045;

    canvas.drawLine(Offset(w * 0.45, h * 0.28), Offset(w * 0.92, h * 0.28), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.50), Offset(w * 0.92, h * 0.50), linePaint);
    canvas.drawLine(Offset(w * 0.45, h * 0.72), Offset(w * 0.92, h * 0.72), linePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.12), Offset(w * 0.68, h * 0.88), linePaint);

    final plateGradient = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.info, AppColors.excelGreen, AppColors.primaryColor],
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
          color: AppColors.surfaceColor,
          fontSize: h * 0.62,
          fontWeight: FontWeight.w900,
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
            color: AppColors.pdfRed.withValues(alpha: 0.38),
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
        colors: [AppColors.errorAlt, AppColors.pdfRed, AppColors.errorDark],
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
        colors: [AppColors.errorBorder, AppColors.errorDark],
      ).createShader(Rect.fromLTWH(w * 0.70, 0, w * 0.30, h * 0.30));

    canvas.drawPath(foldPath, foldPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'PDF',
        style: TextStyle(
          color: AppColors.surfaceColor,
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
// 3. COMPREHENSIVE PURCHASE ORDER EXPORT MODAL DIALOG
// ============================================================================
class PoExportModalDialog extends StatefulWidget {
  final List<PurchaseOrderHeader> orders;

  const PoExportModalDialog({super.key, required this.orders});

  @override
  State<PoExportModalDialog> createState() => _PoExportModalDialogState();
}

class _PoExportModalDialogState extends State<PoExportModalDialog> {
  String _selectedFormat = 'XLSX'; // 'XLSX' or 'PDF'
  final TextEditingController _modalSearchCtrl = TextEditingController();
  String _modalSearchQuery = '';
  late Set<String> _selectedPoNos;

  bool _isExporting = false;
  bool _isExportSuccess = false;
  double _exportProgress = 0.0;
  Timer? _exportTimer;

  @override
  void initState() {
    super.initState();
    _selectedPoNos = widget.orders.map((o) => o.poNo).toSet();
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

  List<PurchaseOrderHeader> get _filteredPreviewOrders {
    if (_modalSearchQuery.isEmpty) return widget.orders;
    return widget.orders.where((o) {
      final noMatch = o.poNo.toLowerCase().contains(_modalSearchQuery);
      final partyMatch = o.partyName.toLowerCase().contains(_modalSearchQuery);
      final storeMatch = o.storeName.toLowerCase().contains(_modalSearchQuery);
      return noMatch || partyMatch || storeMatch;
    }).toList();
  }

  bool get _isAllFilteredSelected {
    final preview = _filteredPreviewOrders;
    if (preview.isEmpty) return false;
    return preview.every((o) => _selectedPoNos.contains(o.poNo));
  }

  void _toggleSelectAllFiltered() {
    final preview = _filteredPreviewOrders;
    setState(() {
      if (_isAllFilteredSelected) {
        for (final o in preview) {
          _selectedPoNos.remove(o.poNo);
        }
      } else {
        for (final o in preview) {
          _selectedPoNos.add(o.poNo);
        }
      }
    });
  }

  void _startExportProcess() {
    if (_selectedPoNos.isEmpty) return;

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
      final selectedList = widget.orders
          .where((o) => _selectedPoNos.contains(o.poNo))
          .toList();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _selectedFormat == 'XLSX' ? 'xlsx' : 'pdf';
      final fileName = 'PurchaseOrders_Export_$timestamp.$extension';

      if (_selectedFormat == 'XLSX') {
        final excel = excel_pkg.Excel.createExcel();
        final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
        excel.rename(defaultSheet, 'Purchase Orders');
        final excel_pkg.Sheet sheet = excel['Purchase Orders'];

        sheet.setColumnWidth(0, 22.0); // PO NO
        sheet.setColumnWidth(1, 16.0); // DATE
        sheet.setColumnWidth(2, 34.0); // PARTY NAME
        sheet.setColumnWidth(3, 18.0); // GSTIN
        sheet.setColumnWidth(4, 16.0); // STORE
        sheet.setColumnWidth(5, 14.0); // MODE
        sheet.setColumnWidth(6, 14.0); // TOT QTY
        sheet.setColumnWidth(7, 18.0); // NET AMT
        sheet.setColumnWidth(8, 14.0); // STATUS

        sheet.setRowHeight(0, 26.0);
        sheet.appendRow([
          excel_pkg.TextCellValue('PO NO'),
          excel_pkg.TextCellValue('DATE'),
          excel_pkg.TextCellValue('PARTY NAME'),
          excel_pkg.TextCellValue('GSTIN'),
          excel_pkg.TextCellValue('STORE'),
          excel_pkg.TextCellValue('MODE'),
          excel_pkg.TextCellValue('TOTAL QTY'),
          excel_pkg.TextCellValue('NET AMOUNT (INR)'),
          excel_pkg.TextCellValue('STATUS'),
        ]);

        for (final o in selectedList) {
          sheet.appendRow([
            excel_pkg.TextCellValue(o.poNo),
            excel_pkg.TextCellValue(o.poDate.toIso8601String().split('T')[0]),
            excel_pkg.TextCellValue(o.partyName),
            excel_pkg.TextCellValue(o.gstin),
            excel_pkg.TextCellValue(o.storeName),
            excel_pkg.TextCellValue(o.poMode),
            excel_pkg.DoubleCellValue(o.totQty),
            excel_pkg.DoubleCellValue(o.netAmt),
            excel_pkg.TextCellValue(o.approved ? 'Approved' : 'Pending'),
          ]);
        }

        final fileBytes = excel.save();
        if (fileBytes != null) {
          await FileExportHelper.saveAndLaunchFile(bytes: fileBytes, fileName: fileName);
        }
      } else {
        // PDF Export
        final pdf = pw.Document();
        final headers = ['PO NO', 'DATE', 'PARTY NAME', 'STORE', 'MODE', 'QTY', 'NET AMT', 'STATUS'];

        final data = selectedList.map((o) {
          return [
            o.poNo,
            o.poDate.toIso8601String().split('T')[0],
            o.partyName,
            o.storeName,
            o.poMode,
            o.totQty.toStringAsFixed(2),
            o.netAmt.toStringAsFixed(2),
            o.approved ? 'Approved' : 'Pending',
          ];
        }).toList();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Purchase Orders Directory', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Exported: ${DateTime.now().toIso8601String().split('T')[0]}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: headers,
                  data: data,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  cellHeight: 24,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.centerLeft,
                    4: pw.Alignment.center,
                    5: pw.Alignment.centerRight,
                    6: pw.Alignment.centerRight,
                    7: pw.Alignment.center,
                  },
                ),
              ];
            },
          ),
        );

        final pdfBytes = await pdf.save();
        await FileExportHelper.saveAndLaunchFile(bytes: pdfBytes, fileName: fileName);
      }

      if (mounted) {
        setState(() {
          _isExporting = false;
          _isExportSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 1000,
        height: 620,
        decoration: BoxDecoration(
          color: AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.neutralDark.withValues(alpha: 0.16),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Row(
                children: [
                  // Left Settings Panel (Flex 5)
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.sim_card_download_outlined, color: AppColors.primaryColor, size: 22),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Export Purchase Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.surfaceDark)),
                                  SizedBox(height: 2),
                                  Text('Select format & download records to PC', style: TextStyle(fontSize: 11, color: AppColors.slateMuted)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          const Text('1. Select File Format', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.surfaceDark)),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: _buildSideBySideCard(
                                  formatKey: 'XLSX',
                                  title: 'Excel (.xlsx)',
                                  subtitle: 'Structured sheet with data grid',
                                  logoWidget: const Excel3DBrandLogoWidget(size: 40),
                                  brandColor: AppColors.excelGreen,
                                  bgColor: AppColors.excelGreenLight,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSideBySideCard(
                                  formatKey: 'PDF',
                                  title: 'PDF (.pdf)',
                                  subtitle: 'Printable formatted report',
                                  logoWidget: const Pdf3DBrandLogoWidget(size: 40),
                                  brandColor: AppColors.pdfRed,
                                  bgColor: AppColors.pdfRedLight,
                                ),
                              ),
                            ],
                          ),

                          const Spacer(),

                          if (_isExporting) ...[
                            LinearProgressIndicator(
                              value: _exportProgress,
                              backgroundColor: AppColors.divider,
                              color: AppColors.primaryColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                'Generating Export File... ${(_exportProgress * 100).toInt()}%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryColor),
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
                                    side: const BorderSide(color: AppColors.tableBorder),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(color: AppColors.neutralDark, fontWeight: FontWeight.bold, fontSize: 12.5)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PoAnimatedSuccessButton(
                                  status: _isExporting
                                      ? ButtonStatus.loading
                                      : (_isExportSuccess ? ButtonStatus.success : ButtonStatus.idle),
                                  onPressed: _startExportProcess,
                                  idleText: 'Download File',
                                  loadingText: 'Exporting...',
                                  successText: 'Exported!',
                                  idleIcon: Icons.file_download_outlined,
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

                  // Right Preview Panel (Flex 7)
                  Expanded(
                    flex: 7,
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      color: AppColors.tableRowHover,
                      child: Column(
                        children: [
                          _buildPreviewToolbar(),
                          const SizedBox(height: 12),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? bgColor : AppColors.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? brandColor : AppColors.tableBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
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
                  color: isSelected ? brandColor : AppColors.slateMuted,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? brandColor : AppColors.surfaceDark)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: AppColors.slateMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewToolbar() {
    return Row(
      children: [
        SizedBox(
          width: 220,
          height: 36,
          child: TextField(
            controller: _modalSearchCtrl,
            style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark),
            decoration: InputDecoration(
              hintText: 'Filter export records...',
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.slateMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 15, color: AppColors.primaryColor),
              filled: true,
              fillColor: AppColors.surfaceColor,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.tableBorder)),
            ),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _toggleSelectAllFiltered,
          icon: Icon(_isAllFilteredSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 16, color: AppColors.primaryColor),
          label: Text(_isAllFilteredSelected ? 'Deselect All' : 'Select All', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${_selectedPoNos.length} / ${widget.orders.length}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewDataTable() {
    final list = _filteredPreviewOrders;
    if (list.isEmpty) {
      return const Center(child: Text('No orders found matching search criteria', style: TextStyle(fontSize: 12, color: AppColors.slateMuted)));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.tableBorder),
      ),
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: AppColors.divider),
        itemBuilder: (ctx, i) {
          final o = list[i];
          final isSelected = _selectedPoNos.contains(o.poNo);

          return InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedPoNos.remove(o.poNo);
                } else {
                  _selectedPoNos.add(o.poNo);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: isSelected ? AppColors.secondaryColor.withValues(alpha: 0.04) : Colors.transparent,
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPoNos.add(o.poNo);
                        } else {
                          _selectedPoNos.remove(o.poNo);
                        }
                      });
                    },
                  ),
                  SizedBox(
                    width: 140,
                    child: Text(o.poNo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryColor)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(o.partyName, style: const TextStyle(fontSize: 11.5, color: AppColors.neutralDark), overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text('Qty: ${o.totQty.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: AppColors.slateMuted)),
                  ),
                  SizedBox(
                    width: 110,
                    child: Text('₹ ${o.netAmt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.neutralDark)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
