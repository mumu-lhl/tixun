import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';
import 'exam_store.dart';

class ExamPhotoIntake {
  static const preference = 'pending_exam_photo_target';
  static Future<void> pick(
    AppController c,
    String subject,
    String role, {
    bool camera = false,
  }) async {
    await c.db.setPreference(
      preference,
      jsonEncode({'subject': subject, 'role': role}),
    );
    try {
      final files = camera
          ? [await ImagePicker().pickImage(source: ImageSource.camera)].nonNulls
                .toList()
          : await ImagePicker().pickMultiImage(limit: 4);
      for (final file in files) {
        await c.exams.addImage(subject, role, file.path);
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
