import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/prefs_provider.dart';
import 'local_auth_service.dart';
import 'pin_store.dart';
import 'secure_token_store.dart';

/// مخزن رمز PIN (محلي، مُجزَّأ).
final pinStoreProvider = Provider<PinStore>(
  (ref) => PinStore(ref.watch(sharedPrefsProvider)),
);

/// خدمة البصمة/الوجه.
final localAuthServiceProvider = Provider<LocalAuthService>(
  (ref) => LocalAuthService(),
);

/// مخزن توكنات Moodle الآمن.
final secureTokenStoreProvider = Provider<SecureTokenStore>(
  (ref) => SecureTokenStore(),
);

/// حالة قفل الأمان في الجلسة الحالية.
class AppLockState {
  const AppLockState({required this.isLocked, required this.isPinSet});

  /// هل يجب فتح القفل قبل الدخول؟
  final bool isLocked;

  /// هل يوجد رمز PIN معيّن على الجهاز؟
  final bool isPinSet;
}

/// مزوّد حالة القفل: يبدأ مقفلاً فقط إذا كان الرمز معيّناً مسبقاً.
final appLockProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    final pinSet = ref.watch(pinStoreProvider).isSet;
    return AppLockState(isLocked: pinSet, isPinSet: pinSet);
  }

  void unlock() =>
      state = AppLockState(isLocked: false, isPinSet: state.isPinSet);

  void lock() =>
      state = AppLockState(isLocked: state.isPinSet, isPinSet: state.isPinSet);

  /// تعيين/تغيير الرمز — لا يقفل الجلسة الحالية فوراً.
  Future<void> setPin(String pin) async {
    await ref.read(pinStoreProvider).set(pin);
    state = const AppLockState(isLocked: false, isPinSet: true);
  }

  Future<void> clearPin() async {
    await ref.read(pinStoreProvider).clear();
    state = const AppLockState(isLocked: false, isPinSet: false);
  }
}
