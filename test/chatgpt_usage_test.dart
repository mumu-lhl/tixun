import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/chatgpt/auth.dart";
import "package:tixun/core/ai/chatgpt/usage.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/settings/chatgpt_quota_panel.dart";

import "support/chatgpt_fixture.dart";

String _token(Map<String, dynamic> claims) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll("=", "");
  return '${part({'alg': 'RS256'})}.${part(claims)}.signature';
}

Map<String, dynamic> _record({
  String accountId = "",
  String plan = "",
  String? idToken,
  DateTime? expiresAt,
}) => {
  "client_id": "oaiapp_test",
  "sub": "user-1",
  "id_token": ?idToken,
  if (accountId.isNotEmpty) "account_id": accountId,
  if (plan.isNotEmpty) "plan_type": plan,
  "access_token": "access-token",
  "refresh_token": "refresh-token",
  "scopes": [
    "openid",
    "profile",
    "email",
    "offline_access",
    "resource.invoke",
    "chatgpt.tokens.use.direct",
  ],
  "expires_at": (expiresAt ?? DateTime.now().add(const Duration(hours: 1)))
      .toUtc()
      .toIso8601String(),
};

Future<ChatGptAuth> _auth(Map<String, dynamic> record, {Dio? client}) async {
  final keys = MemoryKeyStore();
  await keys.write(
    ChatGptAuth.storageKey,
    jsonEncode({
      "version": 1,
      "accounts": [record],
      "active": "oaiapp_test:user-1",
    }),
  );
  return ChatGptAuth(keys, client: client);
}

