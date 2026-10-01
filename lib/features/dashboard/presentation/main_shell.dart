import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/state_views.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/presentation/quick_profile_switcher.dart';
import '../../assignments/presentation/assignments_tab.dart';
import '../../courses/presentation/courses_tab.dart';
import '../../notifications/presentation/notifications_tab.dart';
import '../../settings/presentation/settings_tab.dart';
import '../../sync/application/sync_controller.dart';
import 'home_tab.dart';

/// الهيكل الرئيسي للتطبيق: الشريط العلوي للتبديل + تبويبات سفلية.
///
/// يحتفظ بالتبويبات داخل IndexedStack كي يبقى حالة كل شاشة (وموضع
/// التمرير) محفوظة عند التبديل بين الحسابات أو التنقل.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    HomeTab(),
    CoursesTab(),
    AssignmentsTab(),
    NotificationsTab(),
    SettingsTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeAccountProvider);

    // مراقبة المزامنة: يضمن حياة المتحكّم (مزامنة أولى + عودة الشبكة).
    final sync = ref.watch(syncControllerProvider);

    // حُذف الحساب النشط أثناء العمل ← العودة لشاشة الدخول.
    if (active == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.login,
            (route) => false,
          );
        }
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        // الشريط العلوي التنقلي السريع بين الحسابات.
        title: const QuickProfileSwitcher(),
        actions: [
          IconButton(
            tooltip: AppStrings.syncSettings,
            icon: sync.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    sync.phase == SyncPhase.error
                        ? Icons.sync_problem_rounded
                        : Icons.sync_rounded,
                  ),
            onPressed:
                sync.isSyncing ? null : () => ref.read(syncControllerProvider.notifier).syncNow(),
          ),
          IconButton(
            tooltip: AppStrings.accountsManager,
            icon: const Icon(Icons.manage_accounts_rounded),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.accountsManager),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: AppStrings.navCourses,
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: AppStrings.navAssignments,
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: AppStrings.navNotifications,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: AppStrings.navSettings,
          ),
        ],
      ),
    );
  }
}

/// عنوان تبويب موحّد (للشاشات الفرعية داخل التبويبات).
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// عرض «لا نتائج» موحد داخل التبويبات.
class TabEmpty extends StatelessWidget {
  const TabEmpty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) => EmptyStateView(
        icon: icon,
        title: title,
        message: message,
      );
}
