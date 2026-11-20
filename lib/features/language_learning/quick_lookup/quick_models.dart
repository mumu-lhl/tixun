import "dart:convert";

import "../../../core/database/database.dart";
import "../language_store.dart";
import "../lexical_form.dart";

const quickSchemaRevision = 2;
const quickInputLimit = 3000;
const quickSummaryLimit = 240;
const quickContentLimit = 10000;
const quickSearchLimit = 200;
const quickPromptLimit = 4000;
const quickIcons = ["express", "meaning", "usage", "star", "translate"];
const quickLanguages = ["en", "zh", "ja", "fr", "de", "es", "ko"];

const quickBuiltIns = {
  "language_express": (
    icon: "express",
    source: "auto",
    prompt:
        "Give the most natural and common way to express {input} in "
        "{targetLanguage}, including a rewrite if it is already in the target "
        "language. Start with the usable expression. Offer up to two useful "
        "alternatives with register or context differences. Where context "
        "matters, give a common interpretation and briefly state the assumption.",
  ),
  "language_meaning": (
    icon: "meaning",
    source: "auto",
    prompt:
        "Explain what {input} means. For an expression, start with common "
        "meanings and part of speech; separate senses and show useful examples "
        "and collocations. Add pronunciation or inflections only if useful. "
        "For a sentence, start with its overall meaning and natural translation, "
        "then explain the expressions, tone or structure that matter.",
  ),
  "language_usage": (
    icon: "usage",
    source: "auto",
    prompt:
        "Teach how to use {input} with short natural examples, common "
        "collocations and relevant grammar constraints. Separate distinct senses "
        "and show common mistakes with corrections when useful.",
  ),
};

LanguageQuickAction quickActionDefaults(String id, int position, DateTime now) {
  final builtIn = quickBuiltIns[id];
  return LanguageQuickAction(
    id: id,
    name: "",
    icon: builtIn?.icon ?? "star",
    description: "",
    inputHint: "",
    prompt: builtIn?.prompt ?? "",
    sourceLanguage: builtIn?.source ?? "auto",
    targetLanguage: "en",
    glossLanguage: "app",
    detailed: false,
    position: position,
    builtIn: builtIn != null,
    enabled: true,
    deleted: false,
    revision: 1,
    createdAt: now,
    updatedAt: now,
  );
}

const _variables = {
  "input": "the input field in the user data",
  "sourceLanguage": "the sourceLanguage field in the user data",
  "targetLanguage": "the targetLanguage field in the user data",
  "glossLanguage": "the glossLanguage field in the user data",
  "level": "the level field in the user data",
};

/// Replace variables with references to data fields. Neither user input nor
/// language settings are interpolated into instructions.
String compileQuickPrompt(String template) {
  if (template.trim().isEmpty || template.length > quickPromptLimit) {
    throw const FormatException("Invalid lookup template length");
  }
  return template.replaceAllMapped(RegExp(r"\{([^{}]*)\}|[{}]"), (match) {
    final value = _variables[match[1]];
    if (value == null) throw const FormatException("Invalid template variable");
    return value;
  });
}

void validateQuickAction(LanguageQuickAction action) {
  final builtIn = quickBuiltIns.containsKey(action.id);
  if (action.builtIn != builtIn ||
      (!builtIn && action.name.trim().isEmpty) ||
      action.name.length > 50 ||
      action.description.length > 180 ||
      action.inputHint.length > 180 ||
      !quickIcons.contains(action.icon) ||
      !["auto", ...quickLanguages].contains(action.sourceLanguage) ||
      !quickLanguages.contains(action.targetLanguage) ||
      !["app", ...quickLanguages].contains(action.glossLanguage)) {
    throw const FormatException("Invalid lookup action settings");
  }
  compileQuickPrompt(action.prompt);
}

class QuickQuery {
  const QuickQuery({
    required this.actionId,
    required this.actionName,
    required this.actionRevision,
    required this.prompt,
    required this.input,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.glossLanguage,
    required this.level,
    required this.detailed,
  });

  QuickQuery.fromLookup(LanguageQuickLookup row)
    : this(
        actionId: row.actionId,
        actionName: row.actionName,
        actionRevision: row.actionRevision,
        prompt: row.prompt,
        input: row.input,
        sourceLanguage: row.sourceLanguage,
        targetLanguage: row.targetLanguage,
        glossLanguage: row.glossLanguage,
        level: row.level,
        detailed: row.detailed,
      );

  final String actionId, actionName, prompt, input;
  final String sourceLanguage, targetLanguage, glossLanguage, level;
  final int actionRevision;
  final bool detailed;

