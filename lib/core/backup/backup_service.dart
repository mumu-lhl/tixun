import "package:tixun/core/l10n/app_error.dart";

import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:archive/archive_io.dart";
import "package:crypto/crypto.dart";
import "package:drift/drift.dart" show Value;
import "package:path/path.dart" as p;
import "package:sqlite3/sqlite3.dart";
import "package:uuid/uuid.dart";

import "../database/database.dart";
import "../platform/attachment_store.dart";

part "backup_archive.dart";

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
    final work = await Directory.systemTemp.createTemp("tixun-export-");
    final snapshot = File(p.join(work.path, "database.sqlite"));
    final partial = File("${destination.path}.${const Uuid().v4()}.partial");
    try {
      await db.customStatement("VACUUM INTO ?", [snapshot.path]);
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

  static Future<PreparedBackup> prepare(
    File archive,
    Directory liveRoot,
  ) async {
    final container = await Directory(
      p.join(liveRoot.parent.path, ".tixun-stage-${const Uuid().v4()}"),
    ).create(recursive: true);
    try {
      final input = archive.absolute.path,
          target = p.join(container.path, "data");
      final preview = await Isolate.run(() => _decode(input, target));
      await Isolate.run(() => _migrateAndCheck(Directory(target)));
      return PreparedBackup(container, Directory(target), preview);
    } catch (_) {
      await container.delete(recursive: true);
      rethrow;
    }
  }

  static File _journal(Directory root) => File(
    p.join(root.parent.path, ".tixun-restore-${p.basename(root.path)}.json"),
  );
  static Future<Map<String, dynamic>?> _readJournal(Directory root) async {
    final file = _journal(root);
    if (!await file.exists()) return null;
    final data = (jsonDecode(await file.readAsString()) as Map)
        .cast<String, dynamic>();
    if (data["root"] != root.absolute.path ||
        data["previous"] is! String ||
        !p.isWithin(root.parent.absolute.path, data["previous"] as String) ||
        !p
            .basename(data["previous"] as String)
            .startsWith(".tixun-previous-")) {
      throw const AppFormatException(
        AppErrorCode.errorTheRecoveryRecordIsInvalidAutomatic,
        "恢复记录无效；为保护资料，已停止自动处理。",
      );
    }
    // 'staging' is optional (journals written before it existed lack it)
    // and only names the container activate() staged the new data in.
    final staging = data["staging"];
    if (staging != null &&
        (staging is! String ||
            !p.isWithin(root.parent.absolute.path, staging) ||
            !p.basename(staging).startsWith(".tixun-stage-"))) {
      throw const AppFormatException(
        AppErrorCode.errorTheRecoveryRecordIsInvalidAutomatic,
        "恢复记录无效；为保护资料，已停止自动处理。",
      );
    }
    return data;
  }

  static Future<void> _writeJournal(
    File file,
    Map<String, dynamic> value,
  ) async {
    final temp = File("${file.path}.tmp");
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
    if (data == null || data["state"] == "complete") return;
    final previous = Directory(data["previous"] as String);
    if (!await root.exists()) {
      final staging = data["staging"] as String?;
      if (staging != null) {
        final stagedData = Directory(p.join(staging, "data"));
        if (await stagedData.exists()) {
          try {
            _checkDatabase(p.join(stagedData.path, "tixun.sqlite"));
            await stagedData.rename(root.path);
            try {
              await Directory(staging).delete(recursive: true);
            } catch (_) {
              // An empty staging container is harmless; leave it.
            }
            await _writeJournal(_journal(root), {...data, "state": "complete"});
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
    if (!await root.exists()) {
      throw const AppFormatException(
        AppErrorCode.errorRecoveryIsIncompleteAndNoUsable,
        "恢复尚未完成，未找到可用的数据目录。",
      );
    }
    try {
      _checkDatabase(p.join(root.path, "tixun.sqlite"));
    } catch (_) {
      if (!await previous.exists()) rethrow;
      await root.rename("${root.path}.failed-${const Uuid().v4()}");
      await previous.rename(root.path);
    }
    await _writeJournal(_journal(root), {...data, "state": "complete"});
  }

  static Future<Directory?> previousRoot(Directory root) async {
    final data = await _readJournal(root);
    if (data == null || data["state"] != "complete") return null;
    final previous = Directory(data["previous"] as String);
    return await previous.exists() ? previous : null;
  }

  static Future<void> clearPrevious(Directory root) async {
    final previous = await previousRoot(root);
    if (previous == null) return;
    if (p.dirname(previous.absolute.path) != root.parent.absolute.path) {
      throw const AppFormatException(
        AppErrorCode.errorTheSafetyCopyPathIsInvalid,
        "安全副本路径无效，已停止删除。",
      );
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
        !p.basename(prepared.container.path).startsWith(".tixun-stage-") ||
        !await prepared.data.exists()) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidRestoreStagingDirectory,
        "恢复暂存目录无效。",
      );
    }
    final old = await _readJournal(root);
    final previous = Directory(
      p.join(root.parent.path, ".tixun-previous-${const Uuid().v4()}"),
    );
    final receipt = BackupActivation(root, previous, _journal(root), old);
    await _writeJournal(receipt.journal, {
      "root": root.absolute.path,
      "previous": previous.absolute.path,
      // Recorded so recoverPending can resume the activation from the
      // staged data if the process dies between the two renames below.
      "staging": prepared.container.absolute.path,
      "state": "activating",
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
      "root": receipt.live.absolute.path,
      "previous": receipt.previous.absolute.path,
      "state": "complete",
    });
    // Keep one restore undo point. The confirmation UI states this retention rule.
    final older = receipt.oldJournal?["previous"] as String?;
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
          "${receipt.live.path}.failed-${const Uuid().v4()}",
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
    if (previous == null) {
      throw const AppFormatException(
        AppErrorCode.errorThereIsNoRestoreToUndo,
        "没有可撤销的恢复记录。",
      );
    }
    final container = await Directory(
      p.join(root.parent.path, ".tixun-stage-${const Uuid().v4()}"),
    ).create(recursive: true);
    final data = Directory(p.join(container.path, "data"));
    try {
      final source = previous.path, destination = data.path;
      final info = await Isolate.run(() async {
        await Directory(destination).create(recursive: true);
        await for (final entity in Directory(
          source,
        ).list(recursive: true, followLinks: false)) {
          if (await FileSystemEntity.type(entity.path, followLinks: false) ==
              FileSystemEntityType.link) {
            throw const AppFormatException(
              AppErrorCode.errorTheSafetyCopyContainsSymbolicLinks,
              "安全副本含符号链接。",
            );
          }
          if (entity is! File) continue;
          final path = File(
            p.join(destination, p.relative(entity.path, from: source)),
          );
          await path.parent.create(recursive: true);
          await entity.copy(path.path);
        }
        return _checkDatabase(p.join(destination, "tixun.sqlite"));
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
