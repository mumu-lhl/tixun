import "package:tixun/core/l10n/app_error.dart";

import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:jose/jose.dart";
import "package:url_launcher/url_launcher.dart";
import "package:uuid/uuid.dart";

import "../../platform/key_store.dart";
import "../chat_provider.dart";

part "auth_login.dart";

const chatGptIssuer = "https://auth.openai.com";
const chatGptResource = "https://api.openai.com/v1";
const _tokenUrl = "$chatGptIssuer/api/accounts/oauth/token";
const _requiredScopes = {"resource.invoke", "chatgpt.tokens.use.direct"};

class ChatGptAccount {
  const ChatGptAccount({
    required this.clientId,
    required this.subject,
    required this.label,
    required this.connected,
  });
  final String clientId, subject, label;
  final bool connected;
  String get id => "$clientId:$subject";
}

class ChatGptSnapshot {
  ChatGptSnapshot(List<ChatGptAccount> accounts, this.activeId)
    : accounts = List.unmodifiable(accounts);
  final List<ChatGptAccount> accounts;
  final String? activeId;
}

class _AccountRecord {
  _AccountRecord(Map<String, dynamic> data) : data = Map.unmodifiable(data) {
    // Fail eagerly so a record missing its identity is caught by _accounts
    // and reported as an unreadable login instead of a raw TypeError from
    // a getter later.
    if (data["client_id"] is! String || data["sub"] is! String) {
      throw const AppFormatException(
        AppErrorCode.errorTheChatGPTSignInRecordIs,
        "ChatGPT 登录记录损坏。",
      );
    }
  }
  final Map<String, dynamic> data;
  String get clientId => data["client_id"] as String;
  String get subject => data["sub"] as String;
  String get id => "$clientId:$subject";
  String get label =>
      data["email"] as String? ?? data["name"] as String? ?? "ChatGPT";
  bool get connected => (data["refresh_token"] as String? ?? "").isNotEmpty;

  ChatGptAccount get summary => ChatGptAccount(
    clientId: clientId,
    subject: subject,
    label: label,
    connected: connected,
  );
  List<String> get scopes => List<String>.from(data["scopes"] as List? ?? []);
}

class ChatGptModel {
  const ChatGptModel(this.id, this.name, this.vision, {this.reasoningEfforts});
  final String id, name;
  final bool vision;
  final List<String>? reasoningEfforts;
}

