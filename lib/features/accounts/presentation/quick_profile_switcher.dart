import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../application/accounts_providers.dart';

/// الشريط العلوي التنقّلي السريع (Quick Profile Switcher).
///
/// يعرض دوائر الحسابات (حتى 10) في شريط أفقي داخل شريط التطبيق،
/// والتبديل بضغطة واحدة دون فقدان حالة الشاشة الحالية.
/// - ضغطة: تبديل فوري.
/// - ضغطة مطوّلة: فتح إدارة الحسابات.
/// - زر «+»: إضافة حساب جديد.
class QuickProfileSwitcher extends ConsumerWidget {
  const QuickProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final activeId = ref.watch(activeAccountIdProvider);

    if (accounts.isEmpty) return const SizedBox.shrink();

    return Tooltip(
      message: AppStrings.quickSwitchHint,
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: accounts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final account = accounts[index];
            final isActive = account.id == activeId;
            return Tooltip(
              message: account.displayName,
              triggerMode: TooltipTriggerMode.tap,
              child: GestureDetector(
                onTap: () => _switchTo(ref, context, account.id),
                onLongPress: () => Navigator.of(context)
                    .pushNamed(AppRoutes.accountsManager),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InitialsAvatar(
                    initials: account.initials,
                    colorIndex: account.colorIndex,
                    size: 36,
                    isActive: isActive,
                    imageUrl: account.avatarUrl,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _switchTo(WidgetRef ref, BuildContext context, String accountId) {
    final current = ref.read(activeAccountIdProvider);
    if (current == accountId) return;
    ref.read(activeAccountIdProvider.notifier).select(accountId);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            'تم التبديل إلى ${ref.read(accountsProvider).firstWhere((a) => a.id == accountId).displayName}',
          ),
        ),
      );
  }
}
