import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/python/python_workspace_store.dart';

void main() {
  late Directory root;
  late PythonWorkspaceStore store;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('python-workspaces');
    store = PythonWorkspaceStore(root);
  });
  tearDown(() => root.delete(recursive: true));

  test(
    'lists workspace sizes and deletes one session without touching others',
    () async {
      final a = File('${store.workspaces.path}/session-a/nested/data.txt');
      final b = File('${store.workspaces.path}/session-b/other.txt');
      await a.parent.create(recursive: true);
      await b.parent.create(recursive: true);
      await a.writeAsString('hello');
      await b.writeAsString('world!');

      final listed = await store.list();
      expect(listed.map((e) => e.sessionId), ['session-a', 'session-b']);
      expect(listed.first.bytes, 5);
      expect(listed.first.files, 1);

      await store.delete('session-a');
      expect(await File(b.path).exists(), isTrue);
      expect((await store.list()).map((e) => e.sessionId), ['session-b']);
    },
  );

  test('rejects path traversal and can clear all workspaces', () async {
    await expectLater(store.delete('../outside'), throwsArgumentError);
    final file = File('${store.workspaces.path}/one/file');
    await file.parent.create(recursive: true);
    await file.writeAsString('x');
    await store.deleteAll();
    expect(await store.list(), isEmpty);
  });
}
