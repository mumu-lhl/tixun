import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ai/ai_usage_store.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/features/language_learning/exam_ai.dart";
import "package:tixun/features/language_learning/exam_material.dart";
import "package:tixun/features/language_learning/exam_paper_screen.dart";
import "package:tixun/features/language_learning/exam_store.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/sentence_content.dart";

import "support/exam_bundled.dart";

const _config = ProviderConfig(
  id: 1,
  kind: "openai",
  baseUrl: "https://example.com",
  model: "test-model",
  vision: false,
  supportsTools: true,
  thinking: false,
  supportsThinking: false,
  effort: "",
);

class _Provider implements ChatProvider {
  final requests = <AiRequest>[];
  String response = "";
  bool complete = true;
  bool available = true;
  bool cancelReply = false;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        expect(
          encodeCompletion(config, request).containsKey("max_tokens"),
          isFalse,
        );
        requests.add(request);
        if (!available) throw const AiFailure("Offline");
        if (cancelReply) cancel.cancel();
        yield AiChunk(text: response, completed: complete);
      });
}

ExamTarget _target(ExamKind kind) => ExamTarget(
  kind: kind,
  level: SentenceLevel.beginner,
  count: kind == ExamKind.reading ? 3 : 5,
);

Map<String, Object?> _fixture(ExamKind kind) {
  final sample = bundledExamPapers(kind).first.paper;
  return {
    ...sample.toJson(),
    "paragraphs": [
      "This passage was prepared for the exercise.",
      ...sample.paragraphs,
    ],
    if (kind == ExamKind.reading)
      "items": [
        for (final item in sample.items)
          {
            ...item.toJson(),
            "distractors": {
              for (final option in item.options.keys)
                if (!item.answers.contains(option))
                  option: "The passage gives a different detail.",
            },
          },
      ],
  };
}

