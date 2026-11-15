/// Provider account balance, read from the provider itself.
///
/// DeepSeek documents a public endpoint for this (`GET /user/balance`), so the
/// number shown in Settings is the provider's own figure rather than an
/// estimate derived from local usage. This module uses no private web balance
/// endpoints; ChatGPT subscription quota is handled separately in chatgpt/usage.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../l10n/app_error.dart';
import 'ai_types.dart';
import 'account_query_cache.dart';

/// One currency line of a DeepSeek balance. Values stay as the provider's
/// decimal strings so rounding is never invented locally.
class ProviderBalanceLine {
  const ProviderBalanceLine({
    required this.currency,
    required this.total,
    required this.granted,
    required this.toppedUp,
  });

  final String currency;
  final String total;
  final String granted;
  final String toppedUp;
}

class ProviderBalance {
  ProviderBalance({
    required this.available,
    required List<ProviderBalanceLine> lines,
    required this.fetchedAt,
  }) : lines = List.unmodifiable(lines);

  /// `is_available` from the provider: false means the account cannot call the
  /// API right now, whatever the remaining figures say.
  final bool available;
  final List<ProviderBalanceLine> lines;
  final DateTime fetchedAt;
}

class ProviderBalanceClient {
  ProviderBalanceClient({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _client;
  final _cache = AccountQueryCache<ProviderBalance>((value) => value.fetchedAt);

  Object _identity(String baseUrl, String apiKey) => (
    baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
    sha256.convert(utf8.encode(apiKey.trim())).toString(),
  );

  ProviderBalance? cached({required String baseUrl, required String apiKey}) =>
      _cache.peek(_identity(baseUrl, apiKey));

  /// `GET {baseUrl}/user/balance`, documented at
  /// https://api-docs.deepseek.com/zh-cn/api/get-user-balance
  Future<ProviderBalance> deepSeek({
    required String baseUrl,
    required String apiKey,
    bool refresh = false,
  }) => _cache.load(
    _identity(baseUrl, apiKey),
    () => _fetch(baseUrl: baseUrl, apiKey: apiKey),
    refresh: refresh,
  );

  Future<ProviderBalance> _fetch({
    required String baseUrl,
    required String apiKey,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const AiFailure.localized(
        AppErrorCode.saveAnAPIKeyBeforeQueryingTheBalance,
        '请先保存 API Key 再查询余额。',
      );
    }
    final root = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(root);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiFailure.localized(
        AppErrorCode.theConnectionFailedOrThe,
        '网络连接失败或服务暂时不可用，请检查网络后重试。',
      );
    }
    Response<dynamic> response;
    try {
      response = await _client.get<dynamic>(
        '$root/user/balance',
        options: Options(
          headers: {
            'Authorization': 'Bearer $key',
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw const AiFailure.localized(
        AppErrorCode.theConnectionFailedOrThe,
        '网络连接失败或服务暂时不可用，请检查网络后重试。',
      );
    }
    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw const AiFailure.localized(
        AppErrorCode.theAPIKeyIsInvalid,
        'API Key 无效或没有访问权限，请检查设置。',
      );
    }
    if (status == 429) {
      throw const AiFailure.localized(
        AppErrorCode.tooManyRequestsTryAgain,
        '请求过于频繁，请稍后重试。',
      );
    }
    if (status < 200 || status >= 300) {
      throw const AiFailure.localized(
        AppErrorCode.theConnectionFailedOrThe,
        '网络连接失败或服务暂时不可用，请检查网络后重试。',
      );
    }
    return parseDeepSeekBalance(response.data);
  }
}

/// Parses the documented response shape. Unknown extra fields are ignored and a
/// missing `balance_infos` list yields an empty balance instead of throwing:
/// the endpoint contract has changed before without notice.
ProviderBalance parseDeepSeekBalance(Object? data, {DateTime? now}) {
  final map = data is Map ? data : const <String, dynamic>{};
  final available = map['is_available'] == true;
  final rawLines = map['balance_infos'];
  final lines = <ProviderBalanceLine>[];
  if (rawLines is List) {
    for (final row in rawLines) {
      if (row is! Map) continue;
      final currency = _string(row['currency']);
      if (currency.isEmpty) continue;
      lines.add(
        ProviderBalanceLine(
          currency: currency,
          total: _string(row['total_balance']),
          granted: _string(row['granted_balance']),
          toppedUp: _string(row['topped_up_balance']),
        ),
      );
    }
  }
  return ProviderBalance(
    available: available,
    lines: lines,
    fetchedAt: now ?? DateTime.now(),
  );
}

String _string(Object? value) => switch (value) {
  String text => text.trim(),
  num number => number.toString(),
  _ => '',
};
