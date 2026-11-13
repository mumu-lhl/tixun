import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_usage_store.dart';
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

  DateTime? get _from => switch (range) {
    '7d' => DateTime.now().subtract(const Duration(days: 7)),
    '30d' => DateTime.now().subtract(const Duration(days: 30)),
    _ => null,
  };

  Future<void> _export(AiUsageStore store, String extension) async {
    setState(() => exporting = true);
    try {
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

  Future<void> _editPrice(AiUsageStore store, [AiModelPrice? price]) async {
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
                      const SizedBox(height: 8),
                      Text(context.l10n.modelPrices),
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
                    if (model.text.trim().isEmpty ||
                        endpoint.text.trim().isEmpty ||
                        rates.any(
                          (rate) => rate == null || !rate.isFinite || rate < 0,
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
    model.dispose();
    endpoint.dispose();
    if (result == null) return;
    await store.savePrice(
      providerKind: result.provider,
      endpoint: result.endpoint,
      model: result.model,
      inputRateNanoUsdPerMillion: result.input,
      cachedInputRateNanoUsdPerMillion: result.cached,
      outputRateNanoUsdPerMillion: result.output,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(appControllerProvider);
    final store = AiUsageStore(controller.db);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiUsage),
        actions: [
          PopupMenuButton<String>(
            enabled: !exporting,
            tooltip: context.l10n.requestDetails,
            onSelected: (extension) => _export(store, extension),
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
          constraints: const BoxConstraints(maxWidth: 820),
          child: FutureBuilder<List<AiUsageEvent>>(
            key: ValueKey(range),
            future: store.events(from: _from),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <AiUsageEvent>[];
              final input = _sum(rows, (row) => row.inputTokens);
              final cached = _sum(rows, (row) => row.cachedInputTokens);
              final output = _sum(rows, (row) => row.outputTokens);
              final total = _sum(rows, (row) => row.totalTokens);
              final estimateRows = rows
                  .where((row) => row.costBasis == 'estimate')
                  .toList();
              final estimatedCost = estimateRows.fold<int>(
                0,
                (sum, row) => sum + (row.costNanoUsd ?? 0),
              );
              final unknownCosts = rows
                  .where((row) => row.costBasis == 'unknown')
                  .length;
              final cacheKnownRows = rows
                  .where(
                    (row) =>
                        row.inputTokens != null &&
                        row.cachedInputTokens != null,
                  )
                  .toList();
              final inputKnown = cacheKnownRows.fold<int>(
                0,
                (sum, row) => sum + row.inputTokens!,
              );
              final cachedKnown = cacheKnownRows.fold<int>(
                0,
                (sum, row) => sum + row.cachedInputTokens!,
              );
              final cacheRate = inputKnown == 0
                  ? '—'
                  : '${(cachedKnown * 100 / inputKnown).toStringAsFixed(1)}%';
              final models = <String, List<AiUsageEvent>>{};
              final features = <String, List<AiUsageEvent>>{};
              for (final row in rows) {
                models
                    .putIfAbsent(
                      '${row.providerKind} · ${row.endpoint} · ${row.model}',
                      () => [],
                    )
                    .add(row);
                features.putIfAbsent(row.feature, () => []).add(row);
              }
              final timedRows = rows
                  .where((row) => row.durationMs != null)
                  .toList();
              final averageLatency = timedRows.isEmpty
                  ? '—'
                  : '${timedRows.fold<int>(0, (sum, row) => sum + row.durationMs!) ~/ timedRows.length}';
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
                    onSelectionChanged: (value) =>
                        setState(() => range = value.first),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const LinearProgressIndicator()
                  else if (snapshot.hasError)
                    Text(context.l10n.errorSaveTryAgain)
                  else ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _StatCard(
                          context.l10n.requestCount,
                          '${_requestCount(rows)}',
                        ),
                        _StatCard(context.l10n.tokenTotal, total),
                        _StatCard(context.l10n.inputTokens, input),
                        _StatCard(context.l10n.cachedInputTokens, cached),
                        _StatCard(context.l10n.outputTokens, output),
                        _StatCard(
                          context.l10n.imageInputs,
                          '${rows.fold<int>(0, (sum, row) => sum + row.imageCount)}',
                        ),
                        _StatCard(
                          context.l10n.toolCalls,
                          '${rows.fold<int>(0, (sum, row) => sum + row.toolCallCount)}',
                        ),
                        _StatCard(context.l10n.cacheHitRate, cacheRate),
                        _StatCard(context.l10n.averageLatency, averageLatency),
                        _StatCard(
                          context.l10n.requestErrors,
                          '${rows.where((row) => row.status == 'error' && row.usageSource != 'legacy_total').length}',
                        ),
                        _StatCard(
                          context.l10n.estimatedCost,
                          estimateRows.isEmpty ? '—' : _usd(estimatedCost),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.costEstimateOnly),
                    if (unknownCosts > 0)
                      Text('${context.l10n.unknownCost}: $unknownCosts'),
                    if (rows.any((row) => row.costBasis == 'subscription'))
                      Text(context.l10n.subscriptionUsage),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.usageByModel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (models.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(context.l10n.noAiUsageYet),
                      )
                    else
                      for (final entry in models.entries)
                        ListTile(
                          title: Text(entry.key),
                          subtitle: Text(
                            '${context.l10n.requestCount}: ${_requestCount(entry.value)} · '
                            '${context.l10n.tokenTotal}: ${_sum(entry.value, (row) => row.totalTokens)}',
                          ),
                          trailing: Text(
                            entry.value.any((row) => row.costNanoUsd != null)
                                ? _usd(
                                    entry.value.fold<int>(
                                      0,
                                      (sum, row) =>
                                          sum + (row.costNanoUsd ?? 0),
                                    ),
                                  )
                                : '—',
                          ),
                        ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.usageByFeature,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final entry in features.entries)
                      ListTile(
                        title: Text(_feature(context, entry.key)),
                        subtitle: Text(
                          '${context.l10n.requestCount}: ${_requestCount(entry.value)} · '
                          '${context.l10n.tokenTotal}: ${_sum(entry.value, (row) => row.totalTokens)}',
                        ),
                        trailing: Text(
                          entry.value.any((row) => row.costNanoUsd != null)
                              ? _usd(
                                  entry.value.fold<int>(
                                    0,
                                    (sum, row) => sum + (row.costNanoUsd ?? 0),
                                  ),
                                )
                              : '—',
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.requestDetails,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final row in rows.take(50))
                      ListTile(
                        dense: true,
                        title: Text('${row.providerKind} · ${row.model}'),
                        subtitle: Text(
                          '${_feature(context, row.feature)} · '
                          '${_status(context, row.status)} · '
                          '${row.occurredAt.toLocal()} · '
                          '${row.totalTokens ?? context.l10n.providerUsageUnavailable}'
                          '${row.usageSource == 'legacy_total' ? ' · ${context.l10n.legacyUsageTotalOnly}' : ''}'
                          '${row.durationMs == null ? '' : ' · ${row.durationMs} ms'}',
                        ),
                        trailing: Text(
                          row.costBasis == 'estimate' && row.costNanoUsd != null
                              ? _usd(row.costNanoUsd!)
                              : row.costBasis == 'subscription'
                              ? context.l10n.subscriptionUsage
                              : context.l10n.unknownCost,
                        ),
                      ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.modelPrices,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          key: const Key('add-ai-model-price'),
                          tooltip: context.l10n.addModelPrice,
                          onPressed: () => _editPrice(store),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    Text(context.l10n.ratePeakNote),
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://api-docs.deepseek.com/quick_start/pricing/',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: Text(context.l10n.officialPricingPage),
                    ),
                    FutureBuilder<List<AiModelPrice>>(
                      future: store.prices(),
                      builder: (context, snapshot) => Column(
                        children: [
                          for (final price in snapshot.data ?? const [])
                            ListTile(
                              title: Text(
                                '${price.providerKind} · ${price.model}',
                              ),
                              subtitle: Text(
                                '${price.endpoint}\n'
                                '${_usdRate(price.inputRateNanoUsdPerMillion)} / '
                                '${_usdRate(price.cachedInputRateNanoUsdPerMillion)} / '
                                '${_usdRate(price.outputRateNanoUsdPerMillion)}',
                              ),
                              isThreeLine: true,
                              onTap: () => _editPrice(store, price),
                              trailing: IconButton(
                                tooltip: context.l10n.delete,
                                onPressed: () async {
                                  await store.deletePrice(price);
                                  if (mounted) setState(() {});
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ),
                        ],
                      ),
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

  static int _requestCount(List<AiUsageEvent> rows) =>
      rows.where((row) => row.usageSource != 'legacy_total').length;

  static String _sum(
    List<AiUsageEvent> rows,
    int? Function(AiUsageEvent) value,
  ) {
    final known = rows.where((row) => value(row) != null).toList();
    if (known.isEmpty) return '—';
    final sum = known.fold<int>(0, (total, row) => total + value(row)!);
    return known.length == rows.length ? '$sum' : '$sum *';
  }

  static String _status(BuildContext context, String status) =>
      switch (status) {
        'complete' => context.l10n.usageStatusComplete,
        'error' => context.l10n.usageStatusError,
        'incomplete' => context.l10n.usageStatusIncomplete,
        _ => status,
      };

  static String _feature(BuildContext context, String feature) =>
      switch (feature) {
        'chat' => context.l10n.usageFeatureChat,
        'context_compaction' => context.l10n.usageFeatureContextCompaction,
        'exam_scores' => context.l10n.usageFeatureExamScores,
        'connection_test' => context.l10n.usageFeatureConnectionTest,
        _ => feature,
      };
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 174,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

String _usd(int nanoUsd) => '\$${(nanoUsd / 1000000000).toStringAsFixed(6)}';
String _usdRate(int nanoUsd) => (nanoUsd / 1000000000)
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
String _rateText(int nanoUsd) => (nanoUsd / 1000000000)
    .toStringAsFixed(9)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
