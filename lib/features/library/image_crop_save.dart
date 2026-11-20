part of "image_editor.dart";

extension _StudyImageSave on _StudyImageEditorState {
  Future<void> _save({bool split = false}) async {
    if (_image == null || _saving) return;
    _update(() => _saving = true);
    final store = ref.read(studyStoreProvider);
    final files = ref.read(appControllerProvider).files;
    final relative = "attachments/${const Uuid().v4()}.png";
    String? newId;
    try {
      final bytes = await renderStudyCrop(_image!, _crop, _turns);
      if (bytes.length > 8 * 1024 * 1024) {
        throw const AppFormatException(
          AppErrorCode.errorTheEditedCopyExceeds8MB,
          "编辑副本超过 8 MB，请框选更小区域后重试。",
        );
      }
      if (widget.onCreate != null) {
        final created = await widget.onCreate!(bytes, _crop, _turns);
        if (mounted) Navigator.pop(context, created);
        return;
      }
      await files.resolve(relative).writeAsBytes(bytes, flush: true);
      await store.db.transaction(() async {
        if (split) {
          final original = await store.mistakeDetail(widget.ownerId);
          final row = await store.saveMistake(
            MistakeDraft(
              title: "${original.item.title.characters.take(145)} · 分题",
              subject: original.item.subject,
              chapter: original.item.chapter,
              tags: original.tags,
            ),
          );
          newId = row.id;
          final source =
              original.images.where((i) => i.role == "original").firstOrNull ??
              widget.attachment;
          final reference = await store.addImageReference(
            row.id,
            source.relativePath,
            source.mime,
            source.byteLength,
            isMistake: true,
          );
          await store.addImageReference(
            row.id,
            relative,
            "image/png",
            bytes.length,
            isMistake: true,
            parentId: reference.id,
            role: "crop",
          );
        } else {
          await store.addImageReference(
            widget.ownerId,
            relative,
            "image/png",
            bytes.length,
            isMistake: widget.isMistake,
            parentId: widget.attachment.id,
            role: "crop",
          );
        }
      });
      store.changed();
      if (mounted) Navigator.pop(context, newId ?? widget.ownerId);
    } catch (e) {
      if (await files.resolve(relative).exists()) {
        await files.resolve(relative).delete();
      }
      if (mounted) {
        _update(
          () => _error = e is FormatException
              ? e
              : const AppFormatException(
                  AppErrorCode.errorImageCouldNotBeSaved,
                  "图片保存失败，原图没有改变。",
                ),
        );
      }
    } finally {
      if (mounted) _update(() => _saving = false);
    }
  }
}
