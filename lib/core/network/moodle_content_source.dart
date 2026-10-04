import 'dart:convert';

import 'package:dio/dio.dart';

import '../l10n/app_strings.dart';
import 'content_source.dart';
import 'dio_client.dart';
import 'dto.dart';

/// مصدر المحتوى الحقيقي — كل دالة = wsfunction واحدة من Moodle.
///
/// قواعد عامة مطبَّقة هنا:
/// • POST form-urlencoded (Moodle يرفض JSON) مع مفاتيح bracket مسطّحة.
/// • استجابة الخادم قد تكون كائن استثناء {exception, errorcode, message}
///   حتى مع HTTP 200 — نفحصها ونحوّلها لـ MoodleSourceException.
/// • أخطاء الشبكة تُميَّز عبر isNetwork لإيقاف المحرك بدل إعادة المحاولة.
class MoodleContentSource implements ContentSource {
  MoodleContentSource(this._client);

  final DioClient _client;

  // ------------------------------------------------------------- النداء الأساسي
  Future<dynamic> _call(
    MoodleSession session,
    String fn, [
    Map<String, dynamic> params = const {},
  ]) async {
    final data = <String, dynamic>{
      'wstoken': session.token,
      'wsfunction': fn,
      'moodlewsrestformat': 'json',
      ...params,
    };
    try {
      final resp = await _client.dio.post<dynamic>(
        '${session.baseUrl}/webservice/rest/server.php',
        data: data,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final decoded = _decode(resp.data);
      if (decoded is Map && decoded['exception'] != null) {
        throw MoodleSourceException(
          (decoded['message'] ?? AppStrings.networkError).toString(),
          errorCode: decoded['errorcode']?.toString(),
        );
      }
      return decoded;
    } on DioException catch (e) {
      throw MoodleSourceException(
        messageForDioError(e),
        isNetwork: isNetworkError(e),
        errorCode: e.response?.statusCode?.toString(),
      );
    }
  }

  // ------------------------------------------------------------- القراءة
  @override
  Future<List<CourseDto>> fetchCourses(MoodleSession session) async {
    final userId = session.userId;
    if (userId == null) {
      throw const MoodleSourceException('تعذّر تحديد هوية الطالب');
    }
    final data = await _call(
      session,
      'core_enrol_get_users_courses',
      {'userid': userId},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((m) => CourseDto.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<SectionBundleDto>> fetchCourseContents(
    MoodleSession session,
    int courseMoodleId,
  ) async {
    final data = await _call(
      session,
      'core_course_get_contents',
      {'courseid': courseMoodleId},
    );
    if (data is! List) return const [];
    final bundles = <SectionBundleDto>[];
    for (final raw in data.whereType<Map>()) {
      final json = raw.cast<String, dynamic>();
      final section = SectionDto.fromJson(json);
      if (section.id == 0) continue;
      final modulesJson = json['modules'];
      final modules = <ModuleDto>[];
      if (modulesJson is List) {
        var index = 0;
        for (final m in modulesJson.whereType<Map>()) {
          modules.add(
            ModuleDto.fromJson(m.cast<String, dynamic>(), orderIndex: index),
          );
          index++;
        }
      }
      bundles.add(SectionBundleDto(section: section, modules: modules));
    }
    return bundles;
  }

  @override
  Future<List<AssignmentDto>> fetchAssignments(
    MoodleSession session,
    List<int> courseMoodleIds,
  ) async {
    if (courseMoodleIds.isEmpty) return const [];
    final params = <String, dynamic>{
      for (var i = 0; i < courseMoodleIds.length; i++)
        'courseids[$i]': courseMoodleIds[i],
    };
    final data = await _call(session, 'mod_assign_get_assignments', params);
    if (data is! Map) return const [];
    final courses = data['courses'];
    if (courses is! List) return const [];
    final result = <AssignmentDto>[];
    for (final raw in courses.whereType<Map>()) {
      final json = raw.cast<String, dynamic>();
      final courseId = (json['id'] is num) ? (json['id'] as num).toInt() : 0;
      final assignments = json['assignments'];
      if (assignments is! List) continue;
      for (final a in assignments.whereType<Map>()) {
        result.add(
          AssignmentDto.fromJson(
            a.cast<String, dynamic>(),
            courseMoodleIdFallback: courseId,
          ),
        );
      }
    }
    return result;
  }

  @override
  Future<SubmissionStatusDto?> fetchSubmissionStatus(
    MoodleSession session,
    int assignmentMoodleId,
  ) async {
    final data = await _call(
      session,
      'mod_assign_get_submission_status',
      {'assignmentid': assignmentMoodleId},
    );
    if (data is! Map) return null;
    final json = data.cast<String, dynamic>();

    String? status;
    String? onlineText;
    DateTime? submittedAt;

    // آخر محاولة (أو المحاولة الحالية) تحمل الحالة والإجابة النصية.
    final attempt = json['lastattempt'] ?? json['firstattempt'];
    if (attempt is Map) {
      final submission = attempt['submission'];
      if (submission is Map) {
        status = submission['status']?.toString();
        final modified = submission['timemodified'];
        if (modified is num && modified > 0) {
          submittedAt =
              DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000);
        }
      }
    }
    status ??= json['submissionstatus']?.toString();

    // الإجابة النصية من بلجن onlinetext داخل plugins.
    final plugins = json['plugins'];
    if (plugins is List) {
      for (final p in plugins.whereType<Map>()) {
        if (p['type']?.toString() != 'onlinetext') continue;
        final fields = p['editorfields'];
        if (fields is List && fields.isNotEmpty) {
          final first = fields.first;
          if (first is Map) onlineText = first['text']?.toString();
        }
      }
    }

    // الدرجة إن وجدت (assign grades تأتي من مسار gradefeedback أو assignment).
    String? grade;
    final feedback = json['gradefeedback'] ?? json['feedback'];
    if (feedback is Map) {
      grade = (feedback['grade'] ?? feedback['gradetext'])?.toString();
    }

    return SubmissionStatusDto(
      status: status,
      onlineText: onlineText,
      gradeText: grade,
      submittedAt: submittedAt,
    );
  }

  @override
  Future<List<CalendarEventDto>> fetchUpcomingEvents(
    MoodleSession session,
  ) async {
    final now = DateTime.now();
    final data = await _call(
      session,
      'core_calendar_get_action_events_by_timesort',
      {
        'timestart': now.subtract(const Duration(days: 1)).millisecondsSinceEpoch ~/
            1000,
        'timesortuntil':
            now.add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
        'limitnum': 50,
        'orderdirection': 'asc',
      },
    );
    if (data is! Map) return const [];
    final events = data['events'];
    if (events is! List) return const [];
    return events
        .whereType<Map>()
        .map((e) => CalendarEventDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<List<NotificationDto>> fetchNotifications(
    MoodleSession session,
  ) async {
    final data = await _call(
      session,
      'core_message_get_messages',
      {'type': 'notifications', 'newestfirst': 1, 'limitnum': 20},
    );
    if (data is! Map) return const [];
    final messages = data['messages'];
    if (messages is! List) return const [];
    return messages
        .whereType<Map>()
        .map((m) => NotificationDto.fromJson(m.cast<String, dynamic>()))
        .toList();
  }

  // ------------------------------------------------------------- التسليم
  @override
  Future<void> submitText(
    MoodleSession session,
    int assignmentMoodleId,
    String text,
  ) async {
    await _call(
      session,
      'mod_assign_save_submission',
      {
        'assignmentid': assignmentMoodleId,
        'plugindata[onlinetext_editor][text]': text,
        'plugindata[onlinetext_editor][format]': '1',
        'plugindata[onlinetext_editor][itemid]': '0',
      },
    );
    await _submitForGrading(session, assignmentMoodleId);
  }

  @override
  Future<void> submitFiles(
    MoodleSession session,
    int assignmentMoodleId,
    List<String> filePaths, {
    String? text,
  }) async {
    // رفع كل الملفات داخل نفس مناطق المسودة (itemid واحد يُعاد استخدامه).
    var itemid = 0;
    for (var i = 0; i < filePaths.length; i++) {
      itemid = await _uploadFile(session, filePaths[i], i == 0 ? 0 : itemid);
    }

    final params = <String, dynamic>{
      'assignmentid': assignmentMoodleId,
      'plugindata[files_filemanager]': itemid.toString(),
    };
    if (text != null && text.trim().isNotEmpty) {
      params['plugindata[onlinetext_editor][text]'] = text;
      params['plugindata[onlinetext_editor][format]'] = '1';
      params['plugindata[onlinetext_editor][itemid]'] = '0';
    }
    await _call(session, 'mod_assign_save_submission', params);
    await _submitForGrading(session, assignmentMoodleId);
  }

  /// رفع ملف واحد إلى upload.php ويعيد itemid منطقة المسودة.
  Future<int> _uploadFile(
    MoodleSession session,
    String path,
    int itemid,
  ) async {
    try {
      final resp = await _client.dio.post<dynamic>(
        '${session.baseUrl}/webservice/upload.php',
        data: FormData.fromMap({'file': fileFromPath(path)}),
        queryParameters: {'token': session.token, 'itemid': itemid},
      );
      final decoded = _decode(resp.data);
      int? returned;
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) returned = _asInt(first['itemid']);
      } else if (decoded is Map) {
        returned = _asInt(decoded['itemid']);
      }
      return returned ?? itemid;
    } on DioException catch (e) {
      throw MoodleSourceException(
        messageForDioError(e),
        isNetwork: isNetworkError(e),
        errorCode: e.response?.statusCode?.toString(),
      );
    }
  }

  /// إقرار التسليم النهائي — بعض إعدادات Moodle لا تتطلب هذه الخطوة،
  /// وبعض الأخطاء تعني "سُلِّم مسبقاً" فلا نعتبرها فشلاً.
  Future<void> _submitForGrading(
    MoodleSession session,
    int assignmentMoodleId,
  ) async {
    try {
      await _call(
        session,
        'mod_assign_submit_for_grading',
        {
          'assignmentid': assignmentMoodleId,
          'acceptsubmissionstatement': '1',
        },
      );
    } on MoodleSourceException catch (e) {
      final code = (e.errorCode ?? '').toLowerCase();
      if (code.contains('already') ||
          code.contains('nosubmission') ||
          code.contains('nothing')) {
        return;
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------- أدوات
  static dynamic _decode(dynamic raw) {
    if (raw is String) {
      try {
        return jsonDecode(raw);
      } catch (_) {
        return raw;
      }
    }
    return raw;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
