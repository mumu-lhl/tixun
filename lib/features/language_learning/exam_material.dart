import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'language_store.dart';
import 'sentence_content.dart';

enum ExamKind { reading, sentenceInsertion, cloze, grammar }

enum ExamConfidence { certain, unsure, guess }

enum ExamSource { bundled, userCreated, aiGenerated }

enum ExamVerification { bundled, structureChecked, aiReviewed, reviewRejected }

enum ExamProfile {
  zhejiang2026('zhejiang-gaokao-en-2026-v1');

  const ExamProfile(this.id);
  final String id;
}

class ExamTarget {
  const ExamTarget({
    required this.kind,
    required this.level,
    required this.count,
    this.profile = ExamProfile.zhejiang2026,
    this.skill,
    this.topic = '',
  });
  final ExamKind kind;
  final SentenceLevel level;
  final int count;
  final ExamProfile profile;
  final SentenceSkill? skill;
  final String topic;

  List<int> get counts => switch (kind) {
    ExamKind.reading => const [2, 3, 4, 5],
    ExamKind.sentenceInsertion => const [5],
    ExamKind.cloze => const [3, 5, 10, 15],
    ExamKind.grammar => const [3, 5, 10],
  };

  void validate() {
    if (!counts.contains(count) || topic.length > 100) {
      throw const FormatException('Invalid exam practice target');
    }
  }
}

class ExamItem {
  const ExamItem({
    required this.prompt,
    required this.answers,
    required this.skill,
    required this.evidence,
    required this.explanation,
    this.options = const {},
    this.distractors = const {},
  });
  final String prompt, evidence, explanation;
  final SentenceSkill skill;
  final List<String> answers;
  final Map<String, String> options, distractors;

  bool matches(String response) => answers.any(
    (answer) => normalizeExamAnswer(answer) == normalizeExamAnswer(response),
  );

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    'answers': answers,
    'skill': skill.name,
    'evidence': evidence,
    'explanation': explanation,
    if (options.isNotEmpty) 'options': options,
    if (distractors.isNotEmpty) 'distractors': distractors,
  };
}