void main() {
  late AppDatabase db;
  late LanguageLearningStore store;
  late _Provider provider;
  late ExamAi ai;

  setUp(() {
    db = AppDatabase.memory();
    store = LanguageLearningStore(db);
    provider = _Provider();
    ai = ExamAi(
      provider: provider,
      config: _config,
      store: store,
      usageStore: AiUsageStore(db),
    );
  });

  tearDown(() async {
    await store.whenIdle;
    store.dispose();
    await db.close();
  });

  for (final kind in ExamKind.values) {
    test("validates, saves, grades and reloads ${kind.name}", () async {
      provider.response = jsonEncode(_fixture(kind));
      final target = _target(kind);
      final material = await ai.acquire(
        target,
        glossLanguage: "en",
        cancel: CancelToken(),
      );
      expect(provider.requests.single.tools, isEmpty);
      expect(material.source, ExamSource.aiGenerated);
      expect(material.row.profile, ExamProfile.zhejiang2026.id);
      expect(material.verification, ExamVerification.structureChecked);
      provider.available = false;
      final reused = await ai.acquire(
        target,
        glossLanguage: "en",
        cancel: CancelToken(),
      );
      expect(reused.row.id, material.row.id);
      expect(provider.requests, hasLength(1));

      final answers = material.paper.items
          .map((item) => item.answers.first)
          .toList();
      if (kind == ExamKind.grammar) answers[3] = "  IF  ";
      if (kind == ExamKind.sentenceInsertion) {
        await expectLater(
          store.submitExam(
            material: material,
            attemptId: "duplicate",
            responses: List.filled(5, answers.first),
            confidence: null,
            hintUsed: false,
          ),
          throwsFormatException,
        );
      }

      final result = await store.submitExam(
        material: material,
        attemptId: "attempt",
        responses: answers,
        confidence: ExamConfidence.guess,
        hintUsed: true,
      );
      expect(result.matched, answers.length);
      expect(result.confidence, ExamConfidence.guess);
      final replay = await store.submitExam(
        material: material,
        attemptId: "attempt",
        responses: answers,
        confidence: ExamConfidence.guess,
        hintUsed: true,
      );
      expect(replay.id, result.id);
      expect((await store.examHistory(material.row.id).first), hasLength(1));
      expect(await store.reusableExam(target), isNull);
      expect(
        (await db.select(db.aiUsageEvents).get()).single.feature,
        "language_exam_generation",
      );
      expect(await db.select(db.chatMessages).get(), isEmpty);
    });
  }

  test(
    "incomplete replies, bogus evidence, and cancelled replies are never saved",
    () async {
      final target = _target(ExamKind.cloze);
      final payload = _fixture(ExamKind.cloze);
      provider.response = jsonEncode(payload);
      provider.complete = false;
      await expectLater(
        ai.acquire(target, glossLanguage: "en", cancel: CancelToken()),
        throwsFormatException,
      );
      provider.complete = true;
      final items = payload["items"] as List;
      final first = items.first as Map;
      provider.response = jsonEncode({
        ...payload,
        "items": [
          {...first, "evidence": "A quotation that is not in the passage."},
          ...items.skip(1),
        ],
      });
      await expectLater(
        ai.acquire(target, glossLanguage: "en", cancel: CancelToken()),
        throwsFormatException,
      );
      provider.response = jsonEncode(payload);
      provider.cancelReply = true;
      await expectLater(
        ai.acquire(target, glossLanguage: "en", cancel: CancelToken()),
        throwsA(isA<DioException>()),
      );
      expect(await db.select(db.learningExamMaterials).get(), isEmpty);
      final events = await db.select(db.aiUsageEvents).get();
      expect(events.map((event) => event.status), [
        "incomplete",
        "error",
        "cancelled",
      ]);
    },
  );

  test(
    "negative independent review cannot update the verification state",
    () async {
      final target = _target(ExamKind.reading);
      provider.response = jsonEncode(_fixture(ExamKind.reading));
      final material = await ai.acquire(
        target,
        glossLanguage: "en",
        cancel: CancelToken(),
      );
      final wrongAnswers = material.paper.items
          .map(
            (item) => item.options.keys.firstWhere(
              (key) => !item.answers.contains(key),
            ),
          )
          .toList();
      await store.submitExam(
        material: material,
        attemptId: "incorrect-reading",
        responses: wrongAnswers,
        confidence: ExamConfidence.certain,
        hintUsed: false,
      );
      expect(await store.recommendedExamSkill(ExamKind.reading), isNull);
      provider.response =
          '{"approved":false,"issue":"One distractor is ambiguous."}';
      final declined = await ai.review(
        material,
        glossLanguage: "en",
        cancel: CancelToken(),
      );
      expect(declined.material.verification, ExamVerification.reviewRejected);
      expect(declined.issue, isNotEmpty);
      expect(declined.material.row.reviewIssue, declined.issue);
      expect(await store.reusableExam(target), isNull);
      provider.response = '{"approved":true,"issue":""}';
      final approved = await ai.review(
        material,
        glossLanguage: "en",
        cancel: CancelToken(),
      );
      expect(approved.material.verification, ExamVerification.aiReviewed);
      expect(approved.material.row.revision, material.row.revision);
      expect(await store.recommendedExamSkill(ExamKind.reading), isNull);
      final repeated = await store.submitExam(
        material: approved.material,
        attemptId: "reviewed-repeat",
        responses: wrongAnswers,
        confidence: ExamConfidence.certain,
        hintUsed: false,
      );
      expect(await store.recommendedExamSkill(ExamKind.reading), isNull);
      final saved = await db.select(db.learningExamAttempts).get();
      expect(
        saved.singleWhere((a) => a.id == repeated.id).reviewedAtSubmission,
        isTrue,
      );
      expect(
        saved
            .singleWhere((a) => a.id == "incorrect-reading")
            .reviewedAtSubmission,
        isFalse,
      );
      expect(provider.requests, hasLength(3));
    },
  );

  test("old bundled papers are unavailable for new practice", () async {
    final sample = bundledExamPapers(ExamKind.grammar).single;
    final target = _target(ExamKind.grammar);
    await store.saveExamMaterial(
      target: target,
      paper: sample.paper,
      source: ExamSource.bundled,
      id: sample.id,
    );
    expect(await store.examLibrary(target.kind).first, isEmpty);
    expect(await store.reusableExam(target), isNull);
    final demo = ExamAi(
      provider: MockChatProvider(),
      config: _config,
      store: store,
    );
    await expectLater(
      demo.acquire(target, glossLanguage: "en", cancel: CancelToken()),
      throwsFormatException,
    );
    expect(await db.select(db.learningExamMaterials).get(), hasLength(1));
  });

  testWidgets(
    "shared options are disabled across gaps before paper submission",
    (tester) async {
      final sample = bundledExamPapers(ExamKind.sentenceInsertion).single;
      final material = await tester.runAsync(
        () => store.saveExamMaterial(
          target: _target(ExamKind.sentenceInsertion),
          paper: sample.paper,
          source: ExamSource.bundled,
          id: sample.id,
        ),
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale("en"),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExamPaperScreen(ai: ai, material: material!),
        ),
      );
      final chips = find.widgetWithText(ChoiceChip, "D");
      expect(chips, findsNWidgets(5));
      await tester.ensureVisible(chips.first);
      await tester.pumpAndSettle();
      await tester.tap(chips.first);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chips.at(1)).onSelected, isNull);
      expect(
        find.textContaining("The boxes under the stairs were the first plan"),
        findsNothing,
      );
      final submit = find.widgetWithText(FilledButton, "Submit all answers");
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
