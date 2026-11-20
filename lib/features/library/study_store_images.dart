part of "study_store.dart";

mixin _StudyImages on DatabaseNotifier, _StudyQueries {
  AttachmentStore get files;

  List<StudyAttachment> preferredImages(List<StudyAttachment> images) =>
      preferredStudyImages(images);

  Future<void> restoreImage(StudyAttachment image) => runOperation(() async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(false)));
    changed();
  });

  /// Validate an already-imported file under attachments/ without copying
  /// it: it must exist, fit the 8 MB chat limit and still be a supported
  /// image. Returns the format and size to store for the new reference.
  Future<({String mime, int bytes})> checkImageFile(String relativePath) async {
    final file = files.resolve(relativePath);
    if (!await file.exists()) {
      throw const AppFormatException(
        AppErrorCode.errorTheImageFileIsMissing,
        "图片文件缺失。",
      );
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw const AppFormatException(
        AppErrorCode.errorEachImageMustBeAtMost,
        "单张图片上限为 8 MB，请先缩小图片。",
      );
    }
    final (mime, _) = AttachmentStore.identify(bytes);
    return (mime: mime, bytes: bytes.length);
  }

  /// Reference an already-imported study image from a chat session without
  /// copying its bytes again. The chat row shares the same relative path;
  /// [cleanupPurgedAttachments] keeps the file while any table still
  /// references it, so purging one side never deletes the other's image.
  Future<void> attachExistingChatImage(String sessionId, String relativePath) =>
      runOperation(() async {
        final info = await checkImageFile(relativePath);
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: const Uuid().v4(),
                sessionId: sessionId,
                relativePath: relativePath,
                mime: info.mime,
                byteLength: info.bytes,
              ),
            );
      });

  Future<StudyAttachment> importImage(
    String id,
    String path, {
    required bool isMistake,
  }) => runOperation(() async {
    if (isMistake) {
      await mistake(id);
    } else {
      await knowledge(id);
    }
    final image = await files.importFile(path);
    try {
      return await addImageReference(
        id,
        image.path,
        image.mime,
        image.bytes,
        isMistake: isMistake,
      );
    } catch (_) {
      await files.resolve(image.path).delete();
      rethrow;
    }
  });

  Future<StudyAttachment> addImageReference(
    String id,
    String path,
    String mime,
    int bytes, {
    required bool isMistake,
    String? parentId,
    String role = "original",
  }) => runOperation(() async {
    files.resolve(path);
    final row = await db.transaction(() async {
      if (!await files.resolve(path).exists()) {
        throw const AppFormatException(
          AppErrorCode.errorTheImageFileIsMissing,
          "图片文件缺失。",
        );
      }
      if (isMistake) {
        await mistake(id);
      } else {
        await knowledge(id);
      }
      final image = StudyAttachment(
        id: const Uuid().v4(),
        knowledgeId: isMistake ? null : id,
        mistakeId: isMistake ? id : null,
        relativePath: path,
        mime: mime,
        byteLength: bytes,
        parentId: parentId,
        role: role,
        deleted: false,
      );
      await db.into(db.studyAttachments).insert(image);
      return image;
    });
    changed();
    return row;
  });

  Future<void> copyChatImage(
    String id,
    Attachment image, {
    required bool isMistake,
  }) => runOperation(() async {
    final original = await originalChatImage(image, files);
    await db.transaction(() async {
      final root = await addImageReference(
        id,
        original.path,
        original.mime,
        original.bytes,
        isMistake: isMistake,
      );
      if (original.path != image.relativePath) {
        await addImageReference(
          id,
          image.relativePath,
          image.mime,
          image.byteLength,
          isMistake: isMistake,
          parentId: root.id,
          role: "crop",
        );
      }
    });
  });

  Future<void> removeImage(StudyAttachment image) => runOperation(() async {
    await (db.update(db.studyAttachments)..where((t) => t.id.equals(image.id)))
        .write(const StudyAttachmentsCompanion(deleted: Value(true)));
    changed();
  });
}
