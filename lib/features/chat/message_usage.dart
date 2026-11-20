part of "chat_screen.dart";

void _showMessageUsage(
  BuildContext context,
  AppController controller,
  ChatMessage message,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: FutureBuilder<List<AiUsageEvent>>(
          future: AiUsageStore(controller.db).eventsForAction(message.id),
          builder: (context, snapshot) {
            final rows = snapshot.data ?? const <AiUsageEvent>[];
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  context.l10n.requestDetails,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (snapshot.hasError)
                  Text(context.l10n.usageLoadFailed)
                else if (snapshot.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator()
                else if (rows.isEmpty)
                  Text(
                    message.totalTokens == null
                        ? context.l10n.providerUsageUnavailable
                        : "${context.l10n.tokenTotal}: ${usageInteger(message.totalTokens!)}",
                  )
                else ...[
                  _MessageUsageTotals(rows),
                  const SizedBox(height: 16),
                  UsageTokenBreakdown(rows: rows),
                  const SizedBox(height: 12),
                  for (final row in rows)
                    ListTile(
                      dense: true,
                      title: Text(
                        "${usageFeatureLabel(context, row.feature)} · ${row.model}",
                      ),
                      subtitle: Text(
                        [
                          '${context.l10n.inputTokens}: ${row.inputTokens ?? '—'}',
                          '${context.l10n.cachedInputTokens}: ${row.cachedInputTokens ?? '—'}',
                          '${context.l10n.outputTokens}: ${row.outputTokens ?? '—'}',
                          '${context.l10n.reasoningTokens}: ${row.reasoningTokens ?? '—'}',
                          '${context.l10n.tokenTotal}: ${row.totalTokens ?? '—'}',
                          if (row.usageSource == "legacy_total")
                            context.l10n.legacyUsageTotalOnly,
                        ].join(" · "),
                      ),
                      trailing: Text(switch (row.costBasis) {
                        "estimate" when row.costNanoUsd != null =>
                          "\$${(row.costNanoUsd! / 1000000000).toStringAsFixed(6)}",
                        "subscription" => context.l10n.subscriptionUsage,
                        _ => context.l10n.unknownCost,
                      }),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _MessageUsageTotals extends StatelessWidget {
  const _MessageUsageTotals(this.rows);
  final List<AiUsageEvent> rows;

  @override
  Widget build(BuildContext context) {
    final summary = AiUsageSummary.fromRows(rows);
    final l10n = context.l10n;
    final cost = rows
        .where((row) => row.costBasis == "estimate")
        .map((row) => row.costNanoUsd)
        .nonNulls
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        for (final (label, value) in [
          (l10n.tokenTotal, summary.total),
          (l10n.inputTokens, summary.input),
          (l10n.cachedInputTokens, summary.cachedInput),
          (l10n.outputTokens, summary.output),
          (l10n.reasoningTokens, summary.reasoning),
        ])
          Text('$label · ${value.isEmpty ? '—' : usageInteger(value.value)}'),
        if (cost.isNotEmpty)
          Text(
            "${l10n.estimatedCost} · \$${(cost.reduce((a, b) => a + b) / 1000000000).toStringAsFixed(6)}",
          ),
        if (rows.any((row) => row.costBasis == "subscription"))
          Text(l10n.subscriptionUsage),
        if (rows.any((row) => row.costBasis == "unknown"))
          Text(l10n.unknownCost),
      ],
    );
  }
}
