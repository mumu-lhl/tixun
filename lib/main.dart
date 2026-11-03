import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'app/app.dart';
import 'app/controller.dart';
import 'app/theme.dart';
import 'features/library/study_photo_intake.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('TIXUN_DEMO');
  try {
    final c = await AppController.open(demo: demo);
    if (Platform.isAndroid && !demo) {
      try {
        final lost = await ImagePicker().retrieveLostData();
        if (lost.files?.isNotEmpty == true) {
          if (!await StudyPhotoIntake.recover(c, lost.files!)) {
            if (c.selected == null) await c.newSession();
            for (final image in lost.files!) {
              await c.addImage(image.path);
            }
            c.notice = '已将中断选择的图片恢复到对话草稿，请检查后发送。';
          }
        }
        if (lost.files?.isNotEmpty != true) {
          await c.db.setPreference(StudyPhotoIntake.preference, '');
        }
        if (lost.exception != null) c.notice = '上次图片选择未完成，请重新选择。';
      } catch (_) {
        c.notice = '未能恢复上次选取的图片，请重新选择。已有学习记录未改变。';
      }
    }
    runApp(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
        child: const TixunApp(),
      ),
    );
    // A non-sensitive readiness marker used by the GUI smoke test.
    debugPrint('TIXUN_READY demo=$demo');
  } catch (_) {
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
                  const Icon(Icons.storage_outlined, size: 40),
                  const SizedBox(height: 20),
                  const Text(
                    '无法打开本地学习数据库。\n请检查存储空间与应用目录权限。\n应用不会自动删除或重置你的数据。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: main, child: const Text('重试')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
