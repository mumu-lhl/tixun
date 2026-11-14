import 'package:tixun/core/l10n/app_error.dart';

import 'dart:math' as math;

const questionKinds = {
  'single_choice': '单选题',
  'multiple_choice': '多选题',
  'true_false': '判断题',
  'fill_blank': '填空题',
  'numeric': '数值题',
  'short_answer': '自主判分',
  'point_select': '点选',
  'region_select': '区域选择',
  'drag_to_target': '拖到目标',
  'read_value': '读图填数',
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
    this.visualId,
    this.visualRevision,
  });
  final String kind, stem, subject, explanation, hint;
  final Map<String, String> options;
  // Each position contains acceptable answers. Multiple choice uses one position per selected option.
  final List<List<String>> answers;
  final List<String> topics;
  final double absoluteTolerance, relativeTolerance;
  final bool caseSensitive;
  final int? timeLimitSeconds;

  /// The visual scene pinned to this question (immutable snapshot).
  /// Null means the question has no visual. The scene is stored via
  /// the VisualQuestionLinks table, not on the question row.
  final String? visualId;

  /// The pinned snapshot revision of [visualId]. Null means "snapshot
  /// the scene's current state when the question is created".
  final int? visualRevision;

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
      'visual_id',
      'visual_revision',
    };
    if (a.keys.any((k) => !fields.contains(k))) {
      throw const AppFormatException(
        AppErrorCode.errorTheQuestionContainsUnknownFields,
        '题目包含未知字段。',
      );
    }
    String str(String k, [String fallback = '']) {
      final v = a[k] ?? fallback;
      if (v is! String) {
        throw AppFormatException(
          AppErrorCode.errorParameterMustBeText,
          '$k 必须是文字。',
          [k],
        );
      }
      return v;
    }

    final kindValue = str('kind');
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
            a['time_limit_seconds'] is! int) ||
        (a.containsKey('visual_id') && a['visual_id'] is! String) ||
        (a.containsKey('visual_revision') && a['visual_revision'] is! int)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionOptionsAnswersOrArguments,
        '题目选项、答案或参数格式无效。',
      );
    }
    double numValue(String k, double fallback) {
      final v = a[k] ?? fallback;
      if (v is! num) {
        throw AppFormatException(
          AppErrorCode.errorParameterMustBeNumber,
          '$k 必须是数字。',
          [k],
        );
      }
      return v.toDouble();
    }

    final spec = QuestionSpec(
      kind: kindValue,
      stem: str('stem'),
      subject: str('subject', '数学'),
      options: rawOptions.cast<String, String>(),
      answers: rawAnswers.map((v) => (v as List).cast<String>()).toList(),
      explanation: str('explanation'),
      hint: str('hint'),
      topics: rawTopics.cast<String>(),
      // A point answer is a tap or a drag, not a typed number: without
      // an explicit tolerance the numeric default (1e-6 model units)
      // would make every tap wrong, so point questions default to half
      // a model unit.
      absoluteTolerance: numValue(
        'absolute_tolerance',
        kindValue == 'point_select' || kindValue == 'drag_to_target'
            ? 0.5
            : 0.000001,
      ),
      relativeTolerance: numValue('relative_tolerance', 0),
      caseSensitive: a['case_sensitive'] as bool? ?? true,
      timeLimitSeconds: a['time_limit_seconds'] as int?,
      visualId: a['visual_id'] as String?,
      visualRevision: a['visual_revision'] as int?,
    );
    spec.validate();
    return spec;
  }

  void validate() {
    void text(String s, int max, {bool required = false}) {
      if (s.length > max || (required && s.trim().isEmpty)) {
        throw const AppFormatException(
          AppErrorCode.errorTheQuestionTextIsEmptyOr,
          '题目文字为空或过长。',
        );
      }
    }

    if (!questionKinds.containsKey(kind)) {
      throw const AppFormatException(
        AppErrorCode.errorUnsupportedQuestionType,
        '不支持的题型。',
      );
    }
    text(stem, 20000, required: true);
    text(subject, 80, required: true);
    text(explanation, 20000);
    text(hint, 4000);
    if (topics.length > 12 || topics.toSet().length != topics.length) {
      throw const AppFormatException(
        AppErrorCode.errorThereAreTooManyKnowledgePoints,
        '知识点过多或重复。',
      );
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
      throw const AppFormatException(
        AppErrorCode.errorInvalidToleranceOrTimeLimit,
        '容差或限时设置无效。',
      );
    }
    if (visualId != null && visualId!.trim().isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '题目图形引用无效。',
        ['visual_id'],
      );
    }
    if (visualRevision != null && (visualId == null || visualRevision! < 1)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '题目图形修订无效。',
        ['visual_revision'],
      );
    }
    if ((kind == 'point_select' ||
            kind == 'region_select' ||
            kind == 'drag_to_target' ||
            kind == 'read_value') &&
        (visualId == null || visualId!.trim().isEmpty)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '点选、区域选择、拖点或读图题必须附带图形。',
        ['visual_id'],
      );
    }
    if (answers.length > 12 ||
        answers.any(
          (a) => a.isEmpty || a.length > 8 || a.toSet().length != a.length,
        )) {
      throw const AppFormatException(
        AppErrorCode.errorTheNumberOfAnswersIsInvalid,
        '答案数量无效或重复。',
      );
    }
    for (final a in answers.expand((v) => v)) {
      text(a, 4000, required: true);
    }
    final choice = [
      'single_choice',
      'multiple_choice',
      'true_false',
      'region_select',
    ].contains(kind);
    if (choice) {
      if (options.length < (kind == 'region_select' ? 1 : 2) ||
          options.length > 10 ||
          answers.isEmpty ||
          answers.any((a) => a.length != 1 || !options.containsKey(a.single)) ||
          answers.map((a) => a.single).toSet().length != answers.length ||
          (kind != 'multiple_choice' && answers.length != 1)) {
        throw const AppFormatException(
          AppErrorCode.errorTheOptionsAndCorrectAnswersDo,
          '选项和正确答案不一致。',
        );
      }
      if (kind == 'true_false' &&
          (options.length != 2 ||
              !options.keys.toSet().containsAll(['true', 'false']))) {
        throw const AppFormatException(
          AppErrorCode.errorTrueFalseOptionsMustUseTrue,
          '判断题选项必须使用 true 和 false。',
        );
      }
      for (final e in options.entries) {
        text(e.key, 20, required: true);
        text(e.value, 4000, required: true);
      }
    } else {
      if (options.isNotEmpty ||
          (kind != 'short_answer' && answers.isEmpty) ||
          ((kind == 'numeric' || kind == 'read_value') &&
              (answers.length != 1 ||
                  answers.single.length != 1 ||
                  parseNumber(answers.single.single) == null))) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidFillInOrNumericAnswer,
          '填空或数值答案无效。',
        );
      }
      if ((kind == 'point_select' || kind == 'drag_to_target') &&
          (answers.length != 1 ||
              answers.single.length != 1 ||
              parseVisualPoint(answers.single.single) == null)) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidFillInOrNumericAnswer,
          '点选或拖点答案无效，应为 "x,y" 形式的坐标。',
        );
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
    if (visualId != null) 'visual_id': visualId,
    if (visualRevision != null) 'visual_revision': visualRevision,
  };

  int get responseCount => kind == 'fill_blank' ? answers.length : 1;
  bool grade(List<String> responses) {
    validate();
    if (kind == 'short_answer') {
      throw const AppFormatException(
        AppErrorCode.errorThisQuestionRequiresSelfGrading,
        '此题需要自主判分。',
      );
    }
    if ([
      'single_choice',
      'multiple_choice',
      'true_false',
      'region_select',
    ].contains(kind)) {
      final correct = answers.map((a) => a.single).toSet();
      return responses.toSet().length == responses.length &&
          responses.length == correct.length &&
          correct.containsAll(responses);
    }
    if (kind == 'point_select' || kind == 'drag_to_target') {
      if (responses.length != 1) return false;
      final expected = parseVisualPoint(answers.single.single)!;
      final actual = parseVisualPoint(responses.single);
      if (actual == null) return false;
      final dx = actual.$1 - expected.$1, dy = actual.$2 - expected.$2;
      return math.sqrt(dx * dx + dy * dy) <= absoluteTolerance;
    }
    if (kind == 'numeric' || kind == 'read_value') {
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

/// Parses a point answer in `"x,y"` form (model coordinates, as produced
/// by tapping a visual). A drag-to-target answer may carry the dragged
/// element id as an `"id:x,y"` prefix; the id is ignored here (callers
/// that need it read it separately), so old plain `"x,y"` answers keep
/// grading exactly as before. Returns null for anything else.
(double, double)? parseVisualPoint(String value) {
  var text = value;
  final colon = text.indexOf(':');
  if (colon >= 0) text = text.substring(colon + 1);
  final parts = text.split(',');
  if (parts.length != 2) return null;
  final x = double.tryParse(parts[0].trim());
  final y = double.tryParse(parts[1].trim());
  if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
  return (x, y);
}
