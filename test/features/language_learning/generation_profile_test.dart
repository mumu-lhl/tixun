import "dart:convert";

import "package:drift/drift.dart" show Value;
import "package:flutter_test/flutter_test.dart";
import "package:dio/dio.dart";
import "package:tixun/features/language_learning/language_json_request.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/prompt_settings.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/features/language_learning/generation_profile.dart";
import "package:tixun/features/language_learning/generation_provider.dart";
import "package:tixun/features/language_learning/generation_store.dart";
import "package:tixun/features/language_learning/language_skills.dart";
import "package:tixun/features/language_learning/exam_material.dart";

import "package:tixun/features/language_learning/language_store.dart";
import "package:tixun/features/language_learning/language_profile_store.dart";
import "package:tixun/features/language_learning/lexical_form.dart";
import "package:tixun/features/language_learning/lexical_form_store.dart";
import "package:tixun/features/language_learning/next_practice.dart";
import "package:tixun/features/language_learning/sentence_content.dart";

import "package:tixun/features/language_learning/sentence_store.dart";
import "package:tixun/features/language_learning/sentence_batch_ai.dart";
import "package:tixun/features/language_learning/sentence_batch_store.dart";
import "package:tixun/features/language_learning/writing_store.dart";
import "package:tixun/features/language_learning/writing_feedback.dart";

import "generation_history_test.dart" show ReplyProvider, config;

