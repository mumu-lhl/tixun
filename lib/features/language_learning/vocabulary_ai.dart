import "dart:convert";
import "dart:math" as math;

import "package:dio/dio.dart";
import "package:uuid/uuid.dart";

import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/database/database.dart";
import "language_json_request.dart";
import "generation_provider.dart";
import "language_skills.dart";
import "generation_store.dart";
import "language_store.dart";
import "lexical_form.dart";
import "sentence_content.dart";

enum VocabularyLevel { beginner, intermediate, advanced }

class VocabularyProposal {
  const VocabularyProposal(
    this.entries,
    this.provenance, {
    this.requested,
    this.groupTitle,
  });

  final List<VocabularyEntry> entries;
  final VocabularyProvenance provenance;
  final int? requested;
  final String? groupTitle;
}

/// Standalone request: no tools, no chat session and no writes to the word bank.
class VocabularyAi {
  const VocabularyAi(this.provider, {this.usageStore, this.prompts});

  final ChatProvider provider;
  final AiUsageStore? usageStore;
  final PromptSettings? prompts;
  static const maximumEntries = 20;
  static const _perRequest = 6;
  static const promptVersion = 8;

  Future<VocabularyProposal> propose({
    required ProviderConfig config,
    required String topic,
    required VocabularyGroupType groupType,
    required VocabularyLevel level,
    required String glossLanguage,
    required List<String> existingExpressions,
    required CancelToken cancel,
    Set<String> localExclusions = const {},
    int count = _perRequest,
    SentenceSkill? focus,
    bool generateGroupTitle = false,
  }) async {
    if (count < 1 || count > maximumEntries) {
      throw const FormatException("Invalid vocabulary candidate count");
    }
    config = languageConfiguration(provider, config);
    final generationIds = <String>[];
    final generationByForm = <String, String>{};
    LanguageGenerationRun? generated;
    final mock = provider is MockChatProvider;
    String? groupTitle;
    final entries = <VocabularyEntry>[];
    final exclusions = existingExpressions.map(normalizeLanguageText).toSet();
    final blocked = {...exclusions, ...localExclusions};
    if (mock) {
      if (generateGroupTitle) {
        groupTitle = glossLanguage == "zh" ? "旅行英语" : "Travel English";
      }
      entries.addAll(
        _parse(decodeLanguageJson(_mockReply(glossLanguage).text), _perRequest)
            .where(
              (entry) => !blocked.contains(normalizeLanguageText(entry.form)),
            )
            .take(count),
      );
    } else {
      while (entries.length < count) {
        cancel.checkCancelled();
        final size = math.min(_perRequest, count - entries.length);
        final needsTitle = generateGroupTitle && groupTitle == null;
        try {
          final batch = await requestLanguageJson(
            provider: provider,
            config: config,
            usageStore: usageStore,
            feature: "language_vocabulary",
            learnerFocus: {if (focus != null) sentenceAbility(focus)},
            onCaptured: (run) {
              generated = run;
              generationIds.add(run.id);
            },
            request: AiRequest(
              instructions: LanguagePrompt.vocabulary.instructions(prompts),
              messages: [
                AiMessage.user(
                  jsonEncode({
                    "topic": ?(groupTitle ?? (topic.isEmpty ? null : topic)),
                    if (needsTitle) "generateGroupTitle": true,
                    "groupType": groupType.name,
                    "level": level.name,
                    "count": size,
                    "glossLanguage": glossLanguage,
                    if (focus != null) "focus": focus.name,
                    "exclude": [
                      ...entries.map((entry) => entry.form).take(20),
                      ...exclusions.take(25),
                    ],
                  }),
                ),
              ],
            ),
            cancel: cancel,
            maxChars: 12000,
            parse: (value) => (
              title: needsTitle ? _parseGroupTitle(value) : null,
              entries: _parse(value, size)
                  .where(
                    (entry) =>
                        !blocked.contains(normalizeLanguageText(entry.form)) &&
                        !entries.any(
                          (earlier) =>
                              normalizeLanguageText(earlier.form) ==
                              normalizeLanguageText(entry.form),
                        ),
                  )
                  .toList(),
            ),
          );
          if (generated != null) {
            for (final entry in batch.entries) {
              generationByForm[normalizeLanguageText(entry.form)] =
                  generated!.id;
            }
          }
          groupTitle ??= batch.title;
          entries.addAll(batch.entries);
          if (batch.entries.length < size) break;
        } catch (_) {
          cancel.checkCancelled();
          if (entries.isEmpty) rethrow;
          break;
        }
      }
    }
    cancel.checkCancelled();
    if (entries.isEmpty) {
      throw const FormatException("No new vocabulary candidates");
    }
    return VocabularyProposal(
      List.unmodifiable(entries),
      VocabularyProvenance(
        batchId: const Uuid().v4(),
        model: mock ? "Mock" : (generated?.model ?? config.model),
        promptVersion: promptVersion,
        generatedAt: DateTime.now(),
        mock: mock,
        generationIds: generationIds,
        generationByForm: generationByForm,
      ),
      requested: count,
      groupTitle: groupTitle,
    );
  }

