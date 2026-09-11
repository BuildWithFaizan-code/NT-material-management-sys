import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';
import '../services/api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ApiService _api =
      ApiService(baseUrl: 'http://localhost:5000/api/dashboard');

  bool _isLoading = true;
  bool _isOffline = false;

  MetricsDto? _metrics;
  List<VelocityDataPoint> _velocityData = [];
  List<TransactionRecord> _transactions = [];

  String _selectedMetric = 'Material Velocity';

  // Local macro shortcuts
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
      _isOffline = false;
    });

    try {
      final results = await Future.wait([
        _api.fetchMetrics(),
        _api.fetchVelocity(metricType: _selectedMetric),
        _api.fetchTransactions(),
      ]);

      if (!mounted) return;
      setState(() {
        _metrics = results[0] as MetricsDto;
        _velocityData = results[1] as List<VelocityDataPoint>;
        _transactions = results[2] as List<TransactionRecord>;
        _isLoading = false;
        _isOffline = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Resilient fallback to default seed MMS data so dashboard always renders
      setState(() {
        _metrics = _defaultMetrics;
        _velocityData = _getDefaultVelocity(_selectedMetric);
        _transactions = List.from(_defaultTransactions);
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _onMetricChanged(String metric) async {
    setState(() => _selectedMetric = metric);
    try {
      final data = await _api.fetchVelocity(metricType: metric);
      if (!mounted) return;
      setState(() => _velocityData = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _velocityData = _getDefaultVelocity(metric));
    }
  }

  void _addCustomShortcut() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Shortcut',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g. Dyeing Job Card',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _macros.add(_MacroData(
                    icon: Icons.bookmark_border_rounded,
                    label: controller.text.trim(),
                  ));
                });
              }
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }

    final metrics = _metrics ?? _defaultMetrics;

    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offline notification strip if server is unreachable
            if (_isOffline) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Backend server offline — displaying cached MMS operational records.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _fetchAll,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: const [
                            Icon(Icons.refresh_rounded,
                                size: 15, color: Color(0xFF92400E)),
                            SizedBox(width: 4),
                            Text(
                              'Reconnect',
                              style: TextStyle(
                                color: Color(0xFF92400E),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── ROW 1: Vibrant Gradient KPI Cards (Image 1 reference) ──────
            _buildGradientKpiCards(metrics, isLarge),
            const SizedBox(height: 20),

            // ── ROW 2: Multi-Wave Spline Graph & Donut Breakdown ──────────
            _buildVisualizationsRow(context, isLarge),
            const SizedBox(height: 20),

            // ── ROW 3: Monthly Fulfillment, Storage Telemetry & Quick Macros
            _buildOperationsRow(context, isLarge),
            const SizedBox(height: 20),

            // ── ROW 4: Corporate Enterprise Live Transactions Table ────────
            _CorporateTransactionsTable(transactions: _transactions),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // ROW 1: GRADIENT KPI CARDS
  // ==========================================================================
  Widget _buildGradientKpiCards(MetricsDto metrics, bool isLarge) {
    final cards = [
      _GradientKpiCard(
        title: 'Active Stock SKUs',
        value: '${metrics.activeStocks}',
        trend: '+8.4% this month',
        subtitle: 'Material catalog items',
        icon: Icons.inventory_2_outlined,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5E62), Color(0xFFFF9966)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _GradientKpiCard(
        title: 'Procurement Volume',
        value: metrics.procurementTotal >= 1000
            ? '₹${(metrics.procurementTotal / 1000).toStringAsFixed(1)}K'
            : '₹${metrics.procurementTotal.toStringAsFixed(0)}',
        trend: '+12.6% vs target',
        subtitle: 'Current requisition value',
        icon: Icons.shopping_bag_outlined,
        gradient: const LinearGradient(
          colors: [Color(0xFF2575FC), Color(0xFF6A11CB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _GradientKpiCard(
        title: 'Optimization Score',
        value: '${metrics.optimizationScore.toStringAsFixed(1)}%',
        trend: '+2.1% efficiency',
        subtitle: 'Stock turnover index',
        icon: Icons.speed_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF0BA360), Color(0xFF3CBA92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _GradientKpiCard(
        title: 'Avg Lead Time',
        value: '${metrics.avgLeadTime.toStringAsFixed(1)} Days',
        trend: '-0.8d turnaround',
        subtitle: 'Vendor delivery pace',
        icon: Icons.timelapse_rounded,
        gradient: const LinearGradient(
          colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];

    if (isLarge) {
      return Row(
        children: cards
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: c,
                  ),
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 560 ? 2 : 1;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map((c) => SizedBox(
                    width: crossCount == 2
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth,
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  // ==========================================================================
  // ROW 2: SPLINE GRAPH + WAREHOUSE DONUT
  // ==========================================================================
  Widget _buildVisualizationsRow(BuildContext context, bool isLarge) {
    final splineChart = _MaterialVelocitySplineCard(
      selectedMetric: _selectedMetric,
      velocityData: _velocityData,
      onMetricChanged: _onMetricChanged,
    );

    final donutCard = const _WarehouseDistributionCard();

    if (isLarge) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: splineChart),
          const SizedBox(width: 14),
          Expanded(flex: 3, child: donutCard),
        ],
      );
    }

    return Column(
      children: [
        splineChart,
        const SizedBox(height: 14),
        donutCard,
      ],
    );
  }

  // ==========================================================================
  // ROW 3: OPERATIONS, STORAGE TELEMETRY & QUICK MACROS
  // ==========================================================================
  Widget _buildOperationsRow(BuildContext context, bool isLarge) {
    final barCard = const _MonthlyFulfillmentBarCard();
    final telemetryCard = const _WarehouseCapacityTelemetryCard();
    final macrosCard = _QuickMacrosCard(
      macros: _macros,
      onAdd: _addCustomShortcut,
    );

    if (isLarge) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: barCard),
          const SizedBox(width: 14),
          Expanded(flex: 4, child: telemetryCard),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: macrosCard),
        ],
      );
    }

    return Column(
      children: [
        barCard,
        const SizedBox(height: 14),
        telemetryCard,
        const SizedBox(height: 14),
        macrosCard,
      ],
    );
  }
}

// ============================================================================
// 1. GRADIENT KPI CARD (Ref: Image 1 & 2)
// ============================================================================
class _GradientKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;

  const _GradientKpiCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 148,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Soft Watermark Circular Geometry from Reference Image 1
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Positioned(
              right: 28,
              bottom: -40,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Title & Icon Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.90),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(icon, color: Colors.white, size: 17),
                        ),
                      ),
                    ],
                  ),

                  // Large Bold Metric
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),

                  // Trend pill & Subtitle
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trend,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
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
  }
}

