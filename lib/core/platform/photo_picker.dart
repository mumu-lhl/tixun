import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart' as assets;
import 'package:wechat_camera_picker/wechat_camera_picker.dart' as camera;

import '../l10n/app_strings.dart';

/// Only the picker is platform-specific. Callers copy results into managed
/// storage before opening the shared crop editor; picker cache paths never persist.
Future<List<XFile>> pickPhotos(
  BuildContext context, {
  bool takePhoto = false,
  bool filesOnly = false,
}) async {
  if (!Platform.isAndroid || filesOnly) {
    final files = await openFiles(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Images',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        ),
      ],
    );
    return files;
  }
  final english = AppStrings.of(context).locale.languageCode == 'en';
  if (takePhoto) {
    String? path;
    final navigator = Navigator.of(context, rootNavigator: true);
    await camera.CameraPicker.pickFromCamera(
      context,
      pickerConfig: camera.CameraPickerConfig(
        enableAudio: false,
        enableRecording: false,
        // The app handles storage and review; no gallery write permission needed.
        shouldDeletePreviewFile: false,
        textDelegate: english
            ? const camera.EnglishCameraPickerTextDelegate()
            : const camera.CameraPickerTextDelegate(),
        onXFileCaptured: (file, type) {
          path = file.path;
          navigator.pop();
          return true;
        },
      ),
    );
    return path == null ? [] : [XFile(path!)];
  }
  final picked = await assets.AssetPicker.pickAssets(
    context,
    pickerConfig: assets.AssetPickerConfig(
      requestType: assets.RequestType.image,
      // No app-level cap: the picker's own default maxAssets applies.
      pickerTheme: Theme.of(context),
      textDelegate: english
          ? const assets.EnglishAssetPickerTextDelegate()
          : const assets.AssetPickerTextDelegate(),
    ),
  );
  final result = <XFile>[];
  for (final entity in picked ?? <assets.AssetEntity>[]) {
    final file = await entity.file;
    if (file == null) throw const FormatException('无法读取所选图片，请重新选择。');
    result.add(XFile(file.path));
  }
  return result;
}
