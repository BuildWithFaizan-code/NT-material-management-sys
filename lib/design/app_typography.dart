import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get textTheme {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.titleSmall?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        color: AppColors.neutralDark,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: AppColors.neutralDark.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
      labelLarge: base.labelLarge?.copyWith(
        color: AppColors.neutralDark.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: AppColors.neutralDark.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
