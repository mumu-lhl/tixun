part of 'ai_usage_screen.dart';

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
              '${context.l10n.tokenTotal}: ${usageTokenCount(total)}',
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
      '${context.l10n.tokenTotal}: ${usageTokenCount(day.tokens)}',
      '${context.l10n.requestCount}: ${usageInteger(day.requests)}',
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
