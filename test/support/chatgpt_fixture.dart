import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:jose/jose.dart';
import 'package:tixun/core/ai/chatgpt/auth.dart';
import 'package:tixun/core/platform/key_store.dart';

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handle);
  final FutureOr<ResponseBody> Function(RequestOptions) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async => handle(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody fixtureJson(Object data, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(data),
      status,
      headers: {
        'content-type': ['application/json'],
      },
    );
ResponseBody fixtureSse(List<Map<String, dynamic>> events) =>
    ResponseBody.fromString(
      events.map((e) => 'data: ${jsonEncode(e)}\n\n').join(),
      200,
      headers: {
        'content-type': ['text/event-stream'],
      },
    );
Map<String, dynamic> completed({
  List<dynamic> output = const [],
  int tokens = 17,
}) => {
  'type': 'response.completed',
  'response': {
    'status': 'completed',
    'output': output,
    'usage': {'total_tokens': tokens},
  },
};

class ChatGptFixture {
  ChatGptFixture() {
    dio.httpClientAdapter = FixtureAdapter(handle);
    auth = ChatGptAuth(keys, client: dio, openBrowser: openBrowser);
  }
  final keys = MemoryKeyStore();
  final dio = Dio();
  final signingKey = JsonWebKey.generate('RS256');
  late final ChatGptAuth auth;
  Uri? authorization;
  String subject = 'student';
  Map<String, dynamic> overrides = {};
  JsonWebKey? alternativeSigningKey;
  Map<String, Object> protectedHeaders = {};
  int exchanges = 0, refreshes = 0, revocations = 0;
  bool failRevocation = false, denyScope = false;
  Completer<void>? refreshGate;
  Completer<void>? revokeGate;
  final requests = <RequestOptions>[];
  final callbackStatuses = <int>[];
  Future<bool> openBrowser(Uri uri) async {
    authorization = uri;
    final callback = Uri.parse(uri.queryParameters['redirect_uri']!);
    final client = HttpClient();
    try {
      for (final state in ['wrong-state', uri.queryParameters['state']!]) {
        final request = await client.getUrl(
          callback.replace(
            queryParameters: {
              'code': 'code-fixture',
              'state': state,
              'client_id': 'oaiapp_fixture',
            },
          ),
        );
        final response = await request.close();
        callbackStatuses.add(response.statusCode);
        await response.drain<void>();
      }
    } finally {
      client.close(force: true);
    }
    return true;
  }

  String idToken() {
    final builder = JsonWebSignatureBuilder()
      ..jsonContent = {
        'iss': chatGptIssuer,
        'sub': subject,
        'aud': 'oaiapp_fixture',
        'exp':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'nonce': authorization!.queryParameters['nonce'],
        'email': 'student@example.test',
        ...overrides,
      }
      ..setProtectedHeader('typ', 'JWT')
      ..addRecipient(alternativeSigningKey ?? signingKey, algorithm: 'RS256');
    protectedHeaders.forEach(builder.setProtectedHeader);
    return builder.build().toCompactSerialization();
  }

  FutureOr<ResponseBody> handle(RequestOptions request) async {
    requests.add(request);
    if (request.path.endsWith('openid-configuration')) {
      return fixtureJson({
        'issuer': chatGptIssuer,
        'jwks_uri': '$chatGptIssuer/.well-known/jwks.json',
        'revocation_endpoint': '$chatGptIssuer/api/accounts/oauth/revoke',
      });
    }
    if (request.path.endsWith('jwks.json')) {
      return fixtureJson({
        'keys': [
          JsonWebKey.fromCryptoKeys(
            publicKey: signingKey.cryptoKeyPair.publicKey,
          ).toJson(),
        ],
      });
    }
    if (request.path.endsWith('/oauth/token')) {
      final form = request.data as Map;
      if (form['grant_type'] == 'refresh_token') {
        refreshes++;
        await refreshGate?.future;
        return fixtureJson({
          'access_token': 'refreshed-fixture',
          'refresh_token': 'rotated-fixture',
          'token_type': 'Bearer',
          'expires_in': 3600,
        });
      }
      exchanges++;
      return fixtureJson({
        'id_token': idToken(),
        'access_token': 'access-fixture',
        'refresh_token': 'refresh-fixture',
        'token_type': 'Bearer',
        'expires_in': 3600,
        'scope': denyScope
            ? 'openid profile'
            : 'openid offline_access resource.invoke chatgpt.tokens.use.direct',
      });
    }
    if (request.path.endsWith('/oauth/revoke')) {
      revocations++;
      await revokeGate?.future;
      return fixtureJson({}, status: failRevocation ? 503 : 200);
    }
    if (request.path == '$chatGptResource/models') {
      return fixtureJson({
        'models': [
          {
            'slug': 'fixture-text',
            'display_name': 'Fixture text model',
            'visibility': 'list',
          },
          {
            'slug': 'fixture-vision',
            'display_name': 'Fixture vision model',
            'visibility': 'list',
            'input_modalities': ['text', 'image'],
            'supported_reasoning_levels': [
              for (final effort in ['low', 'medium', 'high', 'xhigh', 'max'])
                {'effort': effort, 'description': 'Fixture level'},
            ],
          },
          {'slug': 'hidden', 'display_name': 'Hidden', 'visibility': 'hide'},
        ],
      });
    }
    throw StateError('Unexpected fixture endpoint');
  }

  Future<void> seed({bool expired = false}) async {
    await keys.write(
      ChatGptAuth.storageKey,
      jsonEncode({
        'version': 1,
        'host': 'urn:uuid:test-host',
        'active': 'oaiapp_fixture:student',
        'accounts': [
          {
            'client_id': 'oaiapp_fixture',
            'sub': 'student',
            'email': 'student@example.test',
            'access_token': 'access-fixture',
            'refresh_token': 'refresh-fixture',
            'scopes': ['resource.invoke', 'chatgpt.tokens.use.direct'],
            'expires_at': DateTime.now()
                .add(Duration(hours: expired ? -1 : 1))
                .toUtc()
                .toIso8601String(),
          },
        ],
      }),
    );
  }
}
