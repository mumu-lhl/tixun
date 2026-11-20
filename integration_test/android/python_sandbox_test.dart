import "dart:io";

import "package:dio/dio.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";
import "package:path_provider/path_provider.dart";
import "package:tixun/core/python/python_runtime.dart";

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("Android isolated CPython, workspace and OS access boundaries", (
    tester,
  ) async {
    if (!Platform.isAndroid) return;
    expect(PythonRuntime.isSupportedPlatform, true);
    final support = await getApplicationSupportDirectory();
    final workspace = Directory(
      "${support.path}/tixun/python-workspaces/android-isolation-test",
    );
    await workspace.create(recursive: true);
    final secret = File("${support.path}/python-isolation-canary");
    await secret.writeAsString("private app data");
    addTearDown(() async {
      await workspace.delete(recursive: true);
      await secret.delete();
    });

    Future<Map<String, dynamic>> execute(
      String code, {
      int seconds = 60,
      CancelToken? cancel,
    }) => PythonRuntime.instance.execute(
      code: code,
      workspace: workspace,
      timeoutSeconds: seconds,
      cancel: cancel ?? CancelToken(),
    );

    final result = await execute("""
import sympy as s
print(s.integrate(s.Symbol('x')**2, ('x', 0, 3)))
import numpy as np
print(np.linalg.solve([[2, 0], [0, 4]], [6, 8]).tolist())
from pathlib import Path
Path('nested').mkdir()
Path('nested/result.txt').write_text('isolated')
# Probe libc directly, bypassing the virtual filesystem compatibility layer.
import ctypes
libc = ctypes.CDLL(None, use_errno=True)
print('isolated uid', libc.getuid() % 100000 >= 90000)
for flags in (0, 1):
    fd = libc.open(b'${secret.path}', flags)
    if fd >= 0:
        libc.close(fd)
        raise AssertionError('OS allowed access to private app data')
print('private data blocked')
import socket
try:
    socket.socket(socket.AF_INET, socket.SOCK_STREAM)
except OSError:
    print('network blocked')
else:
    raise AssertionError('isolated UID unexpectedly has network access')
""");
    expect(result["ok"], true, reason: result.toString());
    expect(result["stdout"], contains("9\n[3.0, 2.0]"));
    expect(result["stdout"], contains("isolated uid True"));
    expect(result["stdout"], contains("private data blocked"));
    expect(result["stdout"], contains("network blocked"));
    expect(await secret.readAsString(), "private app data");
    expect(
      await File("${workspace.path}/nested/result.txt").readAsString(),
      "isolated",
    );

    final next = await execute("""
from pathlib import Path
assert Path('nested/result.txt').read_text() == 'isolated'
Path('nested/result.txt').unlink()
print('next execution')
""");
    expect(next["ok"], true, reason: next.toString());
    expect(await File("${workspace.path}/nested/result.txt").exists(), false);

    final timeout = await execute("while True: pass", seconds: 10);
    expect(timeout["ok"], false);
    expect(timeout["error"], contains("超时"));
    final token = CancelToken();
    final stopped = execute("while True: pass", cancel: token);
    final cancellation = expectLater(stopped, throwsA(isA<DioException>()));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 8)),
    );
    token.cancel("device test");
    await cancellation;

    // An uncatchable process exit cannot crash Flutter or poison the next run.
    expect((await execute("import os; os._exit(7)"))["ok"], false);
    final recovery = await execute('print("recovered")');
    expect(recovery["ok"], true, reason: recovery.toString());
    expect(recovery["stdout"], "recovered\n");
  });
}