String normalizeExamAnswer(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll('’', "'")
    .toLowerCase();

class ExamPaper {
  const ExamPaper({
    required this.title,
    required this.paragraphs,
    required this.items,
    this.candidates = const {},
  });
  final String title;
  final List<String> paragraphs;
  final List<ExamItem> items;
  final Map<String, String> candidates;

  String get fingerprint => sha256
      .convert(utf8.encode(normalizeLanguageText(paragraphs.join(' '))))
      .toString();

  Map<String, String> optionsFor(int position) =>
      candidates.isEmpty ? items[position].options : candidates;

  Map<String, Object?> toJson() => {
    'title': title,
    'paragraphs': paragraphs,
    if (candidates.isNotEmpty) 'candidates': candidates,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory ExamPaper.parse(
    Object? input,
    ExamTarget target, {
    bool requireDistractors = true,
  }) {
    target.validate();
    final map = _object(input, {'title', 'paragraphs', 'candidates', 'items'});
    final title = _text(map['title'], 120);
    final paragraphs = _texts(map['paragraphs'], 12, 1500);
    if (paragraphs.join(' ').length > 6800 ||
        paragraphs.map(normalizeLanguageText).toSet().length !=
            paragraphs.length) {
      throw const FormatException('Duplicate or oversized exam passage');
    }
    final insertion = target.kind == ExamKind.sentenceInsertion;
    final grammar = target.kind == ExamKind.grammar;
    final reading = target.kind == ExamKind.reading;
    final candidates = insertion
        ? _options(map['candidates'], min: 7, max: 7)
        : const <String, String>{};
    if (!insertion && map.containsKey('candidates')) {
      throw const FormatException('Unexpected shared candidates');
    }

    final blanks = [
      for (final paragraph in paragraphs)
        for (final match in RegExp(r'\[(\d+)\]').allMatches(paragraph))
          int.parse(match[1]!),
    ];
    if (reading
        ? blanks.isNotEmpty
        : blanks.length != target.count ||
              blanks.indexed.any((entry) => entry.$1 + 1 != entry.$2)) {
      throw const FormatException(
        'Missing, duplicate, or unordered passage blanks',
      );
    }

    final rows = map['items'];
    if (rows is! List || rows.length != target.count) {
      throw const FormatException('Incorrect exam question count');
    }
    final items = <ExamItem>[];
    for (final (index, row) in rows.indexed) {
      final fields = _object(row, {
        'prompt',
        'answers',
        'skill',
        'evidence',
        'explanation',
        'options',
        'distractors',
      });
      final prompt = _text(fields['prompt'], 360);
      final answers = _texts(
        fields['answers'],
        grammar ? 6 : 1,
        grammar ? 100 : 1,
      );
      final evidence = _text(fields['evidence'], 1500);
      final explanation = _text(fields['explanation'], 700);
      final skill = SentenceSkill.values.asNameMap()[fields['skill']];
      final hasOptions = !grammar && !insertion;
      final options = hasOptions
          ? _options(fields['options'], min: 3, max: 4)
          : const <String, String>{};
      final allowed = insertion ? candidates : options;
      final distractors = fields['distractors'] == null
          ? const <String, String>{}
          : _options(fields['distractors'], min: 1, max: 3, consecutive: false);
      if (skill == null ||
          answers.map(normalizeExamAnswer).toSet().length != answers.length ||
          !paragraphs.any((p) => p.contains(evidence)) ||
          (!reading && !prompt.contains('[${index + 1}]')) ||
          (!reading &&
              !paragraphs.any(
                (p) => p.contains(evidence) && p.contains('[${index + 1}]'),
              )) ||
          (!hasOptions && fields.containsKey('options')) ||
          (!grammar && !allowed.containsKey(answers.single)) ||
          distractors.keys.any(
            (key) => !options.containsKey(key) || answers.contains(key),
          ) ||
          (reading &&
              requireDistractors &&
              distractors.length != options.length - 1) ||
          _answerLeak.hasMatch(prompt)) {
        throw const FormatException('Invalid exam answer, skill, or evidence');
      }
      items.add(
        ExamItem(
          prompt: prompt,
          answers: answers,
          skill: skill,
          evidence: evidence,
          explanation: explanation,
          options: options,
          distractors: distractors,
        ),
      );
    }
    if (_answerLeak.hasMatch(paragraphs.join('\n')) ||
        (reading &&
            items.map((i) => normalizeLanguageText(i.prompt)).toSet().length !=
                items.length) ||
        candidates.values.any(
          (text) => paragraphs.any(
            (p) =>
                normalizeLanguageText(p).contains(normalizeLanguageText(text)),
          ),
        ) ||
        (insertion &&
            items.map((item) => item.answers.single).toSet().length != 5) ||
        (target.skill != null && !items.any((i) => i.skill == target.skill))) {
      throw const FormatException(
        'Duplicate exam prompts, repeated candidates, or answer leakage',
      );
    }
    return ExamPaper(
      title: title,
      paragraphs: paragraphs,
      candidates: candidates,
      items: items,
    );
  }
}

final _answerLeak = RegExp(
  r'(?:answer\s*key|correct\s*answers?)\s*[:：]|(?:正确答案|参考答案)\s*[:：]',
  caseSensitive: false,
);

Map<String, dynamic> _object(Object? input, Set<String> fields) {
  if (input is! Map<String, dynamic> ||
      input.keys.any((key) => !fields.contains(key))) {
    throw const FormatException('Unexpected exam fields');
  }
  return input;
}

String _text(Object? input, int limit) {
  if (input is! String || input.trim().isEmpty || input.length > limit) {
    throw const FormatException('Missing or oversized exam text');
  }
  return input.trim();
}

List<String> _texts(Object? input, int max, int textLimit) {
  if (input is! List || input.isEmpty || input.length > max) {
    throw const FormatException('Invalid exam text list');
  }
  return List.unmodifiable(input.map((value) => _text(value, textLimit)));
}

Map<String, String> _options(
  Object? input, {
  required int min,
  required int max,
  bool consecutive = true,
}) {
  if (input is! Map<String, dynamic> ||
      input.length < min ||
      input.length > max ||
      input.keys.any((key) => !RegExp(r'^[A-G]$').hasMatch(key)) ||
      (consecutive &&
          List.generate(
            input.length,
            (i) => String.fromCharCode(65 + i),
          ).any((key) => !input.containsKey(key)))) {
    throw const FormatException('Invalid exam options');
  }
  final keys = input.keys.toList()..sort();
  final options = {for (final key in keys) key: _text(input[key], 420)};
  if (consecutive &&
      options.values.map(normalizeLanguageText).toSet().length !=
          options.length) {
    throw const FormatException('Duplicate exam options');
  }
  return Map.unmodifiable(options);
}
