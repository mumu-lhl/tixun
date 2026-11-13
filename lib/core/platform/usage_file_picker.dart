import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class UsageFilePicker {
  static const _channel = MethodChannel('org.tixun/backup_files');

  static Future<bool> save(String contents, {required String extension}) async {
    if (!{'csv', 'jsonl'}.contains(extension)) {
      throw ArgumentError.value(extension, 'extension');
    }
    final name = 'tixun-ai-usage.$extension';
    if (Platform.isAndroid) {
      final cache = await getTemporaryDirectory();
      final source = File(p.join(cache.path, name));
      await source.writeAsString(
        extension == 'csv' ? '\uFEFF$contents' : contents,
        flush: true,
      );
      try {
        return await _channel.invokeMethod<bool>('saveUsage', {
              'source': source.path,
              'name': name,
            }) ??
            false;
      } finally {
        if (await source.exists()) await source.delete();
      }
    }
    final target = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'AI usage',
          extensions: [extension],
          mimeTypes: [extension == 'csv' ? 'text/csv' : 'application/json'],
        ),
      ],
    );
    if (target == null) return false;
    await File(target.path).writeAsString(
      extension == 'csv' ? '\uFEFF$contents' : contents,
      flush: true,
    );
    return true;
  }
}
