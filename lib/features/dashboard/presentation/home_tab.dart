import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import 'main_shell.dart';

/// تبويب «الرئيسية» — لوحة التحكم السريعة.
///
/// الخطوة 1: الهيكل والبطاقات العربية الجاهزة.
/// الخطوة 3: تُربط الأقسام ببيانات Moodle (واجبات، دروس، إشعارات).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _GreetingCard(account: account),
        const TabHeader(title: AppStrings.upcomingAssignments),
        const _SectionCard(
          icon: Icons.assignment_turned_in_outlined,
          title: AppStrings.noUpcomingAssignments,
          message: 'ستظهر هنا الواجبات فور مزامنة المقررات.',
        ),
        const TabHeader(title: AppStrings.todayMaterials),
        const _SectionCard(
          icon: Icons.menu_book_rounded,
          title: AppStrings.noResults,
          message: 'ستظهر دروس اليوم هنا بعد أول مزامنة.',
        ),
        const TabHeader(title: AppStrings.latestNotifications),
        const _SectionCard(
          icon: Icons.notifications_none_rounded,
          title: AppStrings.noNotifications,
          message: 'التنبيهات الخاصة بهذا الطالب ستظهر هنا.',
        ),
      ],
    );
  }
}

class _GreetingCard extends StatelessWidget {
  const _GreetingCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncText = account.lastSyncedAt == null
        ? AppStrings.neverSynced
        : '${AppStrings.lastSync}: ${DatesAr.timeAgo(account.lastSyncedAt!)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Card(
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              InitialsAvatar(
                initials: account.initials,
                colorIndex: account.colorIndex,
                size: 52,
                isActive: true,
                imageUrl: account.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppStrings.welcomeBack}، ${account.displayName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.cloud_done_rounded,
                            size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            syncText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (message != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
