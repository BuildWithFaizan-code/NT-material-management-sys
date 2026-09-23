import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../design/app_dimensions.dart';
import '../../services/auth_service.dart';
import '../../pages/mfa_setup_dialog.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final bool isNavbarOpen;

  const AppHeader({
    super.key,
    this.title = 'Dashboard',
    this.onMenuTap,
    this.isNavbarOpen = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge =
        MediaQuery.of(context).size.width > AppDimensions.mobileBreakpoint;

    return Padding(
      // Symmetrical horizontal and vertical padding for the header pill
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: const Color(0xFF64748B).withValues(alpha: 0.04),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.9),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (!isLarge && onMenuTap != null) ...[
                IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF1E293B),
                    size: 22,
                  ),
                  onPressed: onMenuTap,
                  tooltip: 'Open Menu',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                const SizedBox(width: 8),
              ],

              // ── Page Title ────────────────────────────────────────────────
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),

              if (isLarge) ...[
                const SizedBox(width: 16),
                // ── Glassmorphism Header Search Bar ─────────────────────────
                Expanded(child: _HeaderGlassSearchBar()),
                const SizedBox(width: 12),

                // ── Refactored Functional Action Buttons ────────────────────
                // 1. Quick New Entry Button (+ Action)
                _QuickActionEntryBtn(),
                const SizedBox(width: 6),

                // 2. Analytics Snapshot Pill
                _HeaderActionPill(
                  label: 'Analytics',
                  icon: Icons.insights_rounded,
                  tooltip: 'Factory Analytics Snapshot',
                  onTap: () => _showAnalyticsModal(context),
                ),
                const SizedBox(width: 6),

                // 3. Quick System Preferences Pill
                _HeaderActionPill(
                  label: 'Preferences',
                  icon: Icons.tune_rounded,
                  tooltip: 'System Preferences & Tools',
                  onTap: () => _showPreferencesModal(context),
                ),
                const SizedBox(width: 10),
              ] else ...[
                const Spacer(),
              ],

              // ── Interactive Notification Bell ──────────────────────────────
              const _InteractiveNotificationBell(count: 3),
              const SizedBox(width: 10),

              // ── Animative Avatar with Written "Admin" ───────────────────────
              _AnimativeAdminProfile(showLabel: isLarge),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalyticsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.insights_rounded,
                            size: 20, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Factory Analytics Snapshot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Live factory operational indicators synced across active warehouses.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _buildMetricTile('Daily Throughput', '8,420 m', '+14.2%', true),
                  const SizedBox(width: 12),
                  _buildMetricTile('Sync Latency', '18 ms', 'Optimal', true),
                  const SizedBox(width: 12),
                  _buildMetricTile('Pending Issues', '3 entries', '-2', false),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Overview',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      String label, String value, String change, bool isPositive) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              change,
              style: TextStyle(
                color: isPositive
                    ? const Color(0xFF10B981)
                    : const Color(0xFF64748B),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreferencesModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'System Preferences',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildPrefItem(
                  Icons.store_rounded, 'Active Warehouse', 'Warehouse A - Main Hub'),
              _buildPrefItem(Icons.currency_rupee_rounded, 'Default Currency',
                  'INR (₹ Indian Rupee)'),
              _buildPrefItem(Icons.sync_rounded, 'Auto Telemetry Refresh',
                  'Every 30 Seconds (Enabled)'),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Save & Apply',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrefItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B))),
                Text(value,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}

// ============================================================================
// GLASSMORPHISM HEADER SEARCH BAR
// ============================================================================
class _HeaderGlassSearchBar extends StatefulWidget {
  @override
  State<_HeaderGlassSearchBar> createState() => _HeaderGlassSearchBarState();
}

class _HeaderGlassSearchBarState extends State<_HeaderGlassSearchBar> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF8FAFC).withValues(alpha: 0.85),
                const Color(0xFFF1F5F9).withValues(alpha: 0.55),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF0F172A).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.7),
                blurRadius: 1,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(
                Icons.search_rounded,
                size: 15,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Focus(
                  onFocusChange: (focus) => setState(() => _isFocused = focus),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search transactions, materials, SKUs...',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                  onPressed: () => setState(() => _ctrl.clear()),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              // Shortcut Pill Badge (Ctrl+K)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Ctrl K',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION BUTTON (+ New Entry)
// ============================================================================
class _QuickActionEntryBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Quick Actions',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 6,
      onSelected: (value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action: $value initiated'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      itemBuilder: (context) => [
        _buildPopupItem(
            'inward', 'New Material Inward', Icons.add_shopping_cart_rounded),
        _buildPopupItem('issue', 'Generate Issue Note', Icons.receipt_long_rounded),
        _buildPopupItem('transfer', 'Warehouse Stock Transfer', Icons.swap_horiz_rounded),
        const PopupMenuDivider(),
        _buildPopupItem('export', 'Export Factory Ledger', Icons.file_download_outlined),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'New Entry',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
      String value, String label, IconData icon) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF475569)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER ACTION PILL
// ============================================================================
class _HeaderActionPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderActionPill({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderActionPill> createState() => _HeaderActionPillState();
}

class _HeaderActionPillState extends State<_HeaderActionPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _isHovered
                  ? const Color(0xFFF1F5F9)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFFCBD5E1)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: _isHovered
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _isHovered
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF475569),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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

