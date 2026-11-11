import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../ai/ai_types.dart';
import '../database/database.dart';
import 'python_runtime.dart';

const pythonPolicyKey = 'python_execution_policy';
final pythonToolSchema = AiTool(
  name: 'run_python',
  description: 'Execute Python code locally for calculations or checking answers. Standard library, SymPy and mpmath are available. Use print() to return results. The app may ask the user to approve the exact code. Files persist in WORKSPACE. This is unrestricted Python, not a sandbox. A computed result verifies only the supplied mathematical model, not the whole question. Do not use code to bypass application approval for study-data edits.',
  parameters: {
    'type': 'object',
    'additionalProperties': false,
    'properties': {
      'code': {'type': 'string', 'maxLength': 64000},
      'purpose': {'type': 'string', 'maxLength': 500},
      'timeout_seconds': {'type': 'integer', 'minimum': 1, 'maximum': 120},
    },
    'required': ['code', 'purpose'],
  },
);

typedef RunPython = Future<Map<String, dynamic>> Function({
  required String code,
  required Directory workspace,
  required int timeoutSeconds,
  required CancelToken cancel,
});

class PythonTool {
  PythonTool(this.db, this.root, {RunPython? execute})
    : execute = execute ?? PythonRuntime.instance.execute;
  final AppDatabase db;
  final Directory root;
  final RunPython execute;

  Future<Map<String, dynamic>> run(
    ToolCall call, {
    required String sessionId,
    required String runId,
    required CancelToken cancel,
    required Future<bool> Function(String, Map<String, dynamic>) confirm,
  }) async {
    final policy = await db.preference(pythonPolicyKey) ?? 'ask';
    if (!['ask', 'auto'].contains(policy)) {
      return {'ok': false, 'error': 'Python 执行已关闭。'};
    }
    Map<String, dynamic> args;
    try {
      args = (jsonDecode(call.arguments) as Map).cast<String, dynamic>();
      if (args.keys.any(
            (k) => !['code', 'purpose', 'timeout_seconds'].contains(k),
          ) ||
          args['code'] is! String ||
          (args['code'] as String).trim().isEmpty ||
          (args['code'] as String).length > 64000 ||
          args['purpose'] is! String ||
          (args['purpose'] as String).trim().isEmpty ||
          (args['purpose'] as String).length > 500 ||
          (args.containsKey('timeout_seconds') &&
              (args['timeout_seconds'] is! int ||
                  (args['timeout_seconds'] as int) < 1 ||
                  (args['timeout_seconds'] as int) > 120))) {
        throw const FormatException();
      }
    } catch (_) {
      return {'ok': false, 'error': 'Python 工具参数无效。'};
    }
    cancel.checkCancelled();
    final fingerprint = sha256
        .convert(utf8.encode(jsonEncode([runId, args['code']])))
        .toString();
    final id = 'python:$fingerprint';
    final existing = await (db.select(
      db.aiToolOperations,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing != null) {
      return {
        'ok': false,
        'error': '这段代码本轮已处理，不会重复执行。',
        if (existing.result != null)
          'previous_result': jsonDecode(existing.result!),
      };
    }
    await db
        .into(db.aiToolOperations)
        .insert(
          AiToolOperationsCompanion.insert(
            id: id,
            runId: runId,
            sessionId: sessionId,
            name: 'run_python',
            status: 'pending',
            arguments: jsonEncode(args),
            createdAt: DateTime.now(),
          ),
        );
    Future<void> save(String status, Map<String, dynamic> result) async {
      await (db.update(
        db.aiToolOperations,
      )..where((t) => t.id.equals(id))).write(
        AiToolOperationsCompanion(
          status: Value(status),
          result: Value(jsonEncode(result)),
        ),
      );
    }

    Map<String, dynamic>? completedResult;
    try {
      if (policy != 'auto' && !await confirm('run_python', args)) {
        final result = {'ok': false, 'error': '用户未允许运行，代码没有执行。'};
        await save('rejected', result);
        return result;
      }
      cancel.checkCancelled();
      await save('running', {'ok': false, 'running': true});
      final result = await execute(
        code: args['code'] as String,
        workspace: Directory(p.join(root.path, 'python-workspaces', sessionId)),
        timeoutSeconds: args['timeout_seconds'] as int? ?? 30,
        cancel: cancel,
      );
      completedResult = result;
      await save(
        result['running'] == true
            ? 'stop_requested'
            : result['ok'] == true
            ? 'succeeded'
            : 'failed',
        result,
      );
      return result;
    } catch (e) {
      if (completedResult != null) {
        final stillRunning = completedResult['running'] == true;
        final result = {
          ...completedResult,
          'ok': false,
          'execution_completed': !stillRunning,
          'error': stillRunning
              ? '已请求停止，但状态保存失败；代码可能仍在运行。'
              : '代码已执行，但执行记录保存异常；不要重复运行有副作用的代码。',
        };
        try {
          await save(
            stillRunning ? 'stop_requested' : 'recording_failed',
            result,
          );
        } catch (_) {}
        return result;
      }
      final result = {
        'ok': false,
        'error': e is DioException ? '已取消执行请求。' : 'Python 执行失败，请检查运行时或重启应用。',
      };
      await save('failed', result);
      if (e is DioException) rethrow;
      return result;
    }
  }
}
