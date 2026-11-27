import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/prompt_settings.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/generation_store.dart";
import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/generation_provider.dart";
import "package:tixun/features/language_learning/language_json_request.dart";
import "package:tixun/features/language_learning/generation_activity.dart";

const config = ProviderConfig(
  id: 1,
  kind: "openai",
  baseUrl: "https://example.invalid",
  model: "original-model",
  vision: false,
  supportsTools: false,
  thinking: true,
  supportsThinking: true,
  effort: "high",
);

class ReplyProvider implements ChatProvider {
  String reply = '{"content":"original"}';
  ProviderConfig? used;
  AiRequest? sent;
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) {
    used = config;
    return AiConversation((request, cancel) async* {
      sent = request;
      yield AiChunk(
        text: reply,
        reasoning: "PRIVATE-REASONING",
        completed: true,
      );
    });
  }
}

void main() {
  late AppDatabase db;
  late LanguageGenerationStore history;
  setUp(() {
    db = AppDatabase.memory();
    history = LanguageGenerationStore(db);
  });
  tearDown(() => db.close());

  test("repeated requests retain both results, share prompts, and return the user's choice", () async {
    final transport = ReplyProvider();
    var selectedConfig = config;
    var useNew = false;
    var comparisons = 0;
    final activity = ValueNotifier<GenerationActivity?>(null);
    final provider = LanguageGenerationProvider(
      provider: () => transport,
      configuration: () => selectedConfig,
      promptSettings: () => PromptSettings(),
      history: history,
      compare: (old, fresh, cancel) async {
        expect(activity.value?.phase, GenerationPhase.comparing);
        comparisons++;
        expect(old.output, contains("original"));
        expect(fresh.model, "better-model");
        return useNew;
      },
    );
    final request = AiRequest(
      instructions: "same immutable prompt",
      messages: [const AiMessage.user("same task input")],
    );
    Future<String> generate() => requestLanguageJson(
      provider: provider,
      config: config,
      usageStore: null,
      feature: "test_generation",
      request: request,
      cancel: CancelToken(),
      parse: (v) => (v as Map)["content"] as String,
    );
    expect(await trackLanguageGeneration(activity, generate), "original");
    expect(transport.sent!.outputFormat, AiOutputFormat.jsonObject);
    expect(transport.sent!.instructions, contains("compact"));
    selectedConfig = config.copyWith(model: "better-model", effort: "xhigh");
    transport.reply = '{"content":"new"}';
    expect(await trackLanguageGeneration(activity, generate), "original");
    expect(transport.used!.model, "better-model");
    expect(await db.select(db.languagePromptSnapshots).get(), hasLength(1));
    expect(await db.select(db.languageGenerationRuns).get(), hasLength(2));
    useNew = true;
    expect(await trackLanguageGeneration(activity, generate), "new");
    activity.dispose();
    expect(comparisons, 2);
    final runs = await db.select(db.languageGenerationRuns).get();
    expect(runs.first.model, "original-model");
    expect(runs.last.effort, "xhigh");
    final active = await history.active(runs.first.taskId);
    expect(active!.id, runs.last.id);
    await history.link("test_content", "saved-result", active.id);
    final before = await db
        .customSelect("SELECT total_changes() n")
        .getSingle();
    final exported = await history.exportJsonl();
    final records = exported
        .trim()
        .split("\n")
        .map((s) => jsonDecode(s) as Map)
        .toList();
    expect(records.where((r) => r["type"] == "run"), hasLength(3));
    expect(records.where((r) => r["type"] == "prompt"), hasLength(1));
    expect(
      records.where((r) => r["type"] == "link").single["contentId"],
      "saved-result",
    );
    expect(exported, isNot(contains("PRIVATE-REASONING")));
    expect(await history.exportCsv(), contains('"better-model"'));
    final after = await db.customSelect("SELECT total_changes() n").getSingle();
    expect(after.read<int>("n"), before.read<int>("n"));
  });

  test(
    "invalid candidates cannot replace a valid result or enter comparison",
    () async {
      final transport = ReplyProvider();
      var comparisons = 0;
      final provider = LanguageGenerationProvider(
        provider: () => transport,
        configuration: () => config,
        promptSettings: () => PromptSettings(),
        history: history,
        compare: (_, _, _) async {
          comparisons++;
          return true;
        },
      );
      Future<String> generate() => requestLanguageJson(
        provider: provider,
        config: config,
        usageStore: null,
        feature: "test_generation",
        request: AiRequest(
          instructions: "prompt",
          messages: [const AiMessage.user("input")],
        ),
        cancel: CancelToken(),
        parse: (v) => (v as Map)["content"] as String,
      );
      await generate();
      transport.reply = '{"wrong":123}';
      await expectLater(generate(), throwsA(isA<TypeError>()));
      expect(comparisons, 0);
      expect(await db.select(db.languageGenerationRuns).get(), hasLength(1));
    },
  );

  test("legacy comparison marks missing settings unknown, and content adoption stays ordered", () async {
    final request = AiRequest(
      instructions: "new prompt",
      messages: [const AiMessage.user("same input")],
    );
    final chosen = await history.capture(
      feature: "legacy",
      request: request,
      config: config,
      output: "new result",
      format: "markdown",
      cancel: CancelToken(),
      original: const GenerationOriginal(
        output: "old result",
        model: "legacy-model",
        kind: "test",
        contentId: "content",
      ),
      compare: (old, candidate, _) async {
        expect(old.promptId, isNull);
        expect(old.thinking, isNull);
        expect(old.effort, isNull);
        return false;
      },
    );
    expect(chosen.output, "old result");
    final runs = await db.select(db.languageGenerationRuns).get();
    final fresh = runs.firstWhere((r) => r.output == "new result");
    await history.link("test", "content", fresh.id);
    await history.link("test", "content", chosen.id);
    expect((await history.currentContentRun("test", "content"))!.id, chosen.id);
    expect(await db.select(db.languageGenerationRuns).get(), hasLength(2));
  });

  test("vocabulary revisions preserve review progress and bind evidence to its material version", () async {
    final store = LanguageLearningStore(db);
    addTearDown(store.dispose);
    final request = AiRequest(
      instructions: "prompt",
      messages: [const AiMessage.user("ticket material")],
    );
    final old = await history.capture(
      feature: "vocabulary",
      request: request,
      config: config,
      output: "Old example",
      format: "markdown",
      cancel: CancelToken(),
    );
    await store.saveEntries(
      language: "en",
      groupTitle: "Travel",
      groupType: VocabularyGroupType.topic,
      entries: const [
        VocabularyEntry(form: "ticket", meaning: "车票", example: "Old example"),
      ],
      provenance: VocabularyProvenance(
        batchId: "batch",
        model: config.model,
        promptVersion: 6,
        generatedAt: DateTime.now(),
        mock: false,
        generationByForm: {"ticket": old.id},
      ),
    );
    final card = (await store.cards(language: "en")).single;
    await store.recordRecall(
      attemptId: "before",
      senseId: card.sense.id,
      rating: RecallRating.good,
      groupPrompt: false,
    );
    final firstInterval =
        (await db.select(db.learningReviewSchedules).get()).single.intervalDays;
    final fresh = await history.capture(
      feature: "vocabulary",
      request: request,
      config: config.copyWith(model: "better-model"),
      output: "New example",
      format: "markdown",
      cancel: CancelToken(),
    );
    await store.reviseVocabulary(
      card,
      const VocabularyEntry(
        form: "ticket",
        meaning: "车票",
        example: "New example",
      ),
      fresh,
    );
    expect(
      (await db.select(db.learningReviewSchedules).get()).single.intervalDays,
      firstInterval,
    );
    await store.recordRecall(
      attemptId: "after",
      senseId: card.sense.id,
      rating: RecallRating.good,
      groupPrompt: false,
    );
    final evidence = await db.select(db.learningEvidence).get();
    expect(
      evidence.singleWhere((e) => e.id == "before").generationRunId,
      old.id,
    );
    expect(
      evidence.singleWhere((e) => e.id == "after").generationRunId,
      fresh.id,
    );
    expect(
      (await store.cards(language: "en")).single.sense.example,
      "New example",
    );
    expect(
      (await db.select(db.languageGenerationRuns).get()).map((r) => r.output),
      contains("Old example"),
    );
  });

  test(
    "cancelled comparison retains the original and archives the candidate",
    () async {
      final request = AiRequest(
        instructions: "prompt",
        messages: [const AiMessage.user("input")],
      );
      final old = await history.capture(
        feature: "test",
        request: request,
        config: config,
        output: "old",
        format: "markdown",
        cancel: CancelToken(),
      );
      final cancel = CancelToken();
      await expectLater(
        history.capture(
          feature: "test",
          request: request,
          config: config,
          output: "new",
          format: "markdown",
          cancel: cancel,
          compare: (_, _, token) async {
            token.cancel();
            return true;
          },
        ),
        throwsA(isA<DioException>()),
      );
      expect((await history.active(old.taskId))!.id, old.id);
      expect(await db.select(db.languageGenerationRuns).get(), hasLength(2));
      expect(await db.select(db.languageGenerationChoices).get(), hasLength(1));
    },
  );
}
