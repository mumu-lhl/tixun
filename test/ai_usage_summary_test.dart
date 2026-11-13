import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_usage.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/ai/ai_usage_summary.dart';
import 'package:tixun/core/database/database.dart';

void main() {
  late AppDatabase db;
  late AiUsageStore store;
  var action = 0;

  setUp(() {
    db = AppDatabase.memory();
    store = AiUsageStore(db);
  });

  tearDown(() => db.close());

  Future<void> record({
    String providerKind = 'compatible',
    String endpoint = 'https://api.test/v1',
    String model = 'm',
    String feature = 'chat',
    String status = 'complete',
    DateTime? occurredAt,
    AiTokenUsage? usage,
    String? usageSource,
  }) => store.record(
    AiUsageCapture(
      actionId: 'action-${action++}',
      providerKind: providerKind,
      endpoint: endpoint,
      model: model,
      feature: feature,
      status: status,
      occurredAt: occurredAt ?? DateTime(2026, 11, 14, 10),
      usage: usage,
      usageSource: usageSource,
    ),
  );

  Future<void> price(String model) => store.savePrice(
    providerKind: 'compatible',
    endpoint: 'https://api.test/v1',
    model: model,
    inputRateNanoUsdPerMillion: 1000000000,
    cachedInputRateNanoUsdPerMillion: 500000000,
    outputRateNanoUsdPerMillion: 2000000000,
  );

  test('aggregates reported values and explains every cost gap', () async {
    await price('m');
    await record(
      usage: const AiTokenUsage(
        inputTokens: 100,
        cachedInputTokens: 50,
        outputTokens: 25,
        reportedTotalTokens: 125,
      ),
    );
    // Total-only usage has no split, so it cannot be priced even with a price.
    await record(usage: const AiTokenUsage(reportedTotalTokens: 10));
    // The provider returned no usage at all.
    await record();
    await record(
      providerKind: 'chatgpt',
      model: 'gpt',
      usage: const AiTokenUsage(
        inputTokens: 10,
        outputTokens: 5,
        reportedTotalTokens: 15,
      ),
    );
    // Backfilled rows keep only a total and never count as requests.
    await record(
      usage: const AiTokenUsage(reportedTotalTokens: 7),
      usageSource: 'legacy_total',
    );
    // Input/output exist but no price is configured for this model.
    await record(
      model: 'unpriced',
      feature: 'context_compaction',
      usage: const AiTokenUsage(
        inputTokens: 10,
        outputTokens: 5,
        reportedTotalTokens: 15,
      ),
    );

    final summary = AiUsageSummary.fromRows(
      await store.events(),
      now: DateTime(2026, 11, 14, 12),
      trendDays: 7,
    );

    expect(summary.rowsCount, 6);
    expect(summary.requests, 5);
    expect(summary.legacyRows, 1);
    expect(summary.errors, 0);
    expect(summary.input.value, 120);
    expect(summary.input.reported, 3);
    expect(summary.input.isPartial, isTrue);
    expect(summary.cachedInput.value, 50);
    expect(summary.output.value, 35);
    expect(summary.total.value, 172);
    expect(summary.cacheHitRate, 50);
    expect(summary.estimatedCostNanoUsd, 125000);
    expect(summary.estimatedRows, 1);
    expect(summary.priceableRows, 2);
    expect(summary.subscriptionRows, 1);
    expect(summary.missingUsage, 1);
    expect(summary.missingDetail, 2);
    expect(summary.missingPrice, 1);
    expect(summary.hasPartialSums, isTrue);
    expect(summary.models.first.label, 'compatible · m');
    expect(summary.models.first.estimatedCostNanoUsd, 125000);
    expect(summary.features.first.id, 'chat');
    expect(summary.recent, hasLength(6));
  });

  test('sorts feature and model buckets by estimated cost', () async {
    await price('a');
    await price('b');
    await record(
      model: 'a',
      usage: const AiTokenUsage(
        inputTokens: 100,
        cachedInputTokens: 0,
        outputTokens: 100,
        reportedTotalTokens: 200,
      ),
    );
    await record(
      model: 'b',
      feature: 'context_compaction',
      usage: const AiTokenUsage(
        inputTokens: 1000,
        cachedInputTokens: 0,
        outputTokens: 1000,
        reportedTotalTokens: 2000,
      ),
    );

    final summary = AiUsageSummary.fromRows(await store.events());

    expect(summary.features.first.id, 'context_compaction');
    expect(summary.models.first.label, 'compatible · b');
    expect(summary.models.last.label, 'compatible · a');
    expect(summary.features.first.requests, 1);
    expect(summary.features.first.tokens.value, 2000);
  });

  test('builds a continuous local-day trend within the requested window', () async {
    await record(
      occurredAt: DateTime(2026, 11, 14, 9),
      usage: const AiTokenUsage(reportedTotalTokens: 100),
    );
    await record(
      occurredAt: DateTime(2026, 11, 13, 9),
      usage: const AiTokenUsage(reportedTotalTokens: 50),
    );
    // Outside the seven-day window: still in the summary, absent from the bars.
    await record(
      occurredAt: DateTime(2026, 10, 1, 9),
      usage: const AiTokenUsage(reportedTotalTokens: 999),
    );
    await record(
      occurredAt: DateTime(2026, 11, 14, 11),
      usage: const AiTokenUsage(reportedTotalTokens: 25),
      usageSource: 'legacy_total',
    );

    final summary = AiUsageSummary.fromRows(
      await store.events(),
      now: DateTime(2026, 11, 14, 12),
      trendDays: 7,
    );

    expect(summary.total.value, 1174);
    expect(summary.days, hasLength(7));
    expect(summary.days.last.day, DateTime(2026, 11, 14));
    expect(summary.days.last.requests, 1);
    expect(summary.days.last.tokens, 125);
    expect(summary.days[5].requests, 1);
    expect(summary.days[5].tokens, 50);
    expect(summary.days.fold<int>(0, (sum, day) => sum + day.tokens), 175);
  });

  test(
    'empty history stays empty instead of showing zeroed averages',
    () async {
      final summary = AiUsageSummary.fromRows(const [], trendDays: 30);

      expect(summary.rowsCount, 0);
      expect(summary.requests, 0);
      expect(summary.input.isEmpty, isTrue);
      expect(summary.cacheHitRate, isNull);
      expect(summary.averageLatencyMs, isNull);
      expect(summary.models, isEmpty);
      expect(summary.features, isEmpty);
      expect(summary.recent, isEmpty);
      expect(summary.days, hasLength(30));
    },
  );
}
