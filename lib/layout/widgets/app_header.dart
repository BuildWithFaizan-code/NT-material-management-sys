import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import '../../design/app_dimensions.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const AppHeader({
    super.key,
    this.title = 'Dashboard',
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge =
        MediaQuery.of(context).size.width > AppDimensions.mobileBreakpoint;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
      decoration: const BoxDecoration(
        color: AppColors.surfaceColor,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (!isLarge)
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.neutralDark),
              onPressed: onMenuTap,
              tooltip: 'Open navigation',
            ),
          if (!isLarge) const SizedBox(width: AppDimensions.spacingSm),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.neutralDark,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (isLarge) ...[
            const SizedBox(width: 32),
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  decoration: InputDecoration(
                    hintText:
                        'Search transaction, item, report... (Ctrl + K)',
                    hintStyle: TextStyle(
                      color: AppColors.neutralDark.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 40),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.neutralDark.withValues(alpha: 0.4),
                        size: 20),
                    filled: true,
                    fillColor: AppColors.backgroundColor,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppColors.secondaryColor, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const Spacer(),
          if (isLarge) ...[
            _TextAction(label: 'Reports'),
            const SizedBox(width: AppDimensions.spacingMd),
            _VerticalDivider(),
            const SizedBox(width: AppDimensions.spacingMd),
            _TextAction(label: 'Inventory'),
            const SizedBox(width: AppDimensions.spacingMd),
            _VerticalDivider(),
            const SizedBox(width: AppDimensions.spacingMd),
            _TextAction(label: 'Settings'),
            const SizedBox(width: AppDimensions.spacingLg),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.neutralDark),
                onPressed: () {},
                tooltip: 'Notifications',
              ),
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53E3E),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.secondaryColor,
            child: Text(
              'A',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          if (isLarge)
            const Text(
              'Admin User',
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  const _TextAction({required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.neutralDark,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: AppColors.divider,
    );
  }
}
