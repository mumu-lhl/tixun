import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:url_launcher/url_launcher.dart";

import "../../app/controller.dart";
import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/ai_usage_summary.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/platform/usage_file_picker.dart";
import "../../core/ui/usage_token_breakdown.dart";
import "../../core/ui/app_menu.dart";

part "ai_usage_charts.dart";
part "ai_usage_prices.dart";
part "ai_usage_requests.dart";

class AiUsageScreen extends ConsumerStatefulWidget {
  const AiUsageScreen({super.key});
  @override
  ConsumerState<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends ConsumerState<AiUsageScreen> {
  String range = "30d";
  AiUsageScope scope = AiUsageScope.all;
  bool exporting = false;
  DateTime? customFrom;
  DateTime? customThrough;
  late Future<List<AiUsageEvent>> events;
  late Future<List<AiModelPrice>> prices;

  AiUsageStore get _store => AiUsageStore(ref.read(appControllerProvider).db);

  /// Aligns the queried range with the calendar-day trend chart.
  DateTime? get _from {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      "7d" => today.subtract(const Duration(days: 6)),
      "30d" => today.subtract(const Duration(days: 29)),
      "custom" => customFrom,
      _ => null,
    };
  }

  DateTime? get _through {
    final day = customThrough ?? customFrom;
    if (range != "custom" || day == null) return null;
    return DateTime(
      day.year,
      day.month,
      day.day + 1,
    ).subtract(const Duration(seconds: 1));
  }

  Future<List<AiUsageEvent>> _queryEvents() =>
      _store.events(from: _from, through: _through, scope: scope);

