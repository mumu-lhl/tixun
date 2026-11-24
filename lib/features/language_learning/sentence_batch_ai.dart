import "dart:convert";
import "dart:math" as math;

import "package:dio/dio.dart";
import "package:uuid/uuid.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/database/database.dart";
import "language_json_request.dart";
import "language_store.dart";
import "sentence_batch_store.dart";
import "sentence_content.dart";
import "generation_provider.dart";
import "language_skills.dart";

class SentenceBatchAi {
  const SentenceBatchAi({
    required this.provider,
    required this._config,
    this.usageStore,
    this.prompts,
  });

  final ChatProvider provider;
  final ProviderConfig _config;
  ProviderConfig get config => languageConfiguration(provider, _config);
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  static const _promptVersion = 2;
  static const maximumCount = 20;
  static const _chunkSize = 5;

  Future<SentenceBatchProposal> propose({
    required SentenceTopic topic,
    required SentenceStyle style,
    required SentenceLevel? level,
    required String glossLanguage,
    required int count,
    required CancelToken cancel,
    SentenceSkill? focus,
    Iterable<String> exclude = const [],
    List<LanguageCard> vocabulary = const [],
  }) async {
    if (count < 1 || count > maximumCount) {
      throw const FormatException("Invalid sentence batch count");
    }
    final contextMode = focus == SentenceSkill.meaningInContext;
    if (contextMode && vocabulary.isEmpty) {
      throw const FormatException("Context understanding requires vocabulary");
    }
    cancel.checkCancelled();
    final id = const Uuid().v4();
    final generationIds = <String>[];
    final generatedModels = <String>{};
    final excluded = {
      ...exclude.take(40).map(normalizeLanguageText),
      if (contextMode)
        ...vocabulary
            .map((c) => normalizeLanguageText(c.sense.example ?? ""))
            .where((s) => s.isNotEmpty),
    };
    final cards = <SentenceCard>[];
    if (provider is MockChatProvider) {
      throw const FormatException(
        "Sentence generation requires an AI provider",
      );
    }
    while (cards.length < count) {
      final requested = math.min(count - cards.length, _chunkSize);
      try {
        final batch = await requestLanguageJson(
          provider: provider,
          config: config,
          usageStore: usageStore,
          feature: contextMode
              ? "language_context_understanding"
              : "language_sentence_batch",
          learnerFocus: {if (focus != null) sentenceAbility(focus)},
          onCaptured: (run) {
            generationIds.add(run.id);
            generatedModels.add(run.model);
          },
          request: AiRequest(
            instructions:
                (contextMode
                        ? LanguagePrompt.contextUnderstanding
                        : LanguagePrompt.sentenceBatch)
                    .instructions(prompts),
            messages: [
              AiMessage.user(
                jsonEncode({
                  "topic": topic.name,
                  if (contextMode)
                    "vocabulary": [
                      for (final c in vocabulary)
                        {"form": c.item.form, "meaning": c.sense.meaning},
                    ],
                  "style": style.name,
                  "level": level?.name ?? "mixed",
                  "count": requested,
                  "glossLanguage": glossLanguage,
                  "skills": SentenceSkill.values
                      .map((skill) => skill.name)
                      .toList(),
                  if (focus != null) "focus": focus.name,
                  "exclude": [
                    for (final text in excluded.take(12))
                      text.substring(0, math.min(text.length, 140)),
                    for (final card in cards.reversed.take(10)) card.text,
                  ],
                }),
              ),
            ],
          ),
          cancel: cancel,
          maxChars: 13000,
          parse: (value) {
            final batch = _parse(
              value,
              id,
              requested,
              cards.length,
              level,
              focus,
              {
                ...excluded,
                for (final card in cards) normalizeLanguageText(card.text),
              },
            );
            String words(String value) => RegExp(
              r"[\p{L}\p{N}]+",
              unicode: true,
            ).allMatches(value.toLowerCase()).map((m) => m.group(0)).join(" ");
            if (contextMode &&
                batch.any(
                  (c) => vocabulary.any(
                    (v) =>
                        v.sense.example != null &&
                        words(c.text) == words(v.sense.example!),
                  ),
                )) {
              throw const FormatException(
                "A new context must differ from saved examples",
              );
            }
            if (contextMode &&
                batch.any(
                  (c) =>
                      c.choices.length < 3 ||
                      c.skill != SentenceSkill.meaningInContext ||
                      c.text.contains("_") ||
                      c.question.contains("_") ||
                      !vocabulary.any(
                        (v) => RegExp(
                          "(?<![A-Za-z0-9_])${RegExp.escape(v.item.form)}(?![A-Za-z0-9_])",
                          caseSensitive: false,
                        ).hasMatch(c.text),
                      ),
                )) {
              throw const FormatException(
                "Expected a new-context interpretation task, not cloze",
              );
            }
            return batch;
          },
        );
        cards.addAll(batch);
      } catch (_) {
        cancel.checkCancelled();
        if (cards.isEmpty) rethrow;
        break;
      }
    }
    cancel.checkCancelled();
    if (cards.isEmpty) {
      throw const FormatException("No suitable English examples");
    }
    return SentenceBatchProposal(
      id: id,
      generationIds: generationIds,
      topic: topic,
      style: style,
      glossLanguage: glossLanguage,
      model: generatedModels.isEmpty
          ? config.model
          : generatedModels.join(" / "),
      promptVersion: _promptVersion,
      isMock: false,
      generatedAt: DateTime.now(),
      cards: List.unmodifiable(cards),
      requestedCount: count,
    );
  }

