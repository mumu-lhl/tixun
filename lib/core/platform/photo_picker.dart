import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart' as assets;
import 'package:image_picker/image_picker.dart' as system;

import '../l10n/app_strings.dart';

/// Only the picker is platform-specific. Callers copy results into managed
/// storage before opening the shared crop editor; picker cache paths never persist.
Future<List<XFile>> pickPhotos(
  BuildContext context, {
  bool takePhoto = false,
  bool filesOnly = false,
}) async {
  if (defaultTargetPlatform != TargetPlatform.android || filesOnly) {
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
    // Let the device's camera app own preview and camera permissions. Some
    // Android devices display a black embedded CameraX preview without errors.
    try {
      final file = await system.ImagePicker().pickImage(
        source: system.ImageSource.camera,
      );
      return file == null ? [] : [XFile(file.path)];
    } on PlatformException {
      throw const FormatException('无法打开系统相机或完成拍照，请检查系统相机权限，或改用相册 / 图片文件。');
    }
  }
  final picked = await assets.AssetPicker.pickAssets(
    context,
    pickerConfig: assets.AssetPickerConfig(
      requestType: assets.RequestType.image,
      // The API requires a positive int. Avoid its implicit 9-photo cap.
      maxAssets: 0x7fffffff,
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
