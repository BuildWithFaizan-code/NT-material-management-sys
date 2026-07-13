import 'dart:ui';
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
 // final ApiService _api = ApiService(baseUrl: 'http://localhost:5000/api/dashboard');
 final ApiService _api = ApiService(baseUrl: 'http://43.228.126.198:5000/api/dashboard');

  bool _isLoading = true;
  String? _error;

  MetricsDto? _metrics;
  List<VelocityDataPoint> _velocityData = [];
  List<AlertItem> _alerts = [];
  List<TransactionRecord> _transactions = [];

  String _selectedMetric = 'Material Velocity';

  // Local macro shortcuts (UI-only, not from API)
  final List<_MacroData> _macros = List.from(_initialMacros);

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.fetchMetrics(),
        _api.fetchVelocity(metricType: _selectedMetric),
        _api.fetchAlerts(),
        _api.fetchTransactions(),
      ]);

      if (!mounted) return;
      setState(() {
        _metrics = results[0] as MetricsDto;
        _velocityData = results[1] as List<VelocityDataPoint>;
        _alerts = results[2] as List<AlertItem>;
        _transactions = results[3] as List<TransactionRecord>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e is ApiException ? e.message : 'Unexpected error occurred.';
      });
    }
  }

  Future<void> _onMetricChanged(String metric) async {
    setState(() => _selectedMetric = metric);
    try {
      final data = await _api.fetchVelocity(metricType: metric);
      if (!mounted) return;
      setState(() => _velocityData = data);
    } catch (_) {}
  }

  Future<void> _onAlertPriorityChanged(AlertItem alert, String priority) async {
    final success = await _api.updateAlertPriority(alert.id, priority);
    if (!mounted) return;
    if (success) {
      setState(() => alert.priority = priority);
    }
  }

  Future<void> _onAlertDismissed(AlertItem alert) async {
    final success = await _api.deleteAlert(alert.id);
    if (!mounted) return;
    if (success) {
      setState(() => _alerts.remove(alert));
    }
  }

  void _addCustomShortcut() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Shortcut'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter shortcut name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _macros.add(_MacroData(
                    icon: Icons.star_border_rounded,
                    label: controller.text.trim(),
                  ));
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLarge =
        MediaQuery.of(context).size.width > AppDimensions.mobileBreakpoint;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRow1(context, isLarge),
            const SizedBox(height: AppDimensions.spacingMd),
            _buildRow2(context, isLarge),
            const SizedBox(height: AppDimensions.spacingMd),
            _buildRow3(context, isLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.neutralDark.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.neutralDark.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _fetchAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow1(BuildContext context, bool isLarge) {
    final metrics = _metrics;
    final velocity = _velocityData;
    final alerts = _alerts;

    if (isLarge) {
      return SizedBox(
        height: 420,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: _MaterialVelocityPanel(
                selectedMetric: _selectedMetric,
                data: velocity,
                metrics: metrics,
                onMetricChanged: _onMetricChanged,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              flex: 3,
              child: _CriticalAlertsPanel(
                alerts: alerts,
                onPriorityChanged: _onAlertPriorityChanged,
                onDismiss: _onAlertDismissed,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 380,
          child: _MaterialVelocityPanel(
            selectedMetric: _selectedMetric,
            data: velocity,
            metrics: metrics,
            onMetricChanged: _onMetricChanged,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        SizedBox(
          height: 400,
          child: _CriticalAlertsPanel(
            alerts: alerts,
            onPriorityChanged: _onAlertPriorityChanged,
            onDismiss: _onAlertDismissed,
          ),
        ),
      ],
    );
  }

  Widget _buildRow2(BuildContext context, bool isLarge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Command Macros',
          style: TextStyle(
            color: AppColors.neutralDark,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Wrap(
          spacing: AppDimensions.spacingMd,
          runSpacing: AppDimensions.spacingMd,
          children: [
            ..._macros.map((m) => _MacroCard(
                  icon: m.icon,
                  label: m.label,
                  onTap: () {},
                )),
            _AddShortcutCard(onTap: _addCustomShortcut),
          ],
        ),
      ],
    );
  }

  Widget _buildRow3(BuildContext context, bool isLarge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Live Transactions',
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            _TextActionChip(label: 'Export PDF'),
            const SizedBox(width: AppDimensions.spacingSm),
            _TextActionChip(label: 'View Ledger', isDark: true),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        _LiveTransactionsTable(
          transactions: _transactions,
          isLarge: isLarge,
        ),
      ],
    );
  }
}

