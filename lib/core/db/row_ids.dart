/// معرّفات صفوف مركّبة بصيغة "accountId:moodleId" —
/// تضمن عزل بيانات كل طالب حتى لو تساوى رقم Moodle بين حسابين.
String rowId(String accountId, int moodleId) => '$accountId:$moodleId';

/// معرّف صف قسم/وحدة/واجب من معرّف مقرر كامل مُركَّب.
String courseIdRow(String accountId, int courseMoodleId) =>
    rowId(accountId, courseMoodleId);
