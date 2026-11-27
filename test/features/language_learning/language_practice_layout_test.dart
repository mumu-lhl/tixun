import "../../support/exam_bundled.dart";

import "dart:io";
import "dart:ui" show PointerDeviceKind;

import "package:flutter/rendering.dart";
import "package:flutter/services.dart";

import "package:tixun/features/language_learning/exam_store.dart";
import "package:tixun/app/theme.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/writing_ai.dart";
import "package:tixun/features/language_learning/writing_store.dart";
import "package:tixun/features/language_learning/writing_practice.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_practice.dart";
import "package:tixun/features/language_learning/sentence_explanation.dart";
import "package:tixun/features/language_learning/vocabulary_batch.dart";
import "package:tixun/features/language_learning/exam_ai.dart";
import "package:tixun/features/language_learning/exam_material.dart";
import "package:tixun/features/language_learning/exam_paper_screen.dart";
import "package:tixun/features/language_learning/sentence_content.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/language_learning/study_settings_dialog.dart";
import "package:tixun/features/language_learning/vocabulary_groups_screen.dart";

const config = ProviderConfig(
  id: 1,
  kind: "openai",
  baseUrl: "https://example.com",
  model: "test-model",
  vision: false,
  supportsTools: false,
  thinking: false,
  supportsThinking: false,
  effort: "",
);

class _WaitingProvider implements ChatProvider {
  bool started = false;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        started = true;
        await cancel.whenCancel;
      });
}

