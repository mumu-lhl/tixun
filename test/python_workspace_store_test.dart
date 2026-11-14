import 'dart:convert';
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

  test(
    'bounded snapshots round trip edits, empty directories and removals',
    () async {
      final old = File('${store.workspaces.path}/one/old.txt');
      await old.parent.create(recursive: true);
      await old.writeAsString('old');
      await store.applySnapshot('one', {
        'files': {'nested/new.txt': base64Encode(utf8.encode('new'))},
        'directories': ['empty', 'nested'],
      });
      expect(await old.exists(), false);
      final value = await store.snapshot('one');
      expect(value['files'], {'nested/new.txt': 'bmV3'});
      expect(value['directories'], unorderedEquals(['empty', 'nested']));
    },
  );

  test(
    'rejects hostile paths and collisions before changing existing data',
    () async {
      final file = File('${store.workspaces.path}/one/kept');
      await file.parent.create(recursive: true);
      await file.writeAsString('original');
      for (final name in [
        '../escape',
        '/absolute',
        'a/../../escape',
        'a//b',
        r'a\b',
        '.',
      ]) {
        await expectLater(
          store.applySnapshot('one', {
            'files': {name: 'eA=='},
            'directories': <String>[],
          }),
          throwsFormatException,
        );
      }
      await expectLater(
        store.applySnapshot('one', {
          'files': {'a': 'eA==', 'a/b': 'eA=='},
          'directories': <String>[],
        }),
        throwsFormatException,
      );
      expect(await file.readAsString(), 'original');
    },
  );

  test('rejects links without reading or modifying their targets', () async {
    final outside = File('${root.path}/outside');
    await outside.writeAsString('private');
    final workspace = Directory('${store.workspaces.path}/one');
    await workspace.create(recursive: true);
    await Link('${workspace.path}/escape').create(outside.path);
    await expectLater(store.snapshot('one'), throwsFormatException);
    await expectLater(
      store.applySnapshot('one', {
        'files': {'escape': 'eA=='},
        'directories': <String>[],
      }),
      throwsFormatException,
    );
    expect(await outside.readAsString(), 'private');
    await Link('${workspace.path}/escape').delete();
    await workspace.delete();
    await Link(workspace.path).create(root.path);
    await expectLater(store.snapshot('one'), throwsFormatException);
  });

  test('rejects oversized and excessive snapshots', () async {
    await expectLater(
      store.applySnapshot('one', {
        'files': {
          'huge': base64Encode(
            List.filled(PythonWorkspaceStore.snapshotByteLimit + 1, 0),
          ),
        },
        'directories': <String>[],
      }),
      throwsFormatException,
    );
    await expectLater(
      store.applySnapshot('one', {
        'files': <String, String>{},
        'directories': List.generate(1001, (i) => 'dir$i'),
      }),
      throwsFormatException,
    );
    // Implicit parent directories count too, not only explicitly sent entries.
    await expectLater(
      store.applySnapshot('one', {
        'files': {for (var i = 0; i < 600; i++) 'dir$i/file': 'eA=='},
        'directories': <String>[],
      }),
      throwsFormatException,
    );
  });

  test('rejects path traversal and can clear all workspaces', () async {
    await expectLater(store.delete('../outside'), throwsArgumentError);
    final file = File('${store.workspaces.path}/one/file');
    await file.parent.create(recursive: true);
    await file.writeAsString('x');
    await store.deleteAll();
    expect(await store.list(), isEmpty);
  });
}
