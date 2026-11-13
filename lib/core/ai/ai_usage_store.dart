import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import 'ai_usage.dart';

const _nanoUsdPerUsd = 1000000000;
const _tokensPerMillion = 1000000;

class AiUsageCapture {
  AiUsageCapture({
    String? id,
    required this.actionId,
    this.sessionId,
    this.messageId,
    required this.providerKind,
    required this.endpoint,
    required this.model,
    required this.feature,
    required this.status,
    required this.occurredAt,
    this.durationMs,
    this.imageCount = 0,
    this.toolCallCount = 0,
    this.usage,
    this.usageSource,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final String actionId;
  final String? sessionId;
  final String? messageId;
  final String providerKind;
  final String endpoint;
  final String model;
  final String feature;
  final String status;
  final DateTime occurredAt;
  final int? durationMs;
  final int imageCount;
  final int toolCallCount;
  final AiTokenUsage? usage;
  final String? usageSource;
}

/// Local request-level AI usage history, pricing snapshots, and export.
class AiUsageStore {
  const AiUsageStore(this.db);
  final AppDatabase db;

  Future<void> record(AiUsageCapture capture) async {
    final usage = capture.usage;
    final isSubscription = capture.providerKind == 'chatgpt';
    final source =
        capture.usageSource ?? (usage == null ? 'unavailable' : 'provider');
    final isMock = source == 'mock';
    final price = isSubscription || isMock
        ? null
        : await (db.select(db.aiModelPrices)..where(
                (p) =>
                    p.providerKind.equals(capture.providerKind) &
                    p.endpoint.equals(_normalizeEndpoint(capture.endpoint)) &
                    p.model.equals(capture.model),
              ))
              .getSingleOrNull();
    final canEstimateCost =
        usage?.inputTokens != null &&
        usage?.outputTokens != null &&
        (usage?.cachedInputTokens != null ||
            (price != null &&
                price.cachedInputRateNanoUsdPerMillion ==
                    price.inputRateNanoUsdPerMillion));
    final cost = price == null || usage == null || !canEstimateCost
        ? null
        : _estimateCostNanoUsd(usage, price);
    await db
        .into(db.aiUsageEvents)
        .insertOnConflictUpdate(
          AiUsageEventsCompanion.insert(
            id: capture.id,
            actionId: capture.actionId,
            sessionId: Value(capture.sessionId),
            messageId: Value(capture.messageId),
            providerKind: capture.providerKind,
            endpoint: Value(_normalizeEndpoint(capture.endpoint)),
            model: capture.model,
            feature: capture.feature,
            status: capture.status,
            usageSource: Value(source),
            occurredAt: capture.occurredAt,
            durationMs: Value(capture.durationMs),
            imageCount: Value(capture.imageCount),
            toolCallCount: Value(capture.toolCallCount),
            inputTokens: Value(usage?.inputTokens),
            cachedInputTokens: Value(usage?.cachedInputTokens),
            outputTokens: Value(usage?.outputTokens),
            reasoningTokens: Value(usage?.reasoningTokens),
            totalTokens: Value(usage?.totalTokens),
            costNanoUsd: Value(cost),
            costBasis: Value(
              isSubscription
                  ? 'subscription'
                  : isMock
                  ? 'mock'
                  : price == null || !canEstimateCost
                  ? 'unknown'
                  : 'estimate',
            ),
            inputRateNanoUsdPerMillion: Value(
              price?.inputRateNanoUsdPerMillion,
            ),
            cachedInputRateNanoUsdPerMillion: Value(
              price?.cachedInputRateNanoUsdPerMillion,
            ),
            outputRateNanoUsdPerMillion: Value(
              price?.outputRateNanoUsdPerMillion,
            ),
            rateSource: Value(price?.source),
            rateUpdatedAt: Value(price?.updatedAt),
          ),
        );
  }

  Future<List<AiUsageEvent>> events({DateTime? from, DateTime? through}) =>
      (db.select(db.aiUsageEvents)
            ..where((e) {
              Expression<bool> filter = const Constant(true);
              if (from != null) {
                filter = filter & e.occurredAt.isBiggerOrEqualValue(from);
              }
              if (through != null) {
                filter = filter & e.occurredAt.isSmallerOrEqualValue(through);
              }
              return filter;
            })
            ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
          .get();

  Future<List<AiUsageEvent>> eventsForAction(String actionId) =>
      (db.select(db.aiUsageEvents)
            ..where((event) => event.actionId.equals(actionId))
            ..orderBy([(event) => OrderingTerm.asc(event.occurredAt)]))
          .get();

  Future<List<AiModelPrice>> prices() => db.select(db.aiModelPrices).get();

  Future<void> ensureBuiltinPrices() async {
    if (await db.preference('ai_usage_default_prices_v1') == '1') return;
    const defaults = [
      (
        model: 'deepseek-flash',
        input: 300000000,
        cached: 6000000,
        output: 1200000000,
      ),
      (
        model: 'deepseek-v4-pro',
        input: 1320000000,
        cached: 44000000,
        output: 3960000000,
      ),
    ];
    for (final price in defaults) {
      await db
          .into(db.aiModelPrices)
          .insert(
            AiModelPricesCompanion.insert(
              providerKind: 'deepseek',
              endpoint: const Value('https://api.deepseek.com'),
              model: price.model,
              inputRateNanoUsdPerMillion: price.input,
              cachedInputRateNanoUsdPerMillion: price.cached,
              outputRateNanoUsdPerMillion: price.output,
              source: const Value('deepseek_official_peak'),
              updatedAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    await db.setPreference('ai_usage_default_prices_v1', '1');
  }

  Future<void> savePrice({
    required String providerKind,
    required String endpoint,
    required String model,
    required int inputRateNanoUsdPerMillion,
    required int cachedInputRateNanoUsdPerMillion,
    required int outputRateNanoUsdPerMillion,
  }) async {
    if (model.trim().isEmpty ||
        inputRateNanoUsdPerMillion < 0 ||
        cachedInputRateNanoUsdPerMillion < 0 ||
        outputRateNanoUsdPerMillion < 0) {
      throw ArgumentError('模型名和价格必须有效。');
    }
    await db
        .into(db.aiModelPrices)
        .insertOnConflictUpdate(
          AiModelPricesCompanion.insert(
            providerKind: providerKind,
            endpoint: Value(_normalizeEndpoint(endpoint)),
            model: model.trim(),
            inputRateNanoUsdPerMillion: inputRateNanoUsdPerMillion,
            cachedInputRateNanoUsdPerMillion: cachedInputRateNanoUsdPerMillion,
            outputRateNanoUsdPerMillion: outputRateNanoUsdPerMillion,
            source: const Value('user'),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> deletePrice(AiModelPrice price) =>
      (db.delete(db.aiModelPrices)..where(
            (p) =>
                p.providerKind.equals(price.providerKind) &
                p.endpoint.equals(price.endpoint) &
                p.model.equals(price.model),
          ))
          .go();

  String toCsv(List<AiUsageEvent> rows) {
    final out = StringBuffer(
      'occurred_at,action_id,session_id,message_id,provider,endpoint,model,feature,status,usage_source,image_count,tool_call_count,input_tokens,cached_input_tokens,output_tokens,reasoning_tokens,total_tokens,cost_basis,cost_usd,input_rate_nano_usd_per_million,cached_rate_nano_usd_per_million,output_rate_nano_usd_per_million,rate_source,rate_updated_at,duration_ms\r\n',
    );
    for (final row in rows) {
      out.writeln(
        [
          row.occurredAt.toIso8601String(),
          row.actionId,
          row.sessionId ?? '',
          row.messageId ?? '',
          row.providerKind,
          row.endpoint,
          row.model,
          row.feature,
          row.status,
          row.usageSource,
          row.imageCount.toString(),
          row.toolCallCount.toString(),
          row.inputTokens?.toString() ?? '',
          row.cachedInputTokens?.toString() ?? '',
          row.outputTokens?.toString() ?? '',
          row.reasoningTokens?.toString() ?? '',
          row.totalTokens?.toString() ?? '',
          row.costBasis,
          row.costNanoUsd == null
              ? ''
              : (row.costNanoUsd! / _nanoUsdPerUsd).toStringAsFixed(9),
          row.inputRateNanoUsdPerMillion?.toString() ?? '',
          row.cachedInputRateNanoUsdPerMillion?.toString() ?? '',
          row.outputRateNanoUsdPerMillion?.toString() ?? '',
          row.rateSource ?? '',
          row.rateUpdatedAt?.toIso8601String() ?? '',
          row.durationMs?.toString() ?? '',
        ].map(_csvField).join(','),
      );
    }
    return out.toString();
  }

  String toJsonLines(List<AiUsageEvent> rows) => rows
      .map(
        (row) => jsonEncode({
          'occurredAt': row.occurredAt.toIso8601String(),
          'actionId': row.actionId,
          'sessionId': row.sessionId,
          'messageId': row.messageId,
          'provider': row.providerKind,
          'endpoint': row.endpoint,
          'model': row.model,
          'feature': row.feature,
          'status': row.status,
          'usageSource': row.usageSource,
          'imageCount': row.imageCount,
          'toolCallCount': row.toolCallCount,
          'inputTokens': row.inputTokens,
          'cachedInputTokens': row.cachedInputTokens,
          'outputTokens': row.outputTokens,
          'reasoningTokens': row.reasoningTokens,
          'totalTokens': row.totalTokens,
          'costBasis': row.costBasis,
          'inputRateNanoUsdPerMillion': row.inputRateNanoUsdPerMillion,
          'cachedInputRateNanoUsdPerMillion':
              row.cachedInputRateNanoUsdPerMillion,
          'outputRateNanoUsdPerMillion': row.outputRateNanoUsdPerMillion,
          'rateSource': row.rateSource,
          'rateUpdatedAt': row.rateUpdatedAt?.toIso8601String(),
          'costUsd': row.costNanoUsd == null
              ? null
              : row.costNanoUsd! / _nanoUsdPerUsd,
          'durationMs': row.durationMs,
        }),
      )
      .join('\n');

  int _estimateCostNanoUsd(AiTokenUsage usage, AiModelPrice price) {
    final input = usage.inputTokens ?? 0;
    final cached = (usage.cachedInputTokens ?? 0).clamp(0, input).toInt();
    final output = usage.outputTokens ?? 0;
    final uncached = input - cached;
    return (uncached * price.inputRateNanoUsdPerMillion +
            cached * price.cachedInputRateNanoUsdPerMillion +
            output * price.outputRateNanoUsdPerMillion) ~/
        _tokensPerMillion;
  }
}

String _normalizeEndpoint(String endpoint) {
  final trimmed = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;
  return uri
      .replace(scheme: uri.scheme.toLowerCase(), host: uri.host.toLowerCase())
      .toString();
}

String _csvField(String value) {
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(value) ? "'$value" : value;
  return '"${safe.replaceAll('"', '""')}"';
}
