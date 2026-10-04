import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/daos.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/application/accounts_providers.dart';
import '../../dashboard/presentation/main_shell.dart';
import 'course_detail_screen.dart';

/// تبويب «المقررات» — مرتب ببيانات Moodle عبر Streams من القاعدة
/// (Offline-First: يعرض المحفوظ فوراً ويتحدث تلقائياً بعد كل مزامنة).
class CoursesTab extends ConsumerWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(activeAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final daos = ref.watch(daosProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: AppStrings.myCourses),
        Expanded(
          child: StreamBuilder<List<Course>>(
            stream: daos.content.watchCourses(account.id),
            builder: (context, snap) {
              if (snap.hasError) {
                return const TabEmpty(
                  icon: Icons.error_outline_rounded,
                  title: AppStrings.error,
                  message: 'تعذّر قراءة المقررات المحفوظة محلياً',
                );
              }
              final courses = snap.data ?? const <Course>[];
              if (courses.isEmpty) {
                return const TabEmpty(
                  icon: Icons.menu_book_rounded,
                  title: AppStrings.noCourses,
                  message: 'سيتم عرض المقررات المسجّلة هنا بعد المزامنة الأولى.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final course = courses[i];
                  return _CourseCard(
                    course: course,
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.courseDetail,
                      arguments: CourseDetailArgs(
                        id: course.id,
                        title: course.fullName,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = course.progress;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (course.shortName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        course.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (progress != null && progress > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
}
