import '../database/database.dart';

/// Sum of one optional numeric field across request rows.
///
/// [reported] counts rows that actually carried the field, so the UI can show
/// a partial sum instead of silently treating missing data as zero.
class UsageSum {
  const UsageSum(this.value, this.reported, this.rows);

  final int value;
  final int reported;
  final int rows;

  bool get isEmpty => reported == 0;
  bool get isPartial => reported > 0 && reported < rows;

  static UsageSum of(
    Iterable<AiUsageEvent> rows,
    int? Function(AiUsageEvent row) pick,
  ) {
    var value = 0;
    var reported = 0;
    var total = 0;
    for (final row in rows) {
      total++;
      final picked = pick(row);
      if (picked != null) {
        value += picked;
        reported++;
      }
    }
    return UsageSum(value, reported, total);
  }
}

/// One "by feature" or "by model" bucket.
class UsageSlice {
  const UsageSlice({
    required this.id,
    required this.label,
    required this.detail,
    required this.requests,
    required this.tokens,
    required this.estimatedCostNanoUsd,
    required this.hasEstimate,
  });

  final String id;

  /// Feature key for feature buckets; "provider · model" for model buckets.
  final String label;

  /// Endpoint for model buckets, null for feature buckets.
  final String? detail;

  final int requests;
  final UsageSum tokens;
  final int estimatedCostNanoUsd;
  final bool hasEstimate;
}

/// One local calendar day in the trend chart.
class UsageDay {
  const UsageDay(
    this.day,
    this.requests,
    this.tokens,
    this.estimatedCostNanoUsd,
  );

  final DateTime day;
  final int requests;
  final int tokens;
  final int estimatedCostNanoUsd;
}

/// Aggregates request-level usage rows for the local usage screen.
///
/// This lives outside the widget so the accounting rules can be tested without
/// pumping a screen: sums distinguish reported from missing values, cache hit
/// rate only uses rows that reported both sides, and cost gaps are split by
/// cause (no usage, no token split, no price).
class AiUsageSummary {
  const AiUsageSummary._({
    required this.rowsCount,
    required this.requests,
    required this.legacyRows,
    required this.errors,
    required this.input,
    required this.cachedInput,
    required this.output,
    required this.reasoning,
    required this.total,
    required this.cacheHitRate,
    required this.averageLatencyMs,
    required this.imageInputs,
    required this.toolCalls,
    required this.estimatedCostNanoUsd,
    required this.estimatedRows,
    required this.priceableRows,
    required this.subscriptionRows,
    required this.missingUsage,
    required this.missingDetail,
    required this.missingPrice,
    required this.features,
    required this.models,
    required this.days,
    required this.recent,
  });

