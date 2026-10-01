import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ثيم التطبيق الفاتح والداكن — خط Tajawal العربي + Material 3.
abstract final class AppTheme {
  static const String fontFamily = 'Tajawal';

  // -------------------------------------------------------------------------
  // السمة الفاتحة (الافتراضية)
  // -------------------------------------------------------------------------
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      error: AppColors.danger,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    return _base(
      scheme,
      brightness: Brightness.light,
      scaffoldBg: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.divider,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
    );
  }

  // -------------------------------------------------------------------------
  // السمة الداكنة
  // -------------------------------------------------------------------------
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: const Color(0xFF7C9BFF),
      secondary: const Color(0xFF40D6C8),
      error: const Color(0xFFFF8A80),
      surface: AppColors.darkSurface,
      brightness: Brightness.dark,
    );

    return _base(
      scheme,
      brightness: Brightness.dark,
      scaffoldBg: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkSurfaceAlt,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
    );
  }

  // -------------------------------------------------------------------------
  // الأساس المشترك
  // -------------------------------------------------------------------------
  static ThemeData _base(
    ColorScheme scheme, {
    required Brightness brightness,
    required Color scaffoldBg,
    required Color cardColor,
    required Color dividerColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final textTheme = _textTheme(textPrimary, textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: dividerColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        height: 66,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? AppColors.surface
              : AppColors.darkBackground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: textTheme.labelMedium,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }

  /// نصوص عربية بمقاسات مريحة للقراءة على الشاشات اللمسية.
  static TextTheme _textTheme(Color primary, Color secondary) {
    const fontFamily = AppTheme.fontFamily;
    TextStyle base(double size, FontWeight weight, {double? height}) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height ?? 1.45,
      color: primary,
    );

    return TextTheme(
      displaySmall: base(30, FontWeight.w900, height: 1.3),
      headlineMedium: base(26, FontWeight.w800, height: 1.3),
      headlineSmall: base(22, FontWeight.w800, height: 1.35),
      titleLarge: base(19, FontWeight.w700),
      titleMedium: base(16, FontWeight.w700),
      titleSmall: base(14, FontWeight.w700),
      bodyLarge: base(16, FontWeight.w400),
      bodyMedium: base(14, FontWeight.w400),
      bodySmall: base(12.5, FontWeight.w400),
      labelLarge: base(14, FontWeight.w700),
      labelMedium: base(13, FontWeight.w600),
      labelSmall: base(11.5, FontWeight.w600),
    ).apply(bodyColor: primary, displayColor: primary).copyWith(
      bodySmall: base(12.5, FontWeight.w400).copyWith(color: secondary),
      labelSmall: base(11.5, FontWeight.w600).copyWith(color: secondary),
    );
  }
}
