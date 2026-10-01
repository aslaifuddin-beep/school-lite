import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_providers.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../accounts/application/accounts_providers.dart';

/// تبويب «الإعدادات» — المظهر، الأمان، الحسابات، حول التطبيق.
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final account = ref.watch(activeAccountProvider);
    final themeMode = ref.watch(themeModeProvider);
    final pinIsSet = ref.watch(appLockProvider).isPinSet;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ------------------------------------------------ بطاقة الحساب
        if (account != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: InitialsAvatar(
                  initials: account.initials,
                  colorIndex: account.colorIndex,
                  isActive: true,
                  imageUrl: account.avatarUrl,
                ),
                title: Text(account.displayName,
                    style: theme.textTheme.titleMedium),
                subtitle: Text(
                  '${account.username} • ${account.serverUrl}\n'
                  '${account.lastSyncedAt == null ? AppStrings.neverSynced : '${AppStrings.lastSync}: ${DatesAr.timeAgo(account.lastSyncedAt!)}'}',
                ),
                isThreeLine: true,
              ),
            ),
          ),

        // ------------------------------------------------ المظهر
        const _SectionLabel(AppStrings.appearance),
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode_outlined),
          title: const Text(AppStrings.darkMode),
          value: themeMode == ThemeMode.dark,
          onChanged: (v) => ref.read(themeModeProvider.notifier).toggleDark(v),
        ),

        // ------------------------------------------------ الأمان
        const _SectionLabel(AppStrings.security),
        ListTile(
          leading: const Icon(Icons.pin_rounded),
          title: const Text(AppStrings.pinLock),
          subtitle: Text(pinIsSet ? 'مفعّل' : 'غير مفعّل'),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.setPin,
            arguments: !pinIsSet,
          ),
        ),

        // ------------------------------------------------ الحسابات
        const _SectionLabel(AppStrings.accounts),
        ListTile(
          leading: const Icon(Icons.manage_accounts_rounded),
          title: const Text(AppStrings.accountsManager),
          subtitle: Text(
            '${ref.watch(accountsProvider).length} من ${AccountsController.maxAccounts}',
          ),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.accountsManager),
        ),

        // ------------------------------------------------ حول
        const _SectionLabel(AppStrings.about),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text(AppStrings.appName),
          subtitle: const Text('${AppStrings.appTagline}\nالإصدار 1.0.0'),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: AppStrings.appName,
            applicationVersion: '1.0.0',
            applicationLegalese: AppStrings.appTagline,
            applicationIcon: const Icon(Icons.school_rounded,
                color: AppColors.primary, size: 40),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primary,
            ),
      ),
    );
  }
}
