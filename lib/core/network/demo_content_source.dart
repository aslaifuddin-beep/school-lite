import 'content_source.dart';
import 'dto.dart';

/// مصدر محتوى تجريبي — بيانات تعليمية عربية واقعية تعمل بلا إنترنت.
///
/// يُستخدم للحسابات الموسومة isDemo وللاختبارات، ويجعل كل مسارات
/// التطبيق (مزامنة، طابور، إشعارات) قابلة للتجربة الفورية.
class DemoContentSource implements ContentSource {
  /// تأخير صغير يحاكي الشبكة (يُختصر في الاختبارات عبر override).
  DemoContentSource({this.latency = const Duration(milliseconds: 120)});

  final Duration latency;

  Future<void> _delay() => Future<void>.delayed(latency);

  // ------------------------------------------------------------------ الدورات
  static const _courses = <CourseDto>[
    CourseDto(
      id: 101,
      fullName: 'الرياضيات — الصف الأول الثانوي',
      shortName: 'رياضيات',
      summary: 'الجبر والهندسة التحليلية وأساسيات التفاضل.',
      progress: 65,
      enrolledCount: 28,
    ),
    CourseDto(
      id: 102,
      fullName: 'العلوم الطبيعية',
      shortName: 'علوم',
      summary: 'الأحياء والكيمياء والفيزياء — المنهج الكامل.',
      progress: 42,
      enrolledCount: 25,
    ),
    CourseDto(
      id: 103,
      fullName: 'اللغة العربية وآدابها',
      shortName: 'عربي',
      summary: 'النحو والبلاغة وأدب المتنبي والمخضرمين.',
      progress: 78,
      enrolledCount: 30,
    ),
    CourseDto(
      id: 104,
      fullName: 'اللغة الإنجليزية',
      shortName: 'إنجليزي',
      summary: 'القواعد والمفردات ومهارات المحادثة.',
      progress: 30,
      enrolledCount: 27,
    ),
  ];

  @override
  Future<List<CourseDto>> fetchCourses(MoodleSession session) async {
    await _delay();
    return List.unmodifiable(_courses);
  }

  // ------------------------------------------------------------- الأقسام
  @override
  Future<List<SectionBundleDto>> fetchCourseContents(
    MoodleSession session,
    int courseMoodleId,
  ) async {
    await _delay();
    switch (courseMoodleId) {
      case 101:
        return _bundles(
          courseTag: 'م1',
          sections: [
            ('الوحدة الأولى: المقادير والمعادلات', [
              ('درس: تعريف المقادير', 'resource', 'ملف PDF — 12 صفحة'),
              ('ملزمة التمارين (الحلقة الأولى)', 'resource', 'ملف PDF'),
              ('رابط مرجع خارجي', 'url', 'مرجع على ويكيبيديا العربية'),
            ]),
            ('الوحدة الثانية: الدوال', [
              ('درس: أنواع الدوال', 'page', 'درس تفاعلي'),
              ('واجب الوحدة الثانية', 'assign', 'سلّمه قبل نهاية الأسبوع'),
            ]),
          ],
        );
      case 102:
        return _bundles(
          courseTag: 'ع1',
          sections: [
            ('الفصل الأول: الخلية', [
              ('شرح الخلية وتركيبها', 'resource', 'عرض تقديمي PDF'),
              ('تجربة المختبر (فيديو)', 'resource', 'فيديو 8 دقائق'),
            ]),
            ('الفصل الثاني: الجدول الدوري', [
              ('ملخص عناصر الجدول الدوري', 'page', 'درس مختصر'),
              ('تقرير المختبر', 'assign', 'أرفق تقريراً من ملفين'),
            ]),
          ],
        );
      case 103:
        return _bundles(
          courseTag: 'خ1',
          sections: [
            ('درس النحو: المفاعيل', [
              ('شرح المفعول به', 'resource', 'PDF'),
              ('تدريبات إعرابية', 'resource', 'ورقة عمل'),
            ]),
            ('الأدب: المتنبي', [
              ('تحليل قصيدة الكاغد', 'assign', 'اكتب تحليلاً في 300 كلمة'),
              ('نص القصيدة ومفرداتها', 'page', 'نص كامل'),
            ]),
          ],
        );
      default:
        return _bundles(
          courseTag: 'ن1',
          sections: [
            ('Unit 1: Greetings', [
              ('Lesson notes', 'resource', 'PDF handout'),
              ('Vocabulary list', 'page', 'Interactive page'),
            ]),
            ('Unit 2: Family', [
              ('Essay: My Family', 'assign', 'Write 150 words'),
              ('Audio practice', 'resource', 'MP3 file'),
            ]),
          ],
        );
    }
  }

