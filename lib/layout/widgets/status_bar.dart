import 'package:flutter/material.dart';
import '../../design/app_colors.dart';
import '../../design/app_dimensions.dart';
import '../../state/status_state.dart';

class StatusBar extends StatelessWidget {
  final StatusState status;

  const StatusBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isLarge = MediaQuery.of(context).size.width > AppDimensions.mobileBreakpoint;

    final cells = [
      // Cell 1: MEERA COTTON & SYNTHETICS (Dark green pill with green dot)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF05211B), // Very dark green/black
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2E7D32), // Green indicator dot
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'MEERA COTTON & SYNTHETICS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      
      // Cell 2: ADMIN (Soft light green pill)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFC7EBD0), // Soft green
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'ADMIN',
          style: TextStyle(
            color: AppColors.primaryColor,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Cell 3: SQL: MCMSL26_SQL (Soft light blue-gray pill)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8), // Soft blue-gray
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'SQL: MCMSL26_SQL',
          style: TextStyle(
            color: AppColors.neutralDark,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // Cell 4: FY 2026-2027 (Soft light blue-gray pill)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'FY 2026-2027',
          style: TextStyle(
            color: AppColors.neutralDark,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ];

    final statusAndPolicy = [
      // Cell 5: SYSTEM STATUS (Soft green pill with checkmark status icon)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFC7EBD0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.primaryColor,
              size: 12,
            ),
            SizedBox(width: 6),
            Text(
              'SYSTEM STATUS',
              style: TextStyle(
                color: AppColors.primaryColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      
      // Cell 6: PRIVACY POLICY (Plain text link)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: InkWell(
          onTap: () {},
          child: const Text(
            'PRIVACY POLICY',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    ];

    if (isLarge) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
          vertical: 8,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFDFE6ED), // Sticky footer background color
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Row(
            children: [
              ...cells.expand((cell) => [cell, const SizedBox(width: 8)]).toList()
                ..removeLast(),
              const Spacer(),
              statusAndPolicy[0],
              const SizedBox(width: 16),
              statusAndPolicy[1],
            ],
          ),
        ),
      );
    }

    // On mobile: Wrap cells to prevent pixel overflow flags on compact screens
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFDFE6ED),
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Wrap(
          spacing: 8.0,
          runSpacing: 6.0,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...cells,
            ...statusAndPolicy,
          ],
        ),
      ),
    );
  }
}

class StatusBarText extends StatelessWidget {
  final StatusState status;

  const StatusBarText({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingXs,
      ),
      child: Text(
        'Company: ${status.company} | User: ${status.user} | Database: ${status.database} | FY: ${status.fiscalYear} | System Status: Connected',
        style: const TextStyle(
          color: AppColors.neutralDark,
          fontSize: 10,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
