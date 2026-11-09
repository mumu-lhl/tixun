import 'features/exams/exam_photo_intake.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'app/app_host.dart';
import 'app/controller.dart';
import 'app/theme.dart';
import 'core/backup/backup_service.dart';
import 'features/library/study_photo_intake.dart';
import 'features/update/linux_staging.dart';

Future<void> main() async {
  if (Platform.isLinux) {
    final applied = await applyPendingUpdate();
    if (applied == ApplyResult.failed) {
      // Fall through and launch the old version; the marker is kept
      // for retry from Settings.
    }
    await cleanupOldBundle();
  }
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('TIXUN_DEMO');
  late final Directory root;
  RandomAccessFile? instance;
  try {
    root = await AppController.rootDirectory(demo: demo);
    await root.parent.create(recursive: true);
    instance = await File(
      p.join(root.parent.path, '.${p.basename(root.path)}.instance.lock'),
    ).open(mode: FileMode.append);
    await instance.lock(FileLock.exclusive);
  } catch (_) {
    await instance?.close();
    runApp(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '无法独占打开应用数据。请关闭其他题训窗口，并检查应用目录权限。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: main, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  AppController? c;
  String? failure;
  try {
    await BackupService.recoverPending(root);
    c = await AppController.openRoot(root, demo: demo, seed: demo);
    if (Platform.isAndroid && !demo) {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (lost.files?.isNotEmpty == true) {
          if (!await ExamPhotoIntake.recover(c, lost.files!) &&
              !await StudyPhotoIntake.recover(c, lost.files!)) {
            if (c.selected == null) await c.newSession();
            for (final image in lost.files!) {
              await c.addImage(image.path);
            }
            c.notice = '已将中断选择的图片恢复到对话草稿，请检查后发送。';
          }
        }
        if (lost.files?.isNotEmpty != true) {
          await c.db.setPreference(StudyPhotoIntake.preference, '');
          await c.db.setPreference(ExamPhotoIntake.preference, '');
        }
        if (lost.exception != null) c.notice = '上次图片选择未完成，请重新选择。';
      } catch (_) {
        c.notice = '未能恢复上次选取的图片，请重新选择。已有学习记录未改变。';
      }
    }
  } catch (_) {
    failure = '无法打开本地学习数据库。请检查存储空间和目录权限，或从备份恢复。已有文件没有自动删除。';
  }
  runApp(
    TixunHost(
      root: root,
      demo: demo,
      initialController: c,
      instanceLock: instance,
      initialError: failure,
    ),
  );
  if (c != null) debugPrint('TIXUN_READY demo=$demo');
}
