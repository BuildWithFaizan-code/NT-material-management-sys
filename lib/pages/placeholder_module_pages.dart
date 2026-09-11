import 'package:flutter/material.dart';
import '../design/app_colors.dart';

// ============================================================================
// SHARED MODULE CONTAINER TEMPLATE
// ============================================================================
class _ModuleScaffold extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final List<Widget> children;

  const _ModuleScaffold({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(icon, color: accentColor, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 13),
                            SizedBox(width: 5),
                            Text(
                              'MODULE ACTIVE',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
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

class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
}

// ============================================================================
// 2. TRANSACTIONS PAGE
// ============================================================================
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ModuleScaffold(
      icon: Icons.receipt_long_outlined,
      title: 'Transactions Register',
      subtitle: 'Audit, monitor, and verify real-time ERP transactions & entries',
      accentColor: const Color(0xFF3B82F6),
      children: [
        const Row(
          children: [
            _MetricBadge(
              label: 'TODAY TRANSACTIONS',
              value: '1,428',
              icon: Icons.receipt_outlined,
              color: Color(0xFF3B82F6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'PENDING APPROVAL',
              value: '14',
              icon: Icons.hourglass_empty_rounded,
              color: Color(0xFFF59E0B),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'COMPLETED ENTRIES',
              value: '99.2%',
              icon: Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTransactionTable(),
      ],
    );
  }

  Widget _buildTransactionTable() {
    final rows = [
      ('TXN-8849', 'Raw Material Issue', 'Cotton Yarn 40s', '₹1,24,000', 'Approved', Color(0xFF10B981)),
      ('TXN-8848', 'Purchase Order', 'Dye Chemical Pigment', '₹48,500', 'Processing', Color(0xFFF59E0B)),
      ('TXN-8847', 'Stock Transfer', 'Warehouse A -> Mill B', '₹3,12,000', 'Approved', Color(0xFF10B981)),
      ('TXN-8846', 'Gate Pass Entry', 'Delivery Vehicle MH-12', '₹0', 'Verified', Color(0xFF3B82F6)),
      ('TXN-8845', 'Scrap Audit', 'Damaged Fabric Rolls', '₹14,200', 'Approved', Color(0xFF10B981)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.withValues(alpha: 0.15),
        ),
        itemBuilder: (context, i) {
          final r = rows[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                Text(
                  r.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Text(
                    r.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    r.$3,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                Text(
                  r.$4,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: r.$6.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r.$5,
                    style: TextStyle(
                      color: r.$6,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// 3. REPORTS PAGE
// ============================================================================
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _ModuleScaffold(
      icon: Icons.bar_chart_rounded,
      title: 'Analytics & Reports',
      subtitle: 'Operational insights, material velocity, and financial accounting reports',
      accentColor: const Color(0xFF8B5CF6),
      children: [
        const Row(
          children: [
            _MetricBadge(
              label: 'MONTHLY TURNOVER',
              value: '₹1.84 Cr',
              icon: Icons.trending_up_rounded,
              color: Color(0xFF8B5CF6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'ACTIVE BATCHES',
              value: '38 Batches',
              icon: Icons.layers_outlined,
              color: Color(0xFF3B82F6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'EFFICIENCY SCORE',
              value: '94.8%',
              icon: Icons.speed_rounded,
              color: Color(0xFF10B981),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Reporting Streams',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _reportTile('Daily Stock Ledger', Icons.table_chart_outlined),
                  _reportTile('Material Consumption Trend', Icons.show_chart_rounded),
                  _reportTile('Vendor Performance Index', Icons.pie_chart_outline_rounded),
                  _reportTile('Cost Allocation by Project', Icons.donut_large_rounded),
                  _reportTile('Tax & GST Summary', Icons.account_balance_outlined),
                  _reportTile('Machine Downtime Log', Icons.build_circle_outlined),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reportTile(String name, IconData icon) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B5CF6), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. BOX REGISTER PAGE
// ============================================================================
class BoxRegisterPage extends StatelessWidget {
  const BoxRegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ModuleScaffold(
      icon: Icons.all_inbox_outlined,
      title: 'Box Register Management',
      subtitle: 'Inventory storage carton tracking, barcode tagging, and pallet locations',
      accentColor: Color(0xFFEC4899),
      children: [
        Row(
          children: [
            _MetricBadge(
              label: 'TOTAL BOXES REGISTERED',
              value: '18,420',
              icon: Icons.inbox_rounded,
              color: Color(0xFFEC4899),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'STORED IN WAREHOUSE',
              value: '14,210',
              icon: Icons.warehouse_rounded,
              color: Color(0xFF3B82F6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'DISPATCH READY',
              value: '4,210',
              icon: Icons.local_shipping_outlined,
              color: Color(0xFF10B981),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 5. TOOLS PAGE
// ============================================================================
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ModuleScaffold(
      icon: Icons.handyman_outlined,
      title: 'MMS System Utilities & Tools',
      subtitle: 'Database re-indexing, cache clear, integrity checks, and configuration',
      accentColor: Color(0xFFF97316),
      children: [
        Row(
          children: [
            _MetricBadge(
              label: 'SQL SERVER STATUS',
              value: 'HEALTHY',
              icon: Icons.check_circle_outline_rounded,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'LAST BACKUP',
              value: 'Today 04:00 AM',
              icon: Icons.backup_outlined,
              color: Color(0xFF3B82F6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'ACTIVE SESSIONS',
              value: '12 Users',
              icon: Icons.people_outline_rounded,
              color: Color(0xFFF97316),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 6. LIVE UPDATES PAGE
// ============================================================================
class LiveUpdatesPage extends StatelessWidget {
  const LiveUpdatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ModuleScaffold(
      icon: Icons.update_rounded,
      title: 'Live System Activity Stream',
      subtitle: 'Real-time sync events, database transaction logs, and operator triggers',
      accentColor: Color(0xFF06B6D4),
      children: [
        Row(
          children: [
            _MetricBadge(
              label: 'SERVER HEARTBEAT',
              value: 'ONLINE (24ms)',
              icon: Icons.wifi_tethering_rounded,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'EVENTS PER MINUTE',
              value: '240 ev/m',
              icon: Icons.bolt_rounded,
              color: Color(0xFF06B6D4),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'PACKET LOSS',
              value: '0.00%',
              icon: Icons.shield_outlined,
              color: Color(0xFF10B981),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 7. DOWNLOAD PAGE
// ============================================================================
class DownloadPage extends StatelessWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ModuleScaffold(
      icon: Icons.download_outlined,
      title: 'Download & Archive Center',
      subtitle: 'Exported Excel sheets, audited PDF ledgers, and database dump files',
      accentColor: Color(0xFF10B981),
      children: [
        Row(
          children: [
            _MetricBadge(
              label: 'EXPORTS READY',
              value: '8 Documents',
              icon: Icons.file_download_outlined,
              color: Color(0xFF10B981),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'ARCHIVE RETENTION',
              value: '90 Days',
              icon: Icons.inventory_2_outlined,
              color: Color(0xFF3B82F6),
            ),
            SizedBox(width: 12),
            _MetricBadge(
              label: 'COMPRESSION FORMAT',
              value: 'ZIP / PDF / XLSX',
              icon: Icons.folder_zip_outlined,
              color: Color(0xFF6B7280),
            ),
          ],
        ),
      ],
    );
  }
}
