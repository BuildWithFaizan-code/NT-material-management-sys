import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';

/// BOM-style 3-step progress bar with step numbers, subtexts, connectors,
/// active glowing rings, and completed checkmarks matching Image 2 & BOM spec.
class SoStepProgressBar extends StatelessWidget {
  final int currentStep; // 1, 2, 3
  final ValueChanged<int> onStepSelected;

  const SoStepProgressBar({
    super.key,
    required this.currentStep,
    required this.onStepSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // STEP 1: HEADER & PARTY
          _buildStepNode(
            stepNumber: 1,
            title: '1. Header & Party',
            subtitle: 'Party, Mode & Terms',
            isActive: currentStep == 1,
            isCompleted: currentStep > 1,
            onTap: () => onStepSelected(1),
          ),

          _buildConnectorLine(isActive: currentStep > 1),

          // STEP 2: LINE ITEMS GRID
          _buildStepNode(
            stepNumber: 2,
            title: '2. Line Items Grid',
            subtitle: 'Catalog & Add Rows',
            isActive: currentStep == 2,
            isCompleted: currentStep > 2,
            onTap: () => onStepSelected(2),
          ),

          _buildConnectorLine(isActive: currentStep > 2),

          // STEP 3: TOTALS & CALCULATION
          _buildStepNode(
            stepNumber: 3,
            title: '3. Totals & Calculation',
            subtitle: 'Duties, Charges & Save',
            isActive: currentStep == 3,
            isCompleted: false,
            onTap: () => onStepSelected(3),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectorLine({required bool isActive}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 2.5,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0C3B2E) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepNode({
    required int stepNumber,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isCompleted,
    required VoidCallback onTap,
  }) {
    final Color primary = const Color(0xFF0C3B2E);
    final Color accent = const Color(0xFF10B981);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle Node (26x26)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? accent
                    : (isActive ? primary : Colors.white),
                border: Border.all(
                  color: isCompleted
                      ? accent
                      : (isActive ? primary : const Color(0xFFCBD5E1)),
                  width: 2.0,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                    : Text(
                        stepNumber.toString(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isActive ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: isActive ? primary : const Color(0xFF1E293B),
                    letterSpacing: -0.1,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isActive ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
