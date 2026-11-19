part of 'ai_usage_screen.dart';

class _SessionUsage extends ConsumerWidget {
  const _SessionUsage({required this.rows});
  final List<AiUsageEvent> rows;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<AiUsageEvent>>{};
    for (final row in rows) {
      if (row.sessionId != null) {
        grouped.putIfAbsent(row.sessionId!, () => []).add(row);
      }
    }
    if (grouped.isEmpty) return const SizedBox.shrink();
    return FutureBuilder<List<ChatSession>>(
      future: ref.read(appControllerProvider).db.sessions(),
      builder: (context, snapshot) {
        final titles = {
          for (final session in snapshot.data ?? <ChatSession>[])
            session.id: session.title,
        };
        return ExpansionTile(
          key: const Key('ai-usage-sessions'),
          tilePadding: EdgeInsets.zero,
          title: Text(context.l10n.usageSessions),
          children: [
            for (final entry in grouped.entries)
              Builder(
                builder: (context) {
                  final summary = AiUsageSummary.fromRows(
                    entry.value,
                    recentLimit: entry.value.length,
                  );
                  return ExpansionTile(
                    title: Text(titles[entry.key] ?? entry.key),
                    subtitle: Text(
                      '${context.l10n.tokenTotal}: ${_sumText(summary.total)} · ${context.l10n.requestCount}: ${summary.requests}',
                    ),
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _SessionUsagePage(
                              sessionId: entry.key,
                              title: titles[entry.key] ?? entry.key,
                            ),
                          ),
                        ),
                        child: Text(context.l10n.usageFullSession),
                      ),
                      _TokenBreakdown(rows: entry.value),
                      ListTile(
                        title: Text(
                          '${context.l10n.inputTokens}: ${_sumText(summary.input)} · ${context.l10n.outputTokens}: ${_sumText(summary.output)}',
                        ),
                      ),
                      ListTile(
                        title: Text(
                          '${context.l10n.cachedInputTokens}: ${_sumText(summary.cachedInput)} · ${context.l10n.reasoningTokens}: ${_sumText(summary.reasoning)}',
                        ),
                      ),
                      for (final row in summary.recent)
                        _UsageRequestTile(row: row),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _SessionUsagePage extends ConsumerStatefulWidget {
  const _SessionUsagePage({required this.sessionId, required this.title});
  final String sessionId;
  final String title;
  @override
  ConsumerState<_SessionUsagePage> createState() => _SessionUsagePageState();
}

class _SessionUsagePageState extends ConsumerState<_SessionUsagePage> {
  late final Future<List<AiUsageEvent>> events;
  @override
  void initState() {
    super.initState();
    events = AiUsageStore(ref.read(appControllerProvider).db)
        .eventsForSession(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: FutureBuilder<List<AiUsageEvent>>(
      future: events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(context.l10n.usageLoadFailed));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        final summary = AiUsageSummary.fromRows(rows, recentLimit: rows.length);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              context.l10n.usageFullSession,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ListTile(
              title: Text(
                '${context.l10n.tokenTotal}: ${_sumText(summary.total)} · ${context.l10n.requestCount}: ${summary.requests}',
              ),
            ),
            ListTile(
              title: Text(
                '${context.l10n.inputTokens}: ${_sumText(summary.input)} · ${context.l10n.outputTokens}: ${_sumText(summary.output)}',
              ),
            ),
            ListTile(
              title: Text(
                '${context.l10n.cachedInputTokens}: ${_sumText(summary.cachedInput)} · ${context.l10n.reasoningTokens}: ${_sumText(summary.reasoning)}',
              ),
            ),
            _TokenBreakdown(rows: rows),
            Text(
              context.l10n.requestDetails,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final row in summary.recent) _UsageRequestTile(row: row),
          ],
        );
      },
    ),
  );
}

class _UsageRequestTile extends StatelessWidget {
  const _UsageRequestTile({required this.row});

  final AiUsageEvent row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (row.status) {
      'complete' => (Icons.check_circle_outline, colors.primary),
      'cancelled' || 'incomplete' => (Icons.pending_outlined, colors.tertiary),
      _ => (Icons.error_outline, colors.error),
    };
    final details = [
      _statusLabel(context, row.status),
      _featureLabel(context, row.feature),
      _dateTime(row.occurredAt.toLocal()),
      row.totalTokens == null
          ? l10n.providerUsageUnavailable
          : '${l10n.tokenTotal}: ${_token(row.totalTokens!)}',
      if (row.rateSource?.endsWith('_off_peak') ?? false)
        l10n.usageOffPeakShort,
      if (row.durationMs != null) _duration(row.durationMs!),
      if (row.usageSource == 'legacy_total') l10n.legacyUsageTotalOnly,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Tooltip(
        message: _statusLabel(context, row.status),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        '${row.providerKind} · ${row.model}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: _costLabel(context, row),
    );
  }

  Widget _costLabel(BuildContext context, AiUsageEvent row) {
    final l10n = context.l10n;
    if (row.costBasis == 'estimate' && row.costNanoUsd != null) {
      return Text(_usd(row.costNanoUsd!));
    }
    if (row.costBasis == 'subscription') {
      return Tooltip(
        message: l10n.subscriptionUsage,
        child: Text(l10n.usageSubscriptionShort),
      );
    }
    return Tooltip(
      message: l10n.unknownCost,
      child: Text(l10n.usageCostUnknownShort),
    );
  }
}

String _featureLabel(BuildContext context, String feature) => switch (feature) {
  'chat' => context.l10n.usageFeatureChat,
  'context_compaction' => context.l10n.usageFeatureContextCompaction,
  'exam_scores' => context.l10n.usageFeatureExamScores,
  'language_quick_lookup' => context.l10n.quickLookup,
  'language_vocabulary' => context.l10n.usageFeatureLanguageVocabulary,
  'language_explanation' => context.l10n.usageFeatureLanguageExplanation,
  'language_sentence_batch' => context.l10n.usageFeatureLanguageSentenceBatch,
  'language_exam_generation' => context.l10n.usageFeatureLanguageExamGeneration,
  'language_exam_review' => context.l10n.usageFeatureLanguageExamReview,
  'language_writing_task' => context.l10n.usageFeatureLanguageWritingTask,
  'language_writing' => context.l10n.usageFeatureLanguageWriting,
  'connection_test' => context.l10n.usageFeatureConnectionTest,
  'a2ui_create' => context.l10n.chatA2uiLabel,
  'visual_create' => context.l10n.usageFeatureVisualCreate,
  'visual_edit' => context.l10n.usageFeatureVisualEdit,
  'quiz_with_visual' => context.l10n.usageFeatureQuizWithVisual,
  _ => feature,
};

String _statusLabel(BuildContext context, String status) => switch (status) {
  'complete' => context.l10n.usageStatusComplete,
  'error' => context.l10n.usageStatusError,
  'incomplete' => context.l10n.usageStatusIncomplete,
  'cancelled' => context.l10n.quickUsageStatusCancelled,
  _ => status,
};

String _int(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String _token(int value) {
  final (divisor, suffix) = value >= 1000000000
      ? (1000000000, 'B')
      : value >= 1000000
      ? (1000000, 'M')
      : value >= 1000
      ? (1000, 'K')
      : (1, '');
  if (divisor == 1) return '$value';
  final formatted = (value / divisor).toStringAsFixed(2);
  return '${formatted.replaceFirst(RegExp(r"0+$"), "").replaceFirst(RegExp(r"\.$"), "")}$suffix';
}

String _sumText(UsageSum sum) =>
    sum.isEmpty ? '—' : '${_token(sum.value)}${sum.isPartial ? '*' : ''}';

String _usd(int nanoUsd) {
  final usd = nanoUsd / 1000000000;
  final digits = usd >= 1
      ? 2
      : usd >= 0.01
      ? 4
      : 6;
  final text = usd
      .toStringAsFixed(digits)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '\$$text';
}

String _usdRate(int nanoUsd) => (nanoUsd / 1000000000)
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

String _rateText(int nanoUsd) => (nanoUsd / 1000000000)
    .toStringAsFixed(9)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');

String _duration(int milliseconds) => milliseconds < 1000
    ? '$milliseconds ms'
    : '${(milliseconds / 1000).toStringAsFixed(1)} s';

String _dateTime(DateTime value) =>
    '${_dateOnly(value)} ${_two(value.hour)}:${_two(value.minute)}';

String _dateOnly(DateTime value) =>
    '${value.year}-${_two(value.month)}-${_two(value.day)}';

String _shortDate(DateTime value) => '${_two(value.month)}-${_two(value.day)}';

String _two(int value) => value.toString().padLeft(2, '0');
