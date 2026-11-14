import 'dart:convert';
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

  static const snapshotByteLimit = 8 * 1024 * 1024;
  static const snapshotEntryLimit = 1000;

  void _validateSession(String sessionId) {
    if (sessionId.isEmpty ||
        p.basename(sessionId) != sessionId ||
        sessionId == '.' ||
        sessionId == '..' ||
        sessionId == '.tixun-runtime') {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
  }

  Future<Directory> _safeWorkspace(String sessionId) async {
    _validateSession(sessionId);
    final directory = Directory(p.join(workspaces.path, sessionId));
    for (final path in [root.path, workspaces.path, directory.path]) {
      if (await FileSystemEntity.type(path, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FormatException('Workspace links are not allowed');
      }
    }
    await directory.create(recursive: true);
    final canonicalRoot = await root.resolveSymbolicLinks();
    final canonicalWorkspaces = await workspaces.resolveSymbolicLinks();
    if (p.dirname(canonicalWorkspaces) != canonicalRoot ||
        p.dirname(await directory.resolveSymbolicLinks()) !=
            canonicalWorkspaces) {
      throw const FormatException('Workspace links are not allowed');
    }
    return directory;
  }

  /// Bounded, regular-file-only transfer to Android's isolated UID.
  Future<Map<String, dynamic>> snapshot(String sessionId) async {
    final directory = await _safeWorkspace(sessionId);
    final files = <String, String>{};
    final directories = <String>[];
    var bytes = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      final name = p.relative(entity.path, from: directory.path);
      _validateSnapshotPath(name);
      if (entity is Directory) {
        directories.add(name);
      } else if (entity is File) {
        final info = await entity.stat();
        if (info.mode & 0xf000 != 0x8000) {
          throw const FormatException(
            'Workspace special files are not allowed',
          );
        }
        bytes += info.size;
        if (bytes > snapshotByteLimit) {
          throw const FormatException('Workspace exceeds 8 MiB');
        }
        files[name] = base64Encode(await entity.readAsBytes());
      } else {
        throw const FormatException(
          'Workspace links and special files are not allowed',
        );
      }
      if (files.length + directories.length > snapshotEntryLimit) {
        throw const FormatException('Workspace exceeds 1000 entries');
      }
    }
    return {'files': files, 'directories': directories};
  }

  void _validateSnapshotPath(String name) {
    final parts = name.split('/');
    if (name.isEmpty ||
        name.length > 1024 ||
        name.contains('\\') ||
        name.contains(String.fromCharCode(0)) ||
        parts.length > 32 ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..')) {
      throw const FormatException('Invalid workspace transfer path');
    }
  }

  /// Treat everything returned by Python as hostile, including paths and sizes.
  Future<void> applySnapshot(String sessionId, Object? value) async {
    if (value is! Map ||
        value['files'] is! Map ||
        value['directories'] is! List) {
      throw const FormatException('Invalid workspace snapshot');
    }
    final encoded = value['files'] as Map;
    final directoryValues = value['directories'] as List;
    if (encoded.length + directoryValues.length > snapshotEntryLimit) {
      throw const FormatException('Workspace exceeds 1000 entries');
    }
    final files = <String, List<int>>{};
    final directories = <String>{};
    var bytes = 0;
    for (final name in directoryValues) {
      if (name is! String) {
        throw const FormatException('Invalid directory name');
      }
      _validateSnapshotPath(name);
      if (!directories.add(name)) {
        throw const FormatException('Duplicate directory');
      }
    }
    for (final entry in encoded.entries) {
      final name = entry.key, content = entry.value;
      if (name is! String || content is! String) {
        throw const FormatException('Invalid workspace file');
      }
      _validateSnapshotPath(name);
      if (directories.contains(name) ||
          content.length > (snapshotByteLimit + 2) ~/ 3 * 4) {
        throw const FormatException('Invalid workspace file or size');
      }
      final data = base64Decode(content);
      bytes += data.length;
      if (bytes > snapshotByteLimit) {
        throw const FormatException('Workspace exceeds 8 MiB');
      }
      files[name] = data;
    }
    for (final name in [...files.keys, ...directories]) {
      var parent = p.posix.dirname(name);
      while (parent != '.') {
        if (files.containsKey(parent)) {
          throw const FormatException('File/directory conflict');
        }
        directories.add(parent);
        parent = p.posix.dirname(parent);
      }
    }
    if (files.length + directories.length > snapshotEntryLimit) {
      throw const FormatException('Workspace exceeds 1000 entries');
    }

    final directory = await _safeWorkspace(sessionId);
    // Reject existing links before modifying anything; the isolated UID cannot
    // race these checks by changing files in the app-owned directory.
    await snapshot(sessionId);
    final existing = await directory
        .list(recursive: true, followLinks: false)
        .toList();
    existing.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final entity in existing) {
      final name = p.relative(entity.path, from: directory.path);
      final retained = entity is File
          ? files.containsKey(name)
          : directories.contains(name) ||
                files.keys.any((file) => file.startsWith('$name/')) ||
                directories.any((dir) => dir.startsWith('$name/'));
      if (!retained) await entity.delete();
    }
    for (final name in directories) {
      await Directory(p.join(directory.path, name)).create(recursive: true);
    }
    for (final entry in files.entries) {
      final file = File(p.join(directory.path, entry.key));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.value, flush: true);
    }
  }

  Future<void> delete(String sessionId) async {
    _validateSession(sessionId);
    final directory = Directory(p.join(workspaces.path, sessionId));
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> deleteAll() async {
    if (await workspaces.exists()) await workspaces.delete(recursive: true);
  }
}
