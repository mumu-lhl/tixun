import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../app/controller.dart';

/// Records the destination before Android may destroy the activity for a picker.
class StudyPhotoIntake {
  static const preference = 'pending_study_photo_target';
  static Future<int> pick(
    AppController c, {
    String? ownerId,
    required bool isMistake,
    bool camera = false,
    String subject = '数学',
  }) async {
    final target = {'id': ownerId, 'mistake': isMistake, 'subject': subject};
    await c.db.setPreference(preference, jsonEncode(target));
    try {
      final files = camera
          ? [await ImagePicker().pickImage(source: ImageSource.camera)].nonNulls
                .toList()
          : await ImagePicker().pickMultiImage(limit: 4);
      for (final file in files) {
        await _apply(c, file, target);
      }
      return files.length;
    } finally {
      await c.db.setPreference(preference, '');
    }
  }

  static Future<bool> recover(AppController c, List<XFile> files) async {
    final value = await c.db.preference(preference);
    if (value == null || value.isEmpty) return false;
    try {
      final target = (jsonDecode(value) as Map).cast<String, dynamic>();
      if (target['mistake'] is! bool ||
          (target['id'] != null && target['id'] is! String) ||
          target['subject'] is! String) {
        throw const FormatException('照片恢复目标无效。');
      }
      final owner = target['id'] as String?;
      if (owner == null && target['mistake'] != true) {
        throw const FormatException('照片恢复目标无效。');
      }
      if (owner != null) {
        try {
          if (target['mistake'] == true) {
            await c.study.mistake(owner);
          } else {
            await c.study.knowledge(owner);
          }
        } on FormatException {
          for (var i = 0; i < files.length; i++) {
            if (i % 4 == 0) await c.newSession();
            await c.addImage(files[i].path);
          }
          c.notice = '原资料已删除，照片已保留到新对话草稿。请检查后重新关联，未自动上传。';
          return true;
        }
      }
      var recovered = 0;
      for (final file in files) {
        await _apply(c, file, target);
        recovered++;
      }
      c.notice =
          '已将 $recovered 张照片恢复到${target['mistake'] == true ? '错题本' : '知识库'}。请检查内容并补充解析。';
      return true;
    } finally {
      await c.db.setPreference(preference, '');
    }
  }

  static Future<void> _apply(
    AppController c,
    XFile file,
    Map<String, dynamic> target,
  ) async {
    final id = target['id'] as String?;
    if (id != null) {
      await c.study.importImage(
        id,
        file.path,
        isMistake: target['mistake'] as bool,
      );
    } else {
      await c.study.importMistake(
        file.path,
        file.name,
        subject: target['subject'] as String,
      );
    }
  }
}
