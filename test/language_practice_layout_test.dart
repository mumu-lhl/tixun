import "support/exam_bundled.dart";

import "package:tixun/features/language_learning/exam_store.dart";
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
import "package:tixun/features/language_learning/sentence_practice.dart";
import "package:tixun/features/language_learning/sentence_explanation.dart";
import "package:tixun/features/language_learning/vocabulary_batch.dart";
import "package:tixun/features/language_learning/exam_ai.dart";
import "package:tixun/features/language_learning/exam_material.dart";
import "package:tixun/features/language_learning/exam_paper_screen.dart";
import "package:tixun/features/language_learning/sentence_content.dart";

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

void main({Future<void> Function(WidgetTester, String)? capture}) {
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

  Widget app(Widget page, {double scale = 1}) => ProviderScope(
    child: MaterialApp(
      locale: const Locale("en"),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
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
        "vocabulary": VocabularyBatch(
          store: store,
          language: "en",
          mode: VocabularyMode.context,
        ),
        "exam": ExamPaperScreen(ai: exam, material: material!),
      };
      for (final entry in pages.entries) {
        await tester.pumpWidget(app(entry.value, scale: 1.6));
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
        if (entry.key == "vocabulary") {
          await tester.enterText(find.byType(TextField).first, "station");
          await tester.ensureVisible(find.text(l10n.languageCheck));
          await tester.tap(find.text(l10n.languageCheck));
          await flush(tester);
          expect(find.text(l10n.languageCorrect), findsOneWidget);
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
