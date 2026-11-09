import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../platform/attachment_store.dart';
import 'database.dart';

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
      if (p.dirname(path) != 'attachments' ||
          await FileSystemEntity.type(
                files.resolve(path).parent.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.directory) {
        throw const FormatException('附件目录无效。');
      }
      await db.transaction(() async {
        final refs = await db
            .customSelect(
              '''SELECT
          EXISTS(SELECT 1 FROM attachments WHERE relative_path=? OR original_path=?) +
          EXISTS(SELECT 1 FROM study_attachments WHERE relative_path=?) +
          EXISTS(SELECT 1 FROM practice_images WHERE relative_path=?) +
          EXISTS(SELECT 1 FROM exam_attachments WHERE relative_path=?) n''',
              variables: [
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
