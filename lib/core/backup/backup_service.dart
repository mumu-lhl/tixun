import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../platform/attachment_store.dart';

class BackupPreview {
  const BackupPreview(
    this.createdAt,
    this.schema,
    this.files,
    this.bytes,
    this.counts,
  );
  final DateTime createdAt;
  final int schema, files, bytes;
  final Map<String, int> counts;
}

class PreparedBackup {
  const PreparedBackup(this.container, this.data, this.preview);
  final Directory container, data;
  final BackupPreview preview;
  Future<void> discard() async {
    if (await container.exists()) await container.delete(recursive: true);
  }
}

class BackupActivation {
  const BackupActivation(
    this.live,
    this.previous,
    this.journal,
    this.oldJournal,
  );
  final Directory live, previous;
  final File journal;
  final Map<String, dynamic>? oldJournal;
}

/// Versioned, local backup. Secrets belong to the OS key store and never enter
/// this service. Immutable attachments plus VACUUM INTO form a consistent copy.
class BackupService {
  static const formatVersion = 1;
  static const _maxEntries = 100002, _maxBytes = 8 * 1024 * 1024 * 1024;
  static const _databaseLimit = 1024 * 1024 * 1024,
      _imageLimit = 16 * 1024 * 1024,
      _manifestLimit = 32 * 1024 * 1024;

  static Future<BackupPreview> export(
    AppDatabase db,
    AttachmentStore files,
    File destination,
  ) async {
    await destination.parent.create(recursive: true);
    final work = await Directory.systemTemp.createTemp('tixun-export-');
    final snapshot = File(p.join(work.path, 'database.sqlite'));
    final partial = File('${destination.path}.${const Uuid().v4()}.partial');
    try {
      await db.customStatement('VACUUM INTO ?', [snapshot.path]);
      final rootPath = files.root.absolute.path,
          snapshotPath = snapshot.path,
          outPath = partial.path;
      final preview = await Isolate.run(
        () => _encode(rootPath, snapshotPath, outPath),
      );
      await partial.rename(destination.path);
      return preview;
    } finally {
      if (await partial.exists()) await partial.delete();
      await work.delete(recursive: true);
    }
  }