Dio _dio(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = FixtureAdapter(handler);

const _usageResponse = {
  "plan_type": "plus",
  "rate_limit": {
    "allowed": true,
    "limit_reached": false,
    "primary_window": {
      "used_percent": 23,
      "limit_window_seconds": 18000,
      "reset_after_seconds": 3400,
      "reset_at": 1760000000,
    },
    "secondary_window": {
      "used_percent": 4,
      "limit_window_seconds": 604800,
      "reset_after_seconds": 120000,
      "reset_at": 1760500000,
    },
  },
  "credits": {"has_credits": true, "unlimited": false, "balance": "12.50"},
  "spend_control": null,
  "additional_rate_limits": null,
};

void main() {
  group("Quota parsing", () {
    test("reads the documented Codex payload", () {
      final quota = parseChatGptQuota(_usageResponse);
      expect(quota.planType, "plus");
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
      expect(quota.creditBalance, "12.50");
      expect(quota.hasCredits, isTrue);
      expect(quota.unlimitedCredits, isFalse);
      expect(quota.hasWindows, isTrue);
    });

    test("missing sections stay unknown instead of failing", () {
      final quota = parseChatGptQuota({"plan_type": "free"});
      expect(quota.planType, "free");
      expect(quota.primary, isNull);
      expect(quota.secondary, isNull);
      expect(quota.creditBalance, isNull);
      expect(quota.hasWindows, isFalse);
      expect(quota.allowed, isTrue);

      final nullWindows = parseChatGptQuota({
        "plan_type": "pro",
        "rate_limit": {"primary_window": null, "secondary_window": null},
        "credits": null,
      });
      expect(nullWindows.hasWindows, isFalse);
    });

    test("numeric strings, clamping and string reset dates are tolerated", () {
      final quota = parseChatGptQuota({
        "plan_type": "",
        "rate_limit": {
          "allowed": false,
          "limit_reached": true,
          "primary_window": {
            "used_percent": "130",
            "limit_window_seconds": "18000",
            "reset_after_seconds": "60",
            "reset_at": "2026-11-10T09:00:00Z",
          },
        },
      });
      expect(quota.primary!.usedPercent, 100);
      expect(quota.primary!.windowSeconds, 18000);
      expect(quota.primary!.resetAt, DateTime.utc(2026, 11, 10, 9));
      expect(quota.limitReached, isTrue);
      expect(quota.allowed, isFalse);
      expect(
        parseChatGptQuota({
          "rate_limit": {
            "primary_window": {"limit_window_seconds": 18000},
          },
        }).primary,
        isNull,
      );
    });

    test("an unrecognized body is a typed failure", () {
      for (final body in [
        <String>["not", "a", "map"],
        42,
        null,
      ]) {
        expect(
          () => parseChatGptQuota(body),
          throwsA(
            isA<AiFailure>().having(
              (error) => error.code,
              "code",
              AppErrorCode.chatGPTReturnedAnUnrecognizedFormat,
            ),
          ),
        );
      }
    });
  });

  group("Quota request", () {
    test(
      "sends the token and the account identity to the Codex endpoint",
      () async {
        late RequestOptions seen;
        final auth = await _auth(
          _record(
            idToken: _token({
              "https://api.openai.com/auth": {
                "chatgpt_account_id": "account-123",
                "chatgpt_plan_type": "plus",
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
        expect(seen.method, "GET");
        expect(
          seen.uri.toString(),
          "https://chatgpt.com/backend-api/wham/usage",
        );
        expect(seen.headers["Authorization"], "Bearer access-token");
        expect(seen.headers["ChatGPT-Account-Id"], "account-123");
        expect(quota.primary!.usedPercent, 23);
      },
    );

    test("fresh quota is reused, refresh bypasses it, and account changes invalidate", () async {
      final keys = MemoryKeyStore();
      await keys.write(
        ChatGptAuth.storageKey,
        jsonEncode({
          "version": 1,
          "active": "oaiapp_test:user-1",
          "accounts": [
            _record(),
            {..._record(), "sub": "user-2", "access_token": "second-token"},
          ],
        }),
      );
      final auth = ChatGptAuth(keys, client: _dio((_) => fixtureJson({})));
      var calls = 0;
      final client = ChatGptUsageClient(
        auth: auth,
        client: _dio((_) {
          calls++;
          return fixtureJson(_usageResponse);
        }),
      );
      final first = await client.fetch();
      expect(await client.fetch(), same(first));
      expect(calls, 1);
      await client.fetch(refresh: true);
      expect(calls, 2);
      await auth.select("oaiapp_test:user-2");
      expect(client.cached, isNull);
      await client.fetch();
      expect(calls, 3);
      await auth.signOut("oaiapp_test:user-2");
      expect(client.cached, isNull);
      await expectLater(client.fetch(), throwsA(isA<AiFailure>()));
      expect(calls, 3);
    });

    test("an account change rejects a late quota response", () async {
      final auth = await _auth(_record());
      final response = Completer<ResponseBody>();
      final started = Completer<void>();
      final client = ChatGptUsageClient(
        auth: auth,
        client: _dio((_) {
          started.complete();
          return response.future;
        }),
      );
      final pending = client.fetch();
      final rejected = expectLater(pending, throwsA(isA<AiFailure>()));
      await started.future;
      await auth.select("oaiapp_test:user-1");
      response.complete(fixtureJson(_usageResponse));
      await rejected;
      expect(client.cached, isNull);
    });

    test("omits the account header when the token carries no claim", () async {
      late RequestOptions seen;
      final client = ChatGptUsageClient(
        auth: await _auth(_record()),
        client: _dio((request) {
          seen = request;
          return fixtureJson(_usageResponse);
        }),
      );
      await client.fetch();
      expect(seen.headers.containsKey("ChatGPT-Account-Id"), isFalse);
    });

    test("quota endpoint errors are independent of sign-in", () async {
      final auth = await _auth(_record());
      Future<void> expectCode(ResponseBody response, AppErrorCode code) async {
        final client = ChatGptUsageClient(
          auth: auth,
          client: _dio((_) => response),
        );
        await expectLater(
          client.fetch(),
          throwsA(isA<AiFailure>().having((error) => error.code, "code", code)),
        );
      }

      await expectCode(
        fixtureJson({"error": "x"}, status: 401),
        AppErrorCode.chatGptQuotaAccessDenied,
      );
      await expectCode(
        ResponseBody.fromString(
          "not JSON",
          403,
          headers: {
            "content-type": ["application/json"],
          },
        ),
        AppErrorCode.chatGptQuotaAccessDenied,
      );
      expect(await auth.accessToken(), "access-token");

      await expectCode(
        fixtureJson({"error": "x"}, status: 429),
        AppErrorCode.tooManyRequestsTryAgain,
      );
      await expectCode(
        fixtureJson({"error": "x"}, status: 500),
        AppErrorCode.theChatGPTRequestFailedCheck,
      );
    });

    test("a transport failure never leaks the raw Dio message", () async {
      final client = ChatGptUsageClient(
        auth: await _auth(_record()),
        client: Dio()
          ..httpClientAdapter = FixtureAdapter(
            (request) => throw DioException(
              requestOptions: request,
              message: "raw socket failure",
            ),
          ),
      );
      await expectLater(
        client.fetch(),
        throwsA(
          isA<AiFailure>()
              .having(
                (error) => error.code,
                "code",
                AppErrorCode.theChatGPTRequestFailedCheck,
              )
              .having(
                (error) => error.message,
                "message",
                isNot(contains("raw socket failure")),
              ),
        ),
      );
    });

    test("a signed-out account cannot be queried", () async {
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
            "code",
            AppErrorCode.signInUsingContinueWith,
          ),
        ),
      );
    });
  });

  group("Account identity", () {
    test("session falls back to the stored token claim", () async {
      final auth = await _auth(
        _record(
          idToken: _token({
            "https://api.openai.com/auth": {"chatgpt_account_id": "claim-9"},
          }),
        ),
      );
      final session = await auth.session();
      expect(session.accessToken, "access-token");
      expect(session.accountId, "claim-9");
    });

    test("a stored account id wins over the token claim", () async {
      final auth = await _auth(
        _record(
          accountId: "stored-1",
          idToken: _token({
            "https://api.openai.com/auth": {"chatgpt_account_id": "claim-9"},
          }),
        ),
      );
      expect((await auth.session()).accountId, "stored-1");
    });

    test("a malformed token yields no identity but keeps working", () async {
      final auth = await _auth(_record(idToken: "not-a-jwt"));
      final session = await auth.session();
      expect(session.accountId, isEmpty);
      expect(session.accessToken, "access-token");
    });
  });

  group("Quota panel", () {
    Widget host(Widget child) => MaterialApp(
      locale: const Locale("zh"),
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
      planType: "plus",
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

    testWidgets("shows both windows, the plan and the credit balance", (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: quota(credits: "12.50"),
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text("订阅类型：Plus"), findsOneWidget);
      expect(find.text("5 小时窗口 · 已用 23%"), findsOneWidget);
      expect(find.text("7 天窗口 · 已用 4%"), findsOneWidget);
      expect(find.text("剩余额度 12.50"), findsOneWidget);
      expect(find.text("查询于 2026-11-10 09:05"), findsOneWidget);
      expect(find.textContaining("未公开接口"), findsOneWidget);
    });

    testWidgets("calls out a used-up window and unlimited credits", (
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
      expect(find.textContaining("已达上限"), findsOneWidget);
      expect(find.text("额度不限。"), findsOneWidget);
    });

    testWidgets("asks for a check and localizes failures", (tester) async {
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
      expect(find.byTooltip("查询额度"), findsOneWidget);

      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: null,
            loading: false,
            failure: const AiFailure.localized(
              AppErrorCode.chatGptQuotaAccessDenied,
              "raw provider text",
            ),
            onRefresh: () {},
          ),
        ),
      );
      expect(find.textContaining("请在 ChatGPT 官方用量页查看"), findsOneWidget);
      expect(find.textContaining("请重新登录"), findsNothing);
      expect(find.textContaining("raw provider text"), findsNothing);
    });

    testWidgets("a failed refresh keeps the last quota marked stale", (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ChatGptQuotaPanel(
            quota: quota(),
            loading: false,
            failure: const AiFailure.localized(
              AppErrorCode.theChatGPTRequestFailedCheck,
              "offline",
            ),
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text("5 小时窗口 · 已用 23%"), findsOneWidget);
      expect(find.text("上次查询结果，可能已过期。"), findsOneWidget);
    });

    test("plan labels capitalize the server word", () {
      expect(planLabel("plus"), "Plus");
      expect(planLabel("pro"), "Pro");
      expect(planLabel("enterprise"), "Enterprise");
      expect(planLabel(""), "");
    });
  });
}
