import 'package:flutter/material.dart';
import '../../design/app_dimensions.dart';
import 'modern_navbar_theme.dart';
import '../../services/auth_service.dart';

/// Collapsed vertical navigation rail matching the left bar in the reference image.
/// Features a stadium-pill shape, sparkle logo, white rounded active icon pill with shadow,
/// vertical line separator, and smooth interactions.
class ModernCollapsedRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onExpand;

  const ModernCollapsedRail({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sidebarCollapsedWidth,
      decoration: BoxDecoration(
        color: ModernNavbarTheme.railBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: ModernNavbarTheme.cardBorder,
          width: 1,
        ),
        boxShadow: ModernNavbarTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Sparkle Button (click expands full menu)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onExpand,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 13,
                      height: 13,
                      child: CustomPaint(
                        painter: FourPointSparklePainter(
                          color: ModernNavbarTheme.sparkle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Navigation icons list
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 0: Dashboard (Home)
                      _RailIconButton(
                        icon: Icons.home_outlined,
                        tooltip: 'Dashboard',
                        isSelected: currentIndex == 0,
                        onTap: () => onItemSelected(0),
                      ),
                      const SizedBox(height: 8),

                      // 1: Master
                      _RailIconButton(
                        icon: Icons.inventory_2_outlined,
                        tooltip: 'Master Register',
                        isSelected: currentIndex == 1,
                        onTap: () => onItemSelected(1),
                      ),
                      const SizedBox(height: 8),

                      // 2: Transaction
                      _RailIconButton(
                        icon: Icons.receipt_long_outlined,
                        tooltip: 'Transaction',
                        isSelected: currentIndex == 2,
                        onTap: () => onItemSelected(2),
                      ),
                      const SizedBox(height: 8),

                      // 3: Reports
                      _RailIconButton(
                        icon: Icons.bar_chart_rounded,
                        tooltip: 'Reports',
                        isSelected: currentIndex == 3,
                        onTap: () => onItemSelected(3),
                      ),
                      const SizedBox(height: 10),

                      // Vertical Tree Line Separator from reference image
                      Container(
                        width: 1.2,
                        height: 36,
                        decoration: BoxDecoration(
                          color: ModernNavbarTheme.connectorLine,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 4: Box Register
                      _RailIconButton(
                        icon: Icons.all_inbox_outlined,
                        tooltip: 'Box Register',
                        isSelected: currentIndex == 4,
                        onTap: () => onItemSelected(4),
                      ),
                      const SizedBox(height: 8),

                      // 5: Tools
                      _RailIconButton(
                        icon: Icons.handyman_outlined,
                        tooltip: 'Tools',
                        isSelected: currentIndex == 5,
                        onTap: () => onItemSelected(5),
                      ),
                      const SizedBox(height: 8),

                      // 6: Live Updates
                      _RailIconButton(
                        icon: Icons.update_rounded,
                        tooltip: 'Live Updates',
                        isSelected: currentIndex == 6,
                        onTap: () => onItemSelected(6),
                      ),
                      const SizedBox(height: 8),

                      // 7: Download
                      _RailIconButton(
                        icon: Icons.download_outlined,
                        tooltip: 'Download',
                        isSelected: currentIndex == 7,
                        onTap: () => onItemSelected(7),
                      ),

                      // 8: User Management (Admin Only)
                      if (AuthService.instance.currentUser?.isAdmin ?? false) ...[
                        const SizedBox(height: 8),
                        _RailIconButton(
                          icon: Icons.manage_accounts_outlined,
                          tooltip: 'User Management',
                          isSelected: currentIndex == 8,
                          onTap: () => onItemSelected(8),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Expand Chevron Pill
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onExpand,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: ModernNavbarTheme.activeSubPillShadow,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: ModernNavbarTheme.inactiveFg,
                        size: 17,
                      ),
                    ),
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

class _RailIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  const _RailIconButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RailIconButton> createState() => _RailIconButtonState();
}

class _RailIconButtonState extends State<_RailIconButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      verticalOffset: 0,
      margin: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: ModernNavbarTheme.activePillBg,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // Active pill: pitch black with soft dark shadow
                  color: isSelected
                      ? ModernNavbarTheme.activePillBg
                      : (_isHovering ? ModernNavbarTheme.hoverBg : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected ? ModernNavbarTheme.activeRailPillShadow : null,
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 17,
                    color: isSelected
                        ? ModernNavbarTheme.activePillFg
                        : ModernNavbarTheme.inactiveIcon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
