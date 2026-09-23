import 'package:flutter/material.dart';
import '../../design/app_dimensions.dart';
import 'modern_navbar_theme.dart';
import '../../services/auth_service.dart';

class NavigationDrawerWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const NavigationDrawerWidget({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: AppDimensions.drawerWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ModernNavbarTheme.cardBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: ModernNavbarTheme.cardBorder,
              width: 1,
            ),
            boxShadow: ModernNavbarTheme.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Column(
              children: [
                _buildDrawerHeader(context),
                const SizedBox(height: 6),
                Builder(
                  builder: (context) {
                    final bool isAdmin = AuthService.instance.currentUser?.isAdmin ?? false;
                    final items = [
                      ..._menuItems,
                      if (isAdmin)
                        const _MenuItem(icon: Icons.manage_accounts_outlined, label: 'User Management'),
                    ];
                    return Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        itemCount: items.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 3),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final selected = index == currentIndex;
                          return _DrawerItem(
                            icon: item.icon,
                            label: item.label,
                            selected: selected,
                            onTap: () {
                              onItemSelected(index);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    );
                  },
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 20, 14, 10),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(
              painter: const FourPointSparklePainter(color: ModernNavbarTheme.sparkle),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Menu',
            style: TextStyle(
              color: ModernNavbarTheme.sparkle,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              color: ModernNavbarTheme.inactiveFg,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ModernNavbarTheme.cardBorder,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Connected: MMS_SQL_GST.EXE',
                style: TextStyle(
                  color: ModernNavbarTheme.inactiveFg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});
}

const List<_MenuItem> _menuItems = [
  _MenuItem(icon: Icons.home_outlined, label: 'Dashboard'),
  _MenuItem(icon: Icons.inventory_2_outlined, label: 'Master'),
  _MenuItem(icon: Icons.receipt_long_outlined, label: 'Transaction'),
  _MenuItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
  _MenuItem(icon: Icons.all_inbox_outlined, label: 'Box Register'),
  _MenuItem(icon: Icons.handyman_outlined, label: 'Tools'),
  _MenuItem(icon: Icons.update_rounded, label: 'Live Updates'),
  _MenuItem(icon: Icons.download_outlined, label: 'Download'),
];

class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? ModernNavbarTheme.activePillBg
                : (_hover ? ModernNavbarTheme.hoverBg : Colors.transparent),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: isSelected
                    ? ModernNavbarTheme.activePillFg
                    : ModernNavbarTheme.inactiveIcon,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: isSelected
                      ? ModernNavbarTheme.activePillFg
                      : ModernNavbarTheme.inactiveFg,
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
