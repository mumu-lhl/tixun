import "dart:convert";
import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../database/database.dart";
import "../l10n/app_strings.dart";

class UsageTokenBreakdown extends StatelessWidget {
  const UsageTokenBreakdown({required this.rows, super.key});
  final List<AiUsageEvent> rows;

  @override
  Widget build(BuildContext context) {
    // Only rows with a reported input/output split can form a non-overlapping
    // chart. Reasoning is a subset of output, not an additional token count.
    final eligible = rows
        .where((row) => row.inputTokens != null && row.outputTokens != null)
        .toList();
    final l10n = context.l10n;
    var cached = 0, uncached = 0, inputUnknown = 0;
    var reasoning = 0, output = 0, outputUnknown = 0;
    for (final row in eligible) {
      final input = row.inputTokens!;
      if (row.cachedInputTokens case final int reported) {
        final hit = reported.clamp(0, input);
        cached += hit;
        uncached += input - hit;
      } else {
        inputUnknown += input;
      }
      final generated = row.outputTokens!;
      if (row.reasoningTokens case final int reported) {
        final thought = reported.clamp(0, generated);
        reasoning += thought;
        output += generated - thought;
      } else {
        outputUnknown += generated;
      }
    }
    final values = [
      cached,
      uncached,
      inputUnknown,
      reasoning,
      output,
      outputUnknown,
    ];
    final total = values.fold<int>(0, (a, b) => a + b);
    const colors = [
      Color(0xff29a08c),
      Color(0xff3977c3),
      Color(0xff657e97),
      Color(0xff9b59b6),
      Color(0xffdf8636),
      Color(0xffad6351),
    ];
    final labels = [
      l10n.cachedInputTokens,
      l10n.usageUncachedInput,
      l10n.usageInputCacheUnknown,
      l10n.reasoningTokens,
      l10n.usageOtherOutput,
      l10n.usageOutputReasoningUnknown,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.usageTokenBreakdown,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.l10n.usageTokenBreakdownNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (total > 0) ...[
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(painter: _DonutPainter(values, colors)),
            ),
          ),
          for (var i = 0; i < values.length; i++)
            if (values[i] > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.circle, color: colors[i], size: 16),
                title: Text(labels[i]),
                trailing: Text(
                  "${(values[i] * 100 / total).toStringAsFixed(1)}% · ${usageTokenCount(values[i])}",
                ),
              ),
        ] else
          Text(context.l10n.providerUsageUnavailable),
        const SizedBox(height: 16),
        _LocalTokenBreakdown(rows: rows),
      ],
    );
  }
}

class _LocalTokenBreakdown extends StatelessWidget {
  const _LocalTokenBreakdown({required this.rows});
  final List<AiUsageEvent> rows;

  @override
  Widget build(BuildContext context) {
    const keys = [
      "system",
      "user",
      "toolDefinitions",
      "toolCalls",
      "toolResults",
      "reasoning",
      "reply",
    ];
    const colors = [
      Color(0xff3977c3),
      Color(0xff29a08c),
      Color(0xffc09827),
      Color(0xffdb5b62),
      Color(0xff778b45),
      Color(0xff9b59b6),
      Color(0xffdf8636),
    ];
    final labels = [
      context.l10n.usageLocalSystem,
      context.l10n.usageLocalUser,
      context.l10n.usageLocalToolDefinitions,
      context.l10n.usageLocalToolCalls,
      context.l10n.usageLocalToolResults,
      context.l10n.reasoningTokens,
      context.l10n.usageLocalReply,
    ];
    final values = List<int>.filled(keys.length, 0);
    var covered = 0;
    for (final row in rows) {
      if (row.tokenBreakdownJson == null) continue;
      try {
        final decoded = jsonDecode(row.tokenBreakdownJson!);
        if (decoded is! Map || decoded["counts"] is! Map) continue;
        final counts = decoded["counts"] as Map;
        covered++;
        for (var i = 0; i < keys.length; i++) {
          if (counts[keys[i]] case final int count when count > 0) {
            values[i] += count;
          }
        }
      } on FormatException {
        // Provider figures remain available for legacy or malformed local rows.
      }
    }
    final total = values.fold<int>(0, (a, b) => a + b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.usageLocalBreakdown,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          context.l10n.usageLocalBreakdownNote(covered, rows.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (total > 0) ...[
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(painter: _DonutPainter(values, colors)),
            ),
          ),
          for (var i = 0; i < values.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.circle, color: colors[i], size: 16),
              title: Text(labels[i]),
              trailing: Text(
                "${(values[i] * 100 / total).toStringAsFixed(1)}% · ${usageTokenCount(values[i])}",
              ),
            ),
        ] else
          Text(context.l10n.providerUsageUnavailable),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors);
  final List<int> values;
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (a, b) => a + b);
    var start = -math.pi / 2;
    final rect = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    for (var i = 0; i < values.length; i++) {
      final sweep = 2 * math.pi * values[i] / total;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}

String usageFeatureLabel(
  BuildContext context,
  String feature,
) => switch (feature) {
  "chat" => context.l10n.usageFeatureChat,
  "context_compaction" => context.l10n.usageFeatureContextCompaction,
  "exam_scores" => context.l10n.usageFeatureExamScores,
  "language_quick_lookup" ||
  "language_quick_extract" => context.l10n.quickLookup,
  "language_vocabulary" => context.l10n.usageFeatureLanguageVocabulary,
  "language_explanation" => context.l10n.usageFeatureLanguageExplanation,
  "language_sentence_check" => context.l10n.usageFeatureLanguageSentenceBatch,
  "language_context_understanding" => context.l10n.languageNewContexts,
  "language_vocabulary_revision" => context.l10n.languageGroups,
  "language_sentence_batch" => context.l10n.usageFeatureLanguageSentenceBatch,
  "language_exam_generation" => context.l10n.usageFeatureLanguageExamGeneration,
  "language_exam_review" => context.l10n.usageFeatureLanguageExamReview,
  "language_writing_task" => context.l10n.usageFeatureLanguageWritingTask,
  "language_writing" => context.l10n.usageFeatureLanguageWriting,
  "connection_test" => context.l10n.usageFeatureConnectionTest,
  "a2ui_create" => context.l10n.chatA2uiLabel,
  "visual_create" => context.l10n.usageFeatureVisualCreate,
  "visual_edit" => context.l10n.usageFeatureVisualEdit,
  "quiz_with_visual" => context.l10n.usageFeatureQuizWithVisual,
  _ => feature,
};

String usageInteger(int value) => value.toString().replaceAllMapped(
  RegExp(r"\B(?=(\d{3})+(?!\d))"),
  (_) => ",",
);

String usageTokenCount(int value) {
  final (divisor, suffix) = value >= 1000000000
      ? (1000000000, "B")
      : value >= 1000000
      ? (1000000, "M")
      : value >= 1000
      ? (1000, "K")
      : (1, "");
  if (divisor == 1) return "$value";
  final formatted = (value / divisor).toStringAsFixed(2);
  return '${formatted.replaceFirst(RegExp(r"0+$"), "").replaceFirst(RegExp(r"\.$"), "")}$suffix';
}
