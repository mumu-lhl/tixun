import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:archive/archive_io.dart";
import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:jose/jose.dart";
import "package:tixun/app/controller.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/ai/chatgpt/auth.dart";
import "package:tixun/core/ai/chatgpt/responses.dart";
import "package:tixun/core/database/database.dart";
import "package:tixun/core/backup/backup_service.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/platform/attachment_store.dart";

import "support/chatgpt_fixture.dart";

part "chatgpt_responses_cases.dart";

const config = ProviderConfig(
  id: 1,
  kind: "chatgpt",
  baseUrl: chatGptResource,
  model: "fixture-vision",
  reasoningLevels: '["low","medium","high","xhigh","max"]',
  vision: true,
  thinking: true,
  supportsThinking: true,
  supportsTools: true,
  effort: "high",
);

void main() {
  test("PKCE loopback sign-in verifies identity, isolates tokens and reuses host/client registration", () async {
    final f = ChatGptFixture();
    final first = await f.auth.signIn();
    expect(first.subject, "student");
    expect(f.callbackStatuses, [400, 200]);
    final authorization = f.authorization!;
    expect(authorization.host, "auth.openai.com");
    expect(authorization.queryParameters["client_id"], "dynamic_agent_client");
    final exchange =
        f.requests.firstWhere((r) => r.path.endsWith("/oauth/token")).data
            as Map;
    expect(exchange["client_id"], "oaiapp_fixture");
    expect(
      exchange["redirect_uri"],
      authorization.queryParameters["redirect_uri"],
    );
    expect(
      base64UrlEncode(
        sha256.convert(ascii.encode(exchange["code_verifier"] as String)).bytes,
      ).replaceAll("=", ""),
      authorization.queryParameters["code_challenge"],
    );
    expect(await f.auth.accessToken(), "access-fixture");
    final models = await f.auth.models();
    expect(models.map((m) => m.id), ["fixture-text", "fixture-vision"]);
    expect(models.last.vision, true);
    await f.auth.signIn(accountId: first.id);
    expect(f.authorization!.queryParameters["client_id"], "oaiapp_fixture");
    expect(
      f.authorization!.queryParameters["ext_agent_host_id"],
      authorization.queryParameters["ext_agent_host_id"],
    );
    expect((await f.auth.snapshot()).accounts.length, 1);
    f.subject = "other-student";
    await expectLater(
      f.auth.signIn(accountId: first.id),
      throwsA(isA<AiFailure>()),
    );
    expect((await f.auth.snapshot()).accounts.single.subject, "student");
    await f.auth.signIn();
    expect((await f.auth.snapshot()).accounts.length, 2);
    await f.auth.select(first.id);
    expect((await f.auth.snapshot()).activeId, first.id);
    expect(await f.auth.signOut(first.id), true);
    expect(
      (await f.auth.snapshot()).accounts
          .firstWhere((a) => a.id == first.id)
          .connected,
      false,
    );
    await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
    expect(f.revocations, 1);
  });

  for (final failure in [
    "nonce",
    "issuer",
    "audience",
    "expiry",
    "signature",
    "scope",
  ]) {
    test("OAuth rejects invalid $failure without saving tokens", () async {
      final f = ChatGptFixture();
      switch (failure) {
        case "nonce":
          f.overrides["nonce"] = "wrong";
        case "issuer":
          f.overrides["iss"] = "https://attacker.invalid";
        case "audience":
          f.overrides["aud"] = "different-client";
        case "expiry":
          f.overrides["exp"] = 1;
        case "signature":
          f.alternativeSigningKey = JsonWebKey.generate("RS256");
        case "scope":
          f.denyScope = true;
      }
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      expect((await f.auth.snapshot()).accounts, isEmpty);
      expect(
        await f.keys.read(ChatGptAuth.storageKey),
        isNot(contains("access-fixture")),
      );
    });
  }

  test("Rotating refresh is serialized and sign-out reports failed remote revocation", () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    final values = await Future.wait([
      f.auth.accessToken(),
      f.auth.accessToken(),
      f.auth.accessToken(),
    ]);
    expect(values, everyElement("refreshed-fixture"));
    expect(f.refreshes, 1);
    final stored = await f.keys.read(ChatGptAuth.storageKey);
    expect(stored, contains("rotated-fixture"));
    final refresh = f.requests.first.data as Map;
    expect(refresh["client_id"], "oaiapp_fixture");
    expect(refresh.containsKey("scope"), false);
    f.failRevocation = true;
    expect(await f.auth.signOut("oaiapp_fixture:student"), false);
    expect((await f.auth.snapshot()).accounts.single.connected, false);
  });

  test("Cancelling browser authorization closes the listener and permits another attempt", () async {
    final f = ChatGptFixture();
    final started = Completer<void>();
    final auth = ChatGptAuth(
      f.keys,
      client: f.dio,
      openBrowser: (_) async {
        started.complete();
        return true;
      },
    );
    final login = auth.signIn();
    final expectation = expectLater(login, throwsA(isA<AiFailure>()));
    await started.future;
    auth.cancelLogin();
    await expectation;
    expect(auth.signingIn, false);
    expect((await f.auth.snapshot()).accounts, isEmpty);
    await f.auth.signIn();
    expect((await f.auth.snapshot()).accounts.single.connected, true);
  });

  _responsesCases();

  test(
    "Corrupt ChatGPT login records report as unreadable instead of raw errors",
    () async {
      final keys = MemoryKeyStore();
      final auth = ChatGptAuth(keys);
      for (final raw in [
        "{not json",
        '{"version":1,"accounts":["oops"]}',
        '{"version":1,"accounts":[{"sub":"no-client"}]}',
        '{"version":1,"accounts":{}}',
      ]) {
        await keys.write(ChatGptAuth.storageKey, raw);
        await expectLater(
          auth.snapshot(),
          throwsA(
            isA<AiFailure>().having(
              (e) => e.message,
              "message",
              contains("登录记录无法读取"),
            ),
          ),
        );
      }
      await keys.write(
        ChatGptAuth.storageKey,
        jsonEncode({"version": 1, "accounts": []}),
      );
      expect((await auth.snapshot()).accounts, isEmpty);
    },
  );

  test("An in-flight refresh cannot restore tokens after sign-out", () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    f.refreshGate = Completer<void>();
    final refresh = f.auth.accessToken();
    final expectation = expectLater(refresh, throwsA(isA<AiFailure>()));
    while (f.refreshes == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await f.auth.signOut("oaiapp_fixture:student");
    f.refreshGate!.complete();
    await expectation;
    expect((await f.auth.snapshot()).accounts.single.connected, false);
  });
  test("Backups include provider settings but exclude OAuth tokens and require sign-in on another device", () async {
    final f = ChatGptFixture();
    await f.seed();
    final parent = await Directory.systemTemp.createTemp(
      "tixun-chatgpt-backup",
    );
    final root = Directory("${parent.path}/app");
    var c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: f.keys,
      chatProvider: RoutedChatProvider(f.auth),
    );
    await c.saveSettings(config, null);
    final archive = File("${parent.path}/learning.tixun-backup");
    await BackupService.export(c.db, c.files, archive);
    final contents = ZipDecoder().decodeBytes(await archive.readAsBytes());
    for (final file in contents.files.where((f) => f.isFile)) {
      final bytes = latin1.decode(file.content);
      expect(bytes, isNot(contains("access-fixture")));
      expect(bytes, isNot(contains("refresh-fixture")));
    }
    final prepared = await BackupService.prepare(archive, root);
    await c.shutdown();
    final activation = await BackupService.activate(prepared, root);
    c = await AppController.openRoot(
      root,
      demo: false,
      keyStore: MemoryKeyStore(),
    );
    await BackupService.finish(activation);
    await prepared.discard();
    expect(c.config.kind, "chatgpt");
    expect((await c.chatGpt.snapshot()).accounts, isEmpty);
    await expectLater(
      c.testConnection(c.config, null),
      throwsA(isA<AiFailure>()),
    );
    await c.shutdown();
    await parent.delete(recursive: true);
  });
  test(
    "Sign-out invalidates local credentials before remote revocation finishes",
    () async {
      final f = ChatGptFixture();
      await f.seed();
      f.revokeGate = Completer<void>();
      final logout = f.auth.signOut("oaiapp_fixture:student");
      while (f.revocations == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect((await f.auth.snapshot()).accounts.single.connected, false);
      await expectLater(f.auth.accessToken(), throwsA(isA<AiFailure>()));
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      f.revokeGate!.complete();
      expect(await logout, true);
    },
  );
  test("Cancelling one token waiter is immediate and does not duplicate or cancel a shared refresh", () async {
    final f = ChatGptFixture();
    await f.seed(expired: true);
    f.refreshGate = Completer<void>();
    final cancel = CancelToken();
    final first = f.auth.accessToken(cancel: cancel);
    final stopped = expectLater(first, throwsA(isA<DioException>()));
    final second = f.auth.accessToken();
    while (f.refreshes == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    cancel.cancel();
    await stopped.timeout(const Duration(seconds: 1));
    final third = f.auth.accessToken();
    f.refreshGate!.complete();
    expect(
      await Future.wait([second, third]),
      everyElement("refreshed-fixture"),
    );
    expect(f.refreshes, 1);
  });
  test("JWT header keys and key URLs are rejected even when attacker signs with the embedded key", () async {
    for (final field in ["jwk", "jku", "x5u"]) {
      final f = ChatGptFixture();
      final attacker = JsonWebKey.generate("RS256");
      f.alternativeSigningKey = attacker;
      f.protectedHeaders[field] = field == "jwk"
          ? JsonWebKey.fromCryptoKeys(
              publicKey: attacker.cryptoKeyPair.publicKey,
            ).toJson()
          : "https://attacker.invalid/jwks";
      await expectLater(f.auth.signIn(), throwsA(isA<AiFailure>()));
      expect((await f.auth.snapshot()).accounts, isEmpty);
      expect(f.requests.every((r) => r.uri.host == "auth.openai.com"), true);
    }
  });
}
