/// نماذج البيانات الواردة من Moodle (DTOs) — تُحوَّل لصفوف Drift في المحرك.
///
/// كل النماذج تحمل حقلاً اختيارياً لأن استجابات Moodle تختلف بين الإصدارات.
library;

/// مقرّر واحد من core_enrol_get_users_courses.
class CourseDto {
  const CourseDto({
    required this.id,
    required this.fullName,
    this.shortName = '',
    this.summary = '',
    this.imageUrl,
    this.progress,
    this.enrolledCount,
  });

  final int id;
  final String fullName;
  final String shortName;
  final String summary;
  final String? imageUrl;
  final double? progress;
  final int? enrolledCount;

  factory CourseDto.fromJson(Map<String, dynamic> json) => CourseDto(
        id: _asInt(json['id']) ?? 0,
        fullName: (json['fullname'] ?? json['shortname'] ?? '').toString(),
        shortName: (json['shortname'] ?? '').toString(),
        summary: _stripHtml((json['summary'] ?? '').toString()),
        imageUrl: json['overviewfiles'] is List &&
                (json['overviewfiles'] as List).isNotEmpty
            ? ((json['overviewfiles'] as List).first
                as Map<String, dynamic>)['fileurl'] as String?
            : null,
        progress: _asDouble(
            json['progress'] ?? json['progresspct'] ?? json['progress_pct']),
        enrolledCount: _asInt(json['enrolledusercount']),
      );
}

/// قسم داخل مقرر (من core_course_get_contents).
class SectionDto {
  const SectionDto({
    required this.id,
    required this.title,
    this.summary = '',
    this.orderIndex = 0,
    this.visible = true,
  });

  final int id;
  final String title;
  final String summary;
  final int orderIndex;
  final bool visible;

  factory SectionDto.fromJson(Map<String, dynamic> json) => SectionDto(
        id: _asInt(json['id']) ?? 0,
        title: (json['name'] ?? '').toString(),
        summary: _stripHtml((json['summary'] ?? '').toString()),
        orderIndex: _asInt(json['section']) ?? 0,
        visible: json['visible'] == null ? true : _asInt(json['visible']) != 0,
      );
}

/// عنصر/وحدة داخل القسم.
class ModuleDto {
  const ModuleDto({
    required this.id,
    required this.name,
    this.modType = 'resource',
    this.intro = '',
    this.externalUrl,
    this.fileUrl,
    this.filename,
    this.fileSize,
    this.orderIndex = 0,
    this.available = true,
  });

  final int id;
  final String name;
  final String modType;
  final String intro;
  final String? externalUrl;
  final String? fileUrl;
  final String? filename;
  final int? fileSize;
  final int orderIndex;
  final bool available;

  factory ModuleDto.fromJson(Map<String, dynamic> json, {int orderIndex = 0}) {
    String? fileUrl;
    String? filename;
    int? fileSize;
    final contents = json['contents'];
    if (contents is List && contents.isNotEmpty) {
      final first = contents.first as Map<String, dynamic>;
      fileUrl = first['fileurl'] as String?;
      filename = first['filename'] as String?;
      fileSize = _asInt(first['filesize']);
    }
    return ModuleDto(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      modType: (json['mod'] ?? 'resource').toString(),
      intro: (json['intro'] ?? '').toString(),
      externalUrl: json['url'] as String?,
      fileUrl: fileUrl,
      filename: filename,
      fileSize: fileSize,
      orderIndex: orderIndex,
      available: json['visible'] == null ? true : _asInt(json['visible']) != 0,
    );
  }
}

/// زوج (قسم + عناصره) لتسهيل كتابة المحرك دفعة واحدة.
class SectionBundleDto {
  const SectionBundleDto({required this.section, required this.modules});

  final SectionDto section;
  final List<ModuleDto> modules;
}

/// واجب من mod_assign_get_assignments (+ حالة من get_submission_status).
class AssignmentDto {
  const AssignmentDto({
    required this.id,
    required this.courseMoodleId,
    required this.name,
    this.intro = '',
    this.dueAt,
    this.submissionsFrom,
    this.allowLateSubmit = true,
    this.status,
    this.gradeText,
    this.onlineText,
    this.submittedAt,
  });

