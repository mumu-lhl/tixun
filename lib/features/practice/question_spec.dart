import 'dart:math' as math;

const questionKinds = {
  'single_choice': '单选题',
  'multiple_choice': '多选题',
  'true_false': '判断题',
  'fill_blank': '填空题',
  'numeric': '数值题',
  'short_answer': '自主判分',
};

class QuestionSpec {
  const QuestionSpec({
    required this.kind,
    required this.stem,
    this.subject = '数学',
    this.options = const {},
    required this.answers,
    this.explanation = '',
    this.hint = '',
    this.topics = const [],
    this.absoluteTolerance = 0.000001,
    this.relativeTolerance = 0,
    this.caseSensitive = true,
    this.timeLimitSeconds,
  });
  final String kind, stem, subject, explanation, hint;
  final Map<String, String> options;
  // Each position contains acceptable answers. Multiple choice uses one position per selected option.
  final List<List<String>> answers;
  final List<String> topics;
  final double absoluteTolerance, relativeTolerance;
  final bool caseSensitive;
  final int? timeLimitSeconds;

  factory QuestionSpec.fromJson(Map<String, dynamic> a) {
    const fields = {
      'kind',
      'stem',
      'subject',
      'options',
      'answers',
      'explanation',
      'hint',
      'topics',
      'absolute_tolerance',
      'relative_tolerance',
      'case_sensitive',
      'time_limit_seconds',
    };
    if (a.keys.any((k) => !fields.contains(k))) {
      throw const FormatException('题目包含未知字段。');
    }
    String str(String k, [String fallback = '']) {
      final v = a[k] ?? fallback;
      if (v is! String) throw FormatException('$k 必须是文字。');
      return v;
    }

    final rawOptions = a['options'] ?? <String, dynamic>{};
    final rawAnswers = a['answers'];
    final rawTopics = a['topics'] ?? <dynamic>[];
    if (rawOptions is! Map ||
        rawOptions.keys.any((k) => k is! String) ||
        rawOptions.values.any((v) => v is! String) ||
        rawAnswers is! List ||
        rawAnswers.any((v) => v is! List || v.any((x) => x is! String)) ||
        rawTopics is! List ||
        rawTopics.any((v) => v is! String) ||
        (a.containsKey('case_sensitive') && a['case_sensitive'] is! bool) ||
        (a.containsKey('time_limit_seconds') &&
            a['time_limit_seconds'] is! int)) {
      throw const FormatException('题目选项、答案或参数格式无效。');
    }
    double numValue(String k, double fallback) {
      final v = a[k] ?? fallback;
      if (v is! num) throw FormatException('$k 必须是数字。');
      return v.toDouble();
    }

    final spec = QuestionSpec(
      kind: str('kind'),
      stem: str('stem'),
      subject: str('subject', '数学'),
      options: rawOptions.cast<String, String>(),
      answers: rawAnswers.map((v) => (v as List).cast<String>()).toList(),
      explanation: str('explanation'),
      hint: str('hint'),
      topics: rawTopics.cast<String>(),
      absoluteTolerance: numValue('absolute_tolerance', 0.000001),
      relativeTolerance: numValue('relative_tolerance', 0),
      caseSensitive: a['case_sensitive'] as bool? ?? true,
      timeLimitSeconds: a['time_limit_seconds'] as int?,
    );
    spec.validate();
    return spec;
  }

  void validate() {
    void text(String s, int max, {bool required = false}) {
      if (s.length > max || (required && s.trim().isEmpty)) {
        throw const FormatException('题目文字为空或过长。');
      }
    }

    if (!questionKinds.containsKey(kind)) {
      throw const FormatException('不支持的题型。');
    }
    text(stem, 20000, required: true);
    text(subject, 80, required: true);
    text(explanation, 20000);
    text(hint, 4000);
    if (topics.length > 12 || topics.toSet().length != topics.length) {
      throw const FormatException('知识点过多或重复。');
    }
    for (final t in topics) {
      text(t, 120, required: true);
    }
    if (!absoluteTolerance.isFinite ||
        !relativeTolerance.isFinite ||
        absoluteTolerance < 0 ||
        relativeTolerance < 0 ||
        relativeTolerance > 0.1 ||
        absoluteTolerance > 100 ||
        (timeLimitSeconds != null &&
            (timeLimitSeconds! < 10 || timeLimitSeconds! > 7200))) {
      throw const FormatException('容差或限时设置无效。');
    }
    if (answers.length > 12 ||
        answers.any(
          (a) => a.isEmpty || a.length > 8 || a.toSet().length != a.length,
        )) {
      throw const FormatException('答案数量无效或重复。');
    }
    for (final a in answers.expand((v) => v)) {
      text(a, 4000, required: true);
    }
    final choice = [
      'single_choice',
      'multiple_choice',
      'true_false',
    ].contains(kind);
    if (choice) {
      if (options.length < 2 ||
          options.length > 10 ||
          answers.isEmpty ||
          answers.any((a) => a.length != 1 || !options.containsKey(a.single)) ||
          answers.map((a) => a.single).toSet().length != answers.length ||
          (kind != 'multiple_choice' && answers.length != 1)) {
        throw const FormatException('选项和正确答案不一致。');
      }
      if (kind == 'true_false' &&
          (options.length != 2 ||
              !options.keys.toSet().containsAll(['true', 'false']))) {
        throw const FormatException('判断题选项必须使用 true 和 false。');
      }
      for (final e in options.entries) {
        text(e.key, 20, required: true);
        text(e.value, 4000, required: true);
      }
    } else {
      if (options.isNotEmpty ||
          (kind != 'short_answer' && answers.isEmpty) ||
          (kind == 'numeric' &&
              (answers.length != 1 ||
                  answers.single.length != 1 ||
                  parseNumber(answers.single.single) == null))) {
        throw const FormatException('填空或数值答案无效。');
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'stem': stem,
    'subject': subject,
    'options': options,
    'answers': answers,
    'explanation': explanation,
    'hint': hint,
    'topics': topics,
    'absolute_tolerance': absoluteTolerance,
    'relative_tolerance': relativeTolerance,
    'case_sensitive': caseSensitive,
    if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
  };

  int get responseCount => kind == 'fill_blank' ? answers.length : 1;
  bool grade(List<String> responses) {
    validate();
    if (kind == 'short_answer') throw const FormatException('此题需要自主判分。');
    if (['single_choice', 'multiple_choice', 'true_false'].contains(kind)) {
      final correct = answers.map((a) => a.single).toSet();
      return responses.toSet().length == responses.length &&
          responses.length == correct.length &&
          correct.containsAll(responses);
    }
    if (kind == 'numeric') {
      if (responses.length != 1) return false;
      final value = parseNumber(responses.single),
          expected = parseNumber(answers.single.single)!;
      return value != null &&
          (value - expected).abs() <=
              math.max(absoluteTolerance, relativeTolerance * expected.abs());
    }
    String normalize(String v) =>
        caseSensitive ? v.trim() : v.trim().toLowerCase();
    return responses.length == answers.length &&
        List.generate(
          answers.length,
          (i) => answers[i].map(normalize).contains(normalize(responses[i])),
        ).every((v) => v);
  }
}

double? parseNumber(String value) {
  final parts = value.trim().split('/');
  if (parts.length > 2) return null;
  final n = double.tryParse(parts[0].trim());
  if (n == null || !n.isFinite) return null;
  if (parts.length == 1) return n;
  final d = double.tryParse(parts[1].trim());
  if (d == null || !d.isFinite || d == 0 || !(n / d).isFinite) return null;
  return n / d;
}