  /// يبني أقساماً بمعرّفات ثابتة مشتقة من وسم المقرر.
  List<SectionBundleDto> _bundles({
    required String courseTag,
    required List<(String, List<(String, String, String)>)> sections,
  }) {
    final bundles = <SectionBundleDto>[];
    for (var s = 0; s < sections.length; s++) {
      final (title, modules) = sections[s];
      final sectionId = _stableId('$courseTag-sec-$s');
      final moduleDtos = <ModuleDto>[];
      for (var m = 0; m < modules.length; m++) {
        final (name, type, intro) = modules[m];
        moduleDtos.add(
          ModuleDto(
            id: _stableId('$courseTag-mod-$s-$m'),
            name: name,
            modType: type,
            intro: intro,
            orderIndex: m,
            fileUrl: type == 'resource'
                ? 'https://demo.moodle.local/pluginfile.php/$m/mod_resource/content/0/${Uri.encodeComponent(name)}.pdf'
                : null,
            filename: type == 'resource' ? '$name.pdf' : null,
            fileSize: type == 'resource' ? 240000 + m * 1000 : null,
            externalUrl: type == 'url' ? 'https://ar.wikipedia.org' : null,
          ),
        );
      }
      bundles.add(
        SectionBundleDto(
          section: SectionDto(
            id: sectionId,
            title: title,
            orderIndex: s,
          ),
          modules: moduleDtos,
        ),
      );
    }
    return bundles;
  }

