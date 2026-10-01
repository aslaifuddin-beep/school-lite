import 'package:flutter/material.dart';

/// لوحة ألوان التطبيق — هوية بصرية تعليمية عصرية تناسب الشاشات اللمسية.
abstract final class AppColors {
  // الألوان الأساسية
  static const primary = Color(0xFF2B5CE6);
  static const primaryDark = Color(0xFF1A3EA8);
  static const primarySurface = Color(0xFFE8EEFD);
  static const secondary = Color(0xFF00A99D);
  static const secondarySurface = Color(0xFFE0F6F4);

  // ألوان الحالة (الواجبات والتنبيهات)
  static const success = Color(0xFF2E7D32);
  static const successSurface = Color(0xFFE6F4EA);
  static const warning = Color(0xFFF57C00);
  static const warningSurface = Color(0xFFFFF3E0);
  static const danger = Color(0xFFD32F2F);
  static const dangerSurface = Color(0xFFFDECEA);
  static const info = Color(0xFF0288D1);

  // محايدات السمة الفاتحة
  static const background = Color(0xFFF5F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFEDF1F8);
  static const divider = Color(0xFFE1E6F0);
  static const textPrimary = Color(0xFF17203A);
  static const textSecondary = Color(0xFF5A6480);
  static const textMuted = Color(0xFF8A93AC);

  // محايدات السمة الداكنة
  static const darkBackground = Color(0xFF10141F);
  static const darkSurface = Color(0xFF1A2032);
  static const darkSurfaceAlt = Color(0xFF242C42);
  static const darkTextPrimary = Color(0xFFEDF1F8);
  static const darkTextSecondary = Color(0xFFA9B2C9);

  /// ألوان دوائر الحسابات (عشرة كحد أقصى) — كل طالب بلون مميز.
  static const accountColors = <Color>[
    Color(0xFF2B5CE6),
    Color(0xFF00A99D),
    Color(0xFFF57C00),
    Color(0xFF8E44AD),
    Color(0xFFD32F2F),
    Color(0xFF16A085),
    Color(0xFF3F51B5),
    Color(0xFFE91E63),
    Color(0xFF5D6D7E),
    Color(0xFF00838F),
  ];

  /// يرجّع لوناً ثابتاً لكل حساب بناءً على ترتيبه (يدور على القائمة).
  static Color colorForIndex(int index) =>
      accountColors[index % accountColors.length];
}
