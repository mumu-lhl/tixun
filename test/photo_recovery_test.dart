import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/exams/exam_photo_intake.dart';
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
  test('Exam photo recovery keeps the batch when an import fails and skips imported files on retry', () async {
    final root = await Directory.systemTemp.createTemp('tixun-exam-recovery');
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
    final event = await c.exams.saveEvent(title: '期中', date: DateTime.now());
    final subject = await c.exams.saveSubject(eventId: event, subject: '数学');
    await c.db.setPreference(
      ExamPhotoIntake.preference,
      jsonEncode({'subject': subject, 'role': 'sheet'}),
    );
    final good = XFile('assets/demo/two_problems.png');
    final missing = XFile('${root.path}/gone.png');
    await expectLater(
      ExamPhotoIntake.recover(c, [good, missing]),
      throwsA(anything),
    );
    expect(await c.db.select(c.db.examAttachments).get(), hasLength(1));
    final retained = jsonDecode(
      await c.db.preference(ExamPhotoIntake.preference) ?? '',
    ) as Map;
    expect(retained['files'], [missing.path]);
    await expectLater(
      ExamPhotoIntake.recover(c, [good, missing]),
      throwsA(anything),
    );
    expect(
      await c.db.select(c.db.examAttachments).get(),
      hasLength(1),
      reason: 'Retry skips the file imported before the failure',
    );
    await c.db.setPreference(
      ExamPhotoIntake.preference,
      jsonEncode({'subject': subject, 'role': 'sheet'}),
    );
    expect(await ExamPhotoIntake.recover(c, [good]), true);
    expect(await c.db.preference(ExamPhotoIntake.preference), '');
    expect(await c.db.select(c.db.examAttachments).get(), hasLength(2));
  });
}
