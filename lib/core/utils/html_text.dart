/// إزالة وسوم HTML من نصوص Moodle للعرض كنص صريح.
abstract final class HtmlText {
  /// يحوّل HTML بسيط (وصف/مقدمة) إلى نص مقروء:
  /// فواصل الأسطر للـ br/paragraph ثم تُزال كل الوسوم.
  static String strip(String html) {
    return html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}
