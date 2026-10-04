import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/core/db/daos.dart';

import 'helpers/db_test_helpers.dart';

Assignment _assignment(String acc, int moodleId, String name, DateTime now) {
  return Assignment(
    id: '$acc:$moodleId',
    accountId: acc,
    courseId: '$acc:1',
    moodleId: moodleId,
    name: name,
    intro: '',
    allowLateSubmit: true,
    status: 'not_submitted',
    pendingSync: false,
    updatedAt: now,
  );
}

void main() {
  test('streams القاعدة معزولة بين الحسابات', () async {
    final db = await openTestDbOrNull();
    if (db == null) {
      skipWithoutSqlite();
      return;
    }
    addTearDown(db.close);

    final now = DateTime.now();

    // واجبات وإشعارات وأقسام لحسابين مختلفين (بالمعرّفات المركّبة).
    await db.into(db.assignments).insert(_assignment('acc-a', 1, 'واجب أ', now));
    await db.into(db.assignments).insert(_assignment('acc-b', 2, 'واجب ب', now));
    await db.into(db.localNotifications).insert(LocalNotification(
      id: 'acc-a:n1',
      accountId: 'acc-a',
      title: 'إشعار أ',
      body: '',
      isRead: false,
      createdAt: now,
    ));
    await db.into(db.localNotifications).insert(LocalNotification(
      id: 'acc-b:n2',
      accountId: 'acc-b',
      title: 'إشعار ب',
      body: '',
      isRead: false,
      createdAt: now,
    ));
    await db.into(db.courseSections).insert(CourseSection(
      id: 'acc-a:s1',
      accountId: 'acc-a',
      courseId: 'acc-a:c1',
      moodleId: 1,
      title: 'قسم أ',
      summary: '',
      orderIndex: 0,
      visible: true,
    ));
    // قسم من حساب ب يستخدم courseId نفسه — يجب ألا يظهر لأ.
    await db.into(db.courseSections).insert(CourseSection(
      id: 'acc-b:s2',
      accountId: 'acc-b',
      courseId: 'acc-a:c1',
      moodleId: 2,
      title: 'قسم ب مخترق',
      summary: '',
      orderIndex: 1,
      visible: true,
    ));

    final assignments = Daos(db);
    final forA = await assignments.assignments.watchAll('acc-a').first;
    expect(forA.map((a) => a.name), ['واجب أ']);
    final forB = await assignments.assignments.watchAll('acc-b').first;
    expect(forB.map((a) => a.name), ['واجب ب']);

    final notesA = await assignments.notifications.watchAll('acc-a').first;
    expect(notesA.single.title, 'إشعار أ');
    final notesB = await assignments.notifications.watchAll('acc-b').first;
    expect(notesB.single.title, 'إشعار ب');

    final sectionsA =
        await assignments.content.watchSections('acc-a', 'acc-a:c1').first;
    expect(sectionsA.single.title, 'قسم أ');
    expect(sectionsA.any((s) => s.title.contains('ب')), isFalse);
  });
}