  Future<SentenceCard> checkSaved(
    SentenceCard card, {
    required String glossLanguage,
    required CancelToken cancel,
  }) => requestLanguageJson(
    provider: provider,
    config: config,
    usageStore: usageStore,
    feature: "language_sentence_check",
    cancel: cancel,
    maxChars: 4000,
    request: AiRequest(
      instructions: LanguagePrompt.sentenceCheck.instructions(prompts),
      messages: [
        AiMessage.user(
          jsonEncode({
            "sentence": card.text,
            "level": card.level.name,
            "glossLanguage": glossLanguage,
            "skills": SentenceSkill.values.map((skill) => skill.name).toList(),
          }),
        ),
      ],
    ),
    parse: (data) {
      if (data is! Map ||
          data.length != 2 ||
          !data.containsKey("skill") ||
          !data.containsKey("check")) {
        throw const FormatException("Invalid saved sentence check");
      }
      final skill = SentenceSkill.values.asNameMap()[data["skill"]];
      return _withCheck(
        card,
        skill,
        data["check"],
        revision: card.revision + 1,
      );
    },
  );

  static List<SentenceCard> _parse(
    Object? data,
    String id,
    int count,
    int offset,
    SentenceLevel? requestedLevel,
    SentenceSkill? focus,
    Set<String> seen,
  ) {
    if (data is! Map ||
        data["language"] != "en" ||
        data["sentences"] is! List) {
      throw const FormatException("Expected English sentences");
    }
    final rows = data["sentences"] as List;
    if (rows.length != count) {
      throw const FormatException("Invalid sentence batch size");
    }
    final cards = <SentenceCard>[];
    for (final row in rows) {
      if (row is! Map ||
          row.keys.any(
            (key) => !const {
              "text",
              "hint",
              "translation",
              "level",
              "skill",
              "check",
            }.contains(key),
          )) {
        throw const FormatException("Invalid sentence fields");
      }
      final text = _text(row["text"]);
      final level = SentenceLevel.values.asNameMap()[row["level"]];
      final skill = SentenceSkill.values.asNameMap()[row["skill"]];
      if (level == null ||
          requestedLevel != null && level != requestedLevel ||
          !_latin.hasMatch(text) ||
          !_latinText.hasMatch(text) ||
          row["skill"] != null && skill == null ||
          !seen.add(normalizeLanguageText(text))) {
        throw const FormatException(
          "Unexpected or repeated sentence, skill, or level",
        );
      }
      final cardId = "$id:${offset + cards.length}";
      final translation = _text(row["translation"]);
      final hint = _text(row["hint"]);
      final check = row["check"];
      if (check == null) {
        cards.add(
          SentenceCard.study(
            id: cardId,
            text: text,
            translation: translation,
            hint: hint,
            level: level,
            skill: skill,
          ),
        );
        continue;
      }
      cards.add(
        _withCheck(
          SentenceCard.study(
            id: cardId,
            text: text,
            translation: translation,
            hint: hint,
            level: level,
            skill: skill,
          ),
          skill,
          check,
        ),
      );
    }
    if (focus != null &&
        cards
                .where((card) => card.skill == focus && card.choices.isNotEmpty)
                .length <
            (count + 1) ~/ 2) {
      throw const FormatException(
        "Insufficient checks for the requested skill",
      );
    }
    return cards;
  }

  static SentenceCard _withCheck(
    SentenceCard card,
    SentenceSkill? skill,
    Object? check, {
    int revision = 1,
  }) {
    if (check is! Map ||
        skill == null ||
        check.keys.any(
          (key) => !const {
            "question",
            "choices",
            "correctIndex",
            "explanation",
          }.contains(key),
        )) {
      throw const FormatException("Invalid sentence comprehension check");
    }
    final options = check["choices"];
    final correctIndex = check["correctIndex"];
    if (options is! List ||
        options.length < 3 ||
        options.length > 4 ||
        correctIndex is! int ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      throw const FormatException("Invalid comprehension check options");
    }
    final choices = options.map(_text).toList();
    if (choices.map(normalizeLanguageText).toSet().length != choices.length) {
      throw const FormatException("Duplicate comprehension check choices");
    }
    final question = _text(check["question"]);
    if (_answerLeak.hasMatch(question)) {
      throw const FormatException("Comprehension check reveals an answer");
    }
    return SentenceCard(
      id: card.id,
      text: card.text,
      translation: card.translation,
      hint: card.hint,
      level: card.level,
      skill: skill,
      language: card.language,
      revision: revision,
      question: question,
      choices: choices,
      correctIndex: correctIndex,
      checkExplanation: _text(check["explanation"]),
    );
  }

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty || value.length > 420) {
      throw const FormatException("Missing or oversized sentence content");
    }
    return value.trim();
  }

  static final _latin = RegExp(r"\p{Script=Latin}", unicode: true);
  static final _latinText = RegExp(
    r"^[\p{Script=Latin}\p{M}\p{N}\p{P}\p{Zs}\r\n]+$",
    unicode: true,
  );
  static final _answerLeak = RegExp(
    r"(?:answer\s*key|correct\s*answer)\s*[:：]",
    caseSensitive: false,
  );
}
