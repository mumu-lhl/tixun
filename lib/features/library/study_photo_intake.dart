import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:material_ui/material_ui.dart';

import '../../core/platform/photo_picker.dart';
import 'image_editor.dart';
import '../../core/database/database.dart';
import '../../core/database/attachment_cleanup.dart';

import '../../app/controller.dart';

/// Records the destination before Android may destroy the activity for a picker.
class StudyPhotoIntake {
  static const preference = 'pending_study_photo_target';
  static Future<List<String>> pick(
    AppController c, {
    required BuildContext context,
    String? ownerId,
    required bool isMistake,
    bool camera = false,
    String subject = '数学',
  }) async {
    final target = {'id': ownerId, 'mistake': isMistake, 'subject': subject};
    await c.db.setPreference(preference, jsonEncode(target));
    try {
      if (!context.mounted) return [];
      final files = await pickPhotos(context, takePhoto: camera);
      final added = <(String, StudyAttachment)>[];
      for (final file in files) {
        final result = await _apply(c, file, target);
        added.add(result);
      }
      for (final (id, image) in added) {
        if (!context.mounted) break;
        await cropImportedStudyPhoto(context, id, image, isMistake: isMistake);
      }
      return added.map((item) => item.$1).toList();
    } finally {
      await c.db.setPreference(preference, '');
    }
  }

  static Future<bool> recover(AppController c, List<XFile> files) async {
    final value = await c.db.preference(preference);
    if (value == null || value.isEmpty) return false;
    late Map<String, dynamic> target;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, dynamic> ||
          decoded['mistake'] is! bool ||
          (decoded['id'] != null && decoded['id'] is! String) ||
          decoded['subject'] is! String ||
          (decoded['id'] == null && decoded['mistake'] != true) ||
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
    // retrieveLostData is consumed once. Retained paths must work on the next
    // launch even when Android no longer returns the original result.
    final pending = target['files'] is List
        ? (target['files'] as List).cast<String>().map(XFile.new).toList()
        : files;
    if (pending.isEmpty) {
      await c.db.setPreference(preference, '');
      return false;
    }
    var missingOwner = false;
    final owner = target['id'] as String?;
    if (owner != null) {
      try {
        if (target['mistake'] == true) {
          await c.study.mistake(owner);
        } else {
          await c.study.knowledge(owner);
        }
      } on FormatException {
        missingOwner = true;
      }
    }
    if (missingOwner) {
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
        // Insertion and cursor advance commit together, including on retries.
        await c.db.transaction(() async {
          if (missingOwner) {
            final image = await c.addImage(pending[i].path);
            importedPaths.add(image.relativePath);
          } else {
            final (_, image) = await _apply(c, pending[i], target);
            importedPaths.add(image.relativePath);
          }
          await _retainRemaining(c, target, pending, i + 1);
        });
      }
    } catch (_) {
      await cleanupPurgedAttachments(c.db, c.files, importedPaths);
      // A failed cursor write also rolls back the insert; refresh any draft
      // snapshot loaded inside that transaction before showing the error.
      if (missingOwner && c.selected != null) {
        await c.selectSession(c.selected!);
      }
      rethrow;
    }
    await c.db.setPreference(preference, '');
    c.notice = missingOwner
        ? '原资料已删除，照片已保留到新对话草稿。请检查后重新关联，未自动上传。'
        : '已将 ${pending.length} 张照片恢复到${target['mistake'] == true ? '错题本' : '知识库'}。请检查内容并补充解析。';
    return true;
  }

  static Future<void> _retainRemaining(
    AppController c,
    Map<String, dynamic> target,
    List<XFile> files,
    int next,
  ) => c.db.setPreference(
    preference,
    jsonEncode({
      ...target,
      'files': files.skip(next).map((f) => f.path).toList(),
    }),
  );

  static Future<(String, StudyAttachment)> _apply(
    AppController c,
    XFile file,
    Map<String, dynamic> target,
  ) async {
    final id = target['id'] as String?;
    if (id != null) {
      final image = await c.study.importImage(
        id,
        file.path,
        isMistake: target['mistake'] as bool,
      );
      return (id, image);
    } else {
      final row = await c.study.importMistake(
        file.path,
        file.name,
        subject: target['subject'] as String,
      );
      final detail = await c.study.mistakeDetail(row.id);
      return (row.id, detail.images.single);
    }
  }
}
