import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// خدمة المصادقة البيومترية (بصمة/وجه) مع معالجة آمنة للأخطاء.
class LocalAuthService {
  LocalAuthService({LocalAuthentication? auth}) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// هل يدعم الجهاز البصمة/الوجه وهل هي مفعّلة؟ (استعلام سريع)
  Future<bool> get isAvailable async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// محاولة فتح القفل — تُرجع true عند نجاح التحقق.
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
