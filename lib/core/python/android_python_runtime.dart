import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dio/dio.dart";
import "package:flutter/services.dart";
import "package:path/path.dart" as p;
import "package:uuid/uuid.dart";

import "../ai/ai_types.dart";
import "python_workspace_store.dart";

/// Only JSON and pipes cross into Android's permissionless isolated service.
class AndroidPythonRuntime {
  static const channel = MethodChannel("org.tixun/python_isolate");

  static Future<Map<String, dynamic>> execute({
    required String code,
    required Directory workspace,
    required int timeoutSeconds,
    required CancelToken cancel,
  }) async {
    final started = DateTime.now();
    final requestId = const Uuid().v4();
    var finished = false;
    try {
      cancel.checkCancelled();
      if (p.basename(workspace.parent.path) != "python-workspaces") {
        throw const FormatException("Invalid Python workspace");
      }
      final store = PythonWorkspaceStore(workspace.parent.parent);
      final snapshot = await store.snapshot(p.basename(workspace.path));
      cancel.checkCancelled();
      final execution = channel.invokeMethod<String>("execute", {
        "requestId": requestId,
        "timeoutSeconds": timeoutSeconds,
        "payload": jsonEncode({"code": code, "workspace": snapshot}),
      });
      unawaited(
        cancel.whenCancel.then((_) async {
          if (!finished) {
            try {
              await channel.invokeMethod<void>("cancel", {
                "requestId": requestId,
              });
            } on Exception {
              // A concurrently exiting service is already stopped.
            }
          }
        }),
      );
      final response = await execution;
      cancel.checkCancelled();
      final result = jsonDecode(response!) as Map<String, dynamic>;
      if (result["ok"] is! bool ||
          result["stdout"] is! String ||
          result["stderr"] is! String ||
          result["output_truncated"] is! bool ||
          (result["stdout"] as String).length > 32000 ||
          (result["stderr"] as String).length > 32000) {
        throw const FormatException("Invalid isolated Python result");
      }
      final output = result.remove("workspace");
      if (output != null) {
        await store.applySnapshot(p.basename(workspace.path), output);
      } else if (result["ok"] == true) {
        throw const FormatException("Missing workspace result");
      }
      if (result["ok"] == false) result["error"] = "Python 执行失败，详情见标准错误输出。";
      result["elapsed_ms"] = DateTime.now().difference(started).inMilliseconds;
      return result;
    } on DioException {
      rethrow;
    } on PlatformException catch (error) {
      cancel.checkCancelled();
      return {
        "ok": false,
        "error": error.code == "SANDBOX_TIMEOUT"
            ? "Python 执行超时，隔离进程已终止。"
            : "Python 沙盒启动失败：${error.message}",
        "elapsed_ms": DateTime.now().difference(started).inMilliseconds,
      };
    } catch (error) {
      cancel.checkCancelled();
      return {
        "ok": false,
        "error": "Python 沙盒执行失败：$error",
        "elapsed_ms": DateTime.now().difference(started).inMilliseconds,
      };
    } finally {
      finished = true;
    }
  }
}