void main() {
  test(
    "current target survives the summary budget and old mistakes lose priority",
    () {
      final now = DateTime.now();
      final target = LanguageSkill.condition;
      final profile = LanguageProfile(
        language: "en",
        exam: ExamProfile.zhejiang2026,
        due: 0,
        evidence: [
          for (final skill in LanguageSkill.values)
            for (var i = 0; i < (skill == target ? 18 : 3); i++)
              LanguageObservation(
                id: "${skill.name}-$i",
                skill: skill,
                kind: EvidenceKind.independent,
                verified: true,
                correct: skill == target && i < 6,
                at: now.subtract(Duration(minutes: i)),
                basis: "${skill.name} material $i",
              ),
        ],
      );
      final withoutFocus = generationProfile(
        profile,
        "language_sentence_batch",
      );
      expect(
        (withoutFocus["skills"] as List).any((r) => r["skill"] == target.name),
        isFalse,
      );
      final focused = generationProfile(
        profile,
        "language_sentence_batch",
        focus: {target},
      );
      final rows = focused["skills"] as List;
      expect(rows, hasLength(6));
      expect(rows.first["skill"], target.name);
      expect(rows.first["signal"], "observedSuccess");
      expect(rows.first["recentDifficulties"], isEmpty);
      expect(rows.first["recentOutcomes"], hasLength(3));
      expect(
        rows.first["recentOutcomes"].every((r) => r["correct"] == true),
        isTrue,
      );
      expect(profile.skills[target]!.observations, hasLength(18));
      expect(profile.skills[target]!.weak, isTrue);
      expect(profile.skills[target]!.verifiedRecentWeak, isFalse);
    },
  );

  test("later repeated success is visible without erasing or confirming the earlier error", () {
    final now = DateTime.now();
    final profile = LanguageProfile(
      language: "en",
      exam: ExamProfile.zhejiang2026,
      due: 0,
      evidence: [
        LanguageObservation(
          id: "first",
          skill: LanguageSkill.formProduction,
          kind: EvidenceKind.independent,
          verified: true,
          correct: false,
          at: now.subtract(const Duration(days: 2)),
          basis: "went",
          response: "goed",
          expected: "went",
        ),
        LanguageObservation(
          id: "retry",
          skill: LanguageSkill.formProduction,
          kind: EvidenceKind.repeat,
          verified: true,
          correct: true,
          at: now,
          basis: "went",
          response: "went",
          expected: "went",
        ),
      ],
    );
    final row =
        (generationProfile(profile, "language_vocabulary")["skills"] as List)
            .single;
    expect(row["signal"], "insufficientEvidence");
    expect(row["verifiedIndependentCorrect"], 0);
    expect(row["recentOutcomes"].first["correct"], true);
    expect(row["recentOutcomes"].first["kind"], "repeat");
    expect(row["recentDifficulties"].single["response"], "goed");
  });

  test("non-independent recent work cannot turn old failures into success", () {
    final now = DateTime.now();
    for (final kind in [
      EvidenceKind.repeat,
      EvidenceKind.assisted,
      EvidenceKind.selfReport,
    ]) {
      for (final correct in [true, false]) {
        final profile = LanguageProfile(
          language: "en",
          exam: ExamProfile.zhejiang2026,
          due: 0,
          evidence: [
            for (var i = 0; i < 3; i++)
              LanguageObservation(
                id: "old-$i",
                skill: LanguageSkill.formProduction,
                kind: EvidenceKind.independent,
                correct: false,
                at: now.subtract(Duration(days: i + 1)),
                basis: "went",
              ),
            for (var i = 0; i < 6; i++)
              LanguageObservation(
                id: "practice-$i",
                skill: LanguageSkill.formProduction,
                kind: kind,
                correct: kind == EvidenceKind.selfReport ? null : correct,
                at: now.subtract(Duration(minutes: i)),
                basis: "went",
              ),
          ],
        );
        final row =
            (generationProfile(profile, "language_vocabulary")["skills"]
                    as List)
                .single;
        expect(row["signal"], "insufficientEvidence");
        expect(row["verifiedIndependentCorrect"], 0);
        expect(row["recentOutcomes"].first["kind"], kind.name);
      }
    }
  });

  test("saved practice changes the plan and focused generator transport, not mastery", () async {
    final db = AppDatabase.memory();
    final store = LanguageLearningStore(db);
    addTearDown(() async {
      store.dispose();
      await db.close();
    });
    final cards = [
      for (var i = 0; i < 3; i++)
        SentenceCard(
          id: "place-$i",
          text: "The key is in room $i.",
          translation: "钥匙在房间里。",
          hint: "Find the place.",
          question: "Where is it?",
          choices: ["room $i", "outside"],
          correctIndex: 0,
          skill: SentenceSkill.detail,
          level: SentenceLevel.beginner,
        ),
    ];
    await store.saveSentenceBatch(
      SentenceBatchProposal(
        id: "source",
        topic: SentenceTopic.dailyLife,
        style: SentenceStyle.written,
        glossLanguage: "en",
        model: "real-model",
        promptVersion: 1,
        isMock: false,
        generatedAt: DateTime.now(),
        cards: cards,
      ),
      cards.map((c) => c.id).toSet(),
    );
    for (final card in cards) {
      await store.recordSentence(
        batchId: "run",
        card: card,
        rating: SentenceRating.understood,
        helpUsed: {},
        selectedIndex: 0,
      );
    }
    final profile = await store.readLanguageProfile("en");
    final plan = sentencePlan(
      profile,
      recommendLanguage(
        profile,
        LanguageGoal.communication,
        restrictTo: {LanguageSkill.detail},
      ),
      [],
    );
    expect(plan.level, SentenceLevel.intermediate);
    expect(plan.diagnostic, isFalse);
    expect(plan.performance.checked, 0);
    final transport = ReplyProvider()
      ..reply = jsonEncode({
        "language": "en",
        "sentences": [
          for (var i = 0; i < plan.count; i++)
            {
              "text":
                  "Although the drawer was empty, the spare key remained in locker $i.",
              "translation": "备用钥匙还在柜子里。",
              "hint": "Find the location.",
              "level": "intermediate",
              "skill": "detail",
              "check": {
                "question": "Where was the key?",
                "choices": ["locker $i", "drawer", "outside"],
                "correctIndex": 0,
                "explanation": "The sentence locates the key in the locker.",
              },
            },
        ],
      });
    final provider = LanguageGenerationProvider(
      provider: () => transport,
      configuration: () => config,
      promptSettings: () => PromptSettings(),
      history: LanguageGenerationStore(db),
      compare: (_, _, _) async => true,
    );
    final proposal = await SentenceBatchAi(provider: provider, config: config)
        .propose(
          topic: SentenceTopic.dailyLife,
          style: plan.style,
          level: plan.level,
          glossLanguage: "en",
          count: plan.count,
          focus: plan.skill,
          cancel: CancelToken(),
        );
    expect(proposal.cards, hasLength(plan.count));
    final task = jsonDecode(transport.sent!.messages.first.text);
    expect(task, containsPair("focus", "detail"));
    expect(task, containsPair("level", "intermediate"));
    expect(task, containsPair("count", plan.count));
    final summary =
        jsonDecode(
              transport.sent!.messages.last.text,
            )["learnerProfile"]["skills"]
            as List;
    expect(summary.first["skill"], "detail");
    expect(summary.first["verifiedIndependent"], 0);
    expect(summary.first["recentOutcomes"].first["level"], "beginner");
    expect(summary.first["recentOutcomes"].first["verified"], false);
    expect(await provider.history.exportJsonl(), contains("recentOutcomes"));
  });

  test(
    "sentence context follows content identity, never a later revision",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      const card = SentenceCard(
        id: "key",
        text: "The key is in the hall.",
        translation: "钥匙在大厅",
        hint: "Find the place.",
        question: "Where?",
        choices: ["hall", "kitchen"],
        correctIndex: 0,
        skill: SentenceSkill.detail,
        level: SentenceLevel.beginner,
        checkExplanation: "It names the hall.",
      );
      Future<void> save(
        int revision, {
        String batchId = "saved",
        SentenceLevel level = SentenceLevel.beginner,
      }) => store.saveSentenceBatch(
        SentenceBatchProposal(
          id: batchId,
          topic: SentenceTopic.dailyLife,
          style: SentenceStyle.written,
          glossLanguage: "zh",
          model: "real-model",
          promptVersion: 1,
          isMock: false,
          generatedAt: DateTime(2026),
          cards: [
            SentenceCard(
              id: card.id,
              text: card.text,
              translation: card.translation,
              hint: card.hint,
              question: card.question,
              choices: card.choices,
              correctIndex: card.correctIndex,
              skill: card.skill,
              level: level,
              revision: revision,
              checkExplanation: card.checkExplanation,
            ),
          ],
        ),
        {card.id},
      );
      await save(1);
      await store.recordSentence(
        batchId: "fresh-run",
        card: card,
        rating: SentenceRating.unclear,
        helpUsed: {},
        selectedIndex: 1,
      );
      var row = (await store.readLanguageProfile("en"))
          .skills[LanguageSkill.detail]!
          .observations
          .single;
      expect(row.response, "kitchen");
      expect(row.expected, "hall");
      expect(row.feedback, "It names the hall.");
      expect(row.verified, isFalse);
      expect(row.level, SentenceLevel.beginner);
      await save(1, batchId: "conflicting", level: SentenceLevel.intermediate);
      row = (await store.readLanguageProfile("en"))
          .skills[LanguageSkill.detail]!
          .observations
          .single;
      expect(row.expected, isNull);
      expect(row.level, isNull);
      await (db.delete(
        db.learningSentenceBatches,
      )..where((b) => b.id.equals("conflicting"))).go();
      await db.customStatement(
        """UPDATE learning_sentence_batches SET cards = replace(cards, '"revision":1', '"revision":2')""",
      );
      row = (await store.readLanguageProfile("en"))
          .skills[LanguageSkill.detail]!
          .observations
          .single;
      expect(row.expected, isNull);
      expect(row.level, isNull);
      expect(row.response, "kitchen");
    },
  );

  test(
    "writing sends anchored issues without turning suggestions into errors",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final version = await store.snapshotWriting(
        "He go home.",
        taskId: "task",
      );
      await store.saveWritingFeedback(
        versionId: version,
        model: "real-model",
        promptVersion: 1,
        isMock: false,
        feedback: const WritingFeedback(
          task: 3,
          organization: 3,
          language: 3,
          summary: "Review agreement.",
          notes: [
            WritingNote(3, 5, WritingNoteKind.issue, "Use goes with he."),
            WritingNote(
              6,
              10,
              WritingNoteKind.suggestion,
              "Optional stylistic change.",
            ),
          ],
        ),
      );
      final profile = await store.readLanguageProfile("en");
      final rows =
          generationProfile(profile, "language_writing_task")["skills"] as List;
      for (final row in rows) {
        expect(row["verifiedIndependent"], 0);
        expect(row["recentDifficulties"].single["response"], "go");
        expect(
          row["recentDifficulties"].single["feedback"],
          "Use goes with he.",
        );
        expect(row["recentDifficulties"].single["kind"], "unverified");
      }
    },
  );

  test(
    "wrong form reaches generation as a concrete contrast and is archived",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      await store.saveEntries(
        language: "en",
        groupTitle: "Verbs",
        groupType: VocabularyGroupType.topic,
        entries: const [
          VocabularyEntry(
            form: "go",
            meaning: "move",
            forms: [LexicalFormDraft("went", Inflection.past)],
          ),
        ],
      );
      final exercise = (await store.formPractice("en")).single;
      await store.recordFormPractice(
        attemptId: "error",
        exercise: exercise,
        answer: "goed",
        production: true,
      );
      final transport = ReplyProvider();
      final provider = LanguageGenerationProvider(
        provider: () => transport,
        configuration: () => config,
        promptSettings: () => PromptSettings(),
        history: LanguageGenerationStore(db),
        compare: (_, _, _) async => true,
      );
      await requestLanguageJson(
        provider: provider,
        config: config,
        usageStore: null,
        feature: "language_vocabulary",
        request: AiRequest(
          instructions: "task",
          messages: [const AiMessage.user('{"count":3}')],
        ),
        cancel: CancelToken(),
        parse: (value) => value,
      );
      final rows =
          jsonDecode(
                transport.sent!.messages.last.text,
              )["learnerProfile"]["skills"]
              as List;
      final form = rows.singleWhere((r) => r["skill"] == "formProduction");
      expect(form["signal"], "insufficientEvidence");
      expect(
        form["recentDifficulties"].single,
        containsPair("response", "goed"),
      );
      expect(
        form["recentDifficulties"].single,
        containsPair("expected", "went"),
      );
      expect(form["recentDifficulties"].single, containsPair("task", "past"));
      expect(await provider.history.exportJsonl(), contains("goed"));
    },
  );

  test(
    "follow-up and profile use one policy with explicit delivery constraints",
    () async {
      final db = AppDatabase.memory();
      final store = LanguageLearningStore(db);
      addTearDown(() async {
        store.dispose();
        await db.close();
      });
      final profile = await store.readLanguageProfile("en");
      final recommendation = recommendLanguage(
        profile,
        LanguageGoal.communication,
        restrictTo: {
          for (final skill in SentenceSkill.values) sentenceAbility(skill),
        },
      );
      final plan = await suggestSentences(store);
      expect(sentenceAbility(plan.skill), recommendation.skill);
      expect(plan.level, recommendation.level);
      expect(plan.count, recommendation.count);
      expect(plan.diagnostic, recommendation.diagnostic);
      expect(plan.performance.checked, 0);
    },
  );

  test(
    "bounded summary distinguishes evidence reliability and training scope",
    () {
      final profile = LanguageProfile(
        language: "en",
        exam: ExamProfile.zhejiang2026,
        due: 0,
        evidence: [
          for (final skill in LanguageSkill.values)
            for (var i = 0; i < 3; i++)
              LanguageObservation(
                id: "${skill.name}:$i",
                skill: skill,
                kind: skill == LanguageSkill.condition
                    ? EvidenceKind.assisted
                    : EvidenceKind.independent,
                verified: skill != LanguageSkill.reference,
                correct: false,
                at: DateTime(2026, 1, i + 1),
                basis: "x" * 400,
              ),
        ],
      );
      final summary = generationProfile(profile, "language_sentence_batch");
      final rows = summary["skills"] as List;
      expect(rows.length, lessThanOrEqualTo(6));
      expect(
        rows.every((r) => !r["skill"].toString().startsWith("writing")),
        isTrue,
      );
      final vocabulary = generationProfile(profile, "language_vocabulary");
      expect((vocabulary["skills"] as List).first["signal"], "weak");
      final condition = LanguageProfile(
        language: "en",
        exam: profile.exam,
        due: 0,
        evidence: profile.skills[LanguageSkill.condition]!.observations,
      );
      final row =
          (generationProfile(condition, "language_sentence_batch")["skills"]
                  as List)
              .single;
      expect(row["signal"], "insufficientEvidence");
      expect(row["verifiedIndependent"], 0);
      expect(row["assisted"], 3);
      expect(row["recentDifficulties"], hasLength(2));
      expect(row["recentDifficulties"][0]["material"].length, 180);
      final tentative = LanguageProfile(
        language: "en",
        exam: profile.exam,
        due: 0,
        evidence: profile.skills[LanguageSkill.reference]!.observations,
      );
      final unverified =
          (generationProfile(tentative, "language_sentence_batch")["skills"]
                  as List)
              .single;
      expect(unverified["signal"], "possibleWeakness");
      expect(unverified["verifiedIndependent"], 0);
      expect(unverified["unverifiedIndependent"], 3);
    },
  );

  test(
    "generation preparation reads fresh evidence but lookup stays independent",
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final transport = ReplyProvider();
      final provider = LanguageGenerationProvider(
        provider: () => transport,
        configuration: () => config,
        promptSettings: () => PromptSettings(),
        history: LanguageGenerationStore(db),
        compare: (_, _, _) async => true,
      );
      final request = AiRequest(
        instructions: "task",
        messages: [
          const AiMessage.user('{"focus":"condition","level":"intermediate"}'),
        ],
      );
      final before = await provider.prepare("language_sentence_batch", request);
      expect(
        (jsonDecode(before.messages.last.text)["learnerProfile"]["skills"]
            as List),
        isEmpty,
      );
      await db
          .into(db.learningSentenceAttempts)
          .insert(
            LearningSentenceAttemptsCompanion.insert(
              id: "attempt",
              batchId: "batch",
              sentenceId: "sentence",
              revision: 1,
              language: "en",
              sentence: "If it rains, stay home.",
              skill: "condition",
              rating: const Value("unclear"),
              helpUsed: 0,
              occurredAt: DateTime(2026),
            ),
          );
      final after = await provider.prepare("language_sentence_batch", request);
      final skills =
          jsonDecode(after.messages.last.text)["learnerProfile"]["skills"]
              as List;
      expect(skills.single["skill"], "condition");
      expect(skills.single["selfReported"], 1);
      expect(skills.single["verifiedIndependent"], 0);
      expect(after.messages.first.text, request.messages.first.text);
      expect(after.instructions, contains("Preserve the user's explicit"));
      await requestLanguageJson(
        provider: provider,
        config: config,
        usageStore: null,
        feature: "language_sentence_batch",
        request: request,
        cancel: CancelToken(),
        parse: (value) => value,
      );
      expect(transport.sent!.messages.last.text, after.messages.last.text);
      final archived = await provider.history.exportJsonl();
      expect(archived, contains("learnerProfile"));
      expect(archived, contains("selfReported"));
      final lookup = await provider.prepare("language_quick_lookup", request);
      expect(lookup.messages, hasLength(1));
      expect(lookup.instructions, isNot(contains("learnerProfile")));
    },
  );
}
