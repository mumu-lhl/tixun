import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/features/language_learning/reading_practice.dart';
import 'package:tixun/features/practice/practice_store.dart';
import 'package:tixun/features/review/review_store.dart';

void main() {
  late AppDatabase db;
  late PracticeStore store;
  late ReviewStore review;
  final submit = find.widgetWithText(FilledButton, 'Submit answer');

  Widget app(EnglishReadingSkill skill) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ReadingPractice(store: store, skill: skill),
  );

  Future<void> open(
    WidgetTester tester,
    EnglishReadingSkill skill,
    String title,
  ) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      db = AppDatabase.memory();
      store = PracticeStore(db);
      review = ReviewStore(db);
    });
    addTearDown(() async {
      await store.whenIdle;
      store.dispose();
      review.dispose();
      await db.close();
    });
    await tester.pumpWidget(app(skill));
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<PracticeAttempt> grade(WidgetTester tester) async {
    expect(find.text('Evidence in the passage'), findsNothing);
    expect(find.text('View attempt history'), findsNothing);
    final graded = Completer<PracticeAttempt>();
    store.onGraded = (attempt) async {
      await review.record(attempt);
      graded.complete(attempt);
    };
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.runAsync(() => tester.tap(submit));
    for (var poll = 0; poll < 20 && !graded.isCompleted; poll++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    }
    expect(graded.isCompleted, isTrue);
    final result = await tester.runAsync(() async {
      await store.whenIdle;
      return graded.future;
    });
    await tester.pumpAndSettle();
    expect(find.text('Evidence in the passage'), findsOneWidget);
    return result!;
  }

  testWidgets('seven candidates map to five separately graded gaps', (
    tester,
  ) async {
    await open(
      tester,
      EnglishReadingSkill.sentenceInsertion,
      'A Garden for the Courtyard',
    );
    expect(find.byType(ChoiceChip), findsNWidgets(7));
    const answers = [
      'That first plan overlooked a basic problem.',
      'A neighbor suggested moving the boxes to the sunny wall.',
      'The children kept a simple record of what they saw.',
      'They shared those findings at the next neighborhood meeting.',
      'The garden also gave people a reason to stop and talk.',
    ];
    for (final (index, answer) in answers.indexed) {
      expect(find.text('Which sentence fits [${index + 1}]?'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tapVisible(tester, find.widgetWithText(ChoiceChip, answer));
      expect((await grade(tester)).correct, isTrue);
      if (index < answers.length - 1) {
        await tapVisible(tester, find.text('Next question'));
      }
    }
    await tapVisible(tester, find.text('Back to passages'));
    await tapVisible(tester, find.text('A Garden for the Courtyard'));
    expect(find.text('Which sentence fits [1]?'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(
      tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .any((c) => c.selected),
      isFalse,
    );
  });

  testWidgets('cloze retries keep the same question and separate attempts', (
    tester,
  ) async {
    await open(tester, EnglishReadingSkill.cloze, 'Bread Before School');
    await tapVisible(tester, find.text('count'));
    final wrong = await grade(tester);
    expect(wrong.correct, isFalse);
    await tester.runAsync(() async {
      final schedule = await review.forQuestion(wrong.questionId);
      expect(schedule?.lapses, 1);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(EnglishReadingSkill.cloze));
    await tapVisible(tester, find.text('Bread Before School'));
    await tapVisible(tester, find.text('collect'));
    final correct = await grade(tester);
    expect(correct.correct, isTrue);
    expect(correct.questionId, wrong.questionId);
    expect(correct.id, isNot(wrong.id));
    await tester.runAsync(() async {
      final detail = await store.detail(correct.questionId);
      expect(
        detail.attempts.map((attempt) => attempt.id),
        containsAll([wrong.id, correct.id]),
      );
      expect(detail.spec.stem, contains('He stopped to [1] them'));
      expect(await db.select(db.practiceQuestions).get(), hasLength(1));
    });
  });

  testWidgets(
    'grammar clears each input and accepts alternatives regardless of case',
    (tester) async {
      await open(tester, EnglishReadingSkill.grammarGap, 'Finding the Way');
      for (final answer in ['VISITED', 'on', 'to print', ' IF ']) {
        expect(tester.widget<FilledButton>(submit).onPressed, isNull);
        final field = find.byType(TextField);
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.enterText(field, answer);
        await tester.pumpAndSettle();
        final result = await grade(tester);
        expect(result.correct, isTrue);
        if (answer == ' IF ') {
          expect(find.textContaining('whether / if'), findsOneWidget);
        } else {
          await tapVisible(tester, find.text('Next question'));
          expect(
            tester
                .widget<EditableText>(
                  find.descendant(
                    of: field,
                    matching: find.byType(EditableText),
                  ),
                )
                .controller
                .text,
            isEmpty,
          );
        }
      }
    },
  );
}
