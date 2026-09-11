import 'package:flutter/material.dart';

class ModernNavbarTheme {
  ModernNavbarTheme._();

  // Background surfaces
  static const Color cardBg = Color(0xFFF3F4F6); // Soft off-white / light slate surface
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color railBg = Color(0xFFF3F4F6); // Collapsed rail surface
  
  // Active pill (Black / Charcoal)
  static const Color activePillBg = Color(0xFF111827); // Pitch charcoal / black
  static const Color activePillFg = Color(0xFFFFFFFF); // Pure white
  
  // Active sub-item capsule (Elevated White)
  static const Color activeSubPillBg = Color(0xFFFFFFFF); // Pure white capsule
  static const Color activeSubPillFg = Color(0xFF111827); // Dark slate text & icon
  
  // Inactive / Muted
  static const Color inactiveFg = Color(0xFF64748B); // Slate-500
  static const Color inactiveIcon = Color(0xFF64748B);
  static const Color hoverBg = Color(0xFFE5E7EB); // Subtle hover fill
  
  // Tree connector line
  static const Color connectorLine = Color(0xFFCBD5E1); // Slate-300
  
  // Sparkle / Star accent
  static const Color sparkle = Color(0xFF111827);
  
  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 28,
          spreadRadius: 0,
          offset: const Offset(4, 12),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(1, 3),
        ),
      ];

  static List<BoxShadow> get activeSubPillShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get activeRailIconShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          spreadRadius: 0,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get activeRailPillShadow => [
        BoxShadow(
          color: const Color(0xFF111827).withValues(alpha: 0.28),
          blurRadius: 8,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      ];
}

/// Custom 4-pointed sparkle icon painter matching reference image top logo
class FourPointSparklePainter extends CustomPainter {
  final Color color;

  const FourPointSparklePainter({this.color = const Color(0xFF111827)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final path = Path()
      ..moveTo(cx, 0)
      ..quadraticBezierTo(cx, cy, w, cy)
      ..quadraticBezierTo(cx, cy, cx, h)
      ..quadraticBezierTo(cx, cy, 0, cy)
      ..quadraticBezierTo(cx, cy, cx, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant FourPointSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}
