import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/reading_practice.dart';
import 'package:tixun/features/practice/practice_store.dart';

void main() {
  testWidgets(
    'reading hides feedback until submission and saves a reviewable attempt',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late final AppDatabase db;
      late final PracticeStore store;
      late final Completer<PracticeAttempt> graded;
      await tester.runAsync(() async {
        db = AppDatabase.memory();
        store = PracticeStore(db);
        graded = Completer<PracticeAttempt>();
        store.onGraded = (attempt) async => graded.complete(attempt);
      });
      addTearDown(() async {
        await store.whenIdle;
        store.dispose();
        await db.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReadingPractice(store: store),
        ),
      );
      await tester.tap(find.text('A Library for Seeds'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('They pay a fine.'));
      await tester.pumpAndSettle();
      expect(find.text('Evidence in the passage'), findsNothing);
      await tester.runAsync(() async {
        await tester.tap(find.text('Submit answer'));
        final attempt = await graded.future.timeout(const Duration(seconds: 5));
        await store.whenIdle;
        final detail = await store.detail(
          attempt.questionId,
          attemptId: attempt.id,
        );
        expect(detail.row.verification, 'template_checked');
        expect(attempt.correct, isFalse);
        expect(
          detail.spec.stem,
          contains('If your plants fail, the library asks for nothing back.'),
        );
        expect(
          detail.spec.explanation,
          contains('If your plants fail, the library asks for nothing back.'),
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('Evidence in the passage'), findsOneWidget);
      expect(find.text('View attempt history'), findsOneWidget);
    },
  );
}
