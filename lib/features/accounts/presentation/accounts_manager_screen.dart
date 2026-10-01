import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../application/accounts_providers.dart';
import '../domain/account.dart';

/// شاشة إدارة الحسابات: عرض، تبديل، حذف، وإضافة (بحد أقصى 10).
class AccountsManagerScreen extends ConsumerWidget {
  const AccountsManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.accountsManager)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'يمكنك حفظ حتى ${AccountsController.maxAccounts} حسابات في هذا الجهاز',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Text(
                  '${accounts.length}/${AccountsController.maxAccounts}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: accounts.isEmpty
                ? const _EmptyAccounts()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _AccountTile(account: accounts[index]),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: accounts.length >= AccountsController.maxAccounts
          ? null
          : FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.login),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(AppStrings.addAccount),
            ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_rounded,
                size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(AppStrings.noAccountsYet,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive =
        ref.watch(activeAccountIdProvider) == account.id;
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!isActive) {
            ref.read(activeAccountIdProvider.notifier).select(account.id);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              InitialsAvatar(
                initials: account.initials,
                colorIndex: account.colorIndex,
                isActive: isActive,
                imageUrl: account.avatarUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            account.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: AppColors.success),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.username} • ${account.serverUrl}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (account.isDemo) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          AppStrings.demoMode,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: AppStrings.edit,
                onSelected: (value) async {
                  if (value == 'activate') {
                    await ref
                        .read(activeAccountIdProvider.notifier)
                        .select(account.id);
                  } else if (value == 'delete') {
                    await _confirmDelete(context, ref);
                  }
                },
                itemBuilder: (_) => [
                  if (!isActive)
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text(AppStrings.switchAccount),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      AppStrings.delete,
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteAccount),
        content: Text(
          '${account.displayName}\n\n${AppStrings.deleteAccountWarning}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(accountsProvider.notifier).remove(account.id);
    }
  }
}
