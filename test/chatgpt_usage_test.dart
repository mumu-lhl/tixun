import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/auth.dart';
import 'package:tixun/core/ai/chatgpt/usage.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:tixun/core/l10n/app_strings.dart';
import 'package:tixun/core/l10n/generated/app_localizations.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/settings/chatgpt_quota_panel.dart';

import 'support/chatgpt_fixture.dart';

String _token(Map<String, dynamic> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.signature';
}

/// A stored record shaped exactly like the one sign-in writes.
Map<String, dynamic> _record({
  String accountId = '',
  String plan = '',
  String? idToken,
  DateTime? expiresAt,
}) => {
  'client_id': 'oaiapp_test',
  'sub': 'user-1',
  'id_token': ?idToken,
  if (accountId.isNotEmpty) 'account_id': accountId,
  if (plan.isNotEmpty) 'plan_type': plan,
  'access_token': 'access-token',
  'refresh_token': 'refresh-token',
  'scopes': [
    'openid',
    'profile',
    'email',
    'offline_access',
    'resource.invoke',
    'chatgpt.tokens.use.direct',
  ],
  'expires_at': (expiresAt ?? DateTime.now().add(const Duration(hours: 1)))
      .toUtc()
      .toIso8601String(),
};

Future<ChatGptAuth> _auth(Map<String, dynamic> record, {Dio? client}) async {
  final keys = MemoryKeyStore();
  await keys.write(
    ChatGptAuth.storageKey,
    jsonEncode({
      'version': 1,
      'accounts': [record],
      'active': 'oaiapp_test:user-1',
    }),
  );
  return ChatGptAuth(keys, client: client);
}