  Future<({VocabularyEntry entry, LanguageGenerationRun? generation})> revise({
    required ProviderConfig config,
    required LanguageCard card,
    required String glossLanguage,
    required CancelToken cancel,
  }) async {
    final old = {
      "entries": [
        {
          "form": card.item.form,
          "type": card.item.lexicalType,
          "meaning": card.sense.meaning,
          if (card.sense.partOfSpeech != null)
            "partOfSpeech": card.sense.partOfSpeech,
          if (card.sense.example != null) "example": card.sense.example,
          if (card.sense.exampleTranslation != null)
            "translation": card.sense.exampleTranslation,
          if (card.sense.application != null)
            "application": card.sense.application,
          if (card.sense.applicationAnswer != null)
            "applicationAnswer": card.sense.applicationAnswer,
        },
      ],
    };
    LanguageGenerationRun? generation;
    final entry = await requestLanguageJson(
      provider: provider,
      config: config,
      usageStore: usageStore,
      feature: "language_vocabulary_revision",
      request: AiRequest(
        instructions:
            "${LanguagePrompt.vocabulary.instructions(prompts)}\n$vocabularyRevisionContract",
        messages: [
          AiMessage.user(
            jsonEncode({
              "form": card.item.form,
              "type": card.item.lexicalType,
              "meaning": card.sense.meaning,
              "count": 1,
              "glossLanguage": glossLanguage,
            }),
          ),
        ],
      ),
      cancel: cancel,
      original: GenerationOriginal(
        output: jsonEncode(old),
        model: card.sense.aiModel ?? "unknown",
        kind: "vocabulary",
        contentId: card.sense.id,
      ),
      onCaptured: (run) => generation = run,
      parse: (data) {
        final entry = _parse(data, 1).single;
        if (normalizeLanguageText(entry.form) != card.item.normalizedForm ||
            entry.type.name != card.item.lexicalType ||
            entry.meaning.trim() != card.sense.meaning) {
          throw const FormatException(
            "A vocabulary revision changed the requested sense",
          );
        }
        return entry;
      },
    );
    return (entry: entry, generation: generation);
  }

  static String _parseGroupTitle(Object? data) {
    final value = data is Map ? data["groupTitle"] : null;
    if (value is! String) {
      throw const FormatException("Missing vocabulary group title");
    }
    final title = value.trim();
    if (title.isEmpty ||
        title.length > 100 ||
        title.contains(RegExp(r"[\r\n]"))) {
      throw const FormatException("Invalid vocabulary group title");
    }
    return title;
  }

