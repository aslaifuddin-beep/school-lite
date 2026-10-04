import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_lite/core/db/app_database.dart';
import 'package:school_lite/core/db/database_provider.dart';
import 'package:school_lite/core/l10n/app_strings.dart';
import 'package:school_lite/features/accounts/application/accounts_providers.dart';
import 'package:school_lite/features/assignments/presentation/assignments_tab.dart';
import 'package:school_lite/features/courses/presentation/course_detail_screen.dart';
import 'package:school_lite/features/dashboard/presentation/home_tab.dart';
import 'package:school_lite/features/notifications/presentation/notifications_tab.dart';

import 'helpers/test_helpers.dart';

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  Future<void> pumpLarge(WidgetTester tester, ProviderContainer c, Widget w) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(c, w));
    await tester.pumpAndSettle();
  }

  testWidgets('الرئيسية تعرض أقسامها الثلاثة مع حالات الفراغ', (tester) async {
    final c = await createContainer();
    await addDemoAccount(c, name: 'طالب تجريبي');

    await pumpLarge(tester, c, const HomeTab());

    expect(find.text(AppStrings.upcomingAssignments), findsOneWidget);
    expect(find.text(AppStrings.todayMaterials), findsOneWidget);
    expect(find.text(AppStrings.latestNotifications), findsOneWidget);
    expect(find.text(AppStrings.noUpcomingAssignments), findsOneWidget);
    expect(find.text(AppStrings.noNotifications), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الرئيسية تعرض واجباً قادماً وتفتح ورقة التسليم', (tester) async {
    final c = await createContainer();
    await addDemoAccount(c, name: 'طالب تجريبي');
    final db = c.read(databaseProvider);
    final account = c.read(activeAccountProvider)!;

    await db.into(db.assignments).insert(Assignment(
      id: '${account.id}:50',
      accountId: account.id,
      courseId: '${account.id}:1',
      moodleId: 50,
      name: 'واجب العلوم',
      dueAt: DateTime.now().add(const Duration(hours: 6)),
      updatedAt: DateTime.now(),
    ));

    await pumpLarge(tester, c, const HomeTab());

    expect(find.text('واجب العلوم'), findsWidgets);
    await tester.tap(find.text('واجب العلوم').first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.submitOffline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الواجبات: فراغ ← واجب مع فلاتر ← فتح ورقة التسليم', (tester) async {
    final c = await createContainer();
    await addDemoAccount(c, name: 'طالب تجريبي');
    final db = c.read(databaseProvider);
    final account = c.read(activeAccountProvider)!;

    await pumpLarge(tester, c, const AssignmentsTab());
    expect(find.text(AppStrings.noAssignments), findsOneWidget);

    await db.into(db.assignments).insert(Assignment(
      id: '${account.id}:77',
      accountId: account.id,
      courseId: '${account.id}:1',
      moodleId: 77,
      name: 'واجب الرياضيات',
      dueAt: DateTime.now().add(const Duration(hours: 5)),
      updatedAt: DateTime.now(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('واجب الرياضيات'), findsWidgets);
    expect(find.text(AppStrings.allTasks), findsOneWidget);
    expect(find.text(AppStrings.dueSoonTasks), findsOneWidget);
    expect(find.text(AppStrings.upcomingTasks), findsOneWidget);

    await tester.tap(find.text('واجب الرياضيات').first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.submitOffline), findsOneWidget);

    // إغلاق الورقة بالنقر خارجها.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.submitOffline), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الإشعارات: عرض + زر تحديد الكل كمقروء', (tester) async {
    final c = await createContainer();
    await addDemoAccount(c, name: 'طالب تجريبي');
    final db = c.read(databaseProvider);
    final account = c.read(activeAccountProvider)!;

    await db.into(db.localNotifications).insert(LocalNotification(
      id: '${account.id}:n1',
      accountId: account.id,
      title: 'أول إشعار',
      body: 'نص أول إشعار',
      createdAt: DateTime.now(),
    ));
    await db.into(db.localNotifications).insert(LocalNotification(
      id: '${account.id}:n2',
      accountId: account.id,
      title: 'ثاني إشعار',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ));

    await pumpLarge(tester, c, const NotificationsTab());

    expect(find.text('أول إشعار'), findsOneWidget);
    expect(find.text('ثاني إشعار'), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.markAllRead),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, AppStrings.markAllRead));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextButton, AppStrings.markAllRead),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('تفاصيل المقرر: فراغ عند غياب الأقسام', (tester) async {
    final c = await createContainer();
    await addDemoAccount(c, name: 'طالب تجريبي');
    final account = c.read(activeAccountProvider)!;

    await pumpLarge(
      tester,
      c,
      CourseDetailScreen(
        args: CourseDetailArgs(id: '${account.id}:9', title: 'رياضيات'),
      ),
    );

    expect(find.text('رياضيات'), findsOneWidget);
    expect(find.text('ستظهر أقسام المقرر ووحداته بعد المزامنة الأولى.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