/// Tokens and registration metadata live in one secure-store record, never SQLite.
/// Public HTTP/browser seams permit protocol tests without real credentials.
class ChatGptAuth {
  ChatGptAuth(
    KeyStore keys, {
    Dio? client,
    Future<bool> Function(Uri)? openBrowser,
  }) : _keys = keys,
       _client =
           client ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(seconds: 30),
               sendTimeout: const Duration(seconds: 30),
               followRedirects: false,
             ),
           ),
       _openBrowser =
           openBrowser ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  static const storageKey = "chatgpt.oauth.v1";
  final KeyStore _keys;
  final Dio _client;
  final Future<bool> Function(Uri) _openBrowser;
  Future<void> _writes = Future.value();
  final Map<String, Future<String>> _refreshes = {};
  CancelToken? _login;
  bool _signingOut = false;
  int _accountEpoch = 0;

  bool get signingIn => _login != null;
  void cancelLogin() => _login?.cancel();

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final next = _writes.then((_) => action());
    _writes = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<Map<String, dynamic>> _load() async {
    final raw = await _keys.read(storageKey);
    if (raw == null || raw.isEmpty) {
      return {"version": 1, "accounts": <dynamic>[]};
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data["version"] != 1 || data["accounts"] is! List) {
        throw const AiFailure.localized(
          AppErrorCode.couldNotReadChatGPTSign,
          "ChatGPT 登录记录无法读取，请检查系统安全存储。",
        );
      }
      return data;
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure.localized(
        AppErrorCode.couldNotReadChatGPTSign,
        "ChatGPT 登录记录无法读取，请检查系统安全存储。",
      );
    }
  }

  Future<void> _save(Map<String, dynamic> data) =>
      _keys.write(storageKey, jsonEncode(data));
  List<_AccountRecord> _accounts(Map<String, dynamic> data) {
    try {
      return [
        for (final row in data["accounts"] as List)
          _AccountRecord(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (_) {
      throw const AiFailure.localized(
        AppErrorCode.couldNotReadChatGPTSign,
        "ChatGPT 登录记录无法读取，请检查系统安全存储。",
      );
    }
  }

  Future<ChatGptSnapshot> snapshot() async {
    final data = await _load();
    final accounts = _accounts(data).map((a) => a.summary).toList();
    final active = data["active"] as String?;
    return ChatGptSnapshot(
      accounts,
      accounts.any((a) => a.id == active) ? active : null,
    );
  }

  Future<void> select(String id) => _exclusive(() async {
    final data = await _load();
    if (!_accounts(data).any((a) => a.id == id)) {
      throw const AiFailure.localized(
        AppErrorCode.selectASavedChatGPTAccount,
        "请选择已保存的 ChatGPT 账号。",
      );
    }
    data["active"] = id;
    await _save(data);
    _accountEpoch++;
  });

  Future<Map<String, dynamic>> _discovery() async {
    final result = await _client.get<Map<String, dynamic>>(
      "$chatGptIssuer/.well-known/openid-configuration",
    );
    final data = result.data!;
    if (data["issuer"] != chatGptIssuer) {
      throw const AiFailure.localized(
        AppErrorCode.invalidChatGPTAuthorizationServiceIdentity,
        "ChatGPT 授权服务身份无效。",
      );
    }
    return data;
  }

  Uri _trustedEndpoint(Object? value) {
    final uri = Uri.parse(value as String);
    if (uri.scheme != "https" ||
        uri.host != "auth.openai.com" ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443)) {
      throw const AiFailure.localized(
        AppErrorCode.invalidChatGPTAuthorizationServiceURL,
        "ChatGPT 授权服务地址无效。",
      );
    }
    return uri;
  }

  String _random() =>
      base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)))
          .replaceAll("=", "");

  Future<ChatGptAccount> signIn({String? accountId}) =>
      _signIn(accountId: accountId);

  Future<String> accessToken({CancelToken? cancel}) async {
    cancel?.checkCancelled();
    final epoch = _accountEpoch;
    final data = await _load();
    cancel?.checkCancelled();
    if (epoch != _accountEpoch) {
      throw const AiFailure.localized(
        AppErrorCode.theChatGPTAccountChangedSend,
        "ChatGPT 账号已切换，请重新发送。",
      );
    }
    final account = _accounts(data)
        .where((a) => a.id == data["active"])
        .firstOrNull;
    if (account == null || !account.connected) {
      throw const AiFailure.localized(
        AppErrorCode.signInUsingContinueWith,
        "请先使用 Continue with ChatGPT 登录。",
      );
    }
    if (!_requiredScopes.every(account.scopes.contains)) {
      throw const AiFailure.localized(
        AppErrorCode.thisAccountHasNotGranted,
        "账号未授予 ChatGPT 订阅推理权限，请重新授权。",
      );
    }
    final expiry = DateTime.tryParse(
      account.data["expires_at"] as String? ?? "",
    );
    if (expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return account.data["access_token"] as String;
    }
    var pending = _refreshes[account.id];
    if (pending == null) {
      final refresh = _refresh(account);
      _refreshes[account.id] = refresh;
      pending = refresh;
      void release() {
        if (identical(_refreshes[account.id], refresh)) {
          final _ = _refreshes.remove(account.id);
        }
      }

      unawaited(
        refresh.then<void>(
          (_) => release(),
          onError: (Object _, StackTrace _) => release(),
        ),
      );
    }
    // A caller may stop waiting without cancelling a shared rotating refresh.
    final token = cancel == null
        ? await pending
        : await Future.any<String>([
            pending,
            cancel.whenCancel.then<String>((error) => throw error),
          ]);
    cancel?.checkCancelled();
    if (epoch != _accountEpoch) {
      throw const AiFailure.localized(
        AppErrorCode.theChatGPTAccountChangedSend,
        "ChatGPT 账号已切换，请重新发送。",
      );
    }
    return token;
  }

  Future<String> _refresh(_AccountRecord account) async {
    try {
      final token = (await _client.post<Map<String, dynamic>>(
        _tokenUrl,
        data: {
          "grant_type": "refresh_token",
          "client_id": account.clientId,
          "refresh_token": account.data["refresh_token"],
          "resource": chatGptResource,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      )).data!;
      final next = _tokenRecord(token, account.data);
      await _exclusive(() async {
        final data = await _load();
        final existing = _accounts(data)
            .where((a) => a.id == account.id)
            .firstOrNull;
        if (existing == null ||
            existing.data["refresh_token"] != account.data["refresh_token"]) {
          throw const AiFailure.localized(
            AppErrorCode.chatGPTSignInChangedSend,
            "ChatGPT 登录已改变，请重新发送。",
          );
        }
        data["accounts"] = [
          for (final a in _accounts(data)) a.id == account.id ? next : a.data,
        ];
        await _save(data);
      });
      return next["access_token"] as String;
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure.localized(
        AppErrorCode.couldNotRenewChatGPTSign,
        "ChatGPT 登录续期失败，请重新登录。",
      );
    }
  }

  /// Clear local tokens even if remote revocation is unavailable; report that case.
  Future<bool> signOut(String id) async {
    if (_signingOut) {
      throw const AiFailure.localized(
        AppErrorCode.signingOutOfChatGPTTry,
        "正在退出 ChatGPT，请稍后重试。",
      );
    }
    _signingOut = true;
    cancelLogin();
    _accountEpoch++;
    try {
      final account = _accounts(await _load())
          .where((a) => a.id == id)
          .firstOrNull;
      if (account == null) return true;
      // Invalidate locally before network I/O: navigating away must not leave
      // usable credentials during a slow or failed revocation request.
      await _exclusive(() async {
        final data = await _load();
        data["accounts"] = [
          for (final a in _accounts(data))
            a.id == id
                ? {
                    ...a.data,
                    "access_token": "",
                    "refresh_token": "",
                    "expires_at": "",
                    "scopes": <String>[],
                  }
                : a.data,
        ];
        await _save(data);
      });
      if (!account.connected) return true;
      try {
        final discovery = await _discovery();
        await _client.post<void>(
          _trustedEndpoint(discovery["revocation_endpoint"]).toString(),
          data: {
            "client_id": account.clientId,
            "token": account.data["refresh_token"],
            "token_type_hint": "refresh_token",
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        return true;
      } catch (_) {
        return false;
      }
    } finally {
      _signingOut = false;
    }
  }

  Future<List<ChatGptModel>> models() async {
    try {
      final token = await accessToken();
      final data = (await _client.get<Map<String, dynamic>>(
        "$chatGptResource/models",
        options: Options(headers: {"Authorization": "Bearer $token"}),
      )).data!;
      if (data["models"] is! List) {
        throw const AiFailure.localized(
          AppErrorCode.invalidChatGPTModelCatalog,
          "ChatGPT 模型列表格式无效。",
        );
      }
      return [
        for (final row in data["models"] as List)
          if (row is Map &&
              row["visibility"] == "list" &&
              row["slug"] is String &&
              row["display_name"] is String)
            ChatGptModel(
              row["slug"] as String,
              row["display_name"] as String,
              (row["input_modalities"] is List
                      ? row["input_modalities"] as List
                      : [])
                  .contains("image"),
              reasoningEfforts: advertisedReasoningLevels(row),
            ),
      ];
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure.localized(
        AppErrorCode.couldNotLoadChatGPTModels,
        "无法读取 ChatGPT 模型列表，请检查网络或重新登录。",
      );
    }
  }
}
