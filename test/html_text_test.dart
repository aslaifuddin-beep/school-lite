import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/utils/html_text.dart';

void main() {
  group('HtmlText.strip', () {
    test('يزيل الوسوم ويحوّل فواصل الأسطر', () {
      expect(
        HtmlText.strip('<p>مرحباً</p><br>بالعالم'),
        'مرحباً\nبالعالم',
      );
    });

    test('يزيل br بأي صيغة', () {
      expect(HtmlText.strip('أ<br/>ب<br />ج'), 'أ\nب\nج');
    });

    test('فكّ ترميز الكيانات الشائعة', () {
      expect(
        HtmlText.strip('أ&amp;ب&nbsp;&quot;ج&quot;&#39;د&lt;x&gt;'),
        'أ&ب "ج"\'د<x>',
      );
    });

    test('نص بلا وسوم يبقى كما هو بعد التشذيب', () {
      expect(HtmlText.strip('  نص عادي  '), 'نص عادي');
    });

    test('نص فارغ', () {
      expect(HtmlText.strip(''), '');
    });
  });
}
