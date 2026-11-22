import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:tixun/core/python/android_python_runtime.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory root;
  late Directory workspace;
  setUp(() async {
    root = await Directory.systemTemp.createTemp("android-python");
    workspace = Directory("${root.path}/python-workspaces/session");
    await workspace.create(recursive: true);
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(AndroidPythonRuntime.channel, null);
    await root.delete(recursive: true);
  });

  Future<Map<String, dynamic>> execute({CancelToken? cancel}) =>
      AndroidPythonRuntime.execute(
        code: "print(9)",
        workspace: workspace,
        timeoutSeconds: 10,
        cancel: cancel ?? CancelToken(),
      );

  Map<String, dynamic> response({Object? snapshot}) => {
    "ok": true,
    "stdout": "9\n",
    "stderr": "",
    "output_truncated": false,
    "workspace":
        snapshot ?? {"files": <String, String>{}, "directories": <String>[]},
  };

  test("passes bounded snapshot and persists validated output", () async {
    await File("${workspace.path}/input.txt").writeAsString("input");
    messenger.setMockMethodCallHandler(AndroidPythonRuntime.channel, (
      call,
    ) async {
      expect(call.method, "execute");
      final payload =
          jsonDecode((call.arguments as Map)["payload"] as String) as Map;
      expect((payload["workspace"] as Map)["files"], {"input.txt": "aW5wdXQ="});
      return jsonEncode(
        response(
          snapshot: {
            "files": {"result.txt": "b3V0cHV0"},
            "directories": <String>[],
          },
        ),
      );
    });
    expect((await execute())["ok"], true);
    expect(await File("${workspace.path}/input.txt").exists(), false);
    expect(await File("${workspace.path}/result.txt").readAsString(), "output");
  });

  test("rejects malicious output without writing outside workspace", () async {
    messenger.setMockMethodCallHandler(
      AndroidPythonRuntime.channel,
      (_) async => jsonEncode(
        response(
          snapshot: {
            "files": {"../../escape": "eA=="},
            "directories": <String>[],
          },
        ),
      ),
    );
    expect((await execute())["ok"], false);
    expect(await File("${root.path}/escape").exists(), false);
  });

  test(
    "maps native timeout without falling back to another interpreter",
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(AndroidPythonRuntime.channel, (
        _,
      ) async {
        calls++;
        throw PlatformException(code: "SANDBOX_TIMEOUT");
      });
      expect((await execute())["error"], contains("超时"));
      expect(calls, 1);
    },
  );

  test(
    "cancellation stops the matching isolated request and skips output sync",
    () async {
      final pending = Completer<String>();
      final started = Completer<void>();
      String? requestId;
      messenger.setMockMethodCallHandler(AndroidPythonRuntime.channel, (
        call,
      ) async {
        final args = call.arguments as Map;
        if (call.method == "execute") {
          requestId = args["requestId"] as String;
          started.complete();
          return pending.future;
        }
        expect(call.method, "cancel");
        expect(args["requestId"], requestId);
        pending.complete(
          jsonEncode(
            response(
              snapshot: {
                "files": {"cancelled.txt": "eA=="},
                "directories": <String>[],
              },
            ),
          ),
        );
        return null;
      });
      final token = CancelToken();
      final execution = execute(cancel: token);
      final assertion = expectLater(execution, throwsA(isA<DioException>()));
      await started.future;
      token.cancel();
      await assertion;
      expect(await File("${workspace.path}/cancelled.txt").exists(), false);
    },
  );

  test("missing native channel fails closed", () async {
    expect((await execute())["ok"], false);
  });
}
