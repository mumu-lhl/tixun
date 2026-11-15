import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/app/app.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/ai/chatgpt/auth.dart';
import 'package:tixun/core/ai/chatgpt/usage.dart';
import 'package:tixun/core/ai/provider_balance.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';

import 'support/chatgpt_fixture.dart';

class _Auth extends ChatGptAuth {
  _Auth(super.keys);
  @override
  Future<List<ChatGptModel>> models() async =>
      throw StateError('catalog offline');
}

class _Controller extends AppController {
  _Controller(Directory root, {super.demo = false})
    : super(
        AppDatabase.memory(),
        AttachmentStore(root),
        MemoryKeyStore(),
        MockChatProvider(),
      );

  int balanceRequests = 0, quotaRequests = 0;
  Future<void> pending = Future.value();
  bool fail = false;
  Dio http(ResponseBody Function() response) =>
      Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = FixtureAdapter((_) => response());
  late final _auth = _Auth(keys);
  @override
  ChatGptAuth get chatGpt => _auth; // Catalog failure must not block quota.
  late final balanceClient = ProviderBalanceClient(
    client: http(() {
      balanceRequests++;
      return fixtureJson({
        'is_available': true,
        'balance_infos': [
          {
            'currency': 'CNY',
            'total_balance': '42.00',
            'granted_balance': '0.00',
            'topped_up_balance': '42.00',
          },
        ],
      }, status: fail ? 500 : 200);
    }),
  );
  late final usageClient = ChatGptUsageClient(
    auth: chatGpt,
    client: http(() {
      quotaRequests++;
      return fixtureJson({
        'plan_type': 'plus',
        'rate_limit': {
          'primary_window': {'used_percent': 23, 'limit_window_seconds': 18000},
        },
      }, status: fail ? 500 : 200);
    }),
  );

  @override
  Future<ProviderBalance?> cachedProviderBalance(
    ProviderConfig candidate,
  ) async => balanceClient.cached(
    baseUrl: candidate.baseUrl,
    apiKey: await keys.read(providerKeyId(candidate)) ?? '',
  );
  @override
  Future<ProviderBalance> providerBalance(
    ProviderConfig candidate, {
    String? key,
    ProviderBalanceClient? client,
    bool refresh = false,
  }) {
    final result = super.providerBalance(
      candidate,
      key: key,
      client: client ?? balanceClient,
      refresh: refresh,
    );
    pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  @override
  ChatGptQuota? get cachedChatGptQuota => usageClient.cached;
  @override
  Future<ChatGptQuota> chatGptQuota({
    ChatGptUsageClient? client,
    bool refresh = false,
  }) {
    final result = super.chatGptQuota(
      client: client ?? usageClient,
      refresh: refresh,
    );
    pending = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }
}

void main() {
  for (final service in ['DeepSeek', 'ChatGPT', 'demo', 'disconnected']) {
    testWidgets(
      '$service page entry uses cache; refresh is explicit and failures preserve data',
      (tester) async {
        late Directory root;
        late _Controller c;
        await tester.runAsync(() async {
          root = await Directory.systemTemp.createTemp('account-settings');
          c = _Controller(root, demo: service == 'demo');
          await c.initialize(seed: false);
          if (service != 'disconnected') {
            await c.keys.write(providerKeyId(c.config), 'fixture-key');
            await c.keys.write(
              ChatGptAuth.storageKey,
              jsonEncode({
                'version': 1,
                'active': 'test:user',
                'accounts': [
                  {
                    'client_id': 'test',
                    'sub': 'user',
                    'access_token': 'fixture-token',
                    'refresh_token': 'fixture-refresh',
                    'scopes': ['resource.invoke', 'chatgpt.tokens.use.direct'],
                    'expires_at': DateTime.now()
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                  },
                ],
              }),
            );
          }
        });
        final scope = ProviderContainer(
          overrides: [appControllerProvider.overrideWith((_) => c)],
        );
        addTearDown(() async {
          scope.dispose();
          await c.db.close();
          await root.delete(recursive: true);
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(
          UncontrolledProviderScope(container: scope, child: const TixunApp()),
        );
        Future<void> open(String path) async {
          await tester.runAsync(() async {
            scope.read(routerProvider).go(path);
            await tester.pump();
            await c.pending;
            await tester.pumpAndSettle();
          });
          await tester.pumpAndSettle();
        }

        if (service == 'demo' || service == 'disconnected') {
          await open('/settings/ai');
          await open('/settings/chatgpt');
          expect(c.balanceRequests, 0);
          expect(c.quotaRequests, 0);
        } else {
          final balance = service == 'DeepSeek';
          final path = balance ? '/settings/ai' : '/settings/chatgpt';
          int requests() => balance ? c.balanceRequests : c.quotaRequests;
          await open(path);
          expect(requests(), 1);
          await open('/settings');
          await open(path);
          expect(requests(), 1);
          c.fail = true;
          final refresh = find.byKey(
            Key(balance ? 'provider-balance-refresh' : 'chatgpt-quota-refresh'),
          );
          await tester.ensureVisible(refresh);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(refresh);
            await c.pending;
            await tester.pumpAndSettle();
          });
          await tester.pumpAndSettle();
          expect(requests(), 2);
          expect(
            find.text(balance ? '可用余额 ¥42.00' : '5 小时窗口 · 已用 23%'),
            findsOneWidget,
          );
          expect(find.text('上次查询结果，可能已过期。'), findsOneWidget);
          if (balance) {
            // Editing a key hides the old account immediately, without querying the draft.
            final keyInput = find.byWidgetPredicate(
              (widget) => widget is TextField && widget.obscureText,
            );
            await tester.ensureVisible(keyInput);
            await tester.enterText(keyInput, 'unsaved-key');
            await tester.pump();
            expect(find.text('可用余额 ¥42.00'), findsNothing);
            expect(requests(), 2);
            await open('/settings'); // Dispose the form and its autosave timer.
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
