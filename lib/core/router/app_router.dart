import 'package:flutter/material.dart';

import '../../features/accounts/presentation/accounts_manager_screen.dart';
import '../../features/auth/presentation/lock_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/set_pin_screen.dart';
import '../../features/courses/presentation/course_detail_screen.dart';
import '../../features/courses/presentation/pdf_viewer_screen.dart';
import '../../features/dashboard/presentation/main_shell.dart';
import '../l10n/app_strings.dart';

/// مسارات التنقل داخل التطبيق.
abstract final class AppRoutes {
  static const login = '/login';
  static const lock = '/lock';
  static const main = '/main';
  static const accountsManager = '/accounts-manager';
  static const setPin = '/set-pin';
  static const courseDetail = '/course-detail';
  static const pdfViewer = '/pdf-viewer';
}

/// مولّد المسارات — كل الشاشات تُفتح كـ Route مستقل.
abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
      case AppRoutes.lock:
        return MaterialPageRoute(
          builder: (_) => const LockScreen(),
          settings: settings,
        );
      case AppRoutes.main:
        return MaterialPageRoute(
          builder: (_) => const MainShell(),
          settings: settings,
        );
      case AppRoutes.accountsManager:
        return MaterialPageRoute(
          builder: (_) => const AccountsManagerScreen(),
          settings: settings,
        );
      case AppRoutes.setPin:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => SetPinScreen(
            isInitialSetup: args is bool ? args : true,
          ),
          settings: settings,
        );
      case AppRoutes.courseDetail:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => CourseDetailScreen(
            args: args is CourseDetailArgs
                ? args
                : const CourseDetailArgs(id: '', title: AppStrings.courses),
          ),
          settings: settings,
        );
      case AppRoutes.pdfViewer:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            args: args is PdfViewerArgs
                ? args
                : const PdfViewerArgs(path: '', title: ''),
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const MainShell(),
          settings: settings,
        );
    }
  }
}