  static Future<BackupPreview> _encode(
    String rootPath,
    String snapshotPath,
    String outPath,
  ) async {
    final root = Directory(rootPath), snapshot = File(snapshotPath);
    final info = _checkDatabase(snapshotPath);
    final paths = <String, File>{'database.sqlite': snapshot};
    final dir = Directory(p.join(root.path, 'attachments'));
    if (await dir.exists()) {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        final type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.link) {
          throw const FormatException('附件目录包含符号链接，无法安全备份。');
        }
        if (type != FileSystemEntityType.file) continue;
        final name = p.posix.joinAll(
          p.split(p.relative(entity.path, from: root.path)),
        );
        _checkedPath(name);
        paths[name] = File(entity.path);
      }
    }
    if (paths.length > _maxEntries - 1) {
      throw const FormatException('附件数量超过备份上限。');
    }
    final manifestFiles = <Map<String, dynamic>>[];
    var bytes = 0;
    for (final entry in paths.entries) {
      final length = await entry.value.length();
      _checkSize(entry.key, length);
      bytes += length;
      if (bytes > _maxBytes) throw const FormatException('备份原始数据超过 8 GiB 上限。');
      manifestFiles.add({
        'path': entry.key,
        'size': length,
        'sha256': await _hash(entry.value),
      });
    }
    for (final path in info.references) {
      _checkedPath(path);
      if (!path.startsWith('attachments/') || !paths.containsKey(path)) {
        throw const FormatException('有图片附件缺失；请修复后再备份，以免生成不完整副本。');
      }
    }
    final now = DateTime.now().toUtc();
    final manifest = jsonEncode({
      'format': 'tixun-backup',
      'version': formatVersion,
      'schema': info.schema,
      'created_at': now.toIso8601String(),
      'files': manifestFiles,
      'counts': info.counts,
    });
    if (utf8.encode(manifest).length > _manifestLimit) {
      throw const FormatException('备份清单过大。');
    }
    // Photos are already compressed. STORE streams every file without retaining
    // a database-sized compression buffer; restore accepts only this format.
    final encoder = ZipFileEncoder()
      ..create(outPath, level: ZipFileEncoder.store);
    try {
      encoder.addArchiveFile(ArchiveFile.string('manifest.json', manifest));
      for (final entry in paths.entries) {
        await encoder.addFile(entry.value, entry.key, ZipFileEncoder.store);
      }
    } finally {
      await encoder.close();
    }
    return BackupPreview(
      now,
      info.schema,
      paths.length - 1,
      bytes,
      info.counts,
    );
  }

  static Future<PreparedBackup> prepare(
    File archive,
    Directory liveRoot,
  ) async {
    final container = await Directory(
      p.join(liveRoot.parent.path, '.tixun-stage-${const Uuid().v4()}'),
    ).create(recursive: true);
    try {
      final input = archive.absolute.path,
          target = p.join(container.path, 'data');
      final preview = await Isolate.run(() => _decode(input, target));
      await Isolate.run(() => _migrateAndCheck(Directory(target)));
      return PreparedBackup(container, Directory(target), preview);
    } catch (_) {
      await container.delete(recursive: true);
      rethrow;
    }
  }

  static Future<BackupPreview> _decode(
    String inputPath,
    String targetPath,
  ) async {
    final inputFile = File(inputPath);
    if (await inputFile.length() > _maxBytes + 128 * 1024 * 1024) {
      throw const FormatException('备份文件过大。');
    }
    final input = InputFileStream(inputPath);
    try {
      // Validate the central directory before any content is read. In particular,
      // reject duplicate paths and Unix symlinks before ZipDecoder visits them.
      final directory = ZipDirectory()..read(input, verify: true);
      if (directory.fileHeaders.isEmpty ||
          directory.fileHeaders.length > _maxEntries) {
        throw const FormatException('备份文件数量无效。');
      }
      final names = <String>{};
      var total = 0;
      for (final h in directory.fileHeaders) {
        final name = h.filename;
        _checkedPath(name);
        _checkSize(name, h.uncompressedSize);
        if (!names.add(name) ||
            h.compressionMethod != 0 ||
            h.compressedSize != h.uncompressedSize ||
            ((h.externalFileAttributes >> 16) & 0xf000) == 0xa000) {
          throw const FormatException('备份含重复文件、链接或不支持的压缩方式。');
        }
        total += h.uncompressedSize;
        if (total > _maxBytes + _manifestLimit) {
          throw const FormatException('备份展开内容过大。');
        }
      }
      input.position = 0;
      final archive = ZipDecoder().decodeStream(
        input,
        verify: true,
        throwOnError: true,
      );
      final entry = archive.findFile('manifest.json');
      if (entry == null) throw const FormatException('缺少备份清单。');
      final manifest = (jsonDecode(utf8.decode(entry.readBytes()!)) as Map)
          .cast<String, dynamic>();
      if (manifest['format'] != 'tixun-backup' ||
          manifest['version'] != formatVersion ||
          manifest['schema'] is! int ||
          manifest['schema'] < 1 ||
          manifest['schema'] > AppDatabase.latestSchemaVersion) {
        throw const FormatException('备份格式或数据库版本不受支持，请检查应用版本。');
      }
      final date = DateTime.tryParse(manifest['created_at'] as String? ?? '');
      if (date == null || manifest['files'] is! List) {
        throw const FormatException('备份清单不完整。');
      }
      final expected = <String, Map<String, dynamic>>{};
      for (final raw in manifest['files'] as List) {
        final m = (raw as Map).cast<String, dynamic>();
        if (m['path'] is! String ||
            m['size'] is! int ||
            m['sha256'] is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(m['sha256'] as String)) {
          throw const FormatException('备份校验信息无效。');
        }
        final name = m['path'] as String;
        _checkedPath(name);
        _checkSize(name, m['size'] as int);
        if (name == 'manifest.json' || expected.containsKey(name)) {
          throw const FormatException('备份清单路径重复。');
        }
        expected[name] = m;
      }
      if (!expected.containsKey('database.sqlite') ||
          expected.length != archive.length - 1 ||
          !names.containsAll(expected.keys)) {
        throw const FormatException('备份清单与文件不一致。');
      }
      final target = Directory(targetPath);
      await target.create(recursive: true);
      var actualBytes = 0;
      for (final f in archive) {
        if (f.name == 'manifest.json') continue;
        final record = expected[f.name];
        if (!f.isFile ||
            f.isSymbolicLink ||
            record == null ||
            record['size'] != f.size) {
          throw const FormatException('备份文件信息不一致。');
        }
        final output = File(
          p.join(
            target.path,
            f.name == 'database.sqlite' ? 'tixun.sqlite' : f.name,
          ),
        );
        if (!p.isWithin(target.path, output.path)) {
          throw const FormatException('附件路径越界。');
        }
        await output.parent.create(recursive: true);
        final stream = OutputFileStream(output.path);
        try {
          f.writeContent(stream);
        } finally {
          await stream.close();
        }
        if (await output.length() != record['size'] ||
            await _hash(output) != record['sha256']) {
          throw const FormatException('备份完整性校验失败，未修改现有数据。');
        }
        actualBytes += await output.length();
      }
      final info = _checkDatabase(p.join(target.path, 'tixun.sqlite'));
      if (info.schema != manifest['schema']) {
        throw const FormatException('数据库与备份版本不一致。');
      }
      for (final relative in info.references) {
        _checkedPath(relative);
        if (!relative.startsWith('attachments/') ||
            !expected.containsKey(relative)) {
          throw const FormatException('备份缺少数据库引用的附件。');
        }
      }
      return BackupPreview(
        date,
        info.schema,
        expected.length - 1,
        actualBytes,
        info.counts,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('无法读取备份，文件可能损坏或格式不受支持。');
    } finally {
      await input.close();
    }
  }

  static Future<void> _migrateAndCheck(Directory root) async {
    final db = AppDatabase.file(File(p.join(root.path, 'tixun.sqlite')));
    try {
      final check = await db
          .customSelect('PRAGMA integrity_check(1)')
          .getSingle();
      if (check.data.values.single != 'ok' ||
          (await db.customSelect('PRAGMA foreign_key_check').get())
              .isNotEmpty) {
        throw const FormatException('数据库完整性检查失败。');
      }
      // Check declared columns too: a forged user_version must not skip tables.
      for (final table in db.allTables) {
        final columns = table.$columns.map((c) => 't."${c.$name}"').join(',');
        await db
            .customSelect(
              'SELECT $columns FROM "${table.actualTableName}" AS t LIMIT 0',
            )
            .get();
      }
      await (db.update(db.chatSessions))
          .write(const ChatSessionsCompanion(toolsEnabled: Value(false)));
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await db.close();
    }
  }

  static void _checkedPath(String name) {
    if (name.isEmpty ||
        name.length > 512 ||
        name.contains('\\') ||
        name.contains(':') ||
        name.contains('\u0000') ||
        p.posix.isAbsolute(name) ||
        p.posix.normalize(name) != name ||
        name.split('/').any((s) => s == '..' || s == '.' || s.isEmpty) ||
        !(name == 'manifest.json' ||
            name == 'database.sqlite' ||
            name.startsWith('attachments/'))) {
      throw const FormatException('备份附件路径无效。');
    }
  }

  static void _checkSize(String name, int size) {
    final max = name == 'database.sqlite'
        ? _databaseLimit
        : name == 'manifest.json'
        ? _manifestLimit
        : _imageLimit;
    if (size < 0 || size > max) {
      throw const FormatException('备份中的单个文件大小无效或超过上限。');
    }
  }

  static Future<String> _hash(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
  static ({int schema, Map<String, int> counts, List<String> references})
  _checkDatabase(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final version =
          db.select('PRAGMA user_version').single.values.single as int;
      if (version < 1 ||
          version > AppDatabase.latestSchemaVersion ||
          db.select('PRAGMA integrity_check(1)').single.values.single != 'ok' ||
          db
              .select('SELECT * FROM pragma_foreign_key_check LIMIT 1')
              .isNotEmpty) {
        throw const FormatException('备份数据库无效或版本不受支持。');
      }
      final tables = db
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'] as String)
          .toSet();
      if (!tables.containsAll([
        'chat_sessions',
        'chat_messages',
        'attachments',
        'provider_configs',
        'preferences',
      ])) {
        throw const FormatException('数据库不属于题训。');
      }
      const counters = {
        'chat_sessions': 'chats',
        'knowledge_items': 'knowledge',
        'mistakes': 'mistakes',
        'practice_questions': 'questions',
        'practice_attempts': 'attempts',
        'review_schedules': 'reviews',
        'exam_events': 'exams',
      };
      final counts = <String, int>{};
      for (final e in counters.entries) {
        counts[e.value] = tables.contains(e.key)
            ? db.select('SELECT count(*) n FROM ${e.key}').single['n'] as int
            : 0;
      }
      final refs = <String>[];
      for (final table in [
        'attachments',
        'study_attachments',
        'practice_images',
        'exam_attachments',
      ]) {
        if (tables.contains(table)) {
          refs.addAll(
            db
                .select('SELECT DISTINCT relative_path FROM $table')
                .map((r) => r['relative_path'] as String),
          );
        }
      }
      for (final table in ['attachments', 'exam_attachments']) {
        if (tables.contains(table) &&
            db
                .select('PRAGMA table_info($table)')
                .any((r) => r['name'] == 'original_path')) {
          refs.addAll(
            db
                .select(
                  'SELECT DISTINCT original_path FROM $table WHERE original_path IS NOT NULL',
                )
                .map((r) => r['original_path'] as String),
          );
        }
      }
      return (schema: version, counts: counts, references: refs);
    } finally {
      db.close();
    }
  }

  static File _journal(Directory root) => File(
    p.join(root.parent.path, '.tixun-restore-${p.basename(root.path)}.json'),
  );
  static Future<Map<String, dynamic>?> _readJournal(Directory root) async {
    final file = _journal(root);
    if (!await file.exists()) return null;
    final data = (jsonDecode(await file.readAsString()) as Map)
        .cast<String, dynamic>();
    if (data['root'] != root.absolute.path ||
        data['previous'] is! String ||
        !p.isWithin(root.parent.absolute.path, data['previous'] as String) ||
        !p
            .basename(data['previous'] as String)
            .startsWith('.tixun-previous-')) {
      throw const FormatException('恢复记录无效；为保护资料，已停止自动处理。');
    }
    // 'staging' is optional (journals written before it existed lack it)
    // and only names the container activate() staged the new data in.
    final staging = data['staging'];
    if (staging != null &&
        (staging is! String ||
            !p.isWithin(root.parent.absolute.path, staging) ||
            !p.basename(staging).startsWith('.tixun-stage-'))) {
      throw const FormatException('恢复记录无效；为保护资料，已停止自动处理。');
    }
    return data;
  }

  static Future<void> _writeJournal(
    File file,
    Map<String, dynamic> value,
  ) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(value), flush: true);
    await temp.rename(file.path);
  }

  /// Call before opening the live database. A killed restore cannot strand data
  /// between the two directory renames.
  ///
  /// When activation was killed between `root -> previous` and
  /// `staging/data -> root`, the new data is still in the staging
  /// directory: resume by moving it into place instead of discarding it
  /// and forcing the user to restore from the backup file again. The
  /// previous directory stays as the undo point either way.
  static Future<void> recoverPending(Directory root) async {
    final data = await _readJournal(root);
    if (data == null || data['state'] == 'complete') return;
    final previous = Directory(data['previous'] as String);
    if (!await root.exists()) {
      final staging = data['staging'] as String?;
      if (staging != null) {
        final stagedData = Directory(p.join(staging, 'data'));
        if (await stagedData.exists()) {
          try {
            _checkDatabase(p.join(stagedData.path, 'tixun.sqlite'));
            await stagedData.rename(root.path);
            try {
              await Directory(staging).delete(recursive: true);
            } catch (_) {
              // An empty staging container is harmless; leave it.
            }
            await _writeJournal(_journal(root), {...data, 'state': 'complete'});
            return;
          } catch (_) {
            // Staged data unusable: fall through to restoring previous.
          }
        }
      }
      if (await previous.exists()) {
        await previous.rename(root.path);
      }
    }
    if (!await root.exists()) throw const FormatException('恢复尚未完成，未找到可用的数据目录。');
    try {
      _checkDatabase(p.join(root.path, 'tixun.sqlite'));
    } catch (_) {
      if (!await previous.exists()) rethrow;
      await root.rename('${root.path}.failed-${const Uuid().v4()}');
      await previous.rename(root.path);
    }
    await _writeJournal(_journal(root), {...data, 'state': 'complete'});
  }

  static Future<Directory?> previousRoot(Directory root) async {
    final data = await _readJournal(root);
    if (data == null || data['state'] != 'complete') return null;
    final previous = Directory(data['previous'] as String);
    return await previous.exists() ? previous : null;
  }

  static Future<void> clearPrevious(Directory root) async {
    final previous = await previousRoot(root);
    if (previous == null) return;
    if (p.dirname(previous.absolute.path) != root.parent.absolute.path) {
      throw const FormatException('安全副本路径无效，已停止删除。');
    }
    await previous.delete(recursive: true);
    await _journal(root).delete();
  }

  /// The caller must close all live connections and remove data consumers first.
  static Future<BackupActivation> activate(
    PreparedBackup prepared,
    Directory root,
  ) async {
    if (!p.isWithin(
          root.parent.absolute.path,
          prepared.container.absolute.path,
        ) ||
        !p.basename(prepared.container.path).startsWith('.tixun-stage-') ||
        !await prepared.data.exists()) {
      throw const FormatException('恢复暂存目录无效。');
    }
    final old = await _readJournal(root);
    final previous = Directory(
      p.join(root.parent.path, '.tixun-previous-${const Uuid().v4()}'),
    );
    final receipt = BackupActivation(root, previous, _journal(root), old);
    await _writeJournal(receipt.journal, {
      'root': root.absolute.path,
      'previous': previous.absolute.path,
      // Recorded so recoverPending can resume the activation from the
      // staged data if the process dies between the two renames below.
      'staging': prepared.container.absolute.path,
      'state': 'activating',
    });
    try {
      await root.rename(previous.path);
      await prepared.data.rename(root.path);
      return receipt;
    } catch (_) {
      await rollback(receipt);
      rethrow;
    }
  }

  static Future<void> finish(BackupActivation receipt) async {
    await _writeJournal(receipt.journal, {
      'root': receipt.live.absolute.path,
      'previous': receipt.previous.absolute.path,
      'state': 'complete',
    });
    // Keep one restore undo point. The confirmation UI states this retention rule.
    final older = receipt.oldJournal?['previous'] as String?;
    if (older != null &&
        older != receipt.previous.path &&
        await Directory(older).exists()) {
      try {
        await Directory(older).delete(recursive: true);
      } on FileSystemException {
        /* Keep the older safety copy if cleanup fails. */
      }
    }
  }

  static Future<void> rollback(BackupActivation receipt) async {
    if (await receipt.previous.exists()) {
      if (await receipt.live.exists()) {
        await receipt.live.rename(
          '${receipt.live.path}.failed-${const Uuid().v4()}',
        );
      }
      await receipt.previous.rename(receipt.live.path);
    }
    if (receipt.oldJournal != null) {
      await _writeJournal(receipt.journal, receipt.oldJournal!);
    } else if (await receipt.journal.exists()) {
      await receipt.journal.delete();
    }
  }

  static Future<PreparedBackup> preparePrevious(Directory root) async {
    final previous = await previousRoot(root);
    if (previous == null) throw const FormatException('没有可撤销的恢复记录。');
    final container = await Directory(
      p.join(root.parent.path, '.tixun-stage-${const Uuid().v4()}'),
    ).create(recursive: true);
    final data = Directory(p.join(container.path, 'data'));
    try {
      final source = previous.path, destination = data.path;
      final info = await Isolate.run(() async {
        await Directory(destination).create(recursive: true);
        await for (final entity in Directory(
          source,
        ).list(recursive: true, followLinks: false)) {
          if (await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.link) {
            throw const FormatException('安全副本含符号链接。');
          }
          if (entity is! File) continue;
          final path = File(
            p.join(destination, p.relative(entity.path, from: source)),
          );
          await path.parent.create(recursive: true);
          await entity.copy(path.path);
        }
        return _checkDatabase(p.join(destination, 'tixun.sqlite'));
      });
      final checkPath = data.path;
      await Isolate.run(() => _migrateAndCheck(Directory(checkPath)));
      return PreparedBackup(
        container,
        data,
        BackupPreview(
          DateTime.now(),
          info.schema,
          info.references.toSet().length,
          0,
          info.counts,
        ),
      );
    } catch (_) {
      await container.delete(recursive: true);
      rethrow;
    }
  }
}
