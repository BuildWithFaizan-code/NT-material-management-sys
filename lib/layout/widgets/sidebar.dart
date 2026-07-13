import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import '../../design/app_dimensions.dart';

class Sidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.sidebarWidth,
      color: AppColors.secondaryColor, // Set background color of sidebar to secondaryColor (#6D9773)
      child: Column(
        children: [
          _buildHeader(),
          const Spacer(flex: 2), // Vertical spacing between title and navigation pages
          _buildMenuItems(),
          const Spacer(flex: 3), // Vertical spacing between navigation pages and bottom footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(
        top: 24,
        left: AppDimensions.spacingMd,
        right: AppDimensions.spacingMd,
      ),
      alignment: Alignment.centerLeft,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MMS ERP',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Material Management',
            style: TextStyle(
              color: Color(0xFFE8F5E9), // Light mint text color
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingSm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_menuItems.length, (index) {
          final item = _menuItems[index];
          final selected = index == currentIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: _SidebarItem(
              icon: item.icon,
              label: item.label,
              selected: selected,
              onTap: () => onItemSelected(index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50), // Active green indicator dot
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Connected',
                      style: TextStyle(
                        color: Color(0xFFC7EBD0),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'MMS_SQL_GST.EXE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PROPERTIES',
                      style: TextStyle(
                        color: Color(0xFFC7EBD0),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.spacingMd,
            right: AppDimensions.spacingMd,
            bottom: AppDimensions.spacingMd,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              const Text(
                'System Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  const _MenuItem({required this.icon, required this.label});
}

const List<_MenuItem> _menuItems = [
  _MenuItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
  _MenuItem(icon: Icons.dns_rounded, label: 'Master'),
  _MenuItem(icon: Icons.receipt_long_rounded, label: 'Transaction'),
  _MenuItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
  _MenuItem(icon: Icons.inventory_2_rounded, label: 'Box Register'),
  _MenuItem(icon: Icons.handyman_rounded, label: 'Tools'),
  _MenuItem(icon: Icons.update_rounded, label: 'Live Updates'),
  _MenuItem(icon: Icons.download_rounded, label: 'Download'),
];

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFC7EBD0) // Soft light green capsule exactly matching 1st image
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20), // 20 border radius for high curves matching 1st image
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingMd,
              vertical: 8), // slightly smaller vertical padding
          child: Row(
            children: [
              Icon(icon,
                  color: selected
                      ? AppColors.primaryColor // Dark green icon for selected
                      : Colors.white, // White icon for unselected (to contrast with sage green background)
                  size: 18), // slightly smaller icon size
              const SizedBox(width: AppDimensions.spacingMd),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryColor // Dark green text for selected
                      : Colors.white, // White text for unselected (to contrast with sage green background)
                  fontSize: 13, // slightly smaller font size
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500, // Bold selected
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
