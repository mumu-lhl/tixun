import '../../core/ui/app_menu.dart';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/image_viewer.dart';
import 'image_editor.dart';
import 'library_providers.dart';
import 'study_photo_intake.dart';

Future<List<XFile>> pickStudyImages(BuildContext context) => openFiles(
  acceptedTypeGroups: [
    XTypeGroup(
      label: context.l10n.questionImage,
      extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    ),
  ],
);

class StudyImages extends ConsumerWidget {
  const StudyImages({
    required this.id,
    required this.isMistake,
    required this.images,
    this.editable = true,
    super.key,
  });
  final String id;
  final bool isMistake, editable;
  final List<StudyAttachment> images;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.read(appControllerProvider).files;
    final store = ref.read(studyStoreProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = images.length == 1
            ? constraints.maxWidth.clamp(160.0, 640.0)
            : constraints.maxWidth.clamp(160.0, 220.0);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: images.map((image) {
                final file = files.resolve(image.relativePath);
                Widget picture({bool large = false}) => Image.file(
                  file,
                  cacheWidth: large
                      ? 1600
                      : images.length == 1
                      ? 1200
                      : 600,
                  width: large ? null : tileWidth,
                  height: large ? null : tileWidth * .7,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => SizedBox(
                    width: tileWidth,
                    height: tileWidth * .7,
                    child: Center(
                      child: Text(context.l10n.couldNotReadImageThe),
                    ),
                  ),
                );
                return SizedBox(
                  width: tileWidth,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          image.role == 'original'
                              ? context.l10n.originalTapToEnlarge
                              : context.l10n.editedCopyTapToEnlarge,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Semantics(
                        label: context.l10n.questionImageTapToView,
                        button: true,
                        child: InkWell(
                          onTap: () => showImageViewer(
                            context,
                            images: [
                              for (final item in images)
                                ImageViewerItem(
                                  file: files.resolve(item.relativePath),
                                  heroTag: 'study-image-${item.id}',
                                  cacheWidth: 1600,
                                  errorText: context.l10n.couldNotReadImageThe,
                                ),
                            ],
                            initialIndex: images.indexWhere(
                              (item) => item.id == image.id,
                            ),
                            title: image.role == 'original'
                                ? context.l10n.originalTapToEnlarge
                                : context.l10n.editedCopyTapToEnlarge,
                          ),
                          child: Hero(
                            tag: 'study-image-${image.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: picture(),
                            ),
                          ),
                        ),
                      ),
                      if (editable && isMistake)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => act(context, () async {
                            final c = ref.read(appControllerProvider);
                            final hasDraft =
                                c.selected != null &&
                                (c.selected!.draft.isNotEmpty ||
                                    c.attachments.any(
                                      (a) => a.messageId == null,
                                    ));
                            if (hasDraft) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    context.l10n.switchToTheSplittingChat,
                                  ),
                                  content: Text(
                                    context.l10n.thisSessionHasAnUnsent,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.l10n.startSplitting),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                            }
                            await c.newSession();
                            await c.renameSession(c.selected!, '图片分题 · 检查与整理');
                            await c.addImage(
                              files.resolve(image.relativePath).path,
                            );
                            await c.useToolReasoning();
                            await c.draft(c.prompts.text('split'));
                            if (context.mounted) context.go('/chat');
                          }),
                          icon: const Icon(
                            Icons.auto_awesome_outlined,
                            size: 16,
                          ),
                          label: Text(
                            context.l10n.aiQuestionSplitting,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (editable)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => act(context, () async {
                            final selected = await showDialog<String>(
                              context: context,
                              useSafeArea: false,
                              builder: (_) => StudyImageEditor(
                                attachment: image,
                                ownerId: id,
                                isMistake: isMistake,
                              ),
                            );
                            if (selected != null &&
                                selected != id &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.aSeparateSplitQuestionHas,
                                  ),
                                ),
                              );
                            }
                          }),
                          icon: const Icon(Icons.crop, size: 16),
                          label: Text(
                            context.l10n.cropRotateSplit,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (editable)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: () => act(context, () async {
                            await store.removeImage(image);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.imageRemovedTheOriginalFile,
                                  ),
                                  action: SnackBarAction(
                                    label: context.l10n.undo,
                                    onPressed: () => act(
                                      context,
                                      () => store.restoreImage(image),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }),
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 16,
                          ),
                          label: Text(
                            context.l10n.removeImage,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (editable)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => act(context, () async {
                  final removed = await store.images(
                    id,
                    isMistake: isMistake,
                    trash: true,
                  );
                  if (!context.mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => StatefulBuilder(
                      builder: (context, update) => AlertDialog(
                        title: Text(context.l10n.removedImages),
                        content: SizedBox(
                          width: 480,
                          height: 300,
                          child: removed.isEmpty
                              ? Center(
                                  child: Text(context.l10n.noRemovedImages),
                                )
                              : ListView(
                                  children: removed
                                      .map(
                                        (image) => ListTile(
                                          leading: Image.file(
                                            files.resolve(image.relativePath),
                                            width: 64,
                                            height: 48,
                                            cacheWidth: 160,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                ),
                                          ),
                                          title: Text(
                                            image.role == 'original'
                                                ? context.l10n.original
                                                : context.l10n.editedCopy,
                                          ),
                                          trailing: TextButton(
                                            onPressed: () => act(
                                              context,
                                              () async {
                                                await store.restoreImage(image);
                                                if (context.mounted) {
                                                  update(
                                                    () => removed.removeWhere(
                                                      (r) => r.id == image.id,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                            child: Text(context.l10n.restore),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(context.l10n.close),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                child: Text(
                  context.l10n.removedImages,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (editable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Platform.isAndroid
                    ? PopupMenuButton<String>(
                        popUpAnimationStyle: menuAnimation(context),
                        tooltip: context.l10n.addQuestionImage,
                        onSelected: (kind) => act(context, () async {
                          if (kind == 'file') {
                            if (!context.mounted) return;
                            final picked = await pickStudyImages(context);
                            for (final file in picked) {
                              final image = await store.importImage(
                                id,
                                file.path,
                                isMistake: isMistake,
                              );
                              if (context.mounted) {
                                await cropImportedStudyPhoto(
                                  context,
                                  id,
                                  image,
                                  isMistake: isMistake,
                                );
                              }
                            }
                          } else {
                            await StudyPhotoIntake.pick(
                              ref.read(appControllerProvider),
                              context: context,
                              ownerId: id,
                              isMistake: isMistake,
                              camera: kind == 'camera',
                            );
                          }
                        }),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'camera',
                            child: Text(context.l10n.takePhoto),
                          ),
                          PopupMenuItem(
                            value: 'gallery',
                            child: Text(context.l10n.photoLibrary),
                          ),
                          PopupMenuItem(
                            value: 'file',
                            child: Text(context.l10n.imageFiles),
                          ),
                        ],
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(context.l10n.addPhotos),
                            ],
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => act(context, () async {
                          if (!context.mounted) return;
                          final picked = await pickStudyImages(context);
                          for (final file in picked) {
                            final image = await store.importImage(
                              id,
                              file.path,
                              isMistake: isMistake,
                            );
                            if (context.mounted) {
                              await cropImportedStudyPhoto(
                                context,
                                id,
                                image,
                                isMistake: isMistake,
                              );
                            }
                          }
                        }),
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.addPhotos),
                      ),
              ),
          ],
        );
      },
    );
  }
}