Dio _dio(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = FixtureAdapter(handler);

const _usageResponse = {
  'plan_type': 'plus',
  'rate_limit': {
    'allowed': true,
    'limit_reached': false,
    'primary_window': {
      'used_percent': 23,
      'limit_window_seconds': 18000,
      'reset_after_seconds': 3400,
      'reset_at': 1760000000,
    },
    'secondary_window': {
      'used_percent': 4,
      'limit_window_seconds': 604800,
      'reset_after_seconds': 120000,
      'reset_at': 1760500000,
    },
  },
  'credits': {'has_credits': true, 'unlimited': false, 'balance': '12.50'},
  'spend_control': null,
  'additional_rate_limits': null,
};

void main() {
  group('Quota parsing', () {
    test('reads the documented Codex payload', () {
      final quota = parseChatGptQuota(_usageResponse);
      expect(quota.planType, 'plus');
      expect(quota.allowed, isTrue);
      expect(quota.limitReached, isFalse);
      expect(quota.primary!.usedPercent, 23);
      expect(quota.primary!.windowSeconds, 18000);
      expect(quota.primary!.resetAfterSeconds, 3400);
      expect(
        quota.primary!.resetAt,
        DateTime.fromMillisecondsSinceEpoch(1760000000 * 1000),
      );
      expect(quota.secondary!.usedPercent, 4);
      expect(quota.creditBalance, '12.50');
      expect(quota.hasCredits, isTrue);
      expect(quota.unlimitedCredits, isFalse);
      expect(quota.hasWindows, isTrue);
    });

    test('missing sections stay unknown instead of failing', () {
      final quota = parseChatGptQuota({'plan_type': 'free'});
      expect(quota.planType, 'free');
      expect(quota.primary, isNull);
      expect(quota.secondary, isNull);
      expect(quota.creditBalance, isNull);
      expect(quota.hasWindows, isFalse);
      expect(quota.allowed, isTrue);

      final nullWindows = parseChatGptQuota({
        'plan_type': 'pro',
        'rate_limit': {'primary_window': null, 'secondary_window': null},
        'credits': null,
      });
      expect(nullWindows.hasWindows, isFalse);
    });

    test('numeric strings, clamping and string reset dates are tolerated', () {
      final quota = parseChatGptQuota({
        'plan_type': '',
        'rate_limit': {
          'allowed': false,
          'limit_reached': true,
          'primary_window': {
            'used_percent': '130',
            'limit_window_seconds': '18000',
            'reset_after_seconds': '60',
            'reset_at': '2026-11-10T09:00:00Z',
          },
        },
      });
      expect(quota.primary!.usedPercent, 100);
      expect(quota.primary!.windowSeconds, 18000);
      expect(quota.primary!.resetAt, DateTime.utc(2026, 11, 10, 9));
      expect(quota.limitReached, isTrue);
      expect(quota.allowed, isFalse);
      // A window without `used_percent` is not a reading.
      expect(
        parseChatGptQuota({
          'rate_limit': {
            'primary_window': {'limit_window_seconds': 18000},
          },
        }).primary,
        isNull,
      );
    });

    test('an unrecognized body is a typed failure', () {
      for (final body in [
        <String>['not', 'a', 'map'],
        42,
        null,
      ]) {
        expect(
          () => parseChatGptQuota(body),
          throwsA(
            isA<AiFailure>().having(
              (error) => error.code,
              'code',
              AppErrorCode.chatGPTReturnedAnUnrecognizedFormat,
            ),
          ),
        );
      }
    });
  });

  group('Quota request', () {
    test(
      'sends the token and the account identity to the Codex endpoint',
      () async {
        late RequestOptions seen;
        final auth = await _auth(
          _record(
            idToken: _token({
              'https://api.openai.com/auth': {
                'chatgpt_account_id': 'account-123',
                'chatgpt_plan_type': 'plus',
              },
            }),
          ),
        );
        final client = ChatGptUsageClient(
          auth: auth,
          client: _dio((request) {
            seen = request;
            return fixtureJson(_usageResponse);
          }),
        );
        final quota = await client.fetch();
        expect(seen.method, 'GET');
        expect(
          seen.uri.toString(),
          'https://chatgpt.com/backend-api/wham/usage',
        );
        expect(seen.headers['Authorization'], 'Bearer access-token');
        expect(seen.headers['ChatGPT-Account-Id'], 'account-123');
        expect(quota.primary!.usedPercent, 23);
      },
    );

    test('omits the account header when the token carries no claim', () async {
      late RequestOptions seen;
      final client = ChatGptUsageClient(
        auth: await _auth(_record()),
        client: _dio((request) {
          seen = request;
          return fixtureJson(_usageResponse);
        }),
      );
      await client.fetch();
      expect(seen.headers.containsKey('ChatGPT-Account-Id'), isFalse);
    });

    test('401 asks for a new sign-in, 403 reports plan limits', () async {
      Future<void> expectCode(int status, AppErrorCode code) async {
        final client = ChatGptUsageClient(
          auth: await _auth(_record()),
          client: _dio((_) => fixtureJson({'error': 'x'}, status: status)),
        );
        await expectLater(
          client.fetch(),
          throwsA(isA<AiFailure>().having((error) => error.code, 'code', code)),
        );
      }

      await expectCode(401, AppErrorCode.yourChatGPTSignInHas);
      await expectCode(403, AppErrorCode.chatGPTPlanAllowanceOrPermissions);
      await expectCode(429, AppErrorCode.tooManyRequestsTryAgain);
      await expectCode(500, AppErrorCode.theChatGPTRequestFailedCheck);
    });

    test('a transport failure never leaks the raw Dio message', () async {
      final client = ChatGptUsageClient(
        auth: await _auth(_record()),
        client: Dio()
          ..httpClientAdapter = FixtureAdapter(
            (request) => throw DioException(
              requestOptions: request,
              message: 'raw socket failure',
            ),
          ),
      );
      await expectLater(
        client.fetch(),
        throwsA(
          isA<AiFailure>()
              .having(
                (error) => error.code,
                'code',
                AppErrorCode.theChatGPTRequestFailedCheck,
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('raw socket failure')),
              ),
        ),
      );
    });

    test('a signed-out account cannot be queried', () async {
      final keys = MemoryKeyStore();
      final client = ChatGptUsageClient(
        auth: ChatGptAuth(keys, client: _dio((_) => fixtureJson({}))),
        client: _dio((_) => fixtureJson(_usageResponse)),
      );
      await expectLater(
        client.fetch(),
        throwsA(
          isA<AiFailure>().having(
            (error) => error.code,
            'code',
            AppErrorCode.signInUsingContinueWith,
          ),
        ),
      );
    });
  });

  group('Account identity', () {
    test('session falls back to the stored token claim', () async {
      final auth = await _auth(
        _record(
          idToken: _token({
            'https://api.openai.com/auth': {'chatgpt_account_id': 'claim-9'},
          }),
        ),
      );
      final session = await auth.session();
      expect(session.accessToken, 'access-token');
      expect(session.accountId, 'claim-9');
    });

    test('a stored account id wins over the token claim', () async {
      final auth = await _auth(
        _record(
          accountId: 'stored-1',
          idToken: _token({
            'https://api.openai.com/auth': {'chatgpt_account_id': 'claim-9'},
          }),
        ),
      );
      expect((await auth.session()).accountId, 'stored-1');
    });

    test('a malformed token yields no identity but keeps working', () async {
      final auth = await _auth(_record(idToken: 'not-a-jwt'));
      final session = await auth.session();
      expect(session.accountId, isEmpty);
      expect(session.accessToken, 'access-token');
    });
  });

  group('Quota panel', () {
    Widget host(Widget child) => MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

    ChatGptQuota quota({
      bool limitReached = false,
      String? credits,
      bool unlimited = false,
    }) => ChatGptQuota(
      planType: 'plus',
      allowed: !limitReached,
      limitReached: limitReached,
      fetchedAt: DateTime(2026, 11, 10, 9, 5),
      creditBalance: credits,
      unlimitedCredits: unlimited,
      primary: ChatGptQuotaWindow(
        usedPercent: 23,
        windowSeconds: 18000,
        resetAfterSeconds: 3600,
        resetAt: DateTime.now().add(const Duration(minutes: 60)),
      ),
      secondary: ChatGptQuotaWindow(
        usedPercent: 4,
        windowSeconds: 604800,
        resetAfterSeconds: 86400 * 2,
        resetAt: DateTime.now().add(const Duration(days: 2)),
      ),
    );

    testWidgets('shows both windows, the plan and the credit balance', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: quota(credits: '12.50'),
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text('订阅类型：Plus'), findsOneWidget);
      expect(find.text('5 小时窗口 · 已用 23%'), findsOneWidget);
      expect(find.text('7 天窗口 · 已用 4%'), findsOneWidget);
      expect(find.text('剩余额度 12.50'), findsOneWidget);
      expect(find.text('查询于 2026-11-10 09:05'), findsOneWidget);
      expect(find.textContaining('未公开接口'), findsOneWidget);
    });

    testWidgets('calls out a used-up window and unlimited credits', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: quota(limitReached: true, unlimited: true),
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.textContaining('已达上限'), findsOneWidget);
      expect(find.text('额度不限。'), findsOneWidget);
    });

    testWidgets('asks for a check and localizes failures', (tester) async {
      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: null,
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.byTooltip('查询额度'), findsOneWidget);

      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: null,
            loading: false,
            failure: const AiFailure.localized(
              AppErrorCode.yourChatGPTSignInHas,
              'raw provider text',
            ),
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text('ChatGPT 登录已失效，请重新登录。'), findsOneWidget);
      expect(find.textContaining('raw provider text'), findsNothing);
    });

    test('plan labels capitalize the server word', () {
      expect(planLabel('plus'), 'Plus');
      expect(planLabel('pro'), 'Pro');
      expect(planLabel('enterprise'), 'Enterprise');
      expect(planLabel(''), '');
    });
  });
}
