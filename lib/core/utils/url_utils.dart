/// أدوات التعامل مع روابط خوادم Moodle.
abstract final class UrlUtils {
  /// يوحّد رابط الخادم: يضيف https:// إن لزم، يحذف الشرطة المائلة
  /// الأخيرة، ويحذف مسافات البداية والنهاية.
  static String normalizeServerUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// تحقق أن الرابط صالح للإرسال (يقبل مضيفاً بدون مسار عميق).
  static bool isValidServerUrl(String raw) {
    final url = normalizeServerUrl(raw);
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.host.contains('.') && !url.contains(' ');
  }
}
