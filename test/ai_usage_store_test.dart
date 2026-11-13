import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_usage.dart';
import 'package:tixun/core/ai/ai_usage_store.dart';
import 'package:tixun/core/database/database.dart';

void main() {
  late AppDatabase db;
  late AiUsageStore store;

  setUp(() async {
    db = AppDatabase.memory();
    store = AiUsageStore(db);
  });

  tearDown(() => db.close());

  test(
    'stores request breakdown and snapshots estimated model pricing',
    () async {
      await store.savePrice(
        providerKind: 'compatible',
        endpoint: 'https://api.example.test/v1/',
        model: 'model-x',
        inputRateNanoUsdPerMillion: 2000000000,
        cachedInputRateNanoUsdPerMillion: 500000000,
        outputRateNanoUsdPerMillion: 8000000000,
      );
      await store.record(
        AiUsageCapture(
          actionId: 'action-1',
          sessionId: 'session-1',
          messageId: 'message-1',
          providerKind: 'compatible',
          endpoint: 'https://api.example.test/v1',
          model: 'model-x',
          feature: 'chat',
          status: 'complete',
          occurredAt: DateTime.utc(2026, 1, 2),
          durationMs: 1200,
          usage: const AiTokenUsage(
            inputTokens: 100,
            cachedInputTokens: 40,
            outputTokens: 50,
            reasoningTokens: 10,
            reportedTotalTokens: 150,
          ),
        ),
      );

      final rows = await store.events();
      expect(rows, hasLength(1));
      expect(rows.single.inputTokens, 100);
      expect(rows.single.cachedInputTokens, 40);
      expect(rows.single.outputTokens, 50);
      expect(rows.single.totalTokens, 150);
      expect(rows.single.costBasis, 'estimate');
      expect(rows.single.costNanoUsd, 540000);
      expect(rows.single.inputRateNanoUsdPerMillion, 2000000000);
      expect(store.toCsv(rows), contains('"model-x"'));
      expect(store.toJsonLines(rows), contains('"cachedInputTokens":40'));
    },
  );

  test('total-only usage is not turned into a zero-dollar estimate', () async {
    await store.savePrice(
      providerKind: 'compatible',
      endpoint: '',
      model: 'total-only',
      inputRateNanoUsdPerMillion: 1000000000,
      cachedInputRateNanoUsdPerMillion: 500000000,
      outputRateNanoUsdPerMillion: 2000000000,
    );
    await store.record(
      AiUsageCapture(
        actionId: 'total-only-action',
        providerKind: 'compatible',
        endpoint: '',
        model: 'total-only',
        feature: 'chat',
        status: 'complete',
        occurredAt: DateTime.utc(2026, 1, 4),
        usage: const AiTokenUsage(reportedTotalTokens: 12),
      ),
    );
    final row = (await store.events()).single;
    expect(row.totalTokens, 12);
    expect(row.costNanoUsd, isNull);
    expect(row.costBasis, 'unknown');
  });

  test(
    'missing cache breakdown does not assume all input was uncached',
    () async {
      await store.savePrice(
        providerKind: 'compatible',
        endpoint: '',
        model: 'cache-aware',
        inputRateNanoUsdPerMillion: 1000000000,
        cachedInputRateNanoUsdPerMillion: 100000000,
        outputRateNanoUsdPerMillion: 2000000000,
      );
      await store.record(
        AiUsageCapture(
          actionId: 'cache-unknown',
          providerKind: 'compatible',
          endpoint: '',
          model: 'cache-aware',
          feature: 'chat',
          status: 'complete',
          occurredAt: DateTime.utc(2026, 1, 5),
          usage: const AiTokenUsage(inputTokens: 100, outputTokens: 20),
        ),
      );

      final row = (await store.events()).single;
      expect(row.costNanoUsd, isNull);
      expect(row.costBasis, 'unknown');
    },
  );

  test(
    'DeepSeek peak prices are prefilled and user edits are preserved',
    () async {
      await store.ensureBuiltinPrices();
      var price = (await store.prices()).singleWhere(
        (row) => row.model == 'deepseek-flash',
      );
      expect(price.inputRateNanoUsdPerMillion, 300000000);
      expect(price.cachedInputRateNanoUsdPerMillion, 6000000);
      expect(price.outputRateNanoUsdPerMillion, 1200000000);
      expect(price.offPeakDiscountPercent, 50);

      await store.savePrice(
        providerKind: price.providerKind,
        endpoint: price.endpoint,
        model: price.model,
        inputRateNanoUsdPerMillion: 200000000,
        cachedInputRateNanoUsdPerMillion: 5000000,
        outputRateNanoUsdPerMillion: 900000000,
      );
      await store.ensureBuiltinPrices();
      price = (await store.prices()).singleWhere(
        (row) => row.model == 'deepseek-flash',
      );
      expect(price.inputRateNanoUsdPerMillion, 200000000);
      expect(price.source, 'user');
      await store.deletePrice(price);
      await store.ensureBuiltinPrices();
      expect(
        (await store.prices()).any((row) => row.model == 'deepseek-flash'),
        isFalse,
      );
    },
  );

  test('DeepSeek off-peak requests snapshot the discounted rates', () async {
    await store.savePrice(
      providerKind: 'deepseek',
      endpoint: 'https://api.deepseek.com',
      model: 'deepseek-flash',
      inputRateNanoUsdPerMillion: 1000000000,
      cachedInputRateNanoUsdPerMillion: 500000000,
      outputRateNanoUsdPerMillion: 2000000000,
      offPeakDiscountPercent: 50,
    );
    for (final (action, at) in [
      ('peak', DateTime.utc(2026, 1, 2, 12)),
      ('off-peak', DateTime.utc(2026, 1, 2, 17)),
    ]) {
      await store.record(
        AiUsageCapture(
          actionId: action,
          providerKind: 'deepseek',
          endpoint: 'https://api.deepseek.com',
          model: 'deepseek-flash',
          feature: 'chat',
          status: 'complete',
          occurredAt: at,
          usage: const AiTokenUsage(
            inputTokens: 100,
            cachedInputTokens: 50,
            outputTokens: 25,
            reportedTotalTokens: 125,
          ),
        ),
      );
    }

    final rows = await store.events();
    final peak = rows.singleWhere((row) => row.actionId == 'peak');
    final offPeak = rows.singleWhere((row) => row.actionId == 'off-peak');
    expect(peak.costNanoUsd, 125000);
    expect(peak.inputRateNanoUsdPerMillion, 1000000000);
    expect(peak.rateSource, 'user');
    expect(offPeak.costNanoUsd, 62500);
    expect(offPeak.inputRateNanoUsdPerMillion, 500000000);
    expect(offPeak.cachedInputRateNanoUsdPerMillion, 250000000);
    expect(offPeak.outputRateNanoUsdPerMillion, 1000000000);
    expect(offPeak.rateSource, 'user_off_peak');
  });

  test('DeepSeek off-peak starts at 16:30 and ends at 00:30 UTC', () {
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 2, 16, 29)), isFalse);
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 2, 16, 30)), isTrue);
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 2, 23, 59)), isTrue);
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 3, 0, 29)), isTrue);
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 3, 0, 30)), isFalse);
    expect(isDeepSeekOffPeak(DateTime.utc(2026, 1, 3, 12)), isFalse);
  });

  test('ChatGPT plan usage has no invented per-token cash cost', () async {
    await store.record(
      AiUsageCapture(
        actionId: 'action-2',
        providerKind: 'chatgpt',
        endpoint: '',
        model: 'gpt-model',
        feature: 'chat',
        status: 'complete',
        occurredAt: DateTime.utc(2026, 1, 3),
        usage: const AiTokenUsage(
          inputTokens: 10,
          outputTokens: 5,
          reportedTotalTokens: 15,
        ),
      ),
    );

    final row = (await store.events()).single;
    expect(row.totalTokens, 15);
    expect(row.costNanoUsd, isNull);
    expect(row.costBasis, 'subscription');
  });
}