  Future<void> _pickDate({bool end = false}) async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: end ? customThrough ?? customFrom! : customFrom ?? now,
      firstDate: end ? customFrom! : DateTime(2000),
      lastDate: now,
      helpText: end ? context.l10n.usageEndDate : null,
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (end) {
        customThrough = chosen;
      } else {
        customFrom = chosen;
        if (range != "custom" || (customThrough?.isBefore(chosen) ?? false)) {
          customThrough = null;
        }
      }
      range = "custom";
      events = _queryEvents();
    });
  }

  @override
  void initState() {
    super.initState();
    events = _queryEvents();
    prices = _store.prices();
  }

  void _reloadEvents() => setState(() => events = _queryEvents());

  void _reloadPrices() => setState(() => prices = _store.prices());

  void _reloadAll() => setState(() {
    events = _queryEvents();
    prices = _store.prices();
  });

  void _setRange(String value) {
    if (value == range) return;
    setState(() {
      range = value;
      events = _queryEvents();
    });
  }

  Future<void> _export(String extension) async {
    setState(() => exporting = true);
    try {
      final store = _store;
      final rows = await store.events(
        from: _from,
        through: _through,
        scope: scope,
      );
      final contents = extension == "csv"
          ? store.toCsv(rows)
          : store.toJsonLines(rows);
      final saved = await UsageFilePicker.save(contents, extension: extension);
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.fileExportCancelled)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorSaveTryAgain)));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiUsage),
        actions: [
          IconButton(
            key: const Key("refresh-ai-usage"),
            tooltip: context.l10n.usageRefresh,
            onPressed: _reloadAll,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            enabled: !exporting,
            tooltip: context.l10n.usageExport,
            onSelected: _export,
            itemBuilder: (context) => [
              PopupMenuItem(value: "csv", child: Text(context.l10n.exportCsv)),
              PopupMenuItem(
                value: "jsonl",
                child: Text(context.l10n.exportJsonl),
              ),
            ],
            icon: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: FutureBuilder<List<AiUsageEvent>>(
            future: events,
            builder: (context, snapshot) {
              final waiting =
                  snapshot.connectionState == ConnectionState.waiting;
              final rows = snapshot.data ?? const <AiUsageEvent>[];
              final summary = AiUsageSummary.fromRows(
                rows,
                trendDays: range == "7d" ? 7 : 30,
              );
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(context.l10n.aiUsageHelp),
                  const SizedBox(height: 12),
                  _filters(context),
                  const SizedBox(height: 16),
                  if (waiting)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (snapshot.hasError) ...[
                    Text(context.l10n.usageLoadFailed),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _reloadEvents,
                        child: Text(context.l10n.retry),
                      ),
                    ),
                  ] else if (!waiting && snapshot.hasData) ...[
                    if (rows.isEmpty) ...[
                      Text(context.l10n.noAiUsageYet),
                      const SizedBox(height: 16),
                      _pricesSection(context),
                    ] else ...[
                      _summaryGrid(context, summary),
                      if (summary.imageInputs > 0 || summary.toolCalls > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "${context.l10n.imageInputs}: ${usageInteger(summary.imageInputs)}"
                            " · ${context.l10n.toolCalls}: ${usageInteger(summary.toolCalls)}",
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      _notes(context, summary),
                      const SizedBox(height: 20),
                      UsageTokenBreakdown(rows: rows),
                      const SizedBox(height: 20),
                      _SessionUsage(rows: rows),
                      if (summary.days.any((day) => day.tokens > 0)) ...[
                        const SizedBox(height: 20),
                        _UsageTrend(
                          days: summary.days,
                          caption: range == "all" || range == "custom"
                              ? context.l10n.last30Days
                              : null,
                        ),
                      ],
                      const SizedBox(height: 20),
                      _breakdownSection(
                        context,
                        context.l10n.usageByFeature,
                        summary.features,
                        localize: true,
                      ),
                      const SizedBox(height: 20),
                      _breakdownSection(
                        context,
                        context.l10n.usageByModel,
                        summary.models,
                        localize: false,
                      ),
                      const SizedBox(height: 24),
                      _pricesSection(context),
                      const SizedBox(height: 8),
                      _detailsSection(context, summary),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final l10n = context.l10n;
    final from = range == "custom" ? customFrom : null;
    final through = range == "custom" ? customThrough : null;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 244),
          child: AppSelectField<AiUsageScope>(
            key: const Key("ai-usage-scope"),
            initialValue: scope,
            decoration: InputDecoration(labelText: context.l10n.usageScope),
            items: [
              DropdownMenuItem(
                value: AiUsageScope.all,
                child: Text(context.l10n.usageAllSources),
              ),
              DropdownMenuItem(
                value: AiUsageScope.chats,
                child: Text(context.l10n.usageChatOnly),
              ),
              DropdownMenuItem(
                value: AiUsageScope.language,
                child: Text(context.l10n.usageLanguageOnly),
              ),
            ],
            onChanged: (value) {
              if (value == null || scope == value) return;
              setState(() {
                scope = value;
                events = _queryEvents();
              });
            },
          ),
        ),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: "7d", label: Text(context.l10n.last7Days)),
            ButtonSegment(value: "30d", label: Text(context.l10n.last30Days)),
            ButtonSegment(value: "all", label: Text(context.l10n.allTime)),
          ],
          emptySelectionAllowed: true,
          selected: range == "custom" ? {} : {range},
          onSelectionChanged: (value) {
            if (value.isNotEmpty) _setRange(value.first);
          },
        ),
        OutlinedButton.icon(
          key: const Key("ai-usage-custom-range"),
          onPressed: _pickDate,
          icon: const Icon(Icons.date_range),
          label: Text(from == null ? l10n.usageChooseDate : _dateOnly(from)),
        ),
        if (from != null)
          OutlinedButton.icon(
            key: const Key("ai-usage-end-date"),
            onPressed: () => _pickDate(end: true),
            icon: Icon(through == null ? Icons.add : Icons.arrow_forward),
            label: Text(
              through == null ? l10n.usageAddEndDate : _dateOnly(through),
            ),
          ),
        if (through != null)
          IconButton(
            tooltip: l10n.usageRemoveEndDate,
            onPressed: () => setState(() {
              customThrough = null;
              events = _queryEvents();
            }),
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }

  Widget _summaryGrid(BuildContext context, AiUsageSummary summary) {
    final l10n = context.l10n;
    final cards = <_StatData>[
      _StatData(
        l10n.requestCount,
        usageInteger(summary.requests),
        summary.legacyRows > 0
            ? l10n.usageLegacyRows(
                l10nArgument(usageInteger(summary.legacyRows)),
              )
            : null,
      ),
      _StatData(l10n.tokenTotal, _sumText(summary.total), null),
      _StatData(l10n.inputTokens, _sumText(summary.input), null),
      _StatData(l10n.outputTokens, _sumText(summary.output), null),
      _StatData(
        l10n.cacheHitRate,
        summary.cacheHitRate == null
            ? "—"
            : "${summary.cacheHitRate!.toStringAsFixed(1)}%",
        summary.cacheHitRate == null
            ? null
            : "${l10n.cachedInputTokens}: ${usageTokenCount(summary.cachedInput.value)}",
      ),
      _StatData(
        l10n.averageLatency,
        summary.averageLatencyMs == null
            ? "—"
            : _duration(summary.averageLatencyMs!),
        null,
      ),
      _StatData(l10n.requestErrors, usageInteger(summary.errors), null),
      _StatData(
        l10n.estimatedCost,
        summary.estimatedRows == 0 ? "—" : _usd(summary.estimatedCostNanoUsd),
        summary.priceableRows == 0
            ? null
            : l10n.usageCostCoverage(
                l10nArgument(usageInteger(summary.estimatedRows)),
                l10nArgument(usageInteger(summary.priceableRows)),
              ),
      ),
    ];
    return LayoutBuilder(
      key: const Key("ai-usage-summary"),
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780
            ? 4
            : constraints.maxWidth >= 540
            ? 3
            : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              _StatCard(
                width: width,
                label: card.label,
                value: card.value,
                hint: card.hint,
              ),
          ],
        );
      },
    );
  }

  Widget _notes(BuildContext context, AiUsageSummary summary) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final lines = <String>[
      if (summary.estimatedRows > 0) l10n.costEstimateOnly,
      if (summary.missingPrice > 0)
        l10n.usageCostNoPrice(l10nArgument(usageInteger(summary.missingPrice))),
      if (summary.missingUsage > 0)
        l10n.usageCostNoUsage(l10nArgument(usageInteger(summary.missingUsage))),
      if (summary.missingDetail > 0)
        l10n.usageCostNoDetail(
          l10nArgument(usageInteger(summary.missingDetail)),
        ),
      if (summary.subscriptionRows > 0) l10n.subscriptionUsage,
      if (summary.legacyRows > 0)
        l10n.usageLegacyRows(l10nArgument(usageInteger(summary.legacyRows))),
      if (summary.hasPartialSums) l10n.usagePartialSum,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: style),
          ),
      ],
    );
  }

  Widget _breakdownSection(
    BuildContext context,
    String title,
    List<UsageSlice> slices, {
    required bool localize,
  }) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final slice in slices)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              localize ? usageFeatureLabel(context, slice.label) : slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              [
                "${context.l10n.requestCount}: ${usageInteger(slice.requests)}",
                "${context.l10n.tokenTotal}: ${_sumText(slice.tokens)}",
                if (!localize && slice.detail != null) slice.detail!,
              ].join(" · "),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
            trailing: Text(
              slice.hasEstimate ? _usd(slice.estimatedCostNanoUsd) : "—",
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _detailsSection(BuildContext context, AiUsageSummary summary) {
    if (summary.recent.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ExpansionTile(
      key: const Key("ai-usage-request-details"),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        l10n.requestDetails,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        l10n.usageRecentLimit,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [for (final row in summary.recent) _UsageRequestTile(row: row)],
    );
  }
}
