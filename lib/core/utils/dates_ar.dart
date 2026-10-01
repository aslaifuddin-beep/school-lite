/// تنسيق تواريخ عربي مبسّط (بلا اعتماد على بيانات locales إضافية).
abstract final class DatesAr {
  /// 30/9/2026، 14:30
  static String formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}، $hour:$minute';
  }

  /// 30/9/2026
  static String formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  /// 14:30
  static String formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// «منذ 5 دقائق» / «منذ ساعتين» — لعرض آخر مزامنة.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? 'منذ ساعة' : 'منذ ${diff.inHours} ساعات';
    }
    if (diff.inDays == 1) return 'منذ يوم';
    if (diff.inDays < 30) return 'منذ ${diff.inDays} يوماً';
    return formatDate(dt);
  }
}
