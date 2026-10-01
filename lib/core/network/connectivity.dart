import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// خدمة مراقبة الاتصال (متاحة في الخلفية أيضاً).
final connectivityServiceProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

/// تدفّق تغيّرات الاتصال — يُطلق عند عودة الإنترنت لتشغيل المزامنة.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return ref.watch(connectivityServiceProvider).onConnectivityChanged;
});

/// هل النتيجة تمثّل "متصل"؟ (القائمة الفارغة أو none = بلا إنترنت)
bool isOnlineResults(List<ConnectivityResult> results) {
  if (results.isEmpty) return false;
  return results.any((r) => r != ConnectivityResult.none);
}

/// فحص لحظي واحد للاتصال (قبل مزامنة يدوية مثلاً).
Future<bool> checkOnlineNow(Connectivity connectivity) async {
  try {
    return isOnlineResults(await connectivity.checkConnectivity());
  } catch (_) {
    // فشل الفحص نفسه → نفترض عدم الاتصال (لا نوقف التطبيق).
    return false;
  }
}