  Map<String, Object> get data => {
    "sourceLanguage": sourceLanguage,
    "targetLanguage": targetLanguage,
    "glossLanguage": glossLanguage,
    "level": level,
    "detail": detailed ? "detailed" : "brief",
    "input": input,
  };
}

class QuickSentence {
  const QuickSentence(this.text, this.gloss, this.hint);

  final String text, gloss, hint;

  Map<String, String> toJson() => {"text": text, "gloss": gloss, "hint": hint};
}

class QuickCandidates {
  const QuickCandidates(this.vocabulary, this.sentence);

  factory QuickCandidates.parse(Map<String, dynamic> json) {
    final rawVocabulary = json["vocabulary"];
    if (rawVocabulary != null &&
        (rawVocabulary is! List || rawVocabulary.length > 4)) {
      throw const FormatException("Invalid lookup vocabulary");
    }
    final vocabulary = <VocabularyEntry>[];
    for (final value in rawVocabulary as List? ?? const []) {
      final row = _quickObject(value, {
        "form",
        "type",
        "meaning",
        "example",
        "translation",
        "forms",
      });
      final type = LexicalType.values.asNameMap()[row["type"]];
      if (type == null) throw const FormatException("Invalid lexical type");
      final lemma = _quickText(row["form"], 180);
      final rawForms = row["forms"];
      if (rawForms != null && (rawForms is! List || rawForms.length > 6)) {
        throw const FormatException("Invalid lookup inflections");
      }
      final forms = <LexicalFormDraft>[];
      for (final value in rawForms as List? ?? const []) {
        final form = _quickObject(value, {"surface", "inflection"});
        final inflection = Inflection.values.asNameMap()[form["inflection"]];
        if (inflection == null) {
          throw const FormatException("Invalid inflection tag");
        }
        final draft = LexicalFormDraft(
          _quickText(form["surface"], 80),
          inflection,
        );
        draft.validate(lemma);
        forms.add(draft);
      }
      vocabulary.add(
        VocabularyEntry(
          form: lemma,
          forms: List.unmodifiable(forms),
          type: type,
          meaning: _quickText(row["meaning"], 500),
          example: _quickText(row["example"], 500, optional: true),
          translation: _quickText(row["translation"], 500, optional: true),
        ),
      );
    }
    final rawSentence = json["sentence"];
    QuickSentence? sentence;
    if (rawSentence != null) {
      final row = _quickObject(rawSentence, {"text", "gloss", "hint"});
      sentence = QuickSentence(
        _quickText(row["text"], 1000),
        _quickText(row["gloss"], 1000, optional: true),
        _quickText(row["hint"], 1000, optional: true),
      );
    }
    return QuickCandidates(List.unmodifiable(vocabulary), sentence);
  }

  factory QuickCandidates.fromLookup(LanguageQuickLookup row) =>
      QuickCandidates.parse(jsonDecode(row.candidates) as Map<String, dynamic>);

  final List<VocabularyEntry> vocabulary;
  final QuickSentence? sentence;

  String encode() => jsonEncode({
    if (vocabulary.isNotEmpty)
      "vocabulary": [
        for (final entry in vocabulary)
          {
            "form": entry.form,
            "type": entry.type.name,
            "meaning": entry.meaning,
            "example": entry.example,
            "translation": entry.translation,
            if (entry.forms.isNotEmpty)
              "forms": [
                for (final form in entry.forms)
                  {"surface": form.surface, "inflection": form.inflection.name},
              ],
          },
      ],
    if (sentence != null) "sentence": sentence!.toJson(),
  });
}

class QuickAnswer {
  const QuickAnswer(this.summary, this.content, this.candidates);

  factory QuickAnswer.parse(Object? value) {
    final row = _quickObject(value, {
      "summary",
      "content",
      "vocabulary",
      "sentence",
    });
    final summary = _quickText(row["summary"], quickSummaryLimit);
    if (summary.contains(RegExp(r"[\r\n]"))) {
      throw const FormatException("Invalid lookup summary");
    }
    return QuickAnswer(
      summary,
      _quickText(row["content"], quickContentLimit),
      QuickCandidates.parse(row),
    );
  }

  final String summary, content;
  final QuickCandidates candidates;
}

Map<String, dynamic> _quickObject(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException("Invalid lookup fields");
  }
  return value;
}

String _quickText(Object? value, int limit, {bool optional = false}) {
  if (value == null && optional) return "";
  if (value is! String ||
      (!optional && value.trim().isEmpty) ||
      value.length > limit ||
      value.contains("\u0000")) {
    throw const FormatException("Invalid lookup text");
  }
  return value.trim();
}
