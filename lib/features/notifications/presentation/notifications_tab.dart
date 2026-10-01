import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../dashboard/presentation/main_shell.dart';

/// تبويب «الإشعارات» — الخطوة 1: الهيكل، الخطوة 3: إشعارات لكل حساب.
class NotificationsTab extends StatelessWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabHeader(
          title: AppStrings.notifications,
          trailing: _ReadAllButton(),
        ),
        const Expanded(
          child: TabEmpty(
            icon: Icons.notifications_none_rounded,
            title: AppStrings.noNotifications,
            message: 'تنبيهات مواعيد التسليم والدروس الجديدة ستظهر هنا.',
          ),
        ),
      ],
    );
  }
}

class _ReadAllButton extends StatelessWidget {
  const _ReadAllButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: null,
      child: const Text(
        AppStrings.markAllRead,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
