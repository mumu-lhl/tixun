import 'package:material_ui/material_ui.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../library/image_editor.dart';

Future<void> editExamPhoto(
  BuildContext context,
  AppController c,
  ExamAttachment image,
) async {
  final size = await c.files.resolve(image.relativePath).length();
  if (!context.mounted) return;
  await showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => StudyImageEditor(
      attachment: StudyAttachment(
        id: image.id,
        relativePath: image.relativePath,
        mime: image.mime,
        byteLength: size,
        role: 'original',
        deleted: false,
      ),
      isMistake: true,
      title: '编辑题目图片',
      createLabel: '保存图片编辑',
      allowSplit: false,
      onCreate: (bytes, _, _) => c.exams.replaceImage(image, bytes),
    ),
  );
}
