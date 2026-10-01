import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../dashboard/presentation/main_shell.dart';

/// تبويب «المقررات» — الخطوة 1: الهيكل، الخطوة 3: بيانات Moodle.
class CoursesTab extends StatelessWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: AppStrings.myCourses),
        const Expanded(
          child: TabEmpty(
            icon: Icons.menu_book_rounded,
            title: AppStrings.noCourses,
            message: 'سيتم عرض المقررات المسجّلة هنا بعد المزامنة الأولى.',
          ),
        ),
      ],
    );
  }
}
