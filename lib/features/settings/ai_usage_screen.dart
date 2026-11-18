import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_usage_store.dart';
import '../../core/ai/ai_usage_summary.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/platform/usage_file_picker.dart';

class AiUsageScreen extends ConsumerStatefulWidget {
  const AiUsageScreen({super.key});
  @override
  ConsumerState<AiUsageScreen> createState() => _AiUsageScreenState();
}

class _AiUsageScreenState extends ConsumerState<AiUsageScreen> {
  String range = '30d';
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
      '7d' => today.subtract(const Duration(days: 6)),
      '30d' => today.subtract(const Duration(days: 29)),
      'custom' => customFrom,
      _ => null,
    };
  }

  DateTime? get _through => range == 'custom' && customThrough != null
      ? DateTime(
          customThrough!.year,
          customThrough!.month,
          customThrough!.day,
          23,
          59,
          59,
        )
      : null;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: customFrom ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (start == null || !mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start,
      lastDate: now,
      helpText: context.l10n.usageEndDate,
    );
    if (end == null || !mounted) return;
    setState(() {
      customFrom = start;
      customThrough = end;
      range = 'custom';
      events = _store.events(from: _from, through: _through);
    });
  }

  @override
  void initState() {
    super.initState();
    events = _store.events(from: _from, through: _through);
    prices = _store.prices();
  }

  void _reloadEvents() =>
      setState(() => events = _store.events(from: _from, through: _through));

  void _reloadPrices() => setState(() => prices = _store.prices());

  void _reloadAll() => setState(() {
    events = _store.events(from: _from, through: _through);
    prices = _store.prices();
  });

  void _setRange(String value) {
    if (value == range) return;
    setState(() {
      range = value;
      events = _store.events(from: _from, through: _through);
    });
  }

  Future<void> _export(String extension) async {
    setState(() => exporting = true);
    try {
      final store = _store;
      final rows = await store.events(from: _from, through: _through);
      final contents = extension == 'csv'
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

  Future<void> _deletePrice(AiModelPrice price) async {
    await _store.deletePrice(price);
    if (mounted) _reloadPrices();
  }

  Future<void> _editPrice([AiModelPrice? price]) async {
    final currentConfig = ref.read(appControllerProvider).config;
    final initialProvider =
        price?.providerKind ??
        (currentConfig.kind == 'chatgpt' ? 'deepseek' : currentConfig.kind);
    final input = TextEditingController(
      text: price == null ? '' : _rateText(price.inputRateNanoUsdPerMillion),
    );
    final cached = TextEditingController(
      text: price == null
          ? ''
          : _rateText(price.cachedInputRateNanoUsdPerMillion),
    );
    final output = TextEditingController(
      text: price == null ? '' : _rateText(price.outputRateNanoUsdPerMillion),
    );
    final discount = TextEditingController(
      text: price == null
          ? (initialProvider == 'deepseek' ? '50' : '0')
          : price.offPeakDiscountPercent.toString(),
    );
    final model = TextEditingController(
      text:
          price?.model ??
          (currentConfig.kind == 'chatgpt'
              ? 'deepseek-flash'
              : currentConfig.model),
    );
    final endpoint = TextEditingController(
      text:
          price?.endpoint ??
          (currentConfig.kind == 'chatgpt'
              ? 'https://api.deepseek.com'
              : currentConfig.baseUrl),
    );
    var provider = initialProvider;
    String? validationError;
    final result =
        await showDialog<
          ({
            String provider,
            String model,
            String endpoint,
            int input,
            int cached,
            int output,
            int discount,
          })
        >(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text(
                price == null
                    ? context.l10n.addModelPrice
                    : context.l10n.editModelPrice,
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: provider,
                        decoration: InputDecoration(
                          labelText: context.l10n.provider,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'deepseek',
                            child: Text(context.l10n.providerDeepSeek),
                          ),
                          DropdownMenuItem(
                            value: 'compatible',
                            child: Text(context.l10n.providerCompatible),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => provider = value);
                          }
                        },
                      ),
                      TextField(
                        controller: endpoint,
                        decoration: InputDecoration(
                          labelText: context.l10n.endpoint,
                          hintText: 'https://api.example.com/v1',
                        ),
                      ),
                      TextField(
                        controller: model,
                        decoration: InputDecoration(
                          labelText: context.l10n.model,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.modelPrices,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: input,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.inputPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: cached,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.cachedPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: output,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: context.l10n.outputPricePerMillion,
                        ),
                      ),
                      TextField(
                        controller: discount,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.l10n.offPeakDiscount,
                          helperText: context.l10n.offPeakDiscountHint,
                          helperMaxLines: 3,
                        ),
                      ),
                      if (validationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            validationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final rates = [input, cached, output]
                        .map(
                          (controller) =>
                              double.tryParse(controller.text.trim()),
                        )
                        .toList();
                    final discountPercent = int.tryParse(discount.text.trim());
                    if (model.text.trim().isEmpty ||
                        endpoint.text.trim().isEmpty ||
                        discountPercent == null ||
                        discountPercent < 0 ||
                        discountPercent > 100 ||
                        rates.any(
                          (rate) =>
                              rate == null ||
                              !rate.isFinite ||
                              rate < 0 ||
                              rate > 100000,
                        )) {
                      setDialogState(
                        () => validationError = context.l10n.invalidModelPrice,
                      );
                      return;
                    }
                    validationError = null;
                    Navigator.pop(context, (
                      provider: provider,
                      model: model.text.trim(),
                      endpoint: endpoint.text.trim(),
                      input: (rates[0]! * 1000000000).round(),
                      cached: (rates[1]! * 1000000000).round(),
                      output: (rates[2]! * 1000000000).round(),
                      discount: discountPercent,
                    ));
                  },
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          ),
        );
    input.dispose();
    cached.dispose();
    output.dispose();
    discount.dispose();
    model.dispose();
    endpoint.dispose();
    if (result == null) return;
    await _store.savePrice(
      providerKind: result.provider,
      endpoint: result.endpoint,
      model: result.model,
      inputRateNanoUsdPerMillion: result.input,
      cachedInputRateNanoUsdPerMillion: result.cached,
      outputRateNanoUsdPerMillion: result.output,
      offPeakDiscountPercent: result.discount,
    );
    if (mounted) _reloadPrices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiUsage),
        actions: [
          IconButton(
            key: const Key('refresh-ai-usage'),
            tooltip: context.l10n.usageRefresh,
            onPressed: _reloadAll,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            enabled: !exporting,
            tooltip: context.l10n.usageExport,
            onSelected: _export,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'csv', child: Text(context.l10n.exportCsv)),
              PopupMenuItem(
                value: 'jsonl',
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
                trendDays: range == '7d' ? 7 : 30,
              );
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(context.l10n.aiUsageHelp),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: '7d',
                        label: Text(context.l10n.last7Days),
                      ),
                      ButtonSegment(
                        value: '30d',
                        label: Text(context.l10n.last30Days),
                      ),
                      ButtonSegment(
                        value: 'all',
                        label: Text(context.l10n.allTime),
                      ),
                    ],
                    emptySelectionAllowed: true,
                    selected: range == 'custom' ? {} : {range},
                    onSelectionChanged: (value) {
                      if (value.isNotEmpty) _setRange(value.first);
                    },
                  ),
                  TextButton.icon(
                    key: const Key('ai-usage-custom-range'),
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      range == 'custom'
                          ? '${_dateOnly(customFrom!)} – ${_dateOnly(customThrough!)}'
                          : context.l10n.usageCustomRange,
                    ),
                  ),
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
                  ] else if (snapshot.hasData) ...[
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
                            '${context.l10n.imageInputs}: ${_int(summary.imageInputs)}'
                            ' · ${context.l10n.toolCalls}: ${_int(summary.toolCalls)}',
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
                      _TokenBreakdown(rows: rows),
                      const SizedBox(height: 20),
                      _SessionUsage(rows: rows),
                      if (summary.days.any((day) => day.tokens > 0)) ...[
                        const SizedBox(height: 20),
                        _UsageTrend(
                          days: summary.days,
                          caption: range == 'all' || range == 'custom'
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

  Widget _summaryGrid(BuildContext context, AiUsageSummary summary) {
    final l10n = context.l10n;
    final cards = <_StatData>[
      _StatData(
        l10n.requestCount,
        _int(summary.requests),
        summary.legacyRows > 0
            ? l10n.usageLegacyRows(l10nArgument(_int(summary.legacyRows)))
            : null,
      ),
      _StatData(l10n.tokenTotal, _sumText(summary.total), null),
      _StatData(l10n.inputTokens, _sumText(summary.input), null),
      _StatData(l10n.outputTokens, _sumText(summary.output), null),
      _StatData(
        l10n.cacheHitRate,
        summary.cacheHitRate == null
            ? '—'
            : '${summary.cacheHitRate!.toStringAsFixed(1)}%',
        summary.cacheHitRate == null
            ? null
            : '${l10n.cachedInputTokens}: ${_token(summary.cachedInput.value)}',
      ),
      _StatData(
        l10n.averageLatency,
        summary.averageLatencyMs == null
            ? '—'
            : _duration(summary.averageLatencyMs!),
        null,
      ),
      _StatData(l10n.requestErrors, _int(summary.errors), null),
      _StatData(
        l10n.estimatedCost,
        summary.estimatedRows == 0 ? '—' : _usd(summary.estimatedCostNanoUsd),
        summary.priceableRows == 0
            ? null
            : l10n.usageCostCoverage(
                l10nArgument(_int(summary.estimatedRows)),
                l10nArgument(_int(summary.priceableRows)),
              ),
      ),
    ];
    return LayoutBuilder(
      key: const Key('ai-usage-summary'),
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
        l10n.usageCostNoPrice(l10nArgument(_int(summary.missingPrice))),
      if (summary.missingUsage > 0)
        l10n.usageCostNoUsage(l10nArgument(_int(summary.missingUsage))),
      if (summary.missingDetail > 0)
        l10n.usageCostNoDetail(l10nArgument(_int(summary.missingDetail))),
      if (summary.subscriptionRows > 0) l10n.subscriptionUsage,
      if (summary.legacyRows > 0)
        l10n.usageLegacyRows(l10nArgument(_int(summary.legacyRows))),
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
              localize ? _featureLabel(context, slice.label) : slice.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              [
                '${context.l10n.requestCount}: ${_int(slice.requests)}',
                '${context.l10n.tokenTotal}: ${_sumText(slice.tokens)}',
                if (!localize && slice.detail != null) slice.detail!,
              ].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
            trailing: Text(
              slice.hasEstimate ? _usd(slice.estimatedCostNanoUsd) : '—',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }

  Widget _pricesSection(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.modelPrices, style: theme.textTheme.titleMedium),
            ),
            IconButton(
              key: const Key('add-ai-model-price'),
              tooltip: l10n.addModelPrice,
              onPressed: _editPrice,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        Text(l10n.ratePeakNote, style: style),
        const SizedBox(height: 2),
        Text(l10n.usagePriceSnapshotNote, style: style),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://api-docs.deepseek.com/quick_start/pricing/'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l10n.officialPricingPage),
          ),
        ),
        FutureBuilder<List<AiModelPrice>>(
          future: prices,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <AiModelPrice>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            return Column(
              children: [
                for (final price in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${price.providerKind} · ${price.model}'),
                    subtitle: Text(
                      '${price.endpoint} · '
                      '${l10n.usagePriceUpdated(_dateOnly(price.updatedAt.toLocal()))}\n'
                      '${_usdRate(price.inputRateNanoUsdPerMillion)} / '
                      '${_usdRate(price.cachedInputRateNanoUsdPerMillion)} / '
                      '${_usdRate(price.outputRateNanoUsdPerMillion)}'
                      '${price.offPeakDiscountPercent > 0 ? ' · ${l10n.usageOffPeakDiscount(l10nArgument(_int(price.offPeakDiscountPercent)))}' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => _editPrice(price),
                    trailing: price.source == 'user'
                        ? IconButton(
                            tooltip: l10n.delete,
                            onPressed: () => _deletePrice(price),
                            icon: const Icon(Icons.delete_outline),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _detailsSection(BuildContext context, AiUsageSummary summary) {
    if (summary.recent.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return ExpansionTile(
      key: const Key('ai-usage-request-details'),
      tilePadding: EdgeInsets.zero,
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

class _UsageRequestTile extends StatelessWidget {
  const _UsageRequestTile({required this.row});

  final AiUsageEvent row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (row.status) {
      'complete' => (Icons.check_circle_outline, colors.primary),
      'incomplete' => (Icons.pending_outlined, colors.tertiary),
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
  'connection_test' => context.l10n.usageFeatureConnectionTest,
  'visual_create' => context.l10n.usageFeatureVisualCreate,
  'visual_edit' => context.l10n.usageFeatureVisualEdit,
  'quiz_with_visual' => context.l10n.usageFeatureQuizWithVisual,
  _ => feature,
};

String _statusLabel(BuildContext context, String status) => switch (status) {
  'complete' => context.l10n.usageStatusComplete,
  'error' => context.l10n.usageStatusError,
  'incomplete' => context.l10n.usageStatusIncomplete,
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
