import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../platform/attachment_store.dart';
import 'database.dart';

/// Delete files under attachments/ that no database row references anymore.
///
/// Files are only eligible once they are older than [olderThan]: a file
/// written by [AttachmentStore.importFile] is briefly unreferenced between
/// the disk write and the row insert, so a fresh file must never be swept.
/// Call once at startup; returns the number of files deleted. Failures to
/// list, read or delete are swallowed so a bad attachments directory can
/// never block startup.
Future<int> cleanupOrphanAttachments(
  AppDatabase db,
  AttachmentStore files, {
  Duration olderThan = const Duration(minutes: 10),
}) async {
  final dir = Directory(p.join(files.root.path, 'attachments'));
  if (!await dir.exists()) return 0;
  final referenced = <String>{};
  try {
    for (final (table, columns) in [
      ('attachments', ['relative_path', 'original_path']),
      ('study_attachments', ['relative_path']),
      ('practice_images', ['relative_path']),
      ('exam_attachments', ['relative_path', 'original_path']),
    ]) {
      final rows = await db
          .customSelect(
            'SELECT ${columns.join(', ')} FROM $table',
            readsFrom: {
              db.attachments,
              db.studyAttachments,
              db.practiceImages,
              db.examAttachments,
            },
          )
          .get();
      for (final row in rows) {
        for (final column in columns) {
          final value = row.readNullable<String>(column);
          if (value != null && value.isNotEmpty) referenced.add(value);
        }
      }
    }
  } catch (_) {
    return 0;
  }
  final cutoff = DateTime.now().subtract(olderThan);
  var deleted = 0;
  try {
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final relative = 'attachments/${p.basename(entity.path)}';
      if (referenced.contains(relative)) continue;
      try {
        if ((await entity.stat()).modified.isAfter(cutoff)) continue;
        await entity.delete();
        deleted++;
      } catch (_) {}
    }
  } catch (_) {}
  return deleted;
}

/// Only candidates formerly owned by explicitly purged records are eligible.
/// Recheck all domains under the SQLite transaction before unlinking, so shared
/// originals and concurrent reference creation cannot leave dangling images.
Future<int> cleanupPurgedAttachments(
  AppDatabase db,
  AttachmentStore files,
  Iterable<String> candidates,
) async {
  var failed = 0;
  for (final path in candidates.toSet()) {
    try {
      if (p.dirname(path) != 'attachments') {
        throw const FormatException('附件目录无效。');
      }
      // A missing parent directory means the file is necessarily gone too;
      // that is a successful cleanup, not a failure.
      if (await FileSystemEntity.type(
            files.resolve(path).parent.path,
            followLinks: false,
          ) !=
          FileSystemEntityType.directory) {
        continue;
      }
      await db.transaction(() async {
        final refs = await db
            .customSelect(
              '''SELECT
          EXISTS(SELECT 1 FROM attachments WHERE relative_path=? OR original_path=?) +
          EXISTS(SELECT 1 FROM study_attachments WHERE relative_path=?) +
          EXISTS(SELECT 1 FROM practice_images WHERE relative_path=?) +
          EXISTS(SELECT 1 FROM exam_attachments WHERE relative_path=? OR original_path=?) n''',
              variables: [
                Variable(path),
                Variable(path),
                Variable(path),
                Variable(path),
                Variable(path),
                Variable(path),
              ],
            )
            .getSingle();
        if (refs.read<int>('n') != 0) return;
        final file = files.resolve(path);
        if (await file.exists()) await file.delete();
      });
    } on FileSystemException {
      failed++;
    } on FormatException {
      failed++;
    }
  }
  return failed;
}
