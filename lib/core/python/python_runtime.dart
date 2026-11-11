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
  Future<Directory> _start() => _starting ??= _boot();
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
    try {
      cancel.checkCancelled();
      final root = await Future.any<Directory>([
        _start(),
        cancel.whenCancel.then<Directory>((_) => throw cancel.cancelError!),
      ]);
      cancel.checkCancelled();
      final id = const Uuid().v4();
      final request = File(p.join(root.path, '$id.request.json'));
      final result = File(p.join(root.path, '$id.result.json'));
      final stop = File(p.join(root.path, '$id.cancel'));
      await File('${request.path}.tmp').writeAsString(
        jsonEncode({
          'id': id,
          'code': code,
          'workspace': workspace.path,
          'timeout_seconds': timeoutSeconds,
        }),
      );
      await File('${request.path}.tmp').rename(request.path);
      final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));
      var stopRequested = false;
      while (!await result.exists()) {
        if (cancel.isCancelled || DateTime.now().isAfter(deadline)) {
          if (!stopRequested) {
            await stop.writeAsString('stop');
            stopRequested = true;
          }
          // The worker retains ownership until it really exits. Do not release
          // the busy flag and run another script after a mere Dart timeout.
          if (cancel.isCancelled) {
            awaitingNativeStop = true;
            unawaited(_awaitStopped(result));
            return {
              'ok': false,
              'running': true,
              'error': '已请求停止；原生调用可能仍在运行，必要时请重启应用。',
            };
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final value =
          jsonDecode(await result.readAsString()) as Map<String, dynamic>;
      await result.delete();
      if (await stop.exists()) await stop.delete();
      return value;
    } finally {
      // A cancelled native operation must not make the interpreter available.
      if (!awaitingNativeStop) _busy = false;
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