void main({
  Future<void> Function(WidgetTester, String)? capture,
  Future<void> Function(WidgetTester, Finder, String)? enterText,
}) {
  late AppDatabase db;
  late LanguageLearningStore store;
  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
  });
  tearDown(() async {
    await store.whenIdle;
    store.dispose();
    await db.close();
  });

  Widget app(
    Widget page, {
    double scale = 1,
    ThemeData? theme,
    Locale locale = const Locale("en"),
  }) => ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  Future<void> flush(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
  }

  for (final (width, locale) in [
    (360.0, const Locale("zh")),
    (1200.0, const Locale("en")),
  ]) {
    testWidgets("FSRS settings and all-group vocabulary work at width $width", (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late AppController controller;
      late Directory root;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp("tixun-fsrs-ui-");
        controller = AppController(
          db,
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
          demo: true,
        );
        await controller.initialize(seed: false);
        await controller.preferences.setVocabularyPracticeSize(1);
        for (final group in ["Group A", "Group B"]) {
          await controller.language.saveEntries(
            language: "en",
            groupTitle: group,
            groupType: VocabularyGroupType.topic,
            entries: [
              const VocabularyEntry(form: "shared", meaning: "Shared meaning"),
              VocabularyEntry(
                form: group == "Group A" ? "alpha" : "beta",
                meaning: "Meaning of $group",
              ),
            ],
          );
        }
      });
      addTearDown(
        () => tester.runAsync(() async {
          await controller.preferences.whenIdle;
          await controller.language.whenIdle;
          controller.dispose();
          await root.delete(recursive: true);
        }),
      );
      final prefs = controller.preferences;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appControllerProvider.overrideWith((_) => controller)],
          child: app(
            Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => editLanguageStudy(context, prefs),
                      child: const Text("Settings"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocabularyGroupsScreen(),
                        ),
                      ),
                      child: const Text("Vocabulary"),
                    ),
                  ],
                ),
              ),
            ),
            locale: locale,
            scale: 1.6,
            theme: appTheme(Brightness.light),
          ),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump(const Duration(milliseconds: 500));
        await flush(tester);
      }

      Future<void> settings() async {
        await tap(find.text("Settings"));
        await tap(find.text(l10n.languageVocabularyReviewSettings));
      }

      await settings();
      expect(find.text(l10n.languageReviewRetention(90)), findsOneWidget);
      await tap(find.byType(Switch));
      final slider = find.byType(Slider);
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getRect(slider).centerRight - const Offset(12, 0),
      );
      await flush(tester);
      expect(find.text(l10n.languageReviewRetention(97)), findsOneWidget);
      await tap(find.text(l10n.languageReviewAdvanced));
      final maximum = find.byKey(const Key("vocabulary-review-maximum"));
      final typeText = enterText == null
          ? tester.enterText
          : (Finder field, String text) => enterText(tester, field, text);
      if (capture != null) {
        await capture(tester, "fsrs-settings-${width.toInt()}");
      }
      final save = find.byKey(const Key("save-vocabulary-review-settings"));
      await tester.ensureVisible(maximum);
      await typeText(maximum, "36501");
      await tap(save);
      expect(find.text(l10n.languageReviewMaximumInvalid), findsOneWidget);
      expect(prefs.vocabularyReview.enabled, isFalse);
      await tester.ensureVisible(maximum);
      await typeText(maximum, "1");
      expect(tester.widget<TextField>(maximum).controller!.text, "1");
      await tap(save);
      await tester.runAsync(() => prefs.whenIdle);
      await flush(tester);
      expect(prefs.vocabularyReview.maximumInterval, 1);
      expect(prefs.vocabularyReview.retentionPercent, 97);
      expect(prefs.vocabularyReview.enabled, isTrue);
      await tap(find.widgetWithText(TextButton, l10n.cancel));

      await tap(find.text("Vocabulary"));
      await tap(find.text(l10n.languagePracticeMode));
      await tap(find.text(l10n.languagePracticeAllWords));
      final groupBatch = find.byType(VocabularyBatch);
      expect(tester.widget<VocabularyBatch>(groupBatch).allGroups, isTrue);
      final seen = <String>{};
      for (var round = 0; round < 3; round++) {
        final words = ["shared", "alpha", "beta"];
        final visible = words.singleWhere(
          (word) => find.text(word).evaluate().isNotEmpty,
        );
        expect(seen.add(visible), isTrue);
        expect(find.text(l10n.languageNewVocabularyCard), findsOneWidget);
        await tap(find.text(l10n.languageReveal));
        if (round == 0 && capture != null) {
          await capture(tester, "fsrs-${width.toInt()}");
        }
        await tap(find.text(l10n.languageRemembered));
        if (round < 2) await tap(find.text(l10n.languageNextBatch));
      }
      expect(find.text(l10n.languageNextBatch), findsNothing);
      final schedules = await tester.runAsync(
        () => controller.db.select(controller.db.learningReviewSchedules).get(),
      );
      expect(schedules, hasLength(3));
      expect(
        schedules!.every(
          (row) =>
              row.intervalDays == 1 &&
              row.repetitions == 1 &&
              row.fsrsVersion != null,
        ),
        isTrue,
      );
      await tap(find.byTooltip(l10n.languageFreePractice));
      await tap(find.text(l10n.languageReveal));
      await tap(find.text(l10n.languageRemembered));
      final afterPractice = await tester.runAsync(
        () => controller.db.select(controller.db.learningReviewSchedules).get(),
      );
      expect(afterPractice, schedules);
      for (var back = 0; back < 3; back++) {
        await tap(find.byType(BackButton));
      }
      await settings();
      expect(find.text(l10n.languageReviewRetention(97)), findsOneWidget);
      await tap(find.text(l10n.languageReviewReset));
      await tap(save);
      await tester.runAsync(() => prefs.whenIdle);
      await flush(tester);
      expect(prefs.vocabularyReview.retentionPercent, 90);
      expect(prefs.vocabularyReview.maximumInterval, 180);
      expect(prefs.vocabularyReview.enabled, isTrue);
      expect(
        await tester.runAsync(
          () =>
              controller.db.select(controller.db.learningReviewSchedules).get(),
        ),
        schedules,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    "study spaces list entries and keeps flashcard translations private until revealed",
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        for (final (index, word) in ["station", "ticket"].indexed) {
          await store.saveEntries(
            language: "en",
            groupTitle: "Travel",
            groupType: VocabularyGroupType.topic,
            now: DateTime.utc(2026, 1, index + 1),
            entries: [
              VocabularyEntry(
                form: word,
                meaning: "Meaning of $word",
                partOfSpeech: "n.",
                example: "Example with $word",
                translation: "Translation of $word",
              ),
            ],
          );
        }
      });
      await tester.pumpWidget(
        app(
          VocabularyBatch(
            store: store,
            language: "en",
            mode: VocabularyMode.study,
          ),
          scale: 1.6,
          theme: appTheme(Brightness.light),
        ),
      );
      await flush(tester);
      final cards = find.byType(Card);
      expect(cards, findsNWidgets(2));
      expect(
        tester.getTopLeft(cards.last).dy - tester.getBottomLeft(cards.first).dy,
        greaterThanOrEqualTo(8),
      );

      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.text("Flashcards"));
      expect(cards, findsOneWidget);
      expect(find.text("station"), findsOneWidget);
      expect(find.text("ticket"), findsNothing);
      for (final label in [
        "station",
        "n.",
        "Meaning of station",
        "Example with station",
      ]) {
        expect(
          tester.getCenter(find.text(label)).dx,
          closeTo(tester.getCenter(cards).dx, 1),
        );
      }
      expect(find.text("Translation of station"), findsNothing);
      final navigationY = tester
          .getCenter(find.byKey(const Key("flashcard-navigation")))
          .dy;
      await tap(find.text("Show translation"));
      expect(find.text("Translation of station"), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const Key("flashcard-navigation"))).dy,
        navigationY,
      );

      await tap(find.byTooltip("Next"));
      expect(
        tester.getCenter(find.byKey(const Key("flashcard-navigation"))).dy,
        navigationY,
      );
      expect(find.text("2 / 2"), findsOneWidget);
      expect(find.text("Example with ticket"), findsOneWidget);
      expect(find.text("Translation of ticket"), findsNothing);
      await tap(find.byTooltip("Previous card"));
      expect(find.text("Example with station"), findsOneWidget);
      expect(find.text("Translation of station"), findsNothing);
      await tap(find.byTooltip("Random card"));
      expect(find.text("ticket"), findsOneWidget);
      expect(find.text("station"), findsNothing);

      await tap(find.text("List"));
      expect(cards, findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 1200.0]) {
    testWidgets("practice screens at width $width and large text", (
      tester,
    ) async {
      tester.view.reset();
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(
        () => store.saveEntries(
          language: "en",
          groupTitle: "Travel",
          groupType: VocabularyGroupType.topic,
          entries: const [
            VocabularyEntry(
              form: "station",
              meaning: "A place where trains stop.",
              partOfSpeech: "n.",
              example: "The station is busy.",
              application:
                  "Complete the sentence: I waited for the train at the ___.",
              applicationAnswer: "station",
            ),
          ],
        ),
      );
      final provider = MockChatProvider();
      final exam = ExamAi(store: store, provider: provider, config: config);
      final sample = bundledExamPapers(ExamKind.grammar).single;
      final material = await tester.runAsync(
        () => store.saveExamMaterial(
          target: ExamTarget(
            kind: ExamKind.grammar,
            level: SentenceLevel.beginner,
            count: sample.paper.items.length,
          ),
          paper: sample.paper,
          source: ExamSource.bundled,
          id: sample.id,
        ),
      );
      final pages = <String, Widget>{
        "writing": WritingPractice(
          store: store,
          ai: WritingAi(
            store: store,
            provider: provider,
            config: config,
            task: WritingTask(
              "layout",
              List.filled(12, "Write about a memorable experience.").join(" "),
            ),
          ),
        ),
        "sentence": SentencePractice(
          store: store,
          initialBatch: SentenceBatch([
            SentenceCard(
              id: "layout",
              text: "On Saturdays, the library closes at noon rather than at six.",
              translation: "图书馆周六中午关门，不是六点。" * 20,
              hint: "Rather than contrasts two times. " * 20,
              question: "When does it close?",
              choices: const ["At six", "At noon"],
              correctIndex: 1,
              skill: SentenceSkill.detail,
              level: SentenceLevel.beginner,
            ),
          ]),
          explanation: SentenceExplanation(
            store: store,
            provider: provider,
            config: config,
          ),
        ),
        "context-setup": SentencePractice(
          store: store,
          kind: SentencePracticeKind.newContext,
          batchAi: SentenceBatchAi(provider: provider, config: config),
          explanation: SentenceExplanation(
            store: store,
            provider: provider,
            config: config,
          ),
        ),
        "context-answer": SentencePractice(
          store: store,
          initialBatch: SentenceBatch([
            const SentenceCard(
              id: "context-station",
              text: "Before boarding, Maya asked the station staff which platform to use.",
              translation: "上车前，玛雅向车站工作人员询问站台。",
              hint: "Notice boarding and platform.",
              question: "What does station refer to here?",
              choices: [
                "A place where trains stop.",
                "A radio company.",
                "A person's social position.",
              ],
              correctIndex: 0,
              skill: SentenceSkill.meaningInContext,
              level: SentenceLevel.beginner,
            ),
          ], kind: SentencePracticeKind.newContext),
          explanation: SentenceExplanation(
            store: store,
            provider: provider,
            config: config,
          ),
        ),
        "recall": VocabularyBatch(
          store: store,
          language: "en",
          mode: VocabularyMode.recall,
        ),
        "exam": ExamPaperScreen(ai: exam, material: material!),
      };
      for (final entry in pages.entries) {
        await tester.pumpWidget(
          app(entry.value, scale: 1.6, theme: appTheme(Brightness.light)),
        );
        await flush(tester);
        expect(tester.takeException(), isNull, reason: entry.key);
        final l10n = AppLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        );
        if (entry.key == "sentence") {
          for (final label in [
            l10n.languageSentenceHint,
            l10n.languageSentenceTranslation,
          ]) {
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
          }
        }
        if (entry.key == "recall") {
          final card = find.byType(Card);
          expect(find.text("A place where trains stop."), findsNothing);
          expect(find.text("The station is busy."), findsNothing);
          void expectCentered(String label) {
            expect(
              tester.getCenter(find.text(label)).dx,
              closeTo(tester.getCenter(card).dx, 1),
            );
          }

          expectCentered("station");
          expectCentered("n.");
          final reveal = find.text(l10n.languageReveal);
          await tester.ensureVisible(reveal);
          await tester.tap(reveal);
          await tester.pumpAndSettle();
          expectCentered("A place where trains stop.");
          expectCentered("The station is busy.");
          expect(find.text(l10n.languageRemembered), findsOneWidget);
        }
        if (entry.key == "context-setup") {
          final source = find.text(l10n.languageContextAllVocabulary);
          expect(source, findsOneWidget);
          if (width == 1200) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pumpAndSettle();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.tap(source);
          }
          await tester.pumpAndSettle();
          final group = find.widgetWithText(MenuItemButton, "Travel");
          expect(group, findsOneWidget);
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: tester.getCenter(group));
          await tester.pumpAndSettle();
          await mouse.down(tester.getCenter(group));
          await tester.pump();
          await mouse.up();
          await mouse.removePointer();
          await tester.pumpAndSettle();
          expect(find.text("Travel"), findsOneWidget);
        }
        if (entry.key == "context-answer") {
          expect(find.byType(TextField), findsNothing);
          final option = tester.renderObject<RenderParagraph>(
            find.text("A place where trains stop."),
          );
          expect(option.didExceedMaxLines, isFalse);
          final boxes = option.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 26),
          );
          expect(
            boxes.every((box) => box.right <= option.size.width + 1),
            isTrue,
          );
          await tester.ensureVisible(find.text("A place where trains stop."));
          await tester.pumpAndSettle();
          await tester.tap(find.text("A place where trains stop."));
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text(l10n.languageSentenceCheckAnswer),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(find.text(l10n.languageSentenceCheckAnswer));
          });
          await flush(tester);
          expect(find.text(l10n.languageSentenceCorrect), findsOneWidget);
        }
        expect(
          tester.takeException(),
          isNull,
          reason: "${entry.key} expanded feedback",
        );
        if (capture != null) {
          await capture(tester, "${entry.key}-${width.toInt()}");
        }
        if (entry.key != "vocabulary" &&
            find.byType(TextField).evaluate().isNotEmpty) {
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TextField).first);
          await tester.enterText(
            find.byType(TextField).first,
            "A long answer with details. " * 20,
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: "${entry.key} with keyboard",
          );
          tester.view.resetViewInsets();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await flush(tester);
      }
    });
  }
  testWidgets(
    "writing blocks back during feedback, preserves unsaved draft on cancel",
    (tester) async {
      final provider = _WaitingProvider();
      final page = WritingPractice(
        store: store,
        ai: WritingAi(
          store: store,
          provider: provider,
          config: config,
          task: const WritingTask("exit", "Write a letter."),
        ),
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => page),
                ),
                child: const Text("Open"),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text("Open"));
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        "I would like to join your club.",
      );
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text("Discard unsaved draft changes?"), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, "Cancel"));
      await tester.pumpAndSettle();
      expect(find.text("I would like to join your club."), findsOneWidget);
      await tester.ensureVisible(find.text("Request AI feedback"));
      await tester.tap(find.text("Request AI feedback"));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
      expect(provider.started, isTrue);
      expect(find.text("Generating writing feedback"), findsOneWidget);
      if (capture != null) {
        await capture(tester, "generation-360");
        await capture(tester, "generation-1200");
      }
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WritingPractice), findsOneWidget);
      expect(find.text("Discard unsaved draft changes?"), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await flush(tester);
    },
  );
}
