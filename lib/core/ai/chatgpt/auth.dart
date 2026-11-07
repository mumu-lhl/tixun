import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:jose/jose.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../platform/key_store.dart';
import '../chat_provider.dart';

const chatGptIssuer = 'https://auth.openai.com';
const chatGptResource = 'https://api.openai.com/v1';
const _tokenUrl = '$chatGptIssuer/api/accounts/oauth/token';
const _requiredScopes = {'resource.invoke', 'chatgpt.tokens.use.direct'};

class ChatGptAccount {
  ChatGptAccount(this.data);
  final Map<String, dynamic> data;
  String get clientId => data['client_id'] as String;
  String get subject => data['sub'] as String;
  String get id => '$clientId:$subject';
  String get label =>
      data['email'] as String? ?? data['name'] as String? ?? 'ChatGPT';
  bool get connected => (data['refresh_token'] as String? ?? '').isNotEmpty;
  List<String> get scopes => List<String>.from(data['scopes'] as List? ?? []);
}

class ChatGptModel {
  const ChatGptModel(this.id, this.name, this.vision);
  final String id, name;
  final bool vision;
}

/// Tokens and registration metadata live in one secure-store record, never SQLite.
/// Public HTTP/browser seams permit protocol tests without real credentials.
class ChatGptAuth {
  ChatGptAuth(this.keys, {Dio? client, Future<bool> Function(Uri)? openBrowser})
    : client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          ),
      openBrowser =
          openBrowser ??
          ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));
  static const storageKey = 'chatgpt.oauth.v1';
  final KeyStore keys;
  final Dio client;
  final Future<bool> Function(Uri) openBrowser;
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
    final raw = await keys.read(storageKey);
    if (raw == null || raw.isEmpty) {
      return {'version': 1, 'accounts': <dynamic>[]};
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1 || data['accounts'] is! List) {
      throw const AiFailure('ChatGPT 登录记录无法读取，请检查系统安全存储。');
    }
    return data;
  }

  Future<void> _save(Map<String, dynamic> data) =>
      keys.write(storageKey, jsonEncode(data));
  List<ChatGptAccount> _accounts(Map<String, dynamic> data) => [
    for (final row in data['accounts'] as List)
      ChatGptAccount(Map<String, dynamic>.from(row as Map)),
  ];
  Future<List<ChatGptAccount>> accounts() async => _accounts(await _load());
  Future<String?> activeId() async => (await _load())['active'] as String?;
  Future<void> select(String id) => _exclusive(() async {
    final data = await _load();
    if (!_accounts(data).any((a) => a.id == id)) {
      throw const AiFailure('请选择已保存的 ChatGPT 账号。');
    }
    data['active'] = id;
    await _save(data);
    _accountEpoch++;
  });

  Future<Map<String, dynamic>> _discovery() async {
    final result = await client.get<Map<String, dynamic>>(
      '$chatGptIssuer/.well-known/openid-configuration',
    );
    final data = result.data!;
    if (data['issuer'] != chatGptIssuer) {
      throw const AiFailure('ChatGPT 授权服务身份无效。');
    }
    return data;
  }

  Uri _trustedEndpoint(Object? value) {
    final uri = Uri.parse(value as String);
    if (uri.scheme != 'https' ||
        uri.host != 'auth.openai.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && uri.port != 443)) {
      throw const AiFailure('ChatGPT 授权服务地址无效。');
    }
    return uri;
  }

  String _random() =>
      base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');

  Future<ChatGptAccount> signIn({String? accountId}) async {
    if (_signingOut) throw const AiFailure('正在退出 ChatGPT，请稍后重试。');
    if (_login != null) throw const AiFailure('已有 ChatGPT 登录正在进行。');
    final cancel = _login = CancelToken();
    HttpServer? server;
    Timer? timer;
    try {
      final host = await _exclusive(() async {
        final data = await _load();
        data['host'] ??= 'urn:uuid:${const Uuid().v4()}';
        await _save(
          data,
        ); // Fail before opening browser if secure storage is unavailable.
        return data['host'] as String;
      });
      cancel.checkCancelled();
      final saved = await accounts();
      final old = accountId == null
          ? null
          : saved.where((a) => a.id == accountId).firstOrNull;
      if (accountId != null && old == null) {
        throw const AiFailure('请选择已保存的 ChatGPT 账号。');
      }
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirect = 'http://127.0.0.1:${server.port}/auth/callback';
      final state = _random(), nonce = _random(), verifier = _random();
      final result = Completer<Map<String, String>>();
      cancel.whenCancel.then((_) {
        if (!result.isCompleted) {
          result.completeError(const AiFailure('已取消 ChatGPT 登录。'));
        }
      });
      timer = Timer(const Duration(minutes: 3), () {
        if (!result.isCompleted) {
          result.completeError(const AiFailure('ChatGPT 登录超时，请重试。'));
        }
      });
      // Attach an error listener before browser launch/cancellation can complete it.
      final callback = result.future;
      unawaited(
        callback.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
      server.listen((request) async {
        var accepted = false;
        try {
          final query = request.uri.queryParametersAll;
          accepted =
              request.method == 'GET' &&
              request.uri.path == '/auth/callback' &&
              request.headers.value('host') == '127.0.0.1:${server!.port}' &&
              query.values.every((v) => v.length == 1) &&
              request.uri.queryParameters['state'] == state &&
              !result.isCompleted;
          if (accepted) result.complete(request.uri.queryParameters);
          request.response.statusCode = accepted ? 200 : 400;
          request.response.headers
            ..contentType = ContentType.html
            ..set('Cache-Control', 'no-store')
            ..set('Referrer-Policy', 'no-referrer')
            ..set('Content-Security-Policy', "default-src 'none'");
          request.response.write(
            accepted
                ? '<!doctype html><meta charset="utf-8"><p>Return to TiXun to finish signing in. 请返回题训完成登录。</p>'
                : 'Invalid callback.',
          );
          await request.response.close();
        } catch (_) {
          await request.response.close();
        }
      });
      final uri = Uri.parse('$chatGptIssuer/api/accounts/authorize').replace(
        queryParameters: {
          'response_type': 'code',
          'client_id': old?.clientId ?? 'dynamic_agent_client',
          'agent_name_hint': 'TiXun',
          'ext_agent_host_id': host,
          'redirect_uri': redirect,
          'scope': 'openid profile email offline_access resource.invoke chatgpt.tokens.use.direct',
          'resource': chatGptResource,
          'state': state,
          'nonce': nonce,
          'code_challenge_method': 'S256',
          'code_challenge': base64UrlEncode(
            sha256.convert(ascii.encode(verifier)).bytes,
          ).replaceAll('=', ''),
          if (old?.data['id_token'] case final String hint)
            'id_token_hint': hint,
        },
      );
      bool opened;
      try {
        opened = await openBrowser(uri);
      } catch (_) {
        throw const AiFailure('无法打开系统浏览器，请检查浏览器设置。');
      }
      if (!opened) throw const AiFailure('无法打开系统浏览器，请检查浏览器设置。');
      final answer = await callback;
      cancel.checkCancelled();
      if (answer.containsKey('error')) {
        throw const AiFailure('ChatGPT 授权未完成，请重新登录并确认订阅使用权限。');
      }
      final clientId = answer['client_id'] ?? old?.clientId;
      if (clientId == null ||
          clientId == 'dynamic_agent_client' ||
          !clientId.startsWith('oaiapp_') ||
          (old != null && clientId != old.clientId) ||
          (answer['code'] ?? '').isEmpty) {
        throw const AiFailure('ChatGPT 登录回调无效，请重新登录。');
      }
      final token = (await client.post<Map<String, dynamic>>(
        _tokenUrl,
        data: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'code': answer['code'],
          'code_verifier': verifier,
          'redirect_uri': redirect,
          'resource': chatGptResource,
        },
        cancelToken: cancel,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      )).data!;
      final identity = await _verifyIdentity(
        token['id_token'] as String,
        clientId,
        nonce,
      );
      if (old != null && identity['sub'] != old.subject) {
        throw const AiFailure('登录账号与所选账号不一致，原登录记录未更改。');
      }
      final record = _tokenRecord(token, {...identity, 'client_id': clientId});
      cancel.checkCancelled();
      await _exclusive(() async {
        cancel.checkCancelled();
        final data = await _load();
        final account = ChatGptAccount(record);
        data['accounts'] = [
          for (final a in _accounts(data))
            if (a.id != account.id) a.data,
          record,
        ];
        data['active'] = account.id;
        await _save(data);
        _accountEpoch++;
      });
      return ChatGptAccount(record);
    } on AiFailure {
      rethrow;
    } catch (_) {
      if (cancel.isCancelled) throw const AiFailure('已取消 ChatGPT 登录。');
      throw const AiFailure('ChatGPT 登录失败，请检查网络、系统时间和安全存储后重试。');
    } finally {
      timer?.cancel();
      await server?.close(force: true);
      _login = null;
    }
  }

  Future<Map<String, dynamic>> _verifyIdentity(
    String raw,
    String clientId,
    String nonce,
  ) async {
    final discovery = await _discovery();
    final jwks = (await client.get<Map<String, dynamic>>(
      _trustedEndpoint(discovery['jwks_uri']).toString(),
    )).data!;
    final store = JsonWebKeyStore()..addKeySet(JsonWebKeySet.fromJson(jwks));
    final jwt = await JsonWebToken.decodeAndVerify(
      raw,
      store,
      allowedArguments: ['RS256'],
    );
    final claims = jwt.claims;
    final now = DateTime.now();
    if (claims.issuer.toString() != chatGptIssuer ||
        !(claims.audience ?? []).contains(clientId) ||
        claims.issuedAt == null ||
        claims.expiry == null ||
        !claims.expiry!.isAfter(now) ||
        (claims.notBefore?.isAfter(now.add(const Duration(seconds: 30))) ??
            false) ||
        (claims.issuedAt?.isAfter(now.add(const Duration(seconds: 30))) ??
            false) ||
        claims['nonce'] != nonce ||
        (claims.subject ?? '').isEmpty ||
        ((claims.audience?.length ?? 0) > 1 && claims['azp'] != clientId)) {
      throw const AiFailure('ChatGPT 账号身份校验失败，请重新登录。');
    }
    return {
      'sub': claims.subject,
      'id_token': raw,
      if (claims['email'] is String) 'email': claims['email'],
      if (claims['name'] is String) 'name': claims['name'],
    };
  }

  Map<String, dynamic> _tokenRecord(
    Map<String, dynamic> token,
    Map<String, dynamic> old,
  ) {
    final scopes = token['scope'] is String
        ? (token['scope'] as String)
              .split(' ')
              .where((s) => s.isNotEmpty)
              .toList()
        : List<String>.from(old['scopes'] as List? ?? []);
    if (!_requiredScopes.every(scopes.contains) ||
        token['token_type']?.toString().toLowerCase() != 'bearer' ||
        token['access_token'] is! String ||
        (token['access_token'] as String).isEmpty ||
        token['expires_in'] is! num ||
        (token['expires_in'] as num) <= 0 ||
        (token['expires_in'] as num) > 604800 ||
        ((token['refresh_token'] ?? old['refresh_token']) as String? ?? '')
            .isEmpty) {
      throw const AiFailure('账号未授予 ChatGPT 订阅推理权限，请重新授权。');
    }
    return {
      ...old,
      'access_token': token['access_token'],
      'refresh_token': token['refresh_token'] ?? old['refresh_token'],
      'scopes': scopes,
      'expires_at': DateTime.now()
          .add(Duration(seconds: (token['expires_in'] as num).toInt()))
          .toUtc()
          .toIso8601String(),
    };
  }

  Future<String> accessToken({CancelToken? cancel}) async {
    cancel?.checkCancelled();
    final data = await _load(), epoch = _accountEpoch;
    final account = _accounts(data)
        .where((a) => a.id == data['active'])
        .firstOrNull;
    if (account == null || !account.connected) {
      throw const AiFailure('请先使用 Continue with ChatGPT 登录。');
    }
    if (!_requiredScopes.every(account.scopes.contains)) {
      throw const AiFailure('账号未授予 ChatGPT 订阅推理权限，请重新授权。');
    }
    final expiry = DateTime.tryParse(
      account.data['expires_at'] as String? ?? '',
    );
    if (expiry != null &&
        expiry.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
      return account.data['access_token'] as String;
    }
    final pending = _refreshes.putIfAbsent(account.id, () => _refresh(account));
    try {
      final token = await pending;
      cancel?.checkCancelled();
      if (epoch != _accountEpoch) throw const AiFailure('ChatGPT 账号已切换，请重新发送。');
      return token;
    } finally {
      if (identical(_refreshes[account.id], pending)) {
        _refreshes.remove(account.id);
      }
    }
  }

  Future<String> _refresh(ChatGptAccount account) async {
    try {
      final token = (await client.post<Map<String, dynamic>>(
        _tokenUrl,
        data: {
          'grant_type': 'refresh_token',
          'client_id': account.clientId,
          'refresh_token': account.data['refresh_token'],
          'resource': chatGptResource,
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
            existing.data['refresh_token'] != account.data['refresh_token']) {
          throw const AiFailure('ChatGPT 登录已改变，请重新发送。');
        }
        data['accounts'] = [
          for (final a in _accounts(data)) a.id == account.id ? next : a.data,
        ];
        await _save(data);
      });
      return next['access_token'] as String;
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure('ChatGPT 登录续期失败，请重新登录。');
    }
  }

  /// Clear local tokens even if remote revocation is unavailable; report that case.
  Future<bool> signOut(String id) async {
    if (_signingOut) throw const AiFailure('正在退出 ChatGPT，请稍后重试。');
    _signingOut = true;
    cancelLogin();
    _accountEpoch++;
    try {
      final account = (await accounts()).where((a) => a.id == id).firstOrNull;
      if (account == null) return true;
      // Invalidate locally before network I/O: navigating away must not leave
      // usable credentials during a slow or failed revocation request.
      await _exclusive(() async {
        final data = await _load();
        data['accounts'] = [
          for (final a in _accounts(data))
            a.id == id
                ? {
                    ...a.data,
                    'access_token': '',
                    'refresh_token': '',
                    'expires_at': '',
                    'scopes': <String>[],
                  }
                : a.data,
        ];
        await _save(data);
      });
      if (!account.connected) return true;
      try {
        final discovery = await _discovery();
        await client.post<void>(
          _trustedEndpoint(discovery['revocation_endpoint']).toString(),
          data: {
            'client_id': account.clientId,
            'token': account.data['refresh_token'],
            'token_type_hint': 'refresh_token',
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
      final data = (await client.get<Map<String, dynamic>>(
        '$chatGptResource/models',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      )).data!;
      if (data['models'] is! List) throw const AiFailure('ChatGPT 模型列表格式无效。');
      return [
        for (final row in data['models'] as List)
          if (row is Map &&
              row['visibility'] == 'list' &&
              row['slug'] is String &&
              row['display_name'] is String)
            ChatGptModel(
              row['slug'] as String,
              row['display_name'] as String,
              (row['input_modalities'] as List? ?? []).contains('image'),
            ),
      ];
    } on AiFailure {
      rethrow;
    } catch (_) {
      throw const AiFailure('无法读取 ChatGPT 模型列表，请检查网络或重新登录。');
    }
  }
}
