import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/study_photo_intake.dart';
import 'package:tixun/features/library/study_store.dart';

void main() {
  test('Recovered photos return to their library destination; deleted targets keep a local chat draft', () async {
    final root = await Directory.systemTemp.createTemp('tixun-recovery');
    final c = AppController(
      AppDatabase.memory(),
      AttachmentStore(root),
      MemoryKeyStore(),
      MockChatProvider(),
    );
    await c.initialize();
    addTearDown(() async {
      await c.shutdown();
      await root.delete(recursive: true);
    });
    final wrong = await c.study.saveMistake(
      const MistakeDraft(title: '恢复照片测试'),
    );
    final target = jsonEncode({
      'id': wrong.id,
      'mistake': true,
      'subject': '数学',
    });
    await c.db.setPreference(StudyPhotoIntake.preference, target);
    final file = XFile('assets/demo/two_problems.png');
    expect(await StudyPhotoIntake.recover(c, [file]), true);
    expect((await c.study.images(wrong.id, isMistake: true)).length, 1);
    expect(c.selected, isNull);
    expect(await c.db.preference(StudyPhotoIntake.preference), '');
    await c.study.setDeleted(
      wrong.id,
      isMistake: true,
      deleted: true,
      expectedRevision: wrong.revision,
    );
    await c.db.setPreference(StudyPhotoIntake.preference, target);
    expect(await StudyPhotoIntake.recover(c, [file]), true);
    expect(c.selected, isNotNull);
    expect(c.attachments.length, 1);
    expect(c.attachments.single.messageId, isNull);
    expect(await c.study.searchMistakes(), isEmpty);
    expect(c.notice, contains('未自动上传'));
  });
}
