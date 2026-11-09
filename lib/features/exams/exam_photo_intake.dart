import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../../core/platform/photo_picker.dart';
import '../../core/database/database.dart';
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
    final dynamic target = jsonDecode(value);
    if (target is! Map ||
        target['subject'] is! String ||
        !examImageRoles.containsKey(target['role'])) {
      await c.db.setPreference(preference, '');
      throw const FormatException('照片恢复目标无效。');
    }
    final subject = target['subject'] as String;
    final role = target['role'] as String;
    final pendingPaths = target['files'] is List
        ? (target['files'] as List).whereType<String>().toSet()
        : null;
    final pending = pendingPaths == null
        ? files
        : files.where((f) => pendingPaths.contains(f.path)).toList();
    final owner = await (c.db.select(
      c.db.examSubjects,
    )..where((t) => t.id.equals(subject))).getSingleOrNull();
    if (owner == null) {
      await c.newSession();
      for (var i = 0; i < pending.length; i++) {
        try {
          await c.addImage(pending[i].path);
        } catch (_) {
          await _retainRemaining(c, target, pending, i);
          rethrow;
        }
      }
      c.notice = '原考试科目已删除，照片已恢复到对话草稿，未自动上传。';
    } else {
      for (var i = 0; i < pending.length; i++) {
        try {
          await c.exams.addImage(subject, role, pending[i].path);
        } catch (_) {
          await _retainRemaining(c, target, pending, i);
          rethrow;
        }
      }
      c.notice = '考试照片已恢复，未自动上传。';
    }
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
        'subject': target['subject'],
        'role': target['role'],
        'files': pending.sublist(failedIndex).map((f) => f.path).toList(),
      }),
    );
  }
}
