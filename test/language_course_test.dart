import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/language_course.dart';
import 'package:tixun/features/practice/practice_store.dart';

void main() {
  testWidgets(
    'a completed check unlocks the next English lesson and keeps Japanese separate',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final db = AppDatabase.memory();
      final store = PracticeStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await tester.runAsync(() => db.select(db.practiceAttempts).get());
      Widget app() => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LanguageCourse(practice: store),
      );
      Future<void> settleData() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)),
          );
          await tester.pump(const Duration(milliseconds: 30));
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
            await tester.pumpAndSettle();
            return;
          }
        }
        fail('Course progress did not load');
      }

      await tester.pumpWidget(app());
      await settleData();
      final next = find.widgetWithText(ListTile, 'High-frequency words');
      expect(tester.widget<ListTile>(next).enabled, isFalse);
      await tester.tap(find.text('Letters and short vowels'));
      await tester.pumpAndSettle();
      expect(find.text('cat, hat'), findsOneWidget);
      expect(find.text('Submit answer'), findsNothing);
      await tester.tap(find.text('Check understanding'));
      await tester.pumpAndSettle();
      expect(find.text('cat, hat'), findsNothing);
      await tester.tap(find.text('hat'));
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Submit answer');
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(submit));
      for (var i = 0; i < 20 && find.text('Correct').evaluate().isEmpty; i++) {
        await settleData();
        expect(find.byType(SnackBar), findsNothing);
      }
      expect(find.text('Correct'), findsOneWidget);
      await tester.runAsync(() => tester.tap(find.text('Back to lessons')));
      await settleData();
      expect(find.text('1 of 6 lessons completed'), findsOneWidget);
      expect(tester.widget<ListTile>(next).enabled, isTrue);
      await tester.runAsync(() => tester.tap(find.text('Japanese')));
      await settleData();
      expect(find.text('0 of 3 lessons completed'), findsOneWidget);
      expect(find.text('The five hiragana vowels'), findsOneWidget);
      final later = find.widgetWithText(ListTile, 'First greetings');
      expect(tester.widget<ListTile>(later).enabled, isFalse);
      await tester.tap(find.text('Browse all lessons'));
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(later).enabled, isTrue);
      expect(find.text('0 of 3 lessons completed'), findsOneWidget);
    },
  );
}
