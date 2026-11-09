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

  static Future<bool> recover(AppController c, List<XFile> files) async {
    final value = await c.db.preference(preference);
    if (value == null || value.isEmpty) return false;
    try {
      final dynamic target = jsonDecode(value);
      if (target is! Map ||
          target['subject'] is! String ||
          !examImageRoles.containsKey(target['role'])) {
        throw const FormatException('照片恢复目标无效。');
      }
      final owner =
          await (c.db.select(c.db.examSubjects)
                ..where((t) => t.id.equals(target['subject'] as String)))
              .getSingleOrNull();
      if (owner == null) {
        await c.newSession();
        for (final file in files) {
          await c.addImage(file.path);
        }
        c.notice = '原考试科目已删除，照片已恢复到对话草稿，未自动上传。';
        return true;
      }
      for (final file in files) {
        await c.exams.addImage(
          target['subject'] as String,
          target['role'] as String,
          file.path,
        );
      }
      c.notice = '考试照片已恢复，未自动上传。';
      return true;
    } finally {
      await c.db.setPreference(preference, '');
    }
  }
}
