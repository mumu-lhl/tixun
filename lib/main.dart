import 'app/app_notice.dart';
import 'features/exams/exam_photo_intake.dart';

import 'dart:io';

import 'package:material_ui/material_ui.dart';
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
    try {
      final applied = await applyPendingUpdate();
      if (applied == ApplyResult.failed) {
        // Fall through and launch the old version; the marker is kept
        // for retry from Settings.
      }
    } catch (_) {
      // applyPendingUpdate can throw after a successful swap (e.g. the
      // new binary fails to start once the marker is deleted). There is
      // no UI yet at this point, so fall through and launch the old
      // version instead of exiting without a window.
    }
    try {
      await cleanupOldBundle();
    } catch (_) {
      // Best effort: a stale .old must not block startup.
    }
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
  HostFailure? failure;
  try {
    await BackupService.recoverPending(root);
    c = await AppController.openRoot(root, demo: demo, seed: demo);
    if (Platform.isAndroid && !demo) {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (lost.files?.isNotEmpty != true) {
          // Retry saved batches after retrieveLostData has consumed its result.
          await ExamPhotoIntake.recover(c, []);
          await StudyPhotoIntake.recover(c, []);
        }
        if (lost.files?.isNotEmpty == true) {
          if (!await ExamPhotoIntake.recover(c, lost.files!) &&
              !await StudyPhotoIntake.recover(c, lost.files!)) {
            if (c.selected == null) await c.newSession();
            for (final image in lost.files!) {
              await c.addImage(image.path);
            }
            c.notice = const AppNotice(AppNoticeKind.interruptedImageRestored);
          }
        }
        if (lost.exception != null) {
          c.notice = const AppNotice(AppNoticeKind.imageSelectionIncomplete);
        }
      } catch (_) {
        c.notice = const AppNotice(AppNoticeKind.imageRecoveryFailed);
      }
    }
  } catch (_) {
    failure = HostFailure.initialOpen;
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
