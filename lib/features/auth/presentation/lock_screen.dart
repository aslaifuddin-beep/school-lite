import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/security/security_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../accounts/application/accounts_providers.dart';

/// شاشة قفل التطبيق: فتح بالبصمة/الوجه أو برمز PIN محلي.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _pinLength = 4;

  String _entered = '';
  String? _errorText;
  bool _biometricAvailable = false;
  bool _checkingBiometric = false;

  @override
  void initState() {
    super.initState();
    // محاولة فتح تلقائية بالبصمة فور فتح الشاشة (سلوك تطبيقات البنوك).
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);

    final service = ref.read(localAuthServiceProvider);
    final available = await service.isAvailable;
    if (!mounted) return;
    setState(() => _biometricAvailable = available);

    if (available) {
      final ok = await service.authenticate(
        reason: AppStrings.biometricReason,
      );
      if (ok && mounted) _unlock();
    }
    if (mounted) setState(() => _checkingBiometric = false);
  }

  void _unlock() {
    ref.read(appLockProvider.notifier).unlock();
    Navigator.of(context).pushReplacementNamed(AppRoutes.main);
  }

  void _onDigit(String digit) {
    if (_entered.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += digit;
      _errorText = null;
    });
    if (_entered.length == _pinLength) _verify();
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _errorText = null;
    });
  }

  Future<void> _verify() async {
    final ok = ref.read(pinStoreProvider).verify(_entered);
    if (ok) {
      HapticFeedback.mediumImpact();
      _unlock();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _errorText = AppStrings.wrongPin;
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeName = ref.watch(activeAccountProvider)?.displayName;
    final biometricReady =
        _biometricAvailable && _entered.isEmpty && !_checkingBiometric;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded,
                    size: 42, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.lockTitle, style: theme.textTheme.headlineSmall),
              if (activeName != null) ...[
                const SizedBox(height: 6),
                Text(
                  activeName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 26),
              // ------------------------------------------------ مؤشر الرمز
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _entered.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? AppColors.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: _errorText != null
                            ? AppColors.danger
                            : AppColors.primary.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(
                height: 30,
                child: Center(
                  child: _errorText == null
                      ? null
                      : Text(
                          _errorText!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const Spacer(),
              // ------------------------------------------------ لوحة الأرقام
              _Keypad(
                showBiometric: biometricReady,
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onBiometric: _tryBiometric,
              ),
              const SizedBox(height: 8),
              if (biometricReady)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text(AppStrings.unlockWithBiometric),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// لوحة أرقام عربية-لمسية مخصصة (3×4).
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.showBiometric,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final bool showBiometric;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];

    return Directionality(
      // لوحة الأرقام تُعرض دائماً بترتيب LTR المعتاد (٧٨٩ أعلى).
      textDirection: TextDirection.ltr,
      child: Column(
        children: keys.map((row) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k.isEmpty) {
                return SizedBox(
                  width: 84,
                  height: 68,
                  child: Center(
                    child: showBiometric
                        ? IconButton(
                            onPressed: onBiometric,
                            iconSize: 34,
                            color: AppColors.primary,
                            icon: const Icon(Icons.fingerprint_rounded),
                          )
                        : null,
                  ),
                );
              }
              if (k == '<') {
                return SizedBox(
                  width: 84,
                  height: 68,
                  child: IconButton(
                    onPressed: onBackspace,
                    iconSize: 26,
                    icon: const Icon(Icons.backspace_outlined),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: 72,
                  height: 68,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onDigit(k),
                      child: Center(
                        child: Text(
                          k,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
