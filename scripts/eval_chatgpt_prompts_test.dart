// Manual live evaluation only; excluded from the normal test directory.
// Console output is the progress interface of this opt-in CLI harness.
// ignore_for_file: avoid_print
import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:dio/io.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/platform/key_store.dart";
import "package:tixun/core/ai/chatgpt/auth.dart";
import "package:tixun/core/ai/chatgpt/responses.dart";
import "package:tixun/core/ai/chat_provider.dart";
import "package:tixun/core/database/database.dart";

class TiXunEvalKeys implements KeyStore {
  static const account = "org.tixun.tixun.secureStorage";
  Future<Map<String, dynamic>> load() async {
    final r = await Process.run("secret-tool", ["lookup", "account", account]);
    if (r.exitCode != 0) throw StateError("TiXun keyring unavailable");
    return Map<String, dynamic>.from(jsonDecode(r.stdout as String) as Map);
  }

  @override
  Future<String?> read(String provider) async {
    if (provider != ChatGptAuth.storageKey) {
      throw StateError("Wrong credential");
    }
    return (await load())["tixun.api.$provider"] as String?;
  }

  @override
  Future<void> write(String provider, String key) async {
    if (provider != ChatGptAuth.storageKey || key.isEmpty) {
      throw StateError("Unexpected write");
    }
    final data = await load();
    data["tixun.api.$provider"] = key;
    final p = await Process.start("secret-tool", [
      "store",
      "--label=TiXun secure storage",
      "account",
      account,
      "xdg:schema",
      "default",
    ]);
    p.stdin.write(jsonEncode(data));
    await p.stdin.close();
    await Future.wait([p.stdout.drain<void>(), p.stderr.drain<void>()]);
    if (await p.exitCode != 0 || await read(provider) != key) {
      throw StateError("Credential save failed");
    }
  }
}

Dio evalClient() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 120),
      followRedirects: false,
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: true);
      final ca = Platform.environment["NODE_EXTRA_CA_CERTS"];
      if (ca != null && ca.isNotEmpty) context.setTrustedCertificates(ca);
      final client = HttpClient(context: context);
      final proxy = Platform.environment["HTTPS_PROXY"];
      if (proxy != null && proxy.isNotEmpty) {
        final uri = Uri.parse(proxy);
        client.findProxy = (_) => "PROXY ${uri.host}:${uri.port}";
      }
      return client;
    },
  );
  // Log status only; neither credentials nor response error bodies are logged.
  dio.interceptors.add(
    InterceptorsWrapper(
      onError: (e, h) {
        print(
          "Transport failure: ${e.type.name}; HTTP ${e.response?.statusCode}",
        );
        h.next(e);
      },
    ),
  );
  return dio;
}

void main() {
  test("explicit live ChatGPT subscription A/B", () async {
    if (Platform.environment["TIXUN_LIVE_EVAL"] != "1") {
      fail("Requires TIXUN_LIVE_EVAL=1");
    }
    final directory = Platform.environment["EVAL_PLAN_DIR"];
    if (directory == null) fail("Requires EVAL_PLAN_DIR");
    final out = Directory(directory);
    final plan =
        jsonDecode(await File("${out.path}/plan.json").readAsString()) as Map;
    final settings = plan["config"] as Map;
    if (settings["provider"] != "chatgpt") fail("Wrong provider");
    final effort = settings["effort"] as String;
    final model = settings["model"] as String?;
    if (model == null || model.isEmpty) {
      fail("Requires explicit plan model");
    }
    final client = evalClient();
    final auth = ChatGptAuth(TiXunEvalKeys(), client: client);
    final provider = ChatGptResponses(auth, client: client);
    final config = ProviderConfig(
      id: 0,
      kind: "chatgpt",
      baseUrl: chatGptResource,
      model: model,
      vision: false,
      supportsTools: true,
      thinking: true,
      supportsThinking: true,
      effort: effort,
    );
    final jobs = (plan["jobs"] as List).cast<Map>();
    final pending = <Map>[];
    for (final job in jobs) {
      final name = job["id"] as String;
      if (!RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(name)) fail("Unsafe job id");
      final target = File("${out.path}/$name.json");
      if (await target.exists()) {
        final saved = jsonDecode(await target.readAsString()) as Map;
        if (saved["fingerprint"] != plan["fingerprint"]) {
          fail("Result mismatch");
        }
      } else {
        pending.add(job);
      }
    }
    final budget =
        int.tryParse(Platform.environment["EVAL_MAX_CALLS"] ?? "") ?? 0;
    if (pending.length > budget) fail("Pending calls exceed budget");
    if (pending.isEmpty) return;
    try {
      await auth.accessToken();
      print("TiXun subscription credential ready");
      for (final source in pending) {
        final name = source["id"] as String;
        final target = File("${out.path}/$name.json");
        // Reserve before sending: interrupted calls must not be silently replayed.
        await target.create(exclusive: true);
        await target.writeAsString(
          jsonEncode({"fingerprint": plan["fingerprint"], "completed": false}),
        );
        final instructions = source["instructions"] as String;
        final input = source["input"] as String;
        final request = AiRequest(
          instructions: instructions,
          messages: [AiMessage.user(input)],
        );
        final text = StringBuffer();
        var completed = false;
        AiTokenUsage? usage;
        final started = DateTime.now().toUtc();
        final watch = Stopwatch()..start();
        final cancel = CancelToken();
        await for (final chunk
            in provider.start(config).complete(request, cancel)) {
          text.write(chunk.text);
          completed |= chunk.completed;
          usage = chunk.usage ?? usage;
        }
        watch.stop();
        if (!completed) throw StateError("Missing completion for $name");
        var parsed = true;
        try {
          jsonDecode(text.toString());
        } catch (_) {
          parsed = false;
        }
        final record = {
          "case": source["case"],
          "variant": source["variant"],
          "timestamp": started.toIso8601String(),
          "model": model,
          "effort": effort,
          "fingerprint": plan["fingerprint"],
          "instructions": instructions,
          "input": input,
          "text": text.toString(),
          "completed": completed,
          "jsonParsed": parsed,
          "elapsedSeconds": watch.elapsedMilliseconds / 1000,
          "usage": {
            "inputTokens": usage?.inputTokens,
            "outputTokens": usage?.outputTokens,
            "cachedInputTokens": usage?.cachedInputTokens,
            "reasoningTokens": usage?.reasoningTokens,
            "totalTokens": usage?.totalTokens,
          },
        };
        await target.writeAsString(
          const JsonEncoder.withIndent("  ").convert(record),
        );
        print(
          'Completed $name: in=${usage?.inputTokens} out=${usage?.outputTokens} seconds=${record['elapsedSeconds']}',
        );
      }
    } catch (error) {
      if (error is AiFailure) print("Application failure code: ${error.code}");
      fail(
        "Live evaluation stopped; no automatic retry or credential fallback",
      );
    } finally {
      client.close(force: true);
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
