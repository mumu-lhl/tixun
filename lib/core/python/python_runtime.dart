import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../ai/ai_types.dart';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Executes Python only in a separate Linux process under bubblewrap.
/// Android remains disabled until its isolated-service adapter is implemented.
class PythonRuntime {
  static final instance = PythonRuntime();
  static bool get isSupportedPlatform => Platform.isLinux;

  static const _outputLimit = 32000;
  bool _busy = false;

  Future<Map<String, dynamic>> execute({
    required String code,
    required Directory workspace,
    required int timeoutSeconds,
    required CancelToken cancel,
  }) async {
    if (!isSupportedPlatform) {
      return {'ok': false, 'error': 'Python 沙盒暂不可用于此平台。'};
    }
    if (_busy) return {'ok': false, 'error': 'Python 仍在运行，结束后才能执行下一段代码。'};
    _busy = true;
    final started = DateTime.now();
    File? script;
    Process? process;
    Timer? timer;
    var cancelled = false;
    var timedOut = false;
    var processFinished = false;
    final terminated = Completer<void>();
    try {
      cancel.checkCancelled();
      final workspacesRoot = Directory(p.dirname(workspace.absolute.path));
      if (p.basename(workspacesRoot.path) != 'python-workspaces') {
        return {'ok': false, 'error': 'Python 工作目录无效，执行已阻止。'};
      }
      await workspace.create(recursive: true);
      final canonicalRoot = await workspacesRoot.resolveSymbolicLinks();
      final canonicalWorkspace = await workspace.resolveSymbolicLinks();
      if (p.dirname(canonicalWorkspace) != canonicalRoot ||
          p.basename(canonicalWorkspace) == '.tixun-runtime') {
        return {'ok': false, 'error': 'Python 工作目录无效，执行已阻止。'};
      }

      final bundle = p.dirname(Platform.resolvedExecutable);
      final launcher = p.join(bundle, 'libexec', 'tixun-python-sandbox');
      if (!await File(launcher).exists()) {
        return {'ok': false, 'error': 'Python 沙盒运行时未安装。'};
      }
      script = File(
        p.join(canonicalWorkspace, '.tixun-${const Uuid().v4()}.py'),
      );
      await script.writeAsString(code, flush: true);
      cancel.checkCancelled();
      process = await Process.start(
        'bwrap',
        [
          '--die-with-parent',
          '--new-session',
          '--unshare-user',
          '--unshare-pid',
          '--unshare-ipc',
          '--unshare-uts',
          '--cap-drop',
          'ALL',
          '--ro-bind',
          '/',
          '/',
          '--proc',
          '/proc',
          '--bind',
          canonicalWorkspace,
          canonicalWorkspace,
          '--chdir',
          canonicalWorkspace,
          '--setenv',
          'HOME',
          canonicalWorkspace,
          '--setenv',
          'TMPDIR',
          canonicalWorkspace,
          '--setenv',
          'XDG_CACHE_HOME',
          canonicalWorkspace,
          '--',
          launcher,
          '--bundle',
          bundle,
          script.path,
        ],
        runInShell: false,
        includeParentEnvironment: false,
        environment: const {
          'PATH': '/usr/bin:/bin',
          'LANG': 'C.UTF-8',
          'PYTHONDONTWRITEBYTECODE': '1',
          'PYTHONNOUSERSITE': '1',
          'PYTHONUNBUFFERED': '1',
        },
      );

      final stdout = _capture(process.stdout);
      final stderr = _capture(process.stderr);
      final exit = process.exitCode;
      final runningProcess = process;
      timer = Timer(Duration(seconds: timeoutSeconds), () {
        if (processFinished) return;
        timedOut = true;
        processFinished = true;
        runningProcess.kill(ProcessSignal.sigkill);
        if (!terminated.isCompleted) terminated.complete();
      });
      unawaited(
        cancel.whenCancel.then((_) {
          if (processFinished) return;
          cancelled = true;
          processFinished = true;
          runningProcess.kill(ProcessSignal.sigkill);
          if (!terminated.isCompleted) terminated.complete();
        }),
      );

      final exitCode = await Future.any<int>([
        exit,
        terminated.future.then((_) => -1),
      ]);
      processFinished = true;
      if (exitCode == -1) {
        await exit;
        if (cancelled) cancel.checkCancelled();
      }
      timer.cancel();
      final out = await stdout;
      final err = await stderr;
      if (timedOut) {
        return {
          'ok': false,
          'error': 'Python 执行超时，隔离进程已终止。',
          'stdout': out.text,
          'stderr': err.text,
          'output_truncated': out.truncated || err.truncated,
          'elapsed_ms': DateTime.now().difference(started).inMilliseconds,
        };
      }
      return {
        'ok': exitCode == 0,
        if (exitCode != 0) 'error': 'Python 进程退出，状态码 $exitCode。',
        'stdout': out.text,
        'stderr': err.text,
        'output_truncated': out.truncated || err.truncated,
        'elapsed_ms': DateTime.now().difference(started).inMilliseconds,
      };
    } on DioException {
      rethrow;
    } on ProcessException catch (error) {
      return {'ok': false, 'error': 'Python 沙盒启动失败：${error.message}'};
    } catch (error) {
      if (cancel.isCancelled) rethrow;
      return {'ok': false, 'error': 'Python 沙盒执行失败：$error'};
    } finally {
      timer?.cancel();
      try {
        if (process != null && !processFinished) {
          processFinished = true;
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
        }
        if (script != null && await script.exists()) {
          try {
            await script.delete();
          } on FileSystemException {
            // User code may have removed or replaced its temporary source file.
          }
        }
      } finally {
        _busy = false;
      }
    }
  }

  Future<_CapturedOutput> _capture(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    var truncated = false;
    await for (final chunk in stream) {
      final remaining = _outputLimit - bytes.length;
      if (remaining > 0) bytes.add(chunk.take(remaining).toList());
      if (chunk.length > remaining) truncated = true;
    }
    return _CapturedOutput(
      utf8.decode(bytes.takeBytes(), allowMalformed: true),
      truncated,
    );
  }
}

class _CapturedOutput {
  const _CapturedOutput(this.text, this.truncated);
  final String text;
  final bool truncated;
}
