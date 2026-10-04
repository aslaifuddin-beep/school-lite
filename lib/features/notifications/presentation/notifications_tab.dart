import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/widgets/cached_stream_builder.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../dashboard/presentation/main_shell.dart';

/// تبويب «الإشعارات» — حيّ من القاعدة لكل حساب على حدة.
class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final daos = ref.watch(daosProvider);

    return CachedStreamBuilder<List<LocalNotification>>(
      cacheKey: account.id,
      create: () => daos.notifications.watchAll(account.id),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabHeader(title: AppStrings.notifications),
              Expanded(
                child: TabEmpty(
                  icon: Icons.error_outline_rounded,
                  title: AppStrings.error,
                  message: 'تعذّر قراءة الإشعارات المحفوظة',
                ),
              ),
            ],
          );
        }

        final items = snap.data ?? const <LocalNotification>[];
        final hasUnread = items.any((n) => !n.isRead);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabHeader(
              title: AppStrings.notifications,
              trailing: hasUnread
                  ? TextButton(
                      onPressed: () =>
                          daos.notifications.markAllRead(account.id),
                      child: const Text(
                        AppStrings.markAllRead,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: items.isEmpty
                  ? const TabEmpty(
                      icon: Icons.notifications_none_rounded,
                      title: AppStrings.noNotifications,
                      message: 'تنبيهات مواعيد التسليم والدروس الجديدة ستظهر هنا.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) =>
                          _NotificationCard(item: items[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final LocalNotification item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;

    return Card(
      margin: EdgeInsets.zero,
      color: unread ? AppColors.primarySurface : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unread
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              size: 20,
              color: unread ? AppColors.primary : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.body.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DatesAr.timeAgo(item.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
