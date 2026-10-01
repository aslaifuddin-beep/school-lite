import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/theme/app_colors.dart';

/// شاشة تعيين أو تغيير رمز PIN المحلي.
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key, this.isInitialSetup = true});

  /// true عند التعيين الأول، false عند التغيير (يسمح بإزالة الرمز).
  final bool isInitialSetup;

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(appLockProvider.notifier).setPin(_pinController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.pinSaved)),
    );
    Navigator.of(context).pop();
  }

  Future<void> _removePin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.pinLock),
        content: const Text('هل تريد إزالة رمز القفل؟ سيُفتح التطبيق مباشرة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(appLockProvider.notifier).clearPin();
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinIsSet = ref.watch(appLockProvider).isPinSet;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup
            ? AppStrings.setPin
            : AppStrings.changePin),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.pin_rounded,
                      size: 52, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    'استخدم رقماً من 4 إلى 6 أرقام يُحفظ مشفراً داخل جهازك فقط.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: AppStrings.setPin,
                      prefixIcon: Icon(Icons.password_rounded),
                      counterText: '',
                    ),
                    validator: (v) {
                      final pin = v ?? '';
                      if (pin.length < 4) return 'الرمز 4 أرقام على الأقل';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: AppStrings.confirmPin,
                      prefixIcon: Icon(Icons.password_outlined),
                      counterText: '',
                    ),
                    validator: (v) =>
                        (v ?? '') == _pinController.text
                            ? null
                            : AppStrings.pinMismatch,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(AppStrings.save),
                  ),
                  if (!widget.isInitialSetup && pinIsSet) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _removePin,
                      icon: const Icon(Icons.lock_open_rounded,
                          color: AppColors.danger),
                      label: const Text(
                        'إزالة رمز القفل',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
