part of 'ai_usage_screen.dart';

class _TokenBreakdown extends StatelessWidget {
  const _TokenBreakdown({required this.rows});
  final List<AiUsageEvent> rows;

  @override
  Widget build(BuildContext context) {
    // Only rows with a reported input/output split can form a non-overlapping
    // chart. Reasoning is a subset of output, not an additional token count.
    final eligible = rows
        .where((row) => row.inputTokens != null && row.outputTokens != null)
        .toList();
    var input = 0, reasoning = 0, output = 0;
    for (final row in eligible) {
      input += row.inputTokens!;
      final r = (row.reasoningTokens ?? 0).clamp(0, row.outputTokens!);
      reasoning += r;
      output += row.outputTokens! - r;
    }
    final values = [input, reasoning, output];
    final total = values.fold<int>(0, (a, b) => a + b);
    final colors = [
      const Color(0xff3977c3),
      const Color(0xff9b59b6),
      const Color(0xffdf8636),
    ];
    final labels = [
      context.l10n.inputTokens,
      context.l10n.reasoningTokens,
      context.l10n.usageOtherOutput,
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(Icons.circle, color: colors[i], size: 16),
              title: Text(labels[i]),
              trailing: Text(
                '${(values[i] * 100 / total).toStringAsFixed(1)}% · ${_token(values[i])} (${_int(values[i])})',
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
      'system',
      'user',
      'toolDefinitions',
      'toolCalls',
      'toolResults',
      'reasoning',
      'reply',
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
      final decoded =
          jsonDecode(row.tokenBreakdownJson!) as Map<String, dynamic>;
      final counts = decoded['counts'] as Map<String, dynamic>;
      covered++;
      for (var i = 0; i < keys.length; i++) {
        values[i] += (counts[keys[i]] as int?) ?? 0;
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
                '${(values[i] * 100 / total).toStringAsFixed(1)}% · ${_token(values[i])} (${_int(values[i])})',
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

class _StatData {
  const _StatData(this.label, this.value, this.hint);
  final String label;
  final String value;
  final String? hint;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.label,
    required this.value,
    this.hint,
  });

  final double width;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 28,
                child: Text(
                  hint ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageTrend extends StatelessWidget {
  const _UsageTrend({required this.days, this.caption});

  final List<UsageDay> days;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final maxTokens = days.fold<int>(
      0,
      (max, day) => day.tokens > max ? day.tokens : max,
    );
    final total = days.fold<int>(0, (sum, day) => sum + day.tokens);
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return Column(
      key: const Key('ai-usage-trend'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.usageDailyTokens,
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${context.l10n.tokenTotal}: ${_token(total)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: _bar(context, day, maxTokens, todayKey),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _axisLabels(context),
      ],
    );
  }

  Widget _bar(
    BuildContext context,
    UsageDay day,
    int maxTokens,
    DateTime todayKey,
  ) {
    final colors = Theme.of(context).colorScheme;
    final message = [
      _dateOnly(day.day),
      '${context.l10n.tokenTotal}: ${_token(day.tokens)}',
      '${context.l10n.requestCount}: ${_int(day.requests)}',
      if (day.estimatedCostNanoUsd > 0)
        '${context.l10n.estimatedCost}: ${_usd(day.estimatedCostNanoUsd)}',
    ].join('\n');
    final ratio = maxTokens == 0 ? 0.0 : day.tokens / maxTokens;
    final height = day.tokens == 0
        ? (day.requests > 0 ? 2.0 : 1.0)
        : 6 + 76 * ratio;
    final isToday = day.day == todayKey;
    final hasActivity = day.tokens > 0 || day.requests > 0;
    return Tooltip(
      message: message,
      child: Semantics(
        label: message,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: !hasActivity
                ? colors.outlineVariant.withValues(alpha: .35)
                : colors.primary.withValues(alpha: isToday ? 1 : .55),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ),
      ),
    );
  }

  Widget _axisLabels(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 10,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (days.isEmpty) return const SizedBox.shrink();
    if (days.length <= 7) {
      return Row(
        children: [
          for (final day in days)
            Expanded(
              child: Text(
                _shortDate(day.day),
                textAlign: TextAlign.center,
                style: style,
              ),
            ),
        ],
      );
    }
    return Row(
      children: [
        Text(_shortDate(days.first.day), style: style),
        const Spacer(),
        Text(_shortDate(days.last.day), style: style),
      ],
    );
  }
}