  factory AiUsageSummary.fromRows(
    List<AiUsageEvent> rows, {
    DateTime? now,
    int trendDays = 30,
    int recentLimit = 50,
  }) {
    final clock = now ?? DateTime.now();
    var requests = 0;
    var legacyRows = 0;
    var errors = 0;
    var imageInputs = 0;
    var toolCalls = 0;
    var estimatedCost = 0;
    var estimatedRows = 0;
    var priceableRows = 0;
    var subscriptionRows = 0;
    var missingUsage = 0;
    var missingDetail = 0;
    var missingPrice = 0;
    final latencyRows = <int>[];
    for (final row in rows) {
      final legacy = row.usageSource == 'legacy_total';
      if (legacy) {
        legacyRows++;
      } else {
        requests++;
        if (row.status == 'error') errors++;
      }
      imageInputs += row.imageCount;
      toolCalls += row.toolCallCount;
      if (row.durationMs != null) latencyRows.add(row.durationMs!);
      final priceable =
          !legacy &&
          row.costBasis != 'subscription' &&
          row.costBasis != 'mock' &&
          row.inputTokens != null &&
          row.outputTokens != null;
      if (priceable) priceableRows++;
      if (row.costBasis == 'estimate' && row.costNanoUsd != null) {
        estimatedCost += row.costNanoUsd!;
        estimatedRows++;
      } else if (row.costBasis == 'subscription') {
        subscriptionRows++;
      } else if (row.costBasis != 'mock') {
        if (row.inputTokens == null &&
            row.outputTokens == null &&
            row.totalTokens == null) {
          missingUsage++;
        } else if (row.inputTokens == null || row.outputTokens == null) {
          missingDetail++;
        } else if (row.inputRateNanoUsdPerMillion == null) {
          missingPrice++;
        } else {
          // A price was snapshotted, but the estimate still needs the cached
          // split (for example a provider that only reports input/output).
          missingDetail++;
        }
      }
    }

    final cacheRows = rows.where(
      (row) => row.inputTokens != null && row.cachedInputTokens != null,
    );
    final cacheInput = UsageSum.of(cacheRows, (row) => row.inputTokens);
    final cacheCached = UsageSum.of(cacheRows, (row) => row.cachedInputTokens);
    final cacheHitRate = cacheInput.value <= 0
        ? null
        : (cacheCached.value * 100 / cacheInput.value).clamp(0, 100).toDouble();

    final byFeature = <String, List<AiUsageEvent>>{};
    final byModel = <String, List<AiUsageEvent>>{};
    for (final row in rows) {
      byFeature.putIfAbsent(row.feature, () => []).add(row);
      byModel
          .putIfAbsent(
            '${row.providerKind}\u0000${row.endpoint}\u0000${row.model}',
            () => [],
          )
          .add(row);
    }

    final features = [
      for (final entry in byFeature.entries)
        _slice(
          id: entry.key,
          label: entry.key,
          detail: null,
          rows: entry.value,
        ),
    ]..sort(_compareSlices);
    final models = [
      for (final entry in byModel.entries)
        _slice(
          id: entry.key,
          label:
              '${entry.value.first.providerKind} · ${entry.value.first.model}',
          detail: entry.value.first.endpoint.isEmpty
              ? null
              : entry.value.first.endpoint,
          rows: entry.value,
        ),
    ]..sort(_compareSlices);

    final today = DateTime(clock.year, clock.month, clock.day);
    final start = today.subtract(Duration(days: trendDays.clamp(1, 366) - 1));
    final buckets = <DateTime, _DayBucket>{};
    for (
      var day = start;
      !day.isAfter(today);
      day = DateTime(day.year, day.month, day.day + 1)
    ) {
      buckets[day] = _DayBucket();
    }
    for (final row in rows) {
      final local = row.occurredAt.toLocal();
      final bucket = buckets[DateTime(local.year, local.month, local.day)];
      if (bucket == null) continue;
      if (row.usageSource != 'legacy_total') bucket.requests++;
      bucket.tokens +=
          row.totalTokens ??
          (row.inputTokens != null && row.outputTokens != null
              ? row.inputTokens! + row.outputTokens!
              : 0);
      if (row.costBasis == 'estimate' && row.costNanoUsd != null) {
        bucket.cost += row.costNanoUsd!;
      }
    }

    final recent = List<AiUsageEvent>.of(rows)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return AiUsageSummary._(
      rowsCount: rows.length,
      requests: requests,
      legacyRows: legacyRows,
      errors: errors,
      input: UsageSum.of(rows, (row) => row.inputTokens),
      cachedInput: UsageSum.of(rows, (row) => row.cachedInputTokens),
      output: UsageSum.of(rows, (row) => row.outputTokens),
      reasoning: UsageSum.of(rows, (row) => row.reasoningTokens),
      total: UsageSum.of(rows, (row) => row.totalTokens),
      cacheHitRate: cacheHitRate,
      averageLatencyMs: latencyRows.isEmpty
          ? null
          : latencyRows.fold<int>(0, (sum, value) => sum + value) ~/
                latencyRows.length,
      imageInputs: imageInputs,
      toolCalls: toolCalls,
      estimatedCostNanoUsd: estimatedCost,
      estimatedRows: estimatedRows,
      priceableRows: priceableRows,
      subscriptionRows: subscriptionRows,
      missingUsage: missingUsage,
      missingDetail: missingDetail,
      missingPrice: missingPrice,
      features: features,
      models: models,
      days: [
        for (final entry in buckets.entries)
          UsageDay(
            entry.key,
            entry.value.requests,
            entry.value.tokens,
            entry.value.cost,
          ),
      ],
      recent: recent.take(recentLimit).toList(),
    );
  }

  final int rowsCount;

  /// Requests that stand for a real API call; backfilled legacy message rows
  /// are counted in [legacyRows] instead.
  final int requests;
  final int legacyRows;
  final int errors;
  final UsageSum input;
  final UsageSum cachedInput;
  final UsageSum output;
  final UsageSum reasoning;
  final UsageSum total;
  final double? cacheHitRate;
  final int? averageLatencyMs;
  final int imageInputs;
  final int toolCalls;
  final int estimatedCostNanoUsd;
  final int estimatedRows;

  /// Rows that carry the input/output split a price needs; legacy and
  /// subscription rows cannot be priced, so they are not part of coverage.
  final int priceableRows;
  final int subscriptionRows;

  /// Rows whose cost cannot be estimated, split by cause.
  final int missingUsage;
  final int missingDetail;
  final int missingPrice;

  final List<UsageSlice> features;
  final List<UsageSlice> models;
  final List<UsageDay> days;
  final List<AiUsageEvent> recent;

  bool get hasPartialSums =>
      input.isPartial ||
      cachedInput.isPartial ||
      output.isPartial ||
      total.isPartial;

  static UsageSlice _slice({
    required String id,
    required String label,
    required String? detail,
    required List<AiUsageEvent> rows,
  }) {
    var cost = 0;
    var hasEstimate = false;
    var requests = 0;
    for (final row in rows) {
      if (row.usageSource != 'legacy_total') requests++;
      if (row.costBasis == 'estimate' && row.costNanoUsd != null) {
        cost += row.costNanoUsd!;
        hasEstimate = true;
      }
    }
    return UsageSlice(
      id: id,
      label: label,
      detail: detail,
      requests: requests,
      tokens: UsageSum.of(rows, (row) => row.totalTokens),
      estimatedCostNanoUsd: cost,
      hasEstimate: hasEstimate,
    );
  }

  static int _compareSlices(UsageSlice a, UsageSlice b) {
    final byCost = b.estimatedCostNanoUsd.compareTo(a.estimatedCostNanoUsd);
    if (byCost != 0) return byCost;
    final byTokens = b.tokens.value.compareTo(a.tokens.value);
    if (byTokens != 0) return byTokens;
    return b.requests.compareTo(a.requests);
  }
}

class _DayBucket {
  int requests = 0;
  int tokens = 0;
  int cost = 0;
}
