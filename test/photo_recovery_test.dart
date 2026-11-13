import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/app/app_notice.dart';
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
    expect(c.notice?.kind, AppNoticeKind.studyOwnerDeleted);
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
  for (final exam in [false, true]) {
    final domain = exam ? 'exam' : 'study';
    test(
      '$domain recovery retries retained paths after a database restart without duplicating imports',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-photo-restart',
        );
        final keys = MemoryKeyStore();
        Future<AppController> open() async {
          final c = AppController(
            AppDatabase.file(File('${root.path}/tixun.sqlite')),
            AttachmentStore(root),
            keys,
            MockChatProvider(),
          );
          await c.initialize();
          return c;
        }

        var c = await open();
        addTearDown(() async {
          await c.shutdown();
          await root.delete(recursive: true);
        });
        final pref = exam
            ? ExamPhotoIntake.preference
            : StudyPhotoIntake.preference;
        final id = exam
            ? await c.exams.saveSubject(
                eventId: await c.exams.saveEvent(
                  title: '考试',
                  date: DateTime.now(),
                ),
                subject: '数学',
              )
            : (await c.study.saveMistake(const MistakeDraft(title: '恢复照片'))).id;
        await c.db.setPreference(
          pref,
          jsonEncode(
            exam
                ? {'subject': id, 'role': 'sheet'}
                : {'id': id, 'mistake': true, 'subject': '数学'},
          ),
        );
        Future<bool> recover(List<XFile> photos) => exam
            ? ExamPhotoIntake.recover(c, photos)
            : StudyPhotoIntake.recover(c, photos);
        Future<int> count() async => exam
            ? (await c.db.select(c.db.examAttachments).get()).length
            : (await c.study.images(id, isMistake: true)).length;
        final first = XFile('assets/demo/two_problems.png');
        final missing = File('${root.path}/missing.png');
        await expectLater(
          recover([first, XFile(missing.path)]),
          throwsA(isA<FileSystemException>()),
        );
        expect(await count(), 1);
        await expectLater(recover([]), throwsA(isA<FileSystemException>()));
        expect(await count(), 1);
        await c.shutdown();
        c = await open();
        await missing.writeAsBytes(await File(first.path).readAsBytes());
        expect(await recover([]), true);
        expect(await count(), 2);
        expect(await c.db.preference(pref), '');
      },
    );

    test(
      '$domain missing-owner retries keep one recovery chat and roll back a failed cursor write',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-photo-atomic',
        );
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
        final pref = exam
            ? ExamPhotoIntake.preference
            : StudyPhotoIntake.preference;
        await c.db.setPreference(
          pref,
          jsonEncode(
            exam
                ? {'subject': 'deleted', 'role': 'sheet'}
                : {'id': 'deleted', 'mistake': true, 'subject': '数学'},
          ),
        );
        Future<bool> recover(List<XFile> photos) => exam
            ? ExamPhotoIntake.recover(c, photos)
            : StudyPhotoIntake.recover(c, photos);
        final file = XFile('assets/demo/two_problems.png');
        await c.db.customStatement(
          "CREATE TRIGGER fail_photo_cursor BEFORE UPDATE ON preferences WHEN NEW.name='$pref' AND NEW.value LIKE '%\"files\":[]%' BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        );
        await expectLater(recover([file]), throwsA(anything));
        final recoveryId = c.selected!.id;
        expect(
          c.attachments,
          isEmpty,
          reason: 'A rolled-back import must not remain in the UI snapshot',
        );
        expect(await c.db.images(recoveryId), isEmpty);
        expect(
          await Directory('${root.path}/attachments').list().length,
          0,
          reason: 'Rolled-back imports must not leak managed files',
        );
        await c.newSession();
        final unrelated = c.selected!.id;
        await c.addImage(file.path);
        await c.db.customStatement('DROP TRIGGER fail_photo_cursor');
        expect(await recover([]), true);
        expect(c.selected!.id, recoveryId);
        expect(await c.db.images(recoveryId), hasLength(1));
        expect(await c.db.images(unrelated), hasLength(1));
        expect(await c.db.preference(pref), '');
        expect(await c.db.sessions(), hasLength(2));
      },
    );

    test(
      '$domain clears malformed recovery targets instead of looping at every launch',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-photo-invalid',
        );
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
        final pref = exam
            ? ExamPhotoIntake.preference
            : StudyPhotoIntake.preference;
        for (final invalid in ['{', '[]', '{"files":[42]}']) {
          await c.db.setPreference(pref, invalid);
          await expectLater(
            exam
                ? ExamPhotoIntake.recover(c, [])
                : StudyPhotoIntake.recover(c, []),
            throwsFormatException,
          );
          expect(await c.db.preference(pref), '');
        }
      },
    );
  }
}
