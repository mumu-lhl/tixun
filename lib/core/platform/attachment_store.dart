import 'package:tixun/core/l10n/app_error.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

class ImportedImage {
  const ImportedImage(this.path, this.mime, this.bytes);
  final String path;
  final String mime;
  final int bytes;
}

/// The database stores relative paths only. Originals never depend on picker cache.
class AttachmentStore {
  AttachmentStore(this.root);
  final Directory root;
  File resolve(String relative) {
    final target = p.normalize(p.join(root.path, relative));
    if (!p.isWithin(root.path, target))
      throw const AppFormatException(
        AppErrorCode.errorInvalidAttachmentPath,
        '附件路径无效',
      );
    return File(target);
  }

  Future<ImportedImage> importFile(String source) async {
    final file = File(source);
    final size = await file.length();
    if (size > 8 * 1024 * 1024) {
      throw const AppFormatException(
        AppErrorCode.errorEachImageMustBeAtMost,
        '单张图片上限为 8 MB，请先缩小图片。',
      );
    }
    final data = await file.readAsBytes();
    final (mime, ext) = identify(data);
    final relative = p.join('attachments', '${const Uuid().v4()}.$ext');
    final target = resolve(relative);
    await target.parent.create(recursive: true);
    await target.writeAsBytes(data, flush: true);
    return ImportedImage(relative, mime, size);
  }

  static (String, String) identify(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 137 &&
        b[1] == 80 &&
        b[2] == 78 &&
        b[3] == 71) {
      return ('image/png', 'png');
    }
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255) {
      return ('image/jpeg', 'jpg');
    }
    if (b.length >= 6 && String.fromCharCodes(b.take(6)).startsWith('GIF8')) {
      return ('image/gif', 'gif');
    }
    if (b.length >= 12 &&
        String.fromCharCodes(b.take(4)) == 'RIFF' &&
        String.fromCharCodes(b.skip(8).take(4)) == 'WEBP') {
      return ('image/webp', 'webp');
    }
    throw const AppFormatException(
      AppErrorCode.errorOnlyJPGPNGGIFAndWebP,
      '仅支持 JPG、PNG、GIF 和 WebP 图片。',
    );
  }
}
