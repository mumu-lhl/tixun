import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

class BackupFilePicker {
  static const _channel = MethodChannel('org.tixun/backup_files');
  static Future<bool> save(File file, String name) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>('saveBackup', {
            'source': file.path,
            'name': name,
          }) ??
          false;
    }
    final target = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        const XTypeGroup(label: '题训备份', extensions: ['tixun-backup']),
      ],
    );
    if (target == null) return false;
    await XFile(file.path).saveTo(target.path);
    return true;
  }

  static Future<File?> open() async {
    final selected = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '题训备份',
          extensions: ['tixun-backup', 'zip'],
          mimeTypes: ['application/zip', 'application/octet-stream'],
        ),
      ],
    );
    return selected == null ? null : File(selected.path);
  }
}
