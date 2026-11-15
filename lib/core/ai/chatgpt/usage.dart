/// ChatGPT subscription quota as reported by the same private endpoint the
/// official Codex client uses: `GET https://chatgpt.com/backend-api/wham/usage`.
///
/// The payload is documented only by the generated response models in the
/// `openai/codex` repository, not by the public API reference, so it can change
/// without notice. Parsing therefore keeps every field optional: a missing
/// window, credit block or plan label must not turn a valid answer into an
/// error, and numbers arrive either as JSON numbers or as numeric strings.
library;

import 'dart:convert';

import 'package:dio/dio.dart';

import '../../l10n/app_error.dart';
import '../ai_types.dart';
import '../account_query_cache.dart';
import 'auth.dart';

/// One rolling quota window (typically five hours, plus a weekly window).
class ChatGptQuotaWindow {
  const ChatGptQuotaWindow({
    required this.usedPercent,
    required this.windowSeconds,
    required this.resetAfterSeconds,
    this.resetAt,
  });

  /// 0–100 as reported; never rescaled locally.
  final int usedPercent;
  final int windowSeconds;
  final int resetAfterSeconds;
  final DateTime? resetAt;
}

class ChatGptQuota {
  const ChatGptQuota({
    required this.planType,
    required this.allowed,
    required this.limitReached,
    required this.fetchedAt,
    this.primary,
    this.secondary,
    this.hasCredits = false,
    this.unlimitedCredits = false,
    this.creditBalance,
  });

  /// `plus`, `pro`, `free`, … as sent by the server; may be empty.
  final String planType;
  final bool allowed;
  final bool limitReached;
  final ChatGptQuotaWindow? primary;
  final ChatGptQuotaWindow? secondary;
  final bool hasCredits;
  final bool unlimitedCredits;

  /// Remaining credit balance (currency unknown to the endpoint), if reported.
  final String? creditBalance;
  final DateTime fetchedAt;

  bool get hasWindows => primary != null || secondary != null;
}

class ChatGptUsageClient {
  ChatGptUsageClient({required this.auth, Dio? client, Uri? endpoint})
    : _endpoint = endpoint ?? Uri.parse(_defaultEndpoint),
      _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  static const _defaultEndpoint = 'https://chatgpt.com/backend-api/wham/usage';

  final ChatGptAuth auth;
  final Uri _endpoint;
  final Dio _client;
  final _cache = AccountQueryCache<ChatGptQuota>((value) => value.fetchedAt);

  ChatGptQuota? get cached => _cache.peek(auth.accountRevision);

  /// A settings-page read, with five-minute memory caching and no polling.
  Future<ChatGptQuota> fetch({bool refresh = false}) {
    final revision = auth.accountRevision;
    return _cache.load(revision, () => _fetch(revision), refresh: refresh);
  }

  Future<ChatGptQuota> _fetch(int revision) async {
    final session = await auth.session();
    Response<dynamic> response;
    try {
      response = await _client.get<dynamic>(
        _endpoint.toString(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            // The server ignores an empty identity; omitting the header is
            // what the Codex client does when it has no account claim.
            if (session.accountId.isNotEmpty)
              'ChatGPT-Account-Id': session.accountId,
            'Accept': 'application/json',
          },
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw const AiFailure.localized(
        AppErrorCode.theChatGPTRequestFailedCheck,
        'ChatGPT 请求失败，请检查网络后重试。',
      );
    }
    final status = response.statusCode ?? 0;
    if (status == 401) {
      throw const AiFailure.localized(
        AppErrorCode.yourChatGPTSignInHas,
        'ChatGPT 登录已失效，请重新登录。',
      );
    }
    if (status == 403) {
      throw const AiFailure.localized(
        AppErrorCode.chatGPTPlanAllowanceOrPermissions,
        'ChatGPT 订阅额度或权限不可用，请在 ChatGPT 中检查用量。不会转用 API 计费。',
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
        AppErrorCode.theChatGPTRequestFailedCheck,
        'ChatGPT 请求失败，请检查网络后重试。',
      );
    }
    if (revision != auth.accountRevision) {
      throw const AiFailure.localized(
        AppErrorCode.selectASavedChatGPTAccount,
        '请选择已保存的 ChatGPT 账号。',
      );
    }
    return parseChatGptQuota(response.data);
  }
}

/// Reads the quota payload, tolerating anything the server leaves out.
ChatGptQuota parseChatGptQuota(Object? data, {DateTime? now}) {
  final map = _map(data);
  if (map == null) {
    throw const AiFailure.localized(
      AppErrorCode.chatGPTReturnedAnUnrecognizedFormat,
      'ChatGPT 返回了无法识别的格式，请稍后重试或重新登录。',
    );
  }
  final rateLimit = _map(map['rate_limit']);
  final credits = _map(map['credits']);
  return ChatGptQuota(
    planType: _text(map['plan_type']),
    allowed: rateLimit?['allowed'] != false,
    limitReached: rateLimit?['limit_reached'] == true,
    primary: _window(rateLimit?['primary_window'], now: now),
    secondary: _window(rateLimit?['secondary_window'], now: now),
    hasCredits: credits?['has_credits'] == true,
    unlimitedCredits: credits?['unlimited'] == true,
    creditBalance: _optionalText(credits?['balance']),
    fetchedAt: now ?? DateTime.now(),
  );
}

ChatGptQuotaWindow? _window(Object? value, {DateTime? now}) {
  final map = _map(value);
  if (map == null) return null;
  final used = _int(map['used_percent']);
  if (used == null) return null;
  final window = _int(map['limit_window_seconds']) ?? 0;
  final after = _int(map['reset_after_seconds']) ?? 0;
  final resetSeconds = _int(map['reset_at']);
  final base = now ?? DateTime.now();
  return ChatGptQuotaWindow(
    usedPercent: used.clamp(0, 100),
    windowSeconds: window,
    resetAfterSeconds: after,
    // `reset_at` is epoch seconds in the generated model; accept a string date
    // too so a format change degrades into "unknown" instead of throwing.
    resetAt:
        switch (resetSeconds) {
          final int seconds => DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000,
          ),
          null => DateTime.tryParse(_text(map['reset_at'])),
        } ??
        (after > 0 ? base.add(Duration(seconds: after)) : null),
  );
}

Map<String, dynamic>? _map(Object? value) => switch (value) {
  final Map<String, dynamic> map => map,
  final Map map => {
    for (final entry in map.entries) '${entry.key}': entry.value,
  },
  final String text when text.trimLeft().startsWith('{') => _decode(text),
  _ => null,
};

Map<String, dynamic>? _decode(String text) {
  try {
    final value = jsonDecode(text);
    return value is Map
        ? {for (final e in value.entries) '${e.key}': e.value}
        : null;
  } catch (_) {
    return null;
  }
}

int? _int(Object? value) => switch (value) {
  final int number => number,
  final double number => number.round(),
  final String text =>
    int.tryParse(text.trim()) ?? double.tryParse(text.trim())?.round(),
  _ => null,
};

String _text(Object? value) => switch (value) {
  final String text => text.trim(),
  final num number => number.toString(),
  _ => '',
};

String? _optionalText(Object? value) {
  final text = _text(value);
  return text.isEmpty ? null : text;
}