  final int id;
  final int courseMoodleId;
  final String name;
  final String intro;
  final DateTime? dueAt;
  final DateTime? submissionsFrom;
  final bool allowLateSubmit;
  final String? status;
  final String? gradeText;
  final String? onlineText;
  final DateTime? submittedAt;

  AssignmentDto copyWith({
    String? intro,
    String? status,
    String? gradeText,
    String? onlineText,
    DateTime? submittedAt,
  }) {
    return AssignmentDto(
      id: id,
      courseMoodleId: courseMoodleId,
      name: name,
      intro: intro ?? this.intro,
      dueAt: dueAt,
      submissionsFrom: submissionsFrom,
      allowLateSubmit: allowLateSubmit,
      status: status ?? this.status,
      gradeText: gradeText ?? this.gradeText,
      onlineText: onlineText ?? this.onlineText,
      submittedAt: submittedAt ?? this.submittedAt,
    );
  }

  factory AssignmentDto.fromJson(
    Map<String, dynamic> json, {
    int? courseMoodleIdFallback,
  }) {
    final courseId = _asInt(json['courseid']) ??
        _asInt(json['course']) ??
        courseMoodleIdFallback ??
        0;
    return AssignmentDto(
      id: _asInt(json['id']) ?? 0,
      courseMoodleId: courseId,
      name: (json['name'] ?? '').toString(),
      intro: (json['intro'] ?? json['introtext'] ?? '').toString(),
      dueAt: _asEpoch(_asInt(json['duedate'])),
      submissionsFrom: _asEpoch(_asInt(json['allowsubmissionsfromdate'])),
      allowLateSubmit: _asInt(json['nosubmissions']) != 1 &&
          json['cutoffdate'] == null,
    );
  }
}

/// موعد تقويم من core_calendar_get_action_events_by_timesort.
class CalendarEventDto {
  const CalendarEventDto({
    required this.id,
    required this.name,
    required this.startsAt,
    this.endsAt,
    this.courseMoodleId,
    this.courseName,
  });

  final int id;
  final String name;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? courseMoodleId;
  final String? courseName;

  factory CalendarEventDto.fromJson(Map<String, dynamic> json) {
    final course = json['course'];
    return CalendarEventDto(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      startsAt: _asEpoch(_asInt(json['timesort']) ?? _asInt(json['timestart'])) ??
          DateTime.now(),
      endsAt: _asEpoch(_asInt(json['timefinish'])),
      courseMoodleId: course is Map ? _asInt(course['id']) : null,
      courseName: course is Map ? (course['fullname'] as String?) : null,
    );
  }
}

/// إشعار من core_message_get_messages.
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.title,
    this.body = '',
    this.contextUrl,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final String? contextUrl;
  final DateTime createdAt;

  factory NotificationDto.fromJson(Map<String, dynamic> json) =>
      NotificationDto(
        id: _asInt(json['id']) ?? 0,
        title: (json['subject'] ?? json['smallmessage'] ?? '').toString(),
        body: _stripHtml((json['fullmessage'] ?? '').toString()),
        contextUrl: json['contexturl'] as String?,
        createdAt: _asEpoch(_asInt(json['timecreated'])) ?? DateTime.now(),
      );
}

/// حمولة طابور التسليم (تُخزَّن JSON داخل SyncQueueEntries.payload).
class SubmissionPayload {
  const SubmissionPayload({
    required this.assignmentMoodleId,
    this.text,
    this.filePaths = const [],
  });

  final int assignmentMoodleId;
  final String? text;
  final List<String> filePaths;

  Map<String, dynamic> toJson() => {
        'assignmentMoodleId': assignmentMoodleId,
        'text': text,
        'filePaths': filePaths,
      };

  factory SubmissionPayload.fromJson(Map<String, dynamic> json) =>
      SubmissionPayload(
        assignmentMoodleId: _asInt(json['assignmentMoodleId']) ?? 0,
        text: json['text'] as String?,
        filePaths: (json['filePaths'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

// ---------------------------------------------------------------------------
// أدوات تحويل آمنة (Moodle يرسل أرقاماً أحياناً كسلاسل نصية)
// ---------------------------------------------------------------------------

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.round();
  return int.tryParse(v.toString());
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _asEpoch(int? seconds) {
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

/// إزالة وسوم HTML بسيطة من النصوص (الوصف، المقدمة…) لعرضها ناتجة.
String _stripHtml(String html) {
  if (html.isEmpty) return html;
  final noTags = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return noTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .trim();
}
