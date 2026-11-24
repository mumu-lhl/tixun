import "dart:convert";

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

import "generation_history_test.dart" show ReplyProvider, config;

void main() {
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
              rating: "unclear",
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