  /// معرّف ثابت يبدأ بـ 9 كي لا يتصادم مع معرّفات Moodle الحقيقية.
  int _stableId(String raw) {
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = (hash * 31 + code) & 0x7FFFFFFF;
    }
    return 900000000 + (hash % 900000);
  }

  // ------------------------------------------------------------- الواجبات
  @override
  Future<List<AssignmentDto>> fetchAssignments(
    MoodleSession session,
    List<int> courseMoodleIds,
  ) async {
    await _delay();
    final now = DateTime.now();
    final all = <AssignmentDto>[
      AssignmentDto(
        id: 501,
        courseMoodleId: 101,
        name: 'حل التمارين 1 — 5 (الجبر)',
        intro: 'حل جميع تمارين الوحدة الأولى مع إظهار خطوات الحل.',
        dueAt: now.add(const Duration(days: 2, hours: 5)),
        submissionsFrom: now.subtract(const Duration(days: 3)),
      ),
      AssignmentDto(
        id: 502,
        courseMoodleId: 102,
        name: 'تقرير المختبر: تركيب الخلية',
        intro: 'أرفق تقريراً (PDF أو صور) لا يقل عن صفحتين.',
        dueAt: now.add(const Duration(days: 5)),
        allowLateSubmit: false,
      ),
      AssignmentDto(
        id: 503,
        courseMoodleId: 103,
        name: 'تحليل قصيدة الكاغد للمتنبي',
        intro: 'اكتب تحليلاً أدبياً في 300 كلمة على الأقل.',
        dueAt: now.subtract(const Duration(hours: 6)),
      ),
      AssignmentDto(
        id: 504,
        courseMoodleId: 104,
        name: 'Essay: My Family',
        intro: 'Write a short essay about your family (150 words).',
        dueAt: now.add(const Duration(days: 7)),
      ),
      AssignmentDto(
        id: 505,
        courseMoodleId: 101,
        name: 'واجب الوحدة الثانية: الدوال',
        intro: 'تم حلّه مسبقاً — راجع الدرجة.',
        dueAt: now.add(const Duration(days: 10)),
        status: 'submitted',
        submittedAt: now.subtract(const Duration(days: 1)),
        gradeText: '٩ من ١٠',
      ),
      AssignmentDto(
        id: 506,
        courseMoodleId: 103,
        name: 'تدريبات إعرابية — ورقة العمل',
        intro: 'أجب عن جميع التدريبات.',
        dueAt: now.add(const Duration(hours: 30)),
      ),
    ];
    final allowed = courseMoodleIds.toSet();
    return all.where((a) => allowed.contains(a.courseMoodleId)).toList();
  }

  @override
  Future<SubmissionStatusDto?> fetchSubmissionStatus(
    MoodleSession session,
    int assignmentMoodleId,
  ) async {
    await _delay();
    if (assignmentMoodleId == 505) {
      return const SubmissionStatusDto(
        status: 'submitted',
        gradeText: '٩ من ١٠',
      );
    }
    return const SubmissionStatusDto(status: 'notsubmitted');
  }

  // ------------------------------------------------------------- التقويم
  @override
  Future<List<CalendarEventDto>> fetchUpcomingEvents(
    MoodleSession session,
  ) async {
    await _delay();
    final now = DateTime.now();
    return [
      CalendarEventDto(
        id: _stableId('ev501'),
        name: 'تسليم: حل التمارين 1 — 5',
        startsAt: now.add(const Duration(days: 2, hours: 5)),
        courseMoodleId: 101,
        courseName: 'الرياضيات',
      ),
      CalendarEventDto(
        id: _stableId('ev503'),
        name: 'موعد تحليل قصيدة الكاغد (متأخر)',
        startsAt: now.subtract(const Duration(hours: 6)),
        courseMoodleId: 103,
        courseName: 'اللغة العربية',
      ),
      CalendarEventDto(
        id: _stableId('ev1'),
        name: 'حصة إضافية: مراجعة الجبر',
        startsAt: now.add(const Duration(days: 1)),
        courseMoodleId: 101,
        courseName: 'الرياضيات',
      ),
    ];
  }

  // ------------------------------------------------------------- الإشعارات
  @override
  Future<List<NotificationDto>> fetchNotifications(
    MoodleSession session,
  ) async {
    await _delay();
    final now = DateTime.now();
    return [
      NotificationDto(
        id: _stableId('n1'),
        title: 'درس جديد: أنواع الدوال',
        body: 'تم نشر درس جديد في مقرر الرياضيات.',
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
      NotificationDto(
        id: _stableId('n2'),
        title: 'تذكير بموعد تسليم قريب',
        body: 'يتبقى يومان على تسليم «حل التمارين 1 — 5».',
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NotificationDto(
        id: _stableId('n3'),
        title: 'تم تصحيح واجب',
        body: 'درجة واجب الدوال: ٩ من ١٠.',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // ------------------------------------------------------------- التسليم
  @override
  Future<void> submitText(
    MoodleSession session,
    int assignmentMoodleId,
    String text,
  ) async {
    await _delay();
    if (text.trim().isEmpty) {
      throw const MoodleSourceException('الإجابة فارغة');
    }
  }

  @override
  Future<void> submitFiles(
    MoodleSession session,
    int assignmentMoodleId,
    List<String> filePaths, {
    String? text,
  }) async {
    await _delay();
    if (filePaths.isEmpty && (text == null || text.trim().isEmpty)) {
      throw const MoodleSourceException('لا توجد مرفقات لإرسالها');
    }
  }
}
