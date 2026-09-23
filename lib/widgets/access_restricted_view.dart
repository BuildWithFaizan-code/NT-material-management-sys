import 'package:flutter/material.dart';

class AccessRestrictedView extends StatelessWidget {
  final String moduleName;
  final VoidCallback? onReturnHome;

  const AccessRestrictedView({
    super.key,
    required this.moduleName,
    this.onReturnHome,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFCA5A5),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_person_outlined,
                  size: 32,
                  color: Color(0xFFEF4444),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'You do not have permission to access "$moduleName". Your account role does not have authorization to view this module.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 28),
            if (onReturnHome != null)
              ElevatedButton.icon(
                onPressed: onReturnHome,
                icon: const Icon(Icons.dashboard_rounded, size: 16),
                label: const Text('Return to Dashboard'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