// ============================================================================
// PANEL: Material Velocity Graph
// ============================================================================
class _MaterialVelocityPanel extends StatelessWidget {
  final String selectedMetric;
  final List<VelocityDataPoint> data;
  final MetricsDto? metrics;
  final ValueChanged<String> onMetricChanged;

  const _MaterialVelocityPanel({
    required this.selectedMetric,
    required this.data,
    required this.metrics,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedMetric,
                        style: const TextStyle(
                          color: AppColors.neutralDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Real-time tracking of item movement speed across warehouses.',
                        style: TextStyle(
                          color: AppColors.neutralDark.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward_rounded,
                              color: Color(0xFF2E7D32), size: 12),
                          SizedBox(width: 2),
                          Text(
                            '+16.2%',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F0EB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMetric,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primaryColor,
                            size: 18,
                          ),
                          style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          dropdownColor: AppColors.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          onChanged: (val) {
                            if (val != null) onMetricChanged(val);
                          },
                          items: <String>[
                            'Material Velocity',
                            'Profit & Loss',
                            'Sales & Purchase',
                            'Inventory Turnover',
                            'Procurement Trends',
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CustomPaint(
                  painter: _AnalyticalChartPainter(
                    data: data.map((d) => d.normalized).toList(),
                    peakIndex: data.length > 3 ? 3 : 0,
                    warningIndex: data.length > 7 ? 7 : 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: AppDimensions.spacingSm),
            _MetricFooterRow(metrics: metrics),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER: Graph Painter
// ============================================================================
class _AnalyticalChartPainter extends CustomPainter {
  final List<double> data;
  final int peakIndex;
  final int warningIndex;

  _AnalyticalChartPainter({
    required this.data,
    required this.peakIndex,
    required this.warningIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double barSpacing = 16.0;
    final int barCount = data.length;
    final double totalSpacing = barSpacing * (barCount - 1);
    final double barWidth = (size.width - totalSpacing) / barCount;

    final gridPaint = Paint()
      ..color = AppColors.divider.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    for (int i = 1; i <= 3; i++) {
      final double y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final List<Offset> curvePoints = [];

    for (int i = 0; i < barCount; i++) {
      final double h = data[i] * (size.height - 25);
      final double x = i * (barWidth + barSpacing);
      final double y = size.height - h;

      Color barColor;
      if (i == peakIndex) {
        barColor = AppColors.primaryColor;
      } else if (i == warningIndex) {
        barColor = const Color(0xFFFFC499);
      } else {
        barColor = AppColors.divider.withValues(alpha: 0.6);
      }

      final barPaint = Paint()..color = barColor;
      final RRect rrect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, y, barWidth, h),
        topLeft: const Radius.circular(5),
        topRight: const Radius.circular(5),
      );
      canvas.drawRRect(rrect, barPaint);

      curvePoints.add(Offset(x + barWidth / 2, y + 2));

      if (i == peakIndex) {
        _drawPeakBadge(canvas, x + barWidth / 2, y);
      }
    }

    if (curvePoints.isNotEmpty) {
      final path = Path();
      path.moveTo(curvePoints[0].dx, curvePoints[0].dy);
      for (int i = 0; i < curvePoints.length - 1; i++) {
        final p0 = curvePoints[i];
        final p1 = curvePoints[i + 1];
        final controlX = (p0.dx + p1.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      final curvePaint = Paint()
        ..color = AppColors.tertiaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, curvePaint);
    }
  }

  void _drawPeakBadge(Canvas canvas, double cx, double cy) {
    const double badgeW = 44.0;
    const double badgeH = 18.0;
    final double bx = cx - badgeW / 2;
    final double by = cy - badgeH - 6;

    final capsulePaint = Paint()..color = AppColors.primaryColor;
    final capsule = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, badgeW, badgeH),
      const Radius.circular(9),
    );
    canvas.drawRRect(capsule, capsulePaint);

    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );
    final textSpan = TextSpan(text: 'Peak', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final double tx = cx - textPainter.width / 2;
    final double ty = by + (badgeH - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(tx, ty));
  }

  @override
  bool shouldRepaint(covariant _AnalyticalChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.peakIndex != peakIndex ||
        oldDelegate.warningIndex != warningIndex;
  }
}

// ============================================================================
// PANEL: Critical Alerts
// ============================================================================
class _CriticalAlertsPanel extends StatelessWidget {
  final List<AlertItem> alerts;
  final Function(AlertItem, String) onPriorityChanged;
  final ValueChanged<AlertItem> onDismiss;

  const _CriticalAlertsPanel({
    required this.alerts,
    required this.onPriorityChanged,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFC62828),
                  size: 20,
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                const Text(
                  'Critical Alerts',
                  style: TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${alerts.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Expanded(
              child: alerts.isEmpty
                  ? Center(
                      child: Text(
                        'No critical issues reported.',
                        style: TextStyle(
                          color: AppColors.neutralDark.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: alerts.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: AppDimensions.spacingSm),
                      itemBuilder: (context, index) {
                        final alert = alerts[index];
                        return _AlertItemCard(
                          key: ValueKey(alert.id),
                          alert: alert,
                          onPriorityChanged: (priority) =>
                              onPriorityChanged(alert, priority),
                          onDismiss: () => onDismiss(alert),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFDFE6ED),
                  foregroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {},
                child: const Text(
                  'VIEW ALL INCIDENT LOGS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertItemCard extends StatelessWidget {
  final AlertItem alert;
  final ValueChanged<String> onPriorityChanged;
  final VoidCallback onDismiss;

  const _AlertItemCard({
    super.key,
    required this.alert,
    required this.onPriorityChanged,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHigh = alert.isHigh;

    Border border;
    if (isHigh) {
      border = Border.all(color: AppColors.tertiaryColor, width: 1.5);
    } else if (alert.isWarning) {
      border = Border.all(color: const Color(0xFFE53E3E), width: 1.5);
    } else {
      border = Border.all(color: AppColors.divider, width: 1);
    }

    final Color badgeBg = alert.isWarning
        ? const Color(0xFFFEE2E2)
        : const Color(0xFFFEF3C7);
    final Color badgeIconColor = alert.isWarning
        ? const Color(0xFFEF4444)
        : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                alert.isWarning
                    ? Icons.sync_problem_rounded
                    : Icons.inventory_2_outlined,
                color: badgeIconColor,
                size: 16,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alert.itemName,
                          style: const TextStyle(
                            color: AppColors.neutralDark,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${alert.department} · Stock: ${alert.currentStock.toInt()} (Min: ${alert.safetyThreshold.toInt()})',
                    style: TextStyle(
                      color: AppColors.neutralDark.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppColors.neutralDark.withValues(alpha: 0.4),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (val) {
                if (val == 'high') {
                  onPriorityChanged('High');
                } else if (val == 'low') {
                  onPriorityChanged('Low');
                } else if (val == 'ignore') {
                  onDismiss();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'high',
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded,
                          color: AppColors.tertiaryColor, size: 16),
                      SizedBox(width: 8),
                      Text('Set Priority: High',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'low',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined,
                          color: AppColors.neutralDark, size: 16),
                      SizedBox(width: 8),
                      Text('Set Priority: Low',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'ignore',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 16),
                      SizedBox(width: 8),
                      Text('Ignore Item', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PANEL: Command Macros
// ============================================================================
class _MacroCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MacroCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 135,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F0EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.neutralDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddShortcutCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddShortcutCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      height: 110,
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: AppColors.neutralDark.withValues(alpha: 0.3),
          strokeWidth: 1.5,
          radius: 12,
          gap: 4,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: AppColors.neutralDark,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '+ Add Custom\nShortcut',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double gap;

  _DashedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    ));

    final dashedPath = _buildDashedPath(path, 6.0, gap);
    canvas.drawPath(dashedPath, paint);
  }

  Path _buildDashedPath(Path source, double dashWidth, double dashGap) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashWidth : dashGap;
        if (distance + len > metric.length) {
          dest.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          if (draw) {
            dest.addPath(
              metric.extractPath(distance, distance + len),
              Offset.zero,
            );
          }
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// PANEL: Live Transactions Log Table
// ============================================================================
class _LiveTransactionsTable extends StatelessWidget {
  final List<TransactionRecord> transactions;
  final bool isLarge;

  const _LiveTransactionsTable({
    required this.transactions,
    required this.isLarge,
  });

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return Card(
        color: AppColors.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingMd),
          child: _buildTable(),
        ),
      );
    }
    return Card(
      color: AppColors.surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingSm),
        child: Column(
          children: transactions.map((t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MobileTransactionRow(transaction: t),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderRow(),
        const SizedBox(height: AppDimensions.spacingSm),
        const Divider(color: AppColors.divider, height: 1),
        ...transactions.map((t) => _buildDataRow(t)),
      ],
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildHeaderCell(_headers[0])),
        Expanded(flex: 4, child: _buildHeaderCell(_headers[1])),
        Expanded(flex: 2, child: _buildHeaderCell(_headers[2])),
        Expanded(flex: 2, child: _buildHeaderCell(_headers[3])),
        Expanded(flex: 2, child: _buildHeaderCell(_headers[4])),
        Expanded(flex: 2, child: _buildHeaderCell(_headers[5])),
        Expanded(flex: 1, child: _buildHeaderCell(_headers[6])),
      ],
    );
  }

  Widget _buildHeaderCell(String h) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        h,
        style: TextStyle(
          color: AppColors.neutralDark.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataRow(TransactionRecord t) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _TableCell(
              child: Text(
                t.transactionId,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutralDark,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: _TableCell(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.materialDetail,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutralDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TableCell(
              child: Text(
                t.department,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.neutralDark),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TableCell(
              child: Text(
                t.quantity,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutralDark,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TableCell(
              child: Text(
                t.valueFormatted,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neutralDark,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: _TableCell(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusChip(status: t.status),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: _TableCell(
              child: InkWell(
                onTap: () {},
                child: const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.primaryColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final Widget child;
  const _TableCell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: child,
    );
  }
}

final List<String> _headers = [
  'Transaction ID',
  'Material Detail',
  'Department',
  'Quantity',
  'Value',
  'Status Tag',
  'Action',
];

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final bool isReceived = status == 'RECEIVED';
    final Color bg = isReceived
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);
    final Color text = isReceived
        ? const Color(0xFF2E7D32)
        : AppColors.tertiaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: text,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _TextActionChip extends StatelessWidget {
  final String label;
  final bool isDark;
  const _TextActionChip({required this.label, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.primaryColor : Colors.transparent,
          border: isDark ? null : Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white
                : AppColors.neutralDark.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MobileTransactionRow extends StatelessWidget {
  final TransactionRecord transaction;
  const _MobileTransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.transactionId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neutralDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.materialDetail} · ${transaction.department}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.neutralDark.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${transaction.quantity} · ${transaction.valueFormatted}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.neutralDark,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusChip(status: transaction.status),
              const SizedBox(height: 4),
              const Icon(
                Icons.visibility_outlined,
                color: AppColors.primaryColor,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOCAL MODELS & DATA DEFINITIONS (UI-only)
// ============================================================================
class _MacroData {
  final IconData icon;
  final String label;
  const _MacroData({required this.icon, required this.label});
}

final List<_MacroData> _initialMacros = [
  _MacroData(icon: Icons.exit_to_app_rounded, label: 'New Gate Pass'),
  _MacroData(icon: Icons.receipt_long_rounded, label: 'Material Receipt'),
  _MacroData(icon: Icons.tune_rounded, label: 'Stock Adjustment'),
  _MacroData(icon: Icons.note_alt_outlined, label: 'Issue Note'),
  _MacroData(icon: Icons.business_rounded, label: 'Vendor Master'),
  _MacroData(icon: Icons.verified_rounded, label: 'Quality Check'),
];

// ============================================================================
// METRICS FOOTER
// ============================================================================
class _MetricFooterRow extends StatelessWidget {
  final MetricsDto? metrics;
  const _MetricFooterRow({this.metrics});

  @override
  Widget build(BuildContext context) {
    final blocks = [
      ('ACTIVE STOCKS',
          metrics != null ? '${metrics!.activeStocks} SKUs' : '—', null),
      ('AVG. LEAD TIME',
          metrics != null ? '${metrics!.avgLeadTime} Days' : '—', null),
      ('PROCUREMENT',
          metrics != null ? '₹${_formatCurrency(metrics!.procurementTotal)}' : '—', null),
      ('OPTIMIZATION',
          metrics != null ? '${metrics!.optimizationScore}%' : '—',
          AppColors.tertiaryColor),
    ];

    return Row(
      children: blocks.map((b) {
        final isLast = b == blocks.last;
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                right: isLast
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.divider, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  b.$1,
                  style: TextStyle(
                    color: AppColors.neutralDark.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  b.$2,
                  style: TextStyle(
                    color: b.$3 ?? AppColors.primaryColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    }
    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    }
    return value.toStringAsFixed(0);
  }
}
