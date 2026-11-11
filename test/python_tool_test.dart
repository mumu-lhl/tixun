import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/ai_types.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/python/python_tool.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late String session;
  late PythonTool tool;
  var executions = 0, approvals = 0;
  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('python-tool-test');
    session = (await db.createSession()).id;
    executions = approvals = 0;
    tool = PythonTool(
      db,
      root,
      execute:
          ({
            required code,
            required workspace,
            required timeoutSeconds,
            required cancel,
          }) async {
            executions++;
            expect(code, contains('print'));
            expect(workspace.path, contains(session));
            return {'ok': true, 'stdout': '42\n', 'stderr': ''};
          },
    );
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });
  ToolCall code([String args = '{"code":"print(6*7)","purpose":"核对计算"}']) =>
      ToolCall('test', 'run_python', args);
  Future<Map<String, dynamic>> run(
    ToolCall call, {
    bool approve = true,
    CancelToken? token,
  }) => tool.run(
    call,
    sessionId: session,
    runId: 'run',
    cancel: token ?? CancelToken(),
    confirm: (_, args) async {
      approvals++;
      expect(args['code'], contains('print'));
      return approve;
    },
  );

  test(
    'Default policy reviews exact code before executing and persists output',
    () async {
      expect((await run(code()))['stdout'], '42\n');
      expect(executions, 1);
      expect(approvals, 1);
      final audit = (await db.select(db.aiToolOperations).get()).single;
      expect(audit.status, 'succeeded');
      expect(jsonDecode(audit.result!)['stdout'], '42\n');
      expect(jsonDecode(audit.arguments)['code'], 'print(6*7)');
      await run(code());
      expect(
        executions,
        1,
        reason: 'Duplicate code must not run twice in a turn',
      );
    },
  );
  test('Denial and disabled policy never execute', () async {
    expect((await run(code(), approve: false))['ok'], false);
    expect(executions, 0);
    await db.setPreference(pythonPolicyKey, 'off');
    await run(code());
    expect(executions, 0);
    expect(approvals, 1);
  });
  test('Explicit automatic permission skips review, not validation', () async {
    await db.setPreference(pythonPolicyKey, 'auto');
    expect((await run(code()))['ok'], true);
    expect(executions, 1);
    expect(approvals, 0);
    for (final invalid in [
      '{}',
      '{"code":3,"purpose":"test"}',
      '{"code":"print(1)","purpose":"p","timeout_seconds":999}',
      '{"code":"print(1)","purpose":"p","unknown":true}',
    ]) {
      expect((await run(code(invalid)))['ok'], false);
    }
    expect(executions, 1);
  });
  test('Cancellation after review prevents side effects', () async {
    final cancel = CancelToken();
    await expectLater(
      tool.run(
        code(),
        sessionId: session,
        runId: 'run',
        cancel: cancel,
        confirm: (_, args) async {
          cancel.cancel();
          return true;
        },
      ),
      throwsA(isA<DioException>()),
    );
    expect(executions, 0);
  });
  test(
    'An audit write failure never pretends the executed code had no effects',
    () async {
      await db.customStatement(
        "CREATE TRIGGER fail_python_success BEFORE UPDATE ON ai_tool_operations WHEN NEW.status='succeeded' BEGIN SELECT RAISE(ABORT, 'test disk failure'); END",
      );
      final result = await run(code());
      expect(executions, 1);
      expect(result['ok'], false);
      expect(result['execution_completed'], true);
      expect(result['error'], contains('已执行'));
      await run(code());
      expect(executions, 1);
    },
  );
}
