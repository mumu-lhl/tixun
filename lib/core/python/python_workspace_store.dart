import 'dart:io';

import 'package:path/path.dart' as p;

class PythonWorkspaceInfo {
  const PythonWorkspaceInfo({
    required this.sessionId,
    required this.path,
    required this.bytes,
    required this.files,
  });

  final String sessionId;
  final String path;
  final int bytes;
  final int files;
}

/// Lists and deletes only the Python workspace tree owned by the app.
class PythonWorkspaceStore {
  PythonWorkspaceStore(this.root);

  final Directory root;
  Directory get workspaces => Directory(p.join(root.path, 'python-workspaces'));

  Future<List<PythonWorkspaceInfo>> list() async {
    if (!await workspaces.exists()) return const [];
    final result = <PythonWorkspaceInfo>[];
    await for (final entity in workspaces.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      final totals = await _measure(entity);
      result.add(
        PythonWorkspaceInfo(
          sessionId: id,
          path: entity.path,
          bytes: totals.$1,
          files: totals.$2,
        ),
      );
    }
    result.sort((a, b) => a.sessionId.compareTo(b.sessionId));
    return result;
  }

  Future<(int, int)> _measure(Directory directory) async {
    var bytes = 0;
    var files = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is File) {
        bytes += await entity.length();
        files++;
      } else if (entity is Directory) {
        final nested = await _measure(entity);
        bytes += nested.$1;
        files += nested.$2;
      }
      // Do not follow symlinks; unrestricted Python may create them.
    }
    return (bytes, files);
  }

  Future<void> delete(String sessionId) async {
    if (sessionId.isEmpty ||
        p.basename(sessionId) != sessionId ||
        sessionId == '.' ||
        sessionId == '..') {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    final directory = Directory(p.join(workspaces.path, sessionId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> deleteAll() async {
    if (await workspaces.exists()) await workspaces.delete(recursive: true);
  }
}