// ============================================================================
// INTERACTIVE NOTIFICATION BELL WITH POPUP
// ============================================================================
class _InteractiveNotificationBell extends StatefulWidget {
  final int count;
  const _InteractiveNotificationBell({required this.count});

  @override
  State<_InteractiveNotificationBell> createState() =>
      _InteractiveNotificationBellState();
}

class _InteractiveNotificationBellState
    extends State<_InteractiveNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _tiltCtrl;
  late Animation<double> _tiltAnim;

  @override
  void initState() {
    super.initState();
    _tiltCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _tiltAnim = Tween<double>(begin: 0, end: 0.12).animate(
      CurvedAnimation(parent: _tiltCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _tiltCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Factory Alerts (${widget.count})',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      child: MouseRegion(
        onEnter: (_) => _tiltCtrl.forward(),
        onExit: (_) => _tiltCtrl.reverse(),
        child: AnimatedBuilder(
          animation: _tiltAnim,
          builder: (context, child) {
            return Transform.rotate(
              angle: _tiltAnim.value,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF334155),
                      size: 17,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${widget.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Live Notifications',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                'Mark read',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        _buildAlertItem(
          'Stock Warning',
          'Cotton Yarn 40s below safety reserve',
          'Just now',
          const Color(0xFFEF4444),
          Icons.warning_amber_rounded,
        ),
        _buildAlertItem(
          'Inward Verified',
          'GRN-00018 approved by QA Team',
          '14m ago',
          const Color(0xFF10B981),
          Icons.check_circle_outline_rounded,
        ),
        _buildAlertItem(
          'System Sync',
          'Cloud database synced with 0 errors',
          '1h ago',
          const Color(0xFF3B82F6),
          Icons.cloud_done_outlined,
        ),
      ],
    );
  }

  PopupMenuItem<int> _buildAlertItem(String title, String desc, String time,
      Color indicatorColor, IconData icon) {
    return PopupMenuItem<int>(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: indicatorColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: indicatorColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            time,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATIVE AVATAR WITH WRITTEN "ADMIN"
// ============================================================================
class _AnimativeAdminProfile extends StatefulWidget {
  final bool showLabel;
  const _AnimativeAdminProfile({required this.showLabel});

  @override
  State<_AnimativeAdminProfile> createState() => _AnimativeAdminProfileState();
}

class _AnimativeAdminProfileState extends State<_AnimativeAdminProfile>
    with TickerProviderStateMixin {
  late AnimationController _auraCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    // 1. Aura Pulse Animation
    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _auraCtrl, curve: Curves.easeInOut),
    );

    // 2. Slow Ambient Gradient Rotation
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Admin Account & System Roles',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      onSelected: (val) async {
        if (val == 'logout') {
          await AuthService.instance.logout();
        } else if (val == 'mfa') {
          showDialog(
            context: context,
            builder: (_) => const MfaSetupDialog(),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$val selected'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      itemBuilder: (context) {
        final user = AuthService.instance.currentUser;
        final displayName = user?.username.isNotEmpty == true ? user!.username : 'Admin User';
        final displayEmail = user?.email.isNotEmpty == true ? user!.email : 'admin@newtechmms.com';
        final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A';

        return [
          // Profile Header in Dropdown
          PopupMenuItem(
            enabled: false,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF334155)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      displayEmail,
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          _buildProfileMenuItem('mfa', 'Two-Factor Auth (MFA)', Icons.security_rounded),
          _buildProfileMenuItem('profile', 'Account Settings', Icons.person_outline_rounded),
          _buildProfileMenuItem('roles', 'Role & Access Control', Icons.admin_panel_settings_outlined),
          _buildProfileMenuItem('audit', 'System Audit Trail', Icons.history_rounded),
          const PopupMenuDivider(),
          _buildProfileMenuItem('logout', 'Sign Out', Icons.logout_rounded, isDestructive: true),
        ];
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated Avatar Ring with Continuous Glow & Rotation ─────────
              AnimatedBuilder(
                animation: Listenable.merge([_glowAnim, _rotateCtrl]),
                builder: (context, child) {
                  return Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: const [
                          Color(0xFF10B981), // Emerald
                          Color(0xFF06B6D4), // Cyan
                          Color(0xFF3B82F6), // Blue
                          Color(0xFF8B5CF6), // Violet
                          Color(0xFF10B981), // Loop back
                        ],
                        transform:
                            GradientRotation(_rotateCtrl.value * 2 * math.pi),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.3 * _glowAnim.value),
                          blurRadius: 8 * _glowAnim.value,
                          spreadRadius: 1 * _glowAnim.value,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: Stack(
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF0F172A),
                                      Color(0xFF1E293B),
                                    ],
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              // Online Green Status Dot
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Written "Admin" Badge & Profile Name ───────────────────────
              if (widget.showLabel) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Admin User',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1.5),
                    // Written "ADMIN" corporate capsule badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildProfileMenuItem(
      String value, String title, IconData icon,
      {bool isDestructive = false}) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDestructive
                ? const Color(0xFFEF4444)
                : const Color(0xFF475569),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDestructive
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
