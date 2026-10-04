import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/dates_ar.dart';
import '../../../core/widgets/cached_stream_builder.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../accounts/domain/account.dart';
import '../../dashboard/presentation/main_shell.dart';
import '../../sync/application/sync_controller.dart';
import '../../sync/application/sync_providers.dart';
import '../domain/assignment_urgency.dart';
import 'assignment_submit_sheet.dart';

enum _AssignmentFilter { all, overdue, dueSoon, upcoming }

/// تبويب «الواجبات» — بيانات حيّة من القاعدة + ودجت «مهام اليوم»
/// وتسليم بلمسة (نص/مرفقات/كاميرا) عبر الطابور الذرّي.
class AssignmentsTab extends ConsumerStatefulWidget {
  const AssignmentsTab({super.key});

  @override
  ConsumerState<AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<AssignmentsTab> {
  _AssignmentFilter _filter = _AssignmentFilter.all;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final daos = ref.watch(daosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: AppStrings.assignments),
        Expanded(
          child: CachedStreamBuilder<List<Assignment>>(
            cacheKey: account.id,
            create: () => daos.assignments.watchAll(account.id),
            builder: (context, snap) {
              if (snap.hasError) {
                return const TabEmpty(
                  icon: Icons.error_outline_rounded,
                  title: AppStrings.error,
                  message: 'تعذّر قراءة الواجبات المحفوظة محلياً',
                );
              }
              final all = snap.data ?? const <Assignment>[];
              if (all.isEmpty) {
                return const TabEmpty(
                  icon: Icons.assignment_outlined,
                  title: AppStrings.noAssignments,
                  message: 'ستظهر الواجبات ومواعيد تسليمها هنا.',
                );
              }

              final today =
                  all.where((a) => isTodayTask(a)).take(4).toList();
              final filtered = all.where((a) {
                final urgency = classifyAssignment(a);
                switch (_filter) {
                  case _AssignmentFilter.all:
                    return true;
                  case _AssignmentFilter.overdue:
                    return urgency == AssignmentUrgency.overdue;
                  case _AssignmentFilter.dueSoon:
                    return urgency == AssignmentUrgency.dueSoon;
                  case _AssignmentFilter.upcoming:
                    return urgency == AssignmentUrgency.upcoming ||
                        urgency == AssignmentUrgency.noDate;
                }
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  if (today.isNotEmpty) ...[
                    _TodayTasksCard(
                      tasks: today,
                      onOpen: (a) => showAssignmentSheet(context, a),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final f in _AssignmentFilter.values)
                        FilterChip(
                          label: Text(_filterLabel(f)),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final a in filtered) ...[
                    _AssignmentCard(
                      assignment: a,
                      onOpen: () => showAssignmentSheet(context, a),
                      onQuickCamera: () => _quickCameraSubmit(account, a),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _filterLabel(_AssignmentFilter f) {
    switch (f) {
      case _AssignmentFilter.all:
        return AppStrings.allTasks;
      case _AssignmentFilter.overdue:
        return AppStrings.overdue;
      case _AssignmentFilter.dueSoon:
        return AppStrings.dueSoonTasks;
      case _AssignmentFilter.upcoming:
        return AppStrings.upcomingTasks;
    }
  }

  /// تسليم بلمسة: التقاط صورة بالكاميرا → حفظها في مجلد التطبيق
  /// → إدخالها في الطابور → محاولة رفع فوري.
  Future<void> _quickCameraSubmit(Account account, Assignment a) async {
    try {
      final shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (shot == null) return;

      final dir = await getApplicationDocumentsDirectory();
      final submissions = Directory(p.join(dir.path, 'submissions'));
      await submissions.create(recursive: true);
      final dest = p.join(
        submissions.path,
        '${DateTime.now().millisecondsSinceEpoch}_${p.basename(shot.path)}',
      );
      await File(shot.path).copy(dest);

      final sync = ref.read(syncControllerProvider.notifier);
      await ref.read(submissionServiceProvider).saveFileSubmission(
            accountId: account.id,
            assignmentMoodleId: a.moodleId,
            filePaths: [dest],
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.queuedForSync)),
        );
      try {
        await sync.syncNow();
      } catch (_) {
        // الطابور يكفي إن فشل الرفع الفوري.
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(AppStrings.cameraCaptureFailed)),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// ودجت «مهام اليوم» — المتأخرة والمستحقّة خلال 24 ساعة.
// ---------------------------------------------------------------------------

class _TodayTasksCard extends StatelessWidget {
  const _TodayTasksCard({required this.tasks, required this.onOpen});

  final List<Assignment> tasks;
  final ValueChanged<Assignment> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.today_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppStrings.todaysTasks} (${tasks.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final a in tasks)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onOpen(a),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _UrgencyLabel(urgency: classifyAssignment(a)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UrgencyLabel extends StatelessWidget {
  const _UrgencyLabel({required this.urgency});

  final AssignmentUrgency urgency;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    switch (urgency) {
      case AssignmentUrgency.overdue:
        text = AppStrings.overdue;
        color = Colors.red.shade700;
      case AssignmentUrgency.dueSoon:
        text = AppStrings.dueSoonLabel;
        color = Colors.orange.shade900;
      case AssignmentUrgency.done:
        text = AppStrings.submitted;
        color = Colors.green.shade800;
      case AssignmentUrgency.upcoming:
        text = AppStrings.upcomingTasks;
        color = Colors.blue.shade800;
      case AssignmentUrgency.noDate:
        text = AppStrings.noDueDate;
        color = Colors.grey.shade700;
    }
    return Text(
      text,
      style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700),
    );
  }
}

// ---------------------------------------------------------------------------
// بطاقة واجب واحدة.
// ---------------------------------------------------------------------------

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.onOpen,
    required this.onQuickCamera,
  });

  final Assignment assignment;
  final VoidCallback onOpen;
  final VoidCallback onQuickCamera;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = assignment;
    final urgency = classifyAssignment(a);

    final Color iconColor;
    final IconData icon;
    if (a.pendingSync) {
      iconColor = Colors.orange.shade800;
      icon = Icons.cloud_sync_outlined;
    } else {
      switch (urgency) {
        case AssignmentUrgency.done:
          iconColor = Colors.green.shade700;
          icon = Icons.check_circle_outline_rounded;
        case AssignmentUrgency.overdue:
          iconColor = Colors.red.shade700;
          icon = Icons.schedule_rounded;
        case AssignmentUrgency.dueSoon:
          iconColor = Colors.orange.shade800;
          icon = Icons.timer_outlined;
        case AssignmentUrgency.upcoming:
        case AssignmentUrgency.noDate:
          iconColor = AppColors.primary;
          icon = Icons.assignment_outlined;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLine(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!a.pendingSync && urgency != AssignmentUrgency.done)
                IconButton(
                  tooltip: AppStrings.attachFile,
                  icon: Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onQuickCamera,
                ),
              Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLine() {
    final a = assignment;
    if (a.pendingSync) return AppStrings.pendingSync;
    if (a.status == 'submitted') {
      final at = a.submittedAt;
      return at == null
          ? AppStrings.submitted
          : '${AppStrings.submitted} • ${DatesAr.timeAgo(at)}';
    }
    if (a.status == 'graded') {
      final grade = a.gradeText?.trim();
      return grade == null || grade.isEmpty
          ? AppStrings.graded
          : '${AppStrings.graded}: $grade';
    }
    final due = a.dueAt;
    if (due == null) return AppStrings.noDueDate;
    return '${AppStrings.dueDate}: ${DatesAr.formatDateTime(due)}';
  }
}
