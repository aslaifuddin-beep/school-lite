import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../dashboard/presentation/main_shell.dart';

/// تبويب «الواجبات» — الخطوة 1: الهيكل، الخطوة 3: بيانات + تسليم offline.
class AssignmentsTab extends StatelessWidget {
  const AssignmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(title: AppStrings.assignments),
        const Expanded(
          child: TabEmpty(
            icon: Icons.assignment_outlined,
            title: AppStrings.noAssignments,
            message: 'ستظهر الواجبات ومواعيد تسليمها هنا.',
          ),
        ),
      ],
    );
  }
}
