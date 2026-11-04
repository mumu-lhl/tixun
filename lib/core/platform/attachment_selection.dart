import '../database/database.dart';
import 'attachment_store.dart';

/// Input is in creation order. Keep the newest surviving edit per original.
List<StudyAttachment> preferredStudyImages(List<StudyAttachment> images) {
  final byId = {for (final image in images) image.id: image},
      selected = <String, StudyAttachment>{};
  for (final image in images.where((i) => !i.deleted)) {
    var root = image, key = image.id;
    final seen = <String>{};
    while (root.parentId != null && seen.add(root.id)) {
      key = root.parentId!;
      final parent = byId[key];
      if (parent == null) break;
      root = parent;
    }
    selected[key] = image;
  }
  return selected.values.toList();
}

Future<ImportedImage> originalChatImage(
  Attachment image,
  AttachmentStore files,
) async {
  final path = image.originalPath;
  if (path == null || path == image.relativePath) {
    return ImportedImage(image.relativePath, image.mime, image.byteLength);
  }
  final file = files.resolve(path), handle = await files.resolve(path).open();
  try {
    final (mime, _) = AttachmentStore.identify(await handle.read(16));
    return ImportedImage(path, mime, await file.length());
  } finally {
    await handle.close();
  }
}
