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
      await tester.runAsync(
        () => store.saveEntries(
          language: "en",
          groupTitle: "Words",
          groupType: VocabularyGroupType.topic,
          entries: const [
            VocabularyEntry(form: "alpha", meaning: "first"),
            VocabularyEntry(form: "beta", meaning: "second"),
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
      final missed = find.text("alpha").evaluate().isNotEmpty
          ? "alpha"
          : "beta";
      final passed = missed == "alpha" ? "beta" : "alpha";
      await tap(l10n.languageReveal);
      await tap(l10n.languageForgot);
      await tap(l10n.languageReveal);
      await tap(l10n.languageRemembered);
      expect(find.text(l10n.languageRecallRetry), findsOneWidget);
      await tap(l10n.languageRecallRetry);
      expect(find.text(missed), findsOneWidget);
      expect(find.text(passed), findsNothing);
      expect(find.text(missed == "alpha" ? "first" : "second"), findsNothing);
      await tap(l10n.languageReveal);
      await tap(l10n.languageRemembered);
      expect(find.text(l10n.languageRecallRetry), findsNothing);
      expect(find.text(l10n.languageBatchComplete), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final evidence = await store.recentEvidence("en").first;
        expect(evidence, hasLength(3));
      });
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      await tester.runAsync(db.close);
    });
  }
}