  static List<VocabularyEntry> _parse(Object? data, int count) {
    if (data is! Map || data["language"] != "en" || data["entries"] is! List) {
      throw const FormatException("Expected an English vocabulary list");
    }
    final list = data["entries"] as List;
    if (list.isEmpty || list.length > count) {
      throw const FormatException("Invalid candidate count");
    }

    final seen = <String>{};
    final entries = <VocabularyEntry>[];
    for (final row in list) {
      if (row is! Map) throw const FormatException("Invalid candidate");
      String requiredText(String key, int max) {
        final value = row[key];
        if (value is! String || value.trim().isEmpty || value.length > max) {
          throw const FormatException("Missing or oversized vocabulary field");
        }
        return value.trim();
      }

      final form = requiredText("form", 80);
      final meaning = requiredText("meaning", 240);
      final example = requiredText("example", 240);
      final translation = requiredText("translation", 240);
      final withApplication =
          row["application"] != null || row["applicationAnswer"] != null;
      final application = withApplication
          ? requiredText("application", 240)
          : null;
      final applicationAnswer = withApplication
          ? requiredText("applicationAnswer", 80)
          : null;
      if (application != null &&
          ("___".allMatches(application).length != 1 ||
              !_latinText(application) ||
              !_latinText(applicationAnswer!) ||
              normalizeLanguageText(
                    application.replaceFirst("___", applicationAnswer),
                  ) ==
                  normalizeLanguageText(example))) {
        throw const FormatException("Invalid vocabulary application");
      }
      final type = LexicalType.values
          .where((type) => type.name == row["type"])
          .firstOrNull;
      // Reject obvious script mismatches; English accuracy still needs review.
      if (type == null || !_latinText(form) || !_latinText(example)) {
        throw const FormatException("Invalid vocabulary language or type");
      }
      final partOfSpeech =
          type == LexicalType.word || row["partOfSpeech"] != null
          ? requiredText("partOfSpeech", 24)
          : null;
      if (partOfSpeech != null && !_latinText(partOfSpeech)) {
        throw const FormatException("Invalid vocabulary part of speech");
      }
      if (!seen.add(normalizeLanguageText(form))) {
        continue;
      }
      final rawForms = row["forms"];
      if (rawForms != null && (rawForms is! List || rawForms.length > 16)) {
        throw const FormatException("Invalid vocabulary inflections");
      }
      final forms = <LexicalFormDraft>[];
      final seenForms = <String>{};
      for (final value in (rawForms as List? ?? const [])) {
        if (value is! Map ||
            value["surface"] is! String ||
            value["inflection"] is! String) {
          throw const FormatException("Invalid vocabulary inflection");
        }
        final inflection = Inflection.values.asNameMap()[value["inflection"]];
        if (inflection == null || type != LexicalType.word) {
          throw const FormatException("Invalid vocabulary inflection type");
        }
        final draft = LexicalFormDraft(value["surface"] as String, inflection);
        draft.validate(form);
        if (seenForms.add(
          "${inflection.name}:${LexicalFormDraft.normalizeSurface(draft.surface)}",
        )) {
          forms.add(draft);
        }
      }
      entries.add(
        VocabularyEntry(
          form: form,
          meaning: meaning,
          type: type,
          partOfSpeech: partOfSpeech,
          forms: List.unmodifiable(forms),
          example: example,
          translation: translation,
          application: application,
          applicationAnswer: applicationAnswer,
        ),
      );
    }
    return List.unmodifiable(entries);
  }

  static final _latin = RegExp(r"\p{Script=Latin}", unicode: true);
  static final _englishScript = RegExp(
    r"^[\p{Script=Latin}\p{M}\p{N}\p{P}\p{Zs}]+$",
    unicode: true,
  );

  static bool _latinText(String text) =>
      _latin.hasMatch(text) && _englishScript.hasMatch(text);

  static AiChunk _mockReply(String glossLanguage) {
    final zh = glossLanguage == "zh";
    return AiChunk(
      completed: true,
      text: jsonEncode({
        "language": "en",
        "entries": [
          {
            "form": "ticket",
            "type": "word",
            "partOfSpeech": "n.",
            "meaning": zh ? "车票" : "a pass for a journey",
            "example": "I bought a ticket at the station.",
            "translation": zh
                ? "我在车站买了一张车票。"
                : "I paid for my trip at the station.",
          },
          {
            "form": "check in",
            "type": "phrasalVerb",
            "partOfSpeech": "v.",
            "meaning": zh ? "办理入住手续" : "register upon arrival",
            "example": "We can check in at the hotel after three.",
            "translation": zh
                ? "三点以后我们可以到酒店办理入住。"
                : "The hotel can register us after three.",
          },
          {
            "form": "round trip",
            "type": "phrase",
            "meaning": zh ? "往返旅程" : "a journey to a place and back",
            "example": "Is the round trip cheaper than two single tickets?",
            "translation": zh
                ? "往返票比两张单程票便宜吗？"
                : "Does traveling both ways cost less on one ticket?",
          },
        ],
      }),
    );
  }
}
