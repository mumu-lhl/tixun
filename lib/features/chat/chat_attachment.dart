part of "chat_screen.dart";

class AttachmentImage extends ConsumerWidget {
  const AttachmentImage({
    required this.attachment,
    required this.width,
    required this.height,
    super.key,
  });
  final Attachment attachment;
  final double width, height;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appControllerProvider);
    final file = c.files.resolve(attachment.relativePath);
    Widget picture({bool preview = false}) => Image.file(
      file,
      width: preview ? null : width,
      height: preview ? null : height,
      fit: BoxFit.contain,
      cacheWidth: preview ? 1600 : 500,
      errorBuilder: (_, _, _) => SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(
            context.l10n.couldNotReadImage,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
    return Semantics(
      label: context.l10n.questionImageTapToPreview,
      button: true,
      child: InkWell(
        onTap: () {
          final siblings = c.attachments
              .where((a) => a.messageId == attachment.messageId)
              .toList();
          final index = siblings.indexWhere((a) => a.id == attachment.id);
          unawaited(
            showImageViewer(
              context,
              images: [
                for (final a in siblings)
                  ImageViewerItem(
                    file: c.files.resolve(a.relativePath),
                    heroTag: "chat-image-${a.id}",
                    cacheWidth: 1600,
                  ),
              ],
              initialIndex: index < 0 ? 0 : index,
              title: attachment.originalPath == null
                  ? context.l10n.originalImagePreview
                  : context.l10n.outgoingImagePreview,
              actions: (closeViewer) => [
                if (attachment.originalPath != null)
                  TextButton(
                    onPressed: () => showImageViewer(
                      context,
                      images: [
                        ImageViewerItem(
                          file: c.files.resolve(attachment.originalPath!),
                          cacheWidth: 1600,
                          errorText: context.l10n.couldNotReadOriginalImage,
                        ),
                      ],
                      title: context.l10n.preservedOriginal,
                    ),
                    child: Text(context.l10n.viewPreservedOriginal),
                  ),
                if (attachment.messageId == null)
                  TextButton.icon(
                    key: Key("edit-draft-image-${attachment.id}"),
                    onPressed: c.busy
                        ? null
                        : () => act(context, () async {
                            closeViewer();
                            await editChatPhoto(context, c, attachment);
                          }),
                    icon: const Icon(Icons.crop, size: 18),
                    label: Text(context.l10n.cropRotateResize),
                  ),
              ],
              footnote: context.l10n.theOriginalIsKeptSeparately,
            ),
          );
        },
        child: Hero(
          tag: "chat-image-${attachment.id}",
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: picture(),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> editChatPhoto(
  BuildContext context,
  AppController c,
  Attachment image,
) async {
  await showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => StudyImageEditor(
      attachment: StudyAttachment(
        id: image.id,
        relativePath: image.relativePath,
        mime: image.mime,
        byteLength: image.byteLength,
        role: "original",
        deleted: false,
      ),
      isMistake: true,
      title: context.l10n.editPhoto,
      createLabel: context.l10n.useEditedPhoto,
      allowSplit: false,
      onCreate: (bytes, _, _) => c.replaceDraftImage(image, bytes),
    ),
  );
}
