import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Future<String?> guiWindow() async {
  if (!Platform.isLinux) return null;
  final result = await Process.run('xdotool', [
    'search',
    '--onlyvisible',
    '--class',
    'org.tixun.tixun',
  ]);
  if (result.exitCode != 0) throw StateError('No visible TiXun window');
  return result.stdout.toString().trim().split('\n').first;
}

Future<void> guiCapture(String group, String name) async {
  final window = await guiWindow();
  if (window == null) return;
  await Directory('artifacts/gui-$group').create(recursive: true);
  final magick = await Process.run('which', ['magick']);
  final result = await Process.run(magick.exitCode == 0 ? 'magick' : 'import', [
    if (magick.exitCode == 0) 'import',
    '-window',
    window,
    'artifacts/gui-$group/$name.png',
  ]);
  expect(result.exitCode, 0, reason: 'Capture $name');
}

Future<void> resizeGui(WidgetTester tester, int width, int height) async {
  final window = await guiWindow();
  if (window == null) return;
  expect(
    (await Process.run('xdotool', [
      'windowsize',
      window,
      '$width',
      '$height',
    ])).exitCode,
    0,
  );
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}
