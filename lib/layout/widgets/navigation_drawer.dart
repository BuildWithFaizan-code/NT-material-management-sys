import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import '../../design/app_dimensions.dart';

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
      child: Container(
        color: AppColors.secondaryColor, // Drawer background set to secondaryColor (#6D9773)
        child: Column(
          children: [
            _buildDrawerHeader(),
            const SizedBox(height: AppDimensions.spacingMd),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingSm,
                    vertical: AppDimensions.spacingSm),
                itemCount: _menuItems.length,
                separatorBuilder: (_, index) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
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
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: AppDimensions.spacingSm),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.15), width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          const Expanded(
            child: Text(
              'Connected: MMS_SQL_GST.EXE',
              style: TextStyle(
                color: Color(0xFFE8F5E9),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
  _MenuItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
  _MenuItem(icon: Icons.dns_rounded, label: 'Master'),
  _MenuItem(icon: Icons.receipt_long_rounded, label: 'Transaction'),
  _MenuItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
  _MenuItem(icon: Icons.inventory_2_rounded, label: 'Box Register'),
  _MenuItem(icon: Icons.handyman_rounded, label: 'Tools'),
  _MenuItem(icon: Icons.update_rounded, label: 'Live Updates'),
  _MenuItem(icon: Icons.download_rounded, label: 'Download'),
];

class _DrawerItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFFC7EBD0) // Soft light green capsule matching 1st image
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: selected
                ? AppColors.primaryColor
                : Colors.white, // White for unselected items
            size: 18), // smaller icon size
        title: Text(
          label,
          style: TextStyle(
            color: selected
                ? AppColors.primaryColor
                : Colors.white, // White for unselected items
            fontSize: 13, // smaller font size
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
