import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ai/ai_types.dart';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:serious_python/serious_python.dart';
import 'package:uuid/uuid.dart';

/// Native CPython in the application's process. Intentionally NOT a sandbox.
/// One interpreter is reused across controller restores; executions are serial.
class PythonRuntime {
  static final instance = PythonRuntime();
  Future<Directory>? _starting;
  bool _busy = false;
  Future<Directory> _start() => _starting ??= _boot().catchError((error) {
    _starting = null;
    throw error;
  });
  Future<Directory> _boot() async {
    final root = await Directory.systemTemp.createTemp('tixun-python-');
    final app = await SeriousPython.prepareApp();
    final failure = await SeriousPython.runProgram(
      p.join(app, 'main.py'),
      environmentVariables: {'TIXUN_PYTHON_ROOT': root.path},
    );
    if (failure != null) throw StateError(failure);
    final until = DateTime.now().add(const Duration(seconds: 30));
    while (!await File(p.join(root.path, 'ready')).exists()) {
      if (DateTime.now().isAfter(until)) {
        // Do not start a second interpreter after an ambiguous boot timeout.
        throw StateError('Python 启动超时，请重启应用后重试。');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return root;
  }

  Future<Map<String, dynamic>> execute({
    required String code,
    required Directory workspace,
    required int timeoutSeconds,
    required CancelToken cancel,
  }) async {
    if (_busy) return {'ok': false, 'error': 'Python 仍在运行，结束后才能执行下一段代码。'};
    _busy = true;
    var awaitingNativeStop = false;
    File? pendingRequest;
    File? pendingTemporary;
    try {
      cancel.checkCancelled();
      final root = await Future.any<Directory>([
        _start(),
        cancel.whenCancel.then<Directory>((_) => throw cancel.cancelError!),
      ]);
      cancel.checkCancelled();
      final id = const Uuid().v4();
      final request = File(p.join(root.path, '$id.request.json'));
      pendingRequest = request;
      pendingTemporary = File('${request.path}.tmp');
      final result = File(p.join(root.path, '$id.result.json'));
      final stop = File(p.join(root.path, '$id.cancel'));
      await pendingTemporary.writeAsString(
        jsonEncode({
          'id': id,
          'code': code,
          'workspace': workspace.path,
          'timeout_seconds': timeoutSeconds,
        }),
      );
      await pendingTemporary.rename(request.path);
      final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
      while (!await result.exists()) {
        if (cancel.isCancelled || DateTime.now().isAfter(deadline)) {
          await stop.writeAsString('stop');
          // Return promptly, but quarantine the interpreter until the worker
          // confirms completion. Native calls cannot be safely interrupted.
          awaitingNativeStop = true;
          unawaited(_awaitStopped(result));
          return {
            'ok': false,
            'running': true,
            'error': cancel.isCancelled
                ? '已请求停止；原生调用可能仍在运行，必要时请重启应用。'
                : 'Python 已超时并请求停止；原生调用可能仍在运行，完成前不能再次执行。',
          };
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final value =
          jsonDecode(await result.readAsString()) as Map<String, dynamic>;
      await result.delete();
      if (await stop.exists()) await stop.delete();
      return value;
    } finally {
      // A timed-out/cancelled native operation must not make the interpreter
      // available until its result proves that execution really stopped.
      if (!awaitingNativeStop) {
        _busy = false;
        if (pendingRequest != null && await pendingRequest.exists()) {
          await pendingRequest.delete();
        }
        if (pendingTemporary != null && await pendingTemporary.exists()) {
          await pendingTemporary.delete();
        }
      }
    }
  }

  Future<void> _awaitStopped(File result) async {
    while (!await result.exists()) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await result.delete();
    final stop = File(result.path.replaceFirst('.result.json', '.cancel'));
    if (await stop.exists()) await stop.delete();
    _busy = false;
  }
}
