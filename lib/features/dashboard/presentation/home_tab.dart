import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/widgets/cached_stream_builder.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../assignments/domain/assignment_urgency.dart';
import '../../assignments/presentation/assignment_submit_sheet.dart';
import 'main_shell.dart';

/// تبويب «الرئيسية» — أقسام حيّة من قاعدة البيانات:
/// واجبات قادمة + دروس اليوم (التقويم) + أحدث الإشعارات (آخر 3).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final daos = ref.watch(daosProvider);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _GreetingCard(account: account),

        // ------------------------------------------------ 1) واجبات قادمة
        CachedStreamBuilder<List<Assignment>>(
          cacheKey: account.id,
          create: () => daos.assignments.watchAll(account.id),
          builder: (context, snap) {
            final all = snap.data ?? const <Assignment>[];
            final upcoming = all
                .where((a) => classifyAssignment(a) != AssignmentUrgency.done)
                .toList()
              ..sort((a, b) {
                final da = a.dueAt;
                final db = b.dueAt;
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return da.compareTo(db);
              });
            final top = upcoming.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(title: AppStrings.upcomingAssignments),
                if (top.isEmpty)
                  const _SectionCard(
                    icon: Icons.assignment_turned_in_outlined,
                    title: AppStrings.noUpcomingAssignments,
                    message: 'ستظهر هنا الواجبات فور مزامنة المقررات.',
                  )
                else
                  for (final a in top)
                    _HomeRow(
                      icon: _assignmentIcon(classifyAssignment(a)),
                      iconColor: _assignmentColor(classifyAssignment(a)),
                      title: a.name,
                      subtitle: _assignmentSubtitle(a),
                      onTap: () => showAssignmentSheet(context, a),
                    ),
              ],
            );
          },
        ),

        // ------------------------------------------------ 2) دروس اليوم
        CachedStreamBuilder<List<CalendarEvent>>(
          cacheKey: account.id,
          create: () => daos.calendar.watchUpcoming(account.id),
          builder: (context, snap) {
            final now = DateTime.now();
            final startOfToday = DateTime(now.year, now.month, now.day);
            final today = (snap.data ?? const <CalendarEvent>[])
                .where((e) => e.startsAt.isAfter(startOfToday))
                .take(3)
                .toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(title: AppStrings.todayMaterials),
                if (today.isEmpty)
                  const _SectionCard(
                    icon: Icons.menu_book_rounded,
                    title: AppStrings.noResults,
                    message: 'ستظهر دروس اليوم هنا بعد أول مزامنة.',
                  )
                else
                  for (final e in today)
                    _HomeRow(
                      icon: Icons.event_rounded,
                      iconColor: AppColors.primary,
                      title: e.name,
                      subtitle: e.courseName == null ||
                              e.courseName!.trim().isEmpty
                          ? '${DatesAr.formatDate(e.startsAt)} • ${DatesAr.formatTime(e.startsAt)}'
                          : '${e.courseName} • ${DatesAr.formatDate(e.startsAt)}',
                    ),
              ],
            );
          },
        ),

        // ------------------------------------------------ 3) أحدث الإشعارات
        CachedStreamBuilder<List<LocalNotification>>(
          cacheKey: account.id,
          create: () => daos.notifications.watchAll(account.id),
          builder: (context, snap) {
            final top =
                (snap.data ?? const <LocalNotification>[]).take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabHeader(title: AppStrings.latestNotifications),
                if (top.isEmpty)
                  const _SectionCard(
                    icon: Icons.notifications_none_rounded,
                    title: AppStrings.noNotifications,
                    message: 'التنبيهات الخاصة بهذا الطالب ستظهر هنا.',
                  )
                else
                  for (final n in top)
                    _HomeRow(
                      icon: n.isRead
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_rounded,
                      iconColor: n.isRead
                          ? Colors.grey.shade600
                          : AppColors.primary,
                      title: n.title,
                      subtitle: n.body.trim().isEmpty
                          ? DatesAr.timeAgo(n.createdAt)
                          : n.body.trim(),
                    ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData _assignmentIcon(AssignmentUrgency u) {
    switch (u) {
      case AssignmentUrgency.overdue:
        return Icons.schedule_rounded;
      case AssignmentUrgency.dueSoon:
        return Icons.timer_outlined;
      case AssignmentUrgency.noDate:
        return Icons.assignment_outlined;
      case AssignmentUrgency.upcoming:
      case AssignmentUrgency.done:
        return Icons.assignment_turned_in_outlined;
    }
  }

  Color _assignmentColor(AssignmentUrgency u) {
    switch (u) {
      case AssignmentUrgency.overdue:
        return Colors.red.shade700;
      case AssignmentUrgency.dueSoon:
        return Colors.orange.shade800;
      case AssignmentUrgency.upcoming:
        return AppColors.primary;
      case AssignmentUrgency.noDate:
      case AssignmentUrgency.done:
        return Colors.blueGrey.shade600;
    }
  }

  String _assignmentSubtitle(Assignment a) {
    if (a.pendingSync) return AppStrings.pendingSync;
    if (a.status == 'submitted') return AppStrings.submitted;
    if (a.status == 'graded') return AppStrings.graded;
    final due = a.dueAt;
    if (due == null) return AppStrings.noDueDate;
    final urgency = classifyAssignment(a);
    final when = DatesAr.formatDateTime(due);
    if (urgency == AssignmentUrgency.overdue) {
      return '${AppStrings.overdue} • $when';
    }
    if (urgency == AssignmentUrgency.dueSoon) {
      return '${AppStrings.dueSoonLabel} • $when';
    }
    return '${AppStrings.dueDate}: $when';
  }
}

// ---------------------------------------------------------------------------

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

/// صف قابل لإعادة الاستخدام داخل قسم من أقسام الرئيسية.
class _HomeRow extends StatelessWidget {
  const _HomeRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_left_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
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