// ============================================================================
// 2. MULTI-WAVE SPLINE AREA CHART (Ref: Image 2 & 3)
// ============================================================================
class _MaterialVelocitySplineCard extends StatelessWidget {
  final String selectedMetric;
  final List<VelocityDataPoint> velocityData;
  final ValueChanged<String> onMetricChanged;

  const _MaterialVelocitySplineCard({
    required this.selectedMetric,
    required this.velocityData,
    required this.onMetricChanged,
  });

  static const List<String> _metricsList = [
    'Material Velocity',
    'Sales & Purchase',
    'Inventory Turnover',
    'Procurement Trends',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Title, Filters & Legend
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Material Flow & Velocity Analytics',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Real-time material intake vs fulfillment speed across 12 months',
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Metric Switcher Dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedMetric,
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Color(0xFF374151)),
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _metricsList
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) onMetricChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Legend Indicators
          Row(
            children: [
              _buildLegendDot(const Color(0xFF3B82F6), 'Material Intake Flow'),
              const SizedBox(width: 16),
              _buildLegendDot(
                  const Color(0xFF8B5CF6), 'Plant Consumption Demand'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '12 Months Cycle',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Custom Paint Spline Waves
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _SplineWavePainter(data: velocityData),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SplineWavePainter extends CustomPainter {
  final List<VelocityDataPoint> data;
  _SplineWavePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double w = size.width;
    final double h = size.height - 24;

    // 1. Draw horizontal grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // 2. Compute points
    final int count = data.length;
    final double step = count > 1 ? w / (count - 1) : w;

    double maxVal = 1;
    for (final p in data) {
      if (p.value > maxVal) maxVal = p.value.toDouble();
    }
    if (maxVal <= 0) maxVal = 100;

    final List<Offset> points1 = [];
    final List<Offset> points2 = [];

    for (int i = 0; i < count; i++) {
      final x = i * step;
      final val1 = data[i].value.toDouble();
      final norm1 = (val1 / maxVal).clamp(0.05, 0.95);
      final y1 = h - (norm1 * (h - 20)) - 10;
      points1.add(Offset(x, y1));

      final double waveFactor = 0.5 + 0.3 * math.sin(i * 0.8 + 1.2);
      final y2 = (h - (norm1 * 0.7 * (h - 20)) - 15) * waveFactor + (h * 0.25);
      points2.add(Offset(x, y2.clamp(10.0, h - 10.0)));
    }

    // 3. Draw Wave 2 (Purple)
    _drawSplineArea(
      canvas,
      points2,
      h,
      strokeColor: const Color(0xFF8B5CF6),
      fillColors: [
        const Color(0xFF8B5CF6).withValues(alpha: 0.22),
        const Color(0xFF8B5CF6).withValues(alpha: 0.0),
      ],
    );

    // 4. Draw Wave 1 (Blue)
    _drawSplineArea(
      canvas,
      points1,
      h,
      strokeColor: const Color(0xFF3B82F6),
      fillColors: [
        const Color(0xFF3B82F6).withValues(alpha: 0.35),
        const Color(0xFF3B82F6).withValues(alpha: 0.0),
      ],
    );

    // 5. Draw Month labels
    final textStyle = const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );

    for (int i = 0; i < count; i++) {
      final span = TextSpan(text: data[i].month, style: textStyle);
      final tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(points1[i].dx - (tp.width / 2), h + 8));
    }
  }

  void _drawSplineArea(
    Canvas canvas,
    List<Offset> points,
    double height, {
    required Color strokeColor,
    required List<Color> fillColors,
  }) {
    if (points.length < 2) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, height)
      ..lineTo(points.first.dx, height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: fillColors,
      ).createShader(Rect.fromLTWH(0, 0, points.last.dx, height));

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()..color = strokeColor;
    final whiteDotPaint = Paint()..color = Colors.white;

    for (int i = 0; i < points.length; i += 2) {
      canvas.drawCircle(points[i], 4, dotPaint);
      canvas.drawCircle(points[i], 2, whiteDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SplineWavePainter oldDelegate) => true;
}

// ============================================================================
// 3. WAREHOUSE ALLOCATION DONUT CARD (Ref: Image 1 & 2)
// ============================================================================
class _WarehouseDistributionCard extends StatelessWidget {
  const _WarehouseDistributionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Warehouse Allocation',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Material distribution by department',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Donut Chart Canvas with Center Stat
          Expanded(
            child: Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(170, 170),
                      painter: _DonutChartPainter(),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          '677',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Total SKUs',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Legend Items
          _buildLegendRow('Spinning Dept', '38%', const Color(0xFFFF6E7F)),
          const SizedBox(height: 7),
          _buildLegendRow('Weaving Unit', '28%', const Color(0xFF2193B0)),
          const SizedBox(height: 7),
          _buildLegendRow('Dyeing Unit', '20%', const Color(0xFF11998E)),
          const SizedBox(height: 7),
          _buildLegendRow('Finishing Dept', '14%', const Color(0xFF8E2DE2)),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String title, String percent, Color color) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          percent,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 22.0;

    final slices = [
      {'percent': 0.38, 'color': const Color(0xFFFF6E7F)},
      {'percent': 0.28, 'color': const Color(0xFF2193B0)},
      {'percent': 0.20, 'color': const Color(0xFF11998E)},
      {'percent': 0.14, 'color': const Color(0xFF8E2DE2)},
    ];

    double startAngle = -math.pi / 2;

    for (final slice in slices) {
      final sweepAngle = (slice['percent'] as double) * 2 * math.pi;
      final paint = Paint()
        ..color = slice['color'] as Color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle + 0.05,
        sweepAngle - 0.10,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 4. MONTHLY FULFILLMENT BAR CARD (Ref: Image 1 & 2)
// ============================================================================
class _MonthlyFulfillmentBarCard extends StatelessWidget {
  const _MonthlyFulfillmentBarCard();

  @override
  Widget build(BuildContext context) {
    final data = [
      {'month': 'Jul', 'req': 68, 'del': 62},
      {'month': 'Aug', 'req': 82, 'del': 78},
      {'month': 'Sep', 'req': 74, 'del': 71},
      {'month': 'Oct', 'req': 95, 'del': 89},
      {'month': 'Nov', 'req': 88, 'del': 85},
      {'month': 'Dec', 'req': 102, 'del': 97},
    ];

    return Container(
      height: 310,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Requisitions vs Delivery',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Monthly fulfillment tracking',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '94.8% Met',
                  style: TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: data.map((d) {
                final reqHeight = (d['req'] as int) * 1.5;
                final delHeight = (d['del'] as int) * 1.5;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 10,
                          height: reqHeight,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF22D3EE), Color(0xFF0284C7)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 10,
                          height: delHeight,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d['month'] as String,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. UNIQUE ELEMENT: WAREHOUSE STORAGE & FACILITY TELEMETRY CARD
// ============================================================================
class _WarehouseCapacityTelemetryCard extends StatelessWidget {
  const _WarehouseCapacityTelemetryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Live Telemetry Pulse
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Plant Storage Telemetry',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Live capacity & environment status',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '22°C • 48% RH',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Main Telemetry Visuals: Radial Gauge on Left + Detail Progress Bars on Right
          Expanded(
            child: Row(
              children: [
                // Multi-Ring Radial Storage Gauge
                SizedBox(
                  width: 108,
                  height: 108,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(108, 108),
                        painter: _RadialStorageGaugePainter(),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '84%',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Utilized',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Departmental Capacity Breakdown Progress Rows
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStorageRow(
                        label: 'Warehouse A (Yarn)',
                        current: '42.5K',
                        total: '50K Kg',
                        ratio: 0.85,
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 10),
                      _buildStorageRow(
                        label: 'Warehouse B (Dyes & Chem)',
                        current: '28.2K',
                        total: '40K Kg',
                        ratio: 0.70,
                        color: const Color(0xFF059669),
                      ),
                      const SizedBox(height: 10),
                      _buildStorageRow(
                        label: 'Dispatch Docks (Active)',
                        current: '4',
                        total: '6 Bays',
                        ratio: 0.66,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Facility Environmental Health Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: const [
                Icon(Icons.verified_user_outlined,
                    size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Optimal preservation conditions for textile inventory',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageRow({
    required String label,
    required String current,
    required String total,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$current / $total',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _RadialStorageGaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background track ring 1 (outer)
    final bgPaint1 = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0;
    canvas.drawCircle(center, radius - 4, bgPaint1);

    // Active arc 1 (Outer - Warehouse A: 84%)
    final arcPaint1 = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi / 2,
      0.84 * 2 * math.pi,
      false,
      arcPaint1,
    );

    // Background track ring 2 (inner)
    final bgPaint2 = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius - 15, bgPaint2);

    // Active arc 2 (Inner - Warehouse B: 68%)
    final arcPaint2 = Paint()
      ..color = const Color(0xFF059669)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 15),
      -math.pi / 2,
      0.68 * 2 * math.pi,
      false,
      arcPaint2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// 6. QUICK MACROS CARD
// ============================================================================
class _QuickMacrosCard extends StatelessWidget {
  final List<_MacroData> macros;
  final VoidCallback onAdd;

  const _QuickMacrosCard({required this.macros, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 310,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Fast operational macros',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView(
              children: [
                ...macros.map((m) => _buildMacroTile(m)),
                const SizedBox(height: 6),
                // Add Shortcut Action
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          style: BorderStyle.solid),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_rounded,
                            size: 15, color: Color(0xFF4B5563)),
                        SizedBox(width: 4),
                        Text(
                          'Add Shortcut',
                          style: TextStyle(
                            color: Color(0xFF4B5563),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroTile(_MacroData m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Icon(m.icon, size: 16, color: AppColors.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              m.label,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 10, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
  }
}

// ============================================================================
// 7. CORPORATE ENTERPRISE LIVE TRANSACTIONS TABLE
// ============================================================================
class _CorporateTransactionsTable extends StatefulWidget {
  final List<TransactionRecord> transactions;
  const _CorporateTransactionsTable({required this.transactions});

  @override
  State<_CorporateTransactionsTable> createState() =>
      _CorporateTransactionsTableState();
}

class _CorporateTransactionsTableState
    extends State<_CorporateTransactionsTable> {
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  int _currentPage = 0;
  static const int _pageSize = 50;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.transactions.where((t) {
      final matchesSearch = _searchQuery.isEmpty ||
          t.transactionId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.materialDetail.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.department.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _statusFilter == 'ALL' ||
          t.status.toUpperCase() == _statusFilter.toUpperCase();

      return matchesSearch && matchesStatus;
    }).toList();

    final receivedCount = widget.transactions
        .where((t) => t.status.toUpperCase() == 'RECEIVED')
        .length;
    final transitCount = widget.transactions
        .where((t) => t.status.toUpperCase() == 'IN TRANSIT')
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Corporate Header & Toolbar ─────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              color: Colors.white,
              child: Row(
                children: [
                  // Title + Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Live Factory Transactions',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Realtime Indicator Capsule
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Live Stream',
                                    style: TextStyle(
                                      color: Color(0xFF065F46),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Verified raw material intakes, unit dispatches, and warehouse movement records',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Filter Segmented Buttons
                  _buildFilterTab('ALL', 'All (${widget.transactions.length})'),
                  const SizedBox(width: 5),
                  _buildFilterTab('RECEIVED', 'Received ($receivedCount)'),
                  const SizedBox(width: 5),
                  _buildFilterTab('IN TRANSIT', 'In Transit ($transitCount)'),
                ],
              ),
            ),

            // ── Search Bar Strip (Glassmorphism) ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC).withValues(alpha: 0.92),
                border: const Border(
                  top: BorderSide(color: Color(0xFFF1F5F9)),
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.85),
                                Colors.white.withValues(alpha: 0.45),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.8),
                                blurRadius: 2,
                                offset: const Offset(-1, -1),
                              ),
                            ],
                          ),
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search transaction, item...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                              ),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 15, color: Color(0xFF64748B)),
                              prefixIconConstraints:
                                  BoxConstraints(minWidth: 34),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 7),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.85),
                              Colors.white.withValues(alpha: 0.45),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.tune_rounded,
                                size: 13, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text(
                              'Columns',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Table Column Headers ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              color: const Color(0xFFF1F5F9),
              child: Row(
                children: const [
                  Expanded(
                      flex: 4,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _CorporateHeaderCell('TRANSACTION REF'),
                      )),
                  Expanded(
                      flex: 5,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _CorporateHeaderCell('MATERIAL SPECIFICATION'),
                      )),
                  Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _CorporateHeaderCell('DEPARTMENT'),
                      )),
                  Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _CorporateHeaderCell('NET QUANTITY'),
                      )),
                  Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: _CorporateHeaderCell('TOTAL INVOICE'),
                      )),
                  Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: _CorporateHeaderCell('STATUS'),
                      )),
                  SizedBox(width: 32, child: _CorporateHeaderCell('')),
                ],
              ),
            ),

            // ── Table Body Rows (Virtualized) ─────────────────────────────
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(Icons.inbox_outlined,
                          size: 32, color: Color(0xFF94A3B8)),
                      SizedBox(height: 6),
                      Text(
                        'No transactions match your search filter',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pagedItems(filtered).length,
                itemExtent: 38,
                itemBuilder: (context, index) {
                  final paged = _pagedItems(filtered);
                  return _HoverableTransactionRow(
                    transaction: paged[index],
                  );
                },
              ),

            // ── Table Footer with Real Pagination ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${_currentPage * _pageSize + 1}–${math.min((_currentPage + 1) * _pageSize, filtered.length)} of ${filtered.length} entries',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      _buildRealPaginationBtn(
                        Icons.chevron_left_rounded,
                        'Previous',
                        _currentPage > 0,
                        () => setState(() => _currentPage--),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${_currentPage + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildRealPaginationBtn(
                        Icons.chevron_right_rounded,
                        'Next',
                        (_currentPage + 1) * _pageSize < filtered.length,
                        () => setState(() => _currentPage++),
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
  }

  List<TransactionRecord> _pagedItems(List<TransactionRecord> filtered) {
    final start = _currentPage * _pageSize;
    final end = math.min(start + _pageSize, filtered.length);
    if (start >= filtered.length) return [];
    return filtered.sublist(start, end);
  }

  Widget _buildRealPaginationBtn(
      IconData icon, String tooltip, bool enabled, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: enabled ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: enabled ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String label) {
    final isSelected = _statusFilter == key;
    return InkWell(
      onTap: () => setState(() => _statusFilter = key),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ISOLATED HOVERABLE ROW — Prevents full-table rebuild on mouse hover
// ============================================================================
class _HoverableTransactionRow extends StatefulWidget {
  final TransactionRecord transaction;
  const _HoverableTransactionRow({required this.transaction});

  @override
  State<_HoverableTransactionRow> createState() =>
      _HoverableTransactionRowState();
}

class _HoverableTransactionRowState extends State<_HoverableTransactionRow> {
  bool _isHovered = false;

  static String _formatTxnDisplay(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('TXN-')) clean = clean.substring(4);
    final parts = clean.split('/');
    if (parts.length >= 2) {
      final prefix = parts[0].length > 5 ? parts[0].substring(0, 5) : parts[0];
      return '#$prefix/${parts[1]}';
    }
    if (clean.length > 11) return '#${clean.substring(0, 9)}..';
    return '#$clean';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final isReceived = t.status.toUpperCase() == 'RECEIVED';
    final cleanTxnDisplay = _formatTxnDisplay(t.transactionId);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // 1. Transaction Reference Pill Badge
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Tooltip(
                    message: 'Full Reference: ${t.transactionId}\nTap to copy',
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: t.transactionId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ${t.transactionId}'),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_outlined,
                                size: 11, color: Color(0xFF475569)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                cleanTxnDisplay,
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Material Specification
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 11, color: Color(0xFF475569)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.materialDetail,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Department Tag
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.department.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

            // 4. Net Quantity
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  t.quantity,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 5. Total Invoice Value
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  t.valueFormatted,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // 6. Corporate Status Capsule
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isReceived
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isReceived
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isReceived
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            t.status,
                            style: TextStyle(
                              color: isReceived
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 7. Actions Button
            SizedBox(
              width: 28,
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 14, color: Color(0xFF94A3B8)),
                onPressed: () {},
                tooltip: 'Entry details',
                splashRadius: 12,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CorporateHeaderCell extends StatelessWidget {
  final String text;
  const _CorporateHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ============================================================================
// DATA MODELS & DEFAULT SEEDS
// ============================================================================
class _MacroData {
  final IconData icon;
  final String label;
  const _MacroData({required this.icon, required this.label});
}

final List<_MacroData> _initialMacros = [
  const _MacroData(icon: Icons.tune_rounded, label: 'Stock Adjustment'),
  const _MacroData(icon: Icons.note_alt_outlined, label: 'Issue Note'),
  const _MacroData(icon: Icons.business_rounded, label: 'Vendor Master'),
  const _MacroData(icon: Icons.verified_rounded, label: 'Quality Check'),
];

final MetricsDto _defaultMetrics = MetricsDto(
  activeStocks: 677,
  avgLeadTime: 4.2,
  procurementTotal: 39837.52,
  optimizationScore: 98.2,
);

List<VelocityDataPoint> _getDefaultVelocity(String metricType) {
  final List<int> values = metricType == 'Profit & Loss'
      ? [45, 52, 38, 61, 55, 72, 68, 80, 74, 91, 85, 97]
      : metricType == 'Sales & Purchase'
          ? [120, 135, 110, 148, 155, 170, 162, 180, 175, 195, 188, 210]
          : metricType == 'Inventory Turnover'
              ? [3, 4, 5, 4, 6, 5, 7, 6, 8, 7, 9, 8]
              : [65, 72, 58, 85, 78, 92, 88, 105, 95, 112, 108, 125];

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  return List.generate(
    12,
    (i) => VelocityDataPoint(month: months[i], value: values[i]),
  );
}

final List<TransactionRecord> _defaultTransactions = [
  TransactionRecord(
    transactionId: 'TXN-Abhi/000004/27-20260819',
    materialDetail: '1 To 10 Baby Pants XXL-50×8',
    department: 'Regular',
    quantity: '11,940 Kg',
    value: 52536.0,
    status: 'RECEIVED',
  ),
  TransactionRecord(
    transactionId: 'TXN-Aary/000001/27-20260724',
    materialDetail: '1 To 10 Baby Pants S-75×6',
    department: 'Regular',
    quantity: '10 Kg',
    value: 200.0,
    status: 'RECEIVED',
  ),
  TransactionRecord(
    transactionId: 'TXN-ROWM/000001/27-20260724',
    materialDetail: '1 To 10 Baby Pants S-75×6',
    department: 'Regular',
    quantity: '0 Kg',
    value: 200.0,
    status: 'IN TRANSIT',
  ),
  TransactionRecord(
    transactionId: 'TXN-Aary/000002/27-20260724',
    materialDetail: '1 To 10 Baby Pants XXL-50×8',
    department: 'Regular',
    quantity: '10 Kg',
    value: 300.0,
    status: 'RECEIVED',
  ),
  TransactionRecord(
    transactionId: 'TXN-Aary/000003/27-20260724',
    materialDetail: '5 Ply Corrugated Box Ammy Adult Diaper L-10',
    department: 'Regular',
    quantity: '10 Kg',
    value: 400.0,
    status: 'RECEIVED',
  ),
  TransactionRecord(
    transactionId: 'TXN-JOBM/000001/27-20260724',
    materialDetail: '5 PLY CORRUGATED BOX MYLO XXL-48',
    department: 'Regular',
    quantity: '10 Kg',
    value: 400.0,
    status: 'RECEIVED',
  ),
  TransactionRecord(
    transactionId: 'TXN-ROWM/000179/26-20250731',
    materialDetail: 'Poly Bags Eldry Premium Adult Pants XXL-10',
    department: 'Regular',
    quantity: '16,000 Kg',
    value: 68370.0,
    status: 'RECEIVED',
  ),
];
