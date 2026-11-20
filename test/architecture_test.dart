import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/app/preferences.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/prompt_settings.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/chat/learning_run.dart";
import "package:tixun/features/library/study_store.dart";
import "package:tixun/features/practice/practice_store.dart";
import "package:tixun/features/practice/question_spec.dart";
import "package:tixun/features/review/review_store.dart";
import "package:tixun/features/visual/visual_store.dart";

import "support/chatgpt_fixture.dart";

part "architecture_learning_run_cases.dart";

class ScriptProvider implements ChatProvider {
  ScriptProvider(this.events);
  final List<AiChunk> Function(int turn) events;
  int turns = 0;
  final requests = <AiRequest>[];
  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      AiConversation((request, cancel) async* {
        requests.add(request);
        for (final e in events(++turns)) {
          yield e;
        }
      });
}

class WaitingKeyStore extends MemoryKeyStore {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String provider, String value) async {
    if (value == "preference-test-key") {
      started.complete();
      await release.future;
    }
    await super.write(provider, value);
  }
}

void main() {
  test("One capability policy resolves effort, vision and thinking/tool compatibility", () async {
    final db = AppDatabase.memory();
    final base = await db.config();
    expect(AiOptions(base).toolsAvailable, true);
    expect(AiOptions(base.copyWith(thinking: true)).toolsAvailable, true);
    expect(
      AiOptions(base.copyWith(kind: "compatible", thinking: true))
          .toolsAvailable,
      false,
    );
    expect(
      AiOptions(base.copyWith(kind: "compatible", supportsTools: false))
          .toolsAvailable,
      false,
    );
    final chat = base.copyWith(
      kind: "chatgpt",
      model: "gpt-6.1-sol",
      baseUrl: "https://api.openai.com/v1",
      thinking: true,
      effort: "max",
    );
    expect(AiOptions(chat).toolsAvailable, true);
    expect(AiOptions(chat).effortParameter, "max");
    expect(AiOptions(chat).offLabel, "模型默认");
    expect(AiOptions(base.copyWith(kind: "compatible")).offChoiceLabel, "模型默认");
    expect(AiOptions.forSession(chat, "off").thinking, false);
    expect(AiOptions.forSession(chat, "").effort, "max");
    expect(AiOptions(base.copyWith(model: "deepseek-v4-pro")).vision, false);
    await db.close();
  });

  test(
    "Account snapshot is read-only and never exposes credential records",
    () async {
      final f = ChatGptFixture();
      await f.seed();
      final snapshot = await f.auth.snapshot();
      expect(snapshot.accounts.single.id, snapshot.activeId);
      expect(snapshot.accounts.single.label, "student@example.test");
      expect(() => snapshot.accounts.clear(), throwsUnsupportedError);
      final stored = jsonDecode(
        (await f.keys.read("chatgpt.oauth.v1"))!,
      ) as Map<String, dynamic>;
      stored["active"] = "missing-registration";
      await f.keys.write("chatgpt.oauth.v1", jsonEncode(stored));
      expect((await f.auth.snapshot()).activeId, isNull);
      await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
    },
  );

  test("Controller shutdown waits for preferences independently of study operations", () async {
    final root = await Directory.systemTemp.createTemp("tixun-prefs-barrier");
    final keys = WaitingKeyStore();
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: keys,
      chatProvider: MockChatProvider(),
    );
    final save = c.saveSettings(
      c.config.copyWith(model: "deepseek-v4-pro", vision: false),
      "preference-test-key",
    );
    await keys.started.future;
    var closed = false;
    final closing = c.shutdown().then((_) => closed = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(closed, false);
    keys.release.complete();
    await save;
    await closing;
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
      chatProvider: MockChatProvider(),
    );
    expect(c.config.model, "deepseek-v4-pro");
    await c.shutdown();
    await root.delete(recursive: true);
  });

  test("Practice revision atomically inherits current knowledge links and retains old attempts", () async {
    final db = AppDatabase.memory();
    final dir = await Directory.systemTemp.createTemp("tixun-revision");
    final study = StudyStore(db, AttachmentStore(dir)),
        practice = PracticeStore(db);
    final knowledge = await study.saveKnowledge(
      const KnowledgeDraft(title: "加法", content: "两个量的和"),
    );
    final old = await practice.create(
      const QuestionSpec(
        kind: "numeric",
        stem: "2+2",
        answers: [
          ["4"],
        ],
      ),
      knowledgeIds: [knowledge.id],
    );
    final attempt = await practice.begin(old);
    await practice.submit(attempt.id, ["4"]);
    final revision = await practice.revise(
      old,
      const QuestionSpec(
        kind: "numeric",
        stem: "3+3",
        answers: [
          ["6"],
        ],
      ),
    );
    final links = await (db.select(
      db.practiceQuestionKnowledge,
    )..where((l) => l.questionId.equals(revision))).get();
    expect(links.single.knowledgeId, knowledge.id);
    expect((await practice.detail(revision)).row.parentQuestionId, old);
    expect((await practice.detail(old)).attempts.single.id, attempt.id);
    expect((await practice.detail(old)).responses[attempt.id], ["4"]);
    study.dispose();
    practice.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  _learningRunCases();
}
