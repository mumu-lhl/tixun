import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:material_ui/material_ui.dart';

import '../../core/platform/photo_picker.dart';
import '../../core/database/database.dart';
import '../../core/database/attachment_cleanup.dart';
import 'exam_image_editor.dart';

import '../../app/controller.dart';
import 'exam_store.dart';

class ExamPhotoIntake {
  static const preference = 'pending_exam_photo_target';
  static Future<void> pick(
    AppController c,
    String subject,
    String role, {
    required BuildContext context,
    bool camera = false,
  }) async {
    await c.db.setPreference(
      preference,
      jsonEncode({'subject': subject, 'role': role}),
    );
    try {
      if (!context.mounted) return;
      final files = await pickPhotos(context, takePhoto: camera);
      final added = <ExamAttachment>[];
      for (final file in files) {
        added.add(await c.exams.addImage(subject, role, file.path));
      }
      for (final image in added) {
        if (!context.mounted) break;
        await editExamPhoto(context, c, image);
      }
    } finally {
      await c.db.setPreference(preference, '');
    }
  }

  /// Restores interrupted photo picks. The preference is cleared only after
  /// every file has been imported: on any failure the remaining file paths
  /// are written back into the preference and the error is rethrown (the
  /// caller reports it), so the next launch can retry the unfinished files
  /// instead of silently dropping them. Files already imported in this run
  /// are skipped on retry. An invalid target can never succeed, so it is
  /// cleared instead of retried forever.
  static Future<bool> recover(AppController c, List<XFile> files) async {
    final value = await c.db.preference(preference);
    if (value == null || value.isEmpty) return false;
    late Map<String, dynamic> target;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['subject'] is! String ||
          !examImageRoles.containsKey(decoded['role']) ||
          (decoded['chatSession'] != null &&
              decoded['chatSession'] is! String) ||
          (decoded['files'] != null &&
              (decoded['files'] is! List ||
                  (decoded['files'] as List).any((p) => p is! String)))) {
        throw const FormatException('照片恢复目标无效。');
      }
      target = decoded;
    } on FormatException {
      await c.db.setPreference(preference, '');
      rethrow;
    }
    final subject = target['subject'] as String;
    final role = target['role'] as String;
    final pending = target['files'] is List
        ? (target['files'] as List).cast<String>().map(XFile.new).toList()
        : files;
    if (pending.isEmpty) {
      await c.db.setPreference(preference, '');
      return false;
    }
    final owner = await (c.db.select(
      c.db.examSubjects,
    )..where((t) => t.id.equals(subject))).getSingleOrNull();
    if (owner == null) {
      final chatId = target['chatSession'] as String?;
      final session = chatId == null
          ? null
          : await (c.db.select(c.db.chatSessions)
                  ..where((t) => t.id.equals(chatId) & t.deleted.equals(false)))
                .getSingleOrNull();
      if (session == null) {
        await c.newSession();
      } else {
        await c.selectSession(session);
      }
      target['chatSession'] = c.selected!.id;
    }
    await _retainRemaining(c, target, pending, 0);
    final importedPaths = <String>[];
    try {
      for (var i = 0; i < pending.length; i++) {
        await c.db.transaction(() async {
          if (owner == null) {
            final image = await c.addImage(pending[i].path);
            importedPaths.add(image.relativePath);
          } else {
            final image = await c.exams.addImage(
              subject,
              role,
              pending[i].path,
            );
            importedPaths.add(image.relativePath);
          }
          await _retainRemaining(c, target, pending, i + 1);
        });
      }
    } catch (_) {
      await cleanupPurgedAttachments(c.db, c.files, importedPaths);
      // A failed cursor write also rolls back the insert; refresh any draft
      // snapshot loaded inside that transaction before showing the error.
      if (owner == null && c.selected != null) {
        await c.selectSession(c.selected!);
      }
      rethrow;
    }
    c.notice = owner == null ? '原考试科目已删除，照片已恢复到对话草稿，未自动上传。' : '考试照片已恢复，未自动上传。';
    // Any failure above rethrows before this line, so the preference — the
    // only pointer to this batch — survives for the next launch.
    await c.db.setPreference(preference, '');
    return true;
  }

  static Future<void> _retainRemaining(
    AppController c,
    Map<dynamic, dynamic> target,
    List<XFile> pending,
    int failedIndex,
  ) async {
    await c.db.setPreference(
      preference,
      jsonEncode({
        ...target,
        'files': pending.sublist(failedIndex).map((f) => f.path).toList(),
      }),
    );
  }
}
