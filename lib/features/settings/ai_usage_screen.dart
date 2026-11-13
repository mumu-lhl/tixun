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
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();
    events = _store.events(from: _from);
    prices = _store.prices();
  }

  void _reloadEvents() => setState(() => events = _store.events(from: _from));

  void _reloadPrices() => setState(() => prices = _store.prices());

  void _reloadAll() => setState(() {
    events = _store.events(from: _from);
    prices = _store.prices();
  });

  void _setRange(String value) {
    if (value == range) return;
    setState(() {
      range = value;
      events = _store.events(from: _from);
    });
  }

  Future<void> _export(String extension) async {
    setState(() => exporting = true);
    try {
      final store = _store;
      final rows = await store.events(from: _from);
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
                    selected: {range},
                    onSelectionChanged: (value) => _setRange(value.first),
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
                      if (summary.days.any((day) => day.tokens > 0)) ...[
                        const SizedBox(height: 20),
                        _UsageTrend(
                          days: summary.days,
                          caption: range == 'all'
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
            : '${l10n.cachedInputTokens}: ${_int(summary.cachedInput.value)}',
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
              '${context.l10n.tokenTotal}: ${_int(total)}',
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
      '${context.l10n.tokenTotal}: ${_int(day.tokens)}',
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
          : '${l10n.tokenTotal}: ${_int(row.totalTokens!)}',
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

String _sumText(UsageSum sum) =>
    sum.isEmpty ? '—' : '${_int(sum.value)}${sum.isPartial ? '*' : ''}';

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
