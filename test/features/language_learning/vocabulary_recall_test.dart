import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/vocabulary_batch.dart";

void main() {
  for (final width in [320.0, 1200.0]) {
    testWidgets("recall retries only missed words at $width", (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(
        () => tester.runAsync(() async {
          await store.whenIdle;
          store.dispose();
          await db.close();
        }),
      );
      await tester.runAsync(
        () => store.saveEntries(
          language: "en",
          groupTitle: "Words",
          groupType: VocabularyGroupType.topic,
          entries: const [
            VocabularyEntry(form: "alpha", meaning: "first"),
            VocabularyEntry(form: "beta", meaning: "second"),
            VocabularyEntry(form: "gamma", meaning: "third"),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.6 : 1)),
            child: child!,
          ),
          home: VocabularyBatch(
            store: store,
            language: "en",
            mode: VocabularyMode.recall,
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 80));
        }
      }

      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await settle();
      }

      await settle();
      final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
      final skip = find.text(l10n.languageSkipCard);
      const meanings = {"alpha": "first", "beta": "second", "gamma": "third"};
      String visibleWord() => meanings.keys.singleWhere(
        (word) => find.text(word).evaluate().isNotEmpty,
      );
      final skipped = visibleWord();
      await tap(l10n.languageReveal);
      await tap(l10n.languageSkipCard);
      final missed = visibleWord();
      expect(missed, isNot(skipped));
      await tap(l10n.languageReveal);
      final bounds = [
        for (final label in [
          l10n.languageForgot,
          l10n.languageFuzzy,
          l10n.languageRemembered,
          l10n.languageEasy,
        ])
          tester.getRect(find.widgetWithText(OutlinedButton, label)),
      ];
      expect(bounds[0].top, bounds[1].top);
      expect(bounds[0].height, bounds[1].height);
      expect(bounds[2].top, bounds[3].top);
      expect(bounds[2].height, bounds[3].height);
      expect(bounds[2].top, greaterThan(bounds[0].bottom));
      expect(bounds[0].left, bounds[2].left);
      expect(bounds[1].left, bounds[3].left);
      expect(bounds.map((rect) => rect.width).toSet(), hasLength(1));
      expect(tester.getRect(skip).bottom, lessThan(bounds[0].top));
      await tap(l10n.languageForgot);
      final passed = visibleWord();
      await tap(l10n.languageReveal);
      await tap(l10n.languageRemembered);
      expect(find.text(l10n.languageRecallRetry), findsOneWidget);
      await tap(l10n.languageRecallRetry);
      expect(find.text(missed), findsOneWidget);
      expect(find.text(passed), findsNothing);
      expect(find.text(skipped), findsNothing);
      expect(find.text(meanings[missed]!), findsNothing);
      await tap(l10n.languageReveal);
      await tap(l10n.languageRemembered);
      expect(find.text(l10n.languageRecallRetry), findsNothing);
      expect(find.text(l10n.languageBatchComplete), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final evidence = await store.recentEvidence("en").first;
        expect(evidence, hasLength(3));
        final cards = await store.cards(language: "en");
        final skippedSense = cards
            .singleWhere((card) => card.item.form == skipped)
            .sense;
        expect(evidence.any((row) => row.senseId == skippedSense.id), isFalse);
      });
      await tester.pumpWidget(const SizedBox());
    });
  }
}
