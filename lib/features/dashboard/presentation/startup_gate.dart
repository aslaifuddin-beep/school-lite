import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/application/accounts_providers.dart';

/// شاشة الإقلاع: تُقرر الوجهة الأولى خلال إطار واحد (أقل من ثانية).
///
/// الأولوية: لا حسابات ← تسجيل الدخول | مقفل ← شاشة القفل | وإلا الهيكل.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  void _decide() {
    if (_navigated || !mounted) return;
    _navigated = true;

    final hasAccounts = ref.read(accountsProvider).isNotEmpty;
    final isLocked = ref.read(appLockProvider).isLocked;

    final navigator = Navigator.of(context);
    if (!hasAccounts) {
      navigator.pushReplacementNamed(AppRoutes.login);
    } else if (isLocked) {
      navigator.pushReplacementNamed(AppRoutes.lock);
    } else {
      navigator.pushReplacementNamed(AppRoutes.main);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded,
                  size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(AppStrings.appName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              AppStrings.appTagline,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 26),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
