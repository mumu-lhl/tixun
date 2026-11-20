import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/provider_balance.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/l10n/app_strings.dart";
import "package:tixun/core/l10n/generated/app_localizations.dart";
import "package:tixun/core/platform/attachment_store.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/features/settings/provider_balance_panel.dart";

import "support/chatgpt_fixture.dart";

ProviderConfig _config({
  String kind = "deepseek",
  String baseUrl = "https://api.deepseek.com",
}) => ProviderConfig(
  id: 1,
  kind: kind,
  baseUrl: baseUrl,
  model: "deepseek-flash",
  vision: true,
  supportsTools: true,
  thinking: false,
  supportsThinking: true,
  effort: "high",
);

Dio _dio(FutureOr<ResponseBody> Function(RequestOptions) handler) =>
    Dio(BaseOptions(validateStatus: (_) => true))
      ..httpClientAdapter = FixtureAdapter(handler);

ResponseBody _json(Object data, {int status = 200}) =>
    fixtureJson(data, status: status);

void main() {
  group("DeepSeek balance parsing", () {
    test("reads every documented field", () {
      final balance = parseDeepSeekBalance({
        "is_available": true,
        "balance_infos": [
          {
            "currency": "CNY",
            "total_balance": "110.00",
            "granted_balance": "10.00",
            "topped_up_balance": "100.00",
          },
          {
            "currency": "USD",
            "total_balance": "3.50",
            "granted_balance": "0.00",
            "topped_up_balance": "3.50",
          },
        ],
        "something_new": "ignored",
      });
      expect(balance.available, isTrue);
      expect(balance.lines, hasLength(2));
      final cny = balance.lines.first;
      expect(cny.currency, "CNY");
      expect(cny.total, "110.00");
      expect(cny.granted, "10.00");
      expect(cny.toppedUp, "100.00");
      expect(balance.lines.last.currency, "USD");
    });

    test("an unusable account still reports its figures", () {
      final balance = parseDeepSeekBalance({
        "is_available": false,
        "balance_infos": [
          {
            "currency": "CNY",
            "total_balance": "0.00",
            "granted_balance": "0.00",
            "topped_up_balance": "0.00",
          },
        ],
      });
      expect(balance.available, isFalse);
      expect(balance.lines.single.total, "0.00");
    });

    test("missing or malformed rows are skipped, not fatal", () {
      expect(parseDeepSeekBalance(null).lines, isEmpty);
      expect(parseDeepSeekBalance("nonsense").lines, isEmpty);
      expect(parseDeepSeekBalance({"is_available": true}).lines, isEmpty);
      final balance = parseDeepSeekBalance({
        "is_available": true,
        "balance_infos": [
          {"total_balance": "1.00"},
          "not-an-object",
          {"currency": "CNY", "total_balance": 12.5},
        ],
      });
      expect(balance.lines, hasLength(1));
      expect(balance.lines.single.total, "12.5");
    });
  });

  group("DeepSeek balance request", () {
    test("calls the documented endpoint with the bearer key", () async {
      late RequestOptions seen;
      final client = ProviderBalanceClient(
        client: _dio((request) {
          seen = request;
          return _json({
            "is_available": true,
            "balance_infos": [
              {
                "currency": "CNY",
                "total_balance": "42.00",
                "granted_balance": "2.00",
                "topped_up_balance": "40.00",
              },
            ],
          });
        }),
      );
      final balance = await client.deepSeek(
        baseUrl: "https://api.deepseek.com/",
        apiKey: " sk-test ",
      );
      expect(seen.method, "GET");
      expect(seen.uri.toString(), "https://api.deepseek.com/user/balance");
      expect(seen.headers["Authorization"], "Bearer sk-test");
      expect(balance.lines.single.total, "42.00");
    });

    test(
      "cache is scoped to normalized endpoint and key, with explicit refresh",
      () async {
        var calls = 0;
        final client = ProviderBalanceClient(
          client: _dio((_) {
            calls++;
            return _json({"is_available": true, "balance_infos": []});
          }),
        );
        Future<ProviderBalance> read(
          String key, {
          String base = "https://api.deepseek.com",
          bool refresh = false,
        }) => client.deepSeek(baseUrl: base, apiKey: key, refresh: refresh);
        final first = await read("first");
        expect(
          await read(" first ", base: "https://api.deepseek.com/"),
          same(first),
        );
        expect(calls, 1);
        await read("first", refresh: true);
        await read("second");
        await read("second", base: "https://other.example");
        expect(calls, 4);
        expect(
          client.cached(baseUrl: "https://api.deepseek.com", apiKey: ""),
          isNull,
        );
      },
    );

    test("an unauthorized key is reported as an invalid key", () async {
      final client = ProviderBalanceClient(
        client: _dio((_) => _json({"error": "unauthorized"}, status: 401)),
      );
      await expectLater(
        client.deepSeek(baseUrl: "https://api.deepseek.com", apiKey: "bad"),
        throwsA(
          isA<AiFailure>().having(
            (error) => error.code,
            "code",
            AppErrorCode.theAPIKeyIsInvalid,
          ),
        ),
      );
    });

    test("rate limits and server errors stay distinguishable", () async {
      Future<void> expectCode(int status, AppErrorCode code) async {
        final client = ProviderBalanceClient(
          client: _dio((_) => _json({"error": "x"}, status: status)),
        );
        await expectLater(
          client.deepSeek(baseUrl: "https://api.deepseek.com", apiKey: "k"),
          throwsA(isA<AiFailure>().having((error) => error.code, "code", code)),
        );
      }

      await expectCode(429, AppErrorCode.tooManyRequestsTryAgain);
      await expectCode(500, AppErrorCode.theConnectionFailedOrThe);
    });

    test("a transport error never surfaces a raw Dio message", () async {
      final client = ProviderBalanceClient(
        client: Dio()
          ..httpClientAdapter = FixtureAdapter(
            (request) => throw DioException(
              requestOptions: request,
              message: "raw socket failure",
            ),
          ),
      );
      await expectLater(
        client.deepSeek(baseUrl: "https://api.deepseek.com", apiKey: "k"),
        throwsA(
          isA<AiFailure>().having(
            (error) => error.code,
            "code",
            AppErrorCode.theConnectionFailedOrThe,
          ),
        ),
      );
    });

    test("an empty key is refused before any request", () async {
      var called = false;
      final client = ProviderBalanceClient(
        client: _dio((_) {
          called = true;
          return _json({});
        }),
      );
      await expectLater(
        client.deepSeek(baseUrl: "https://api.deepseek.com", apiKey: "  "),
        throwsA(
          isA<AiFailure>().having(
            (error) => error.code,
            "code",
            AppErrorCode.saveAnAPIKeyBeforeQueryingTheBalance,
          ),
        ),
      );
      expect(called, isFalse);
    });
  });

  group("Controller balance lookup", () {
    late AppController controller;
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp("tixun-balance");
      controller = AppController(
        AppDatabase.memory(),
        AttachmentStore(dir),
        MemoryKeyStore(),
        MockChatProvider(),
        demo: true,
      );
      await controller.initialize();
    });

    tearDown(() async {
      await controller.shutdown();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test("uses the key being typed without saving it", () async {
      final client = ProviderBalanceClient(
        client: _dio((request) {
          expect(request.headers["Authorization"], "Bearer typed-key");
          return _json({
            "is_available": true,
            "balance_infos": [
              {
                "currency": "CNY",
                "total_balance": "5.00",
                "granted_balance": "0.00",
                "topped_up_balance": "5.00",
              },
            ],
          });
        }),
      );
      final balance = await controller.providerBalance(
        _config(),
        key: "typed-key",
        client: client,
      );
      expect(balance.lines.single.total, "5.00");
      expect(await controller.hasApiKey(_config()), isFalse);
    });

    test("falls back to the stored key", () async {
      await controller.keys.write(providerKeyId(_config()), "saved-key");
      final client = ProviderBalanceClient(
        client: _dio((request) {
          expect(request.headers["Authorization"], "Bearer saved-key");
          return _json({"is_available": true, "balance_infos": []});
        }),
      );
      final balance = await controller.providerBalance(
        _config(),
        client: client,
      );
      expect(balance.available, isTrue);
      expect(balance.lines, isEmpty);
    });

    test("other providers have no documented balance endpoint", () async {
      await expectLater(
        controller.providerBalance(_config(kind: "compatible")),
        throwsA(isA<AiFailure>()),
      );
    });
  });

  group("Balance panel", () {
    Widget host(Widget child) => MaterialApp(
      locale: const Locale("zh"),
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: Scaffold(body: child),
    );

    ProviderBalance balance({bool available = true}) => ProviderBalance(
      available: available,
      fetchedAt: DateTime(2026, 11, 10, 9, 5),
      lines: const [
        ProviderBalanceLine(
          currency: "CNY",
          total: "42.00",
          granted: "2.00",
          toppedUp: "40.00",
        ),
      ],
    );

    testWidgets("shows the amount, the breakdown and the check time", (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ProviderBalancePanel(
            balance: balance(),
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text("可用余额 ¥42.00"), findsOneWidget);
      expect(find.text("赠金 ¥2.00 · 充值 ¥40.00"), findsOneWidget);
      expect(find.text("查询于 2026-11-10 09:05"), findsOneWidget);
    });

    testWidgets("asks for a check before the first result", (tester) async {
      await tester.pumpWidget(
        host(
          ProviderBalancePanel(
            balance: null,
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.byTooltip("查询余额"), findsOneWidget);
      expect(find.text("可用余额 ¥42.00"), findsNothing);
    });

    testWidgets("an unusable account is called out", (tester) async {
      await tester.pumpWidget(
        host(
          ProviderBalancePanel(
            balance: balance(available: false),
            loading: false,
            failure: null,
            onRefresh: () {},
          ),
        ),
      );
      expect(find.textContaining("账户当前不可用"), findsOneWidget);
    });

    testWidgets("a failure is localized instead of printed raw", (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ProviderBalancePanel(
            balance: null,
            loading: false,
            failure: const AiFailure.localized(
              AppErrorCode.theAPIKeyIsInvalid,
              "raw provider text",
            ),
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text("API Key 无效或没有访问权限，请检查设置。"), findsOneWidget);
      expect(find.textContaining("raw provider text"), findsNothing);
    });

    testWidgets("a failed refresh keeps the previous amount marked stale", (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ProviderBalancePanel(
            balance: balance(),
            loading: false,
            failure: const AiFailure.localized(
              AppErrorCode.theConnectionFailedOrThe,
              "offline",
            ),
            onRefresh: () {},
          ),
        ),
      );
      expect(find.text("可用余额 ¥42.00"), findsOneWidget);
      expect(find.text("上次查询结果，可能已过期。"), findsOneWidget);
    });

    test("formats the currency it was given", () {
      const line = ProviderBalanceLine(
        currency: "CHF",
        total: "1",
        granted: "0",
        toppedUp: "1",
      );
      expect(balanceAmount(line, "1.00"), "CHF 1.00");
      expect(
        balanceAmount(
          const ProviderBalanceLine(
            currency: "USD",
            total: "1",
            granted: "0",
            toppedUp: "1",
          ),
          "1.00",
        ),
        r"$1.00",
      );
    });
  });
}
