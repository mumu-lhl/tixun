import "dart:io";

import "package:file_selector/file_selector.dart";
import "package:flutter/services.dart";

/// Writes an exported print file to a location the user picks.
///
/// Android cannot hand out a raw path, so the generated file stays in the app
/// cache and the platform document picker copies it out; Linux uses the desktop
/// save dialog. Both paths return `false` when the user cancels.
class ExportFilePicker {
  const ExportFilePicker();

  static const _channel = MethodChannel("org.tixun/backup_files");

  Future<bool> save(
    File source, {
    required String name,
    required String extension,
    required String mimeType,
    required String label,
  }) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<bool>("saveExport", {
            "source": source.path,
            "name": name,
            "extension": extension,
            "mime": mimeType,
          }) ??
          false;
    }
    final target = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [
        XTypeGroup(
          label: label,
          extensions: [extension],
          mimeTypes: [mimeType],
        ),
      ],
    );
    if (target == null) return false;
    await XFile(source.path).saveTo(target.path);
    return true;
  }
}
