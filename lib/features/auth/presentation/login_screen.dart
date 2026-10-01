import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../accounts/application/accounts_providers.dart';
import '../application/auth_providers.dart';
import '../data/moodle_auth_service.dart';

/// شاشة تسجيل الدخول: إضافة حساب طالب جديد إلى الجهاز.
///
/// تعمل بطريقتين:
/// 1) حساب حقيقي: اتصال مباشر بـ Moodle عبر login/token.php (بلا WebView).
/// 2) الوضع التجريبي: إنشاء حساب فوري ببيانات افتراضية للعرض.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController(text: 'https://demo.moodle.net');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdding = ref.watch(accountsProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdding ? AppStrings.addAccount : AppStrings.loginTitle,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ------------------------------------------------ الهوية
                    if (!isAdding) ...[
                      _Header(theme: theme),
                      const SizedBox(height: 26),
                    ],
                    // ------------------------------------------------ الحقول
                    TextFormField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: AppStrings.serverUrl,
                        hintText: AppStrings.serverUrlHint,
                        prefixIcon: Icon(Icons.dns_rounded),
                      ),
                      validator: (v) =>
                          UrlUtils.isValidServerUrl(v ?? '')
                              ? null
                              : AppStrings.invalidServerUrl,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _usernameController,
                      textDirection: TextDirection.ltr,
                      decoration: const InputDecoration(
                        labelText: AppStrings.username,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? AppStrings.requiredField
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: AppStrings.password,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? AppStrings.requiredField
                          : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    if (_errorText != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _errorText!),
                    ],
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _loading ? null : _login,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(_loading
                          ? AppStrings.signingIn
                          : AppStrings.signIn),
                    ),
                    const SizedBox(height: 18),
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('أو',
                            style: theme.textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _loginDemo,
                      icon: const Icon(Icons.science_rounded),
                      label: const Text(AppStrings.demoMode),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.demoModeHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ عمليات

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final result = await ref.read(moodleAuthServiceProvider).login(
            serverUrl: _serverController.text,
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );

      await ref.read(accountsProvider.notifier).add(
            serverUrl: UrlUtils.normalizeServerUrl(_serverController.text),
            username: _usernameController.text.trim(),
            displayName: result.fullName.isNotEmpty
                ? result.fullName
                : _usernameController.text.trim(),
            token: result.token,
            moodleUserId: result.userId,
            avatarUrl: result.avatarUrl,
          );
      if (mounted) _finish();
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = AppStrings.networkError;
        });
      }
    }
  }

  Future<void> _loginDemo() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    await ref.read(accountsProvider.notifier).add(
          serverUrl: 'demo.moodle.local',
          username: 'demo_student',
          displayName: AppStrings.demoAccountName,
          token: 'demo-token',
          isDemo: true,
        );
    if (mounted) _finish();
  }

  /// إنهاء الشاشة: إغلاقها إن كانت مفتوحة كـ«إضافة حساب»، وإلا الانتقال
  /// إلى الهيكل الرئيسي كجذر جديد.
  void _finish() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.main);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.school_rounded,
              size: 46, color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        Text(AppStrings.appName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          AppStrings.appTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}
