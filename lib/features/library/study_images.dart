import '../../core/ui/app_menu.dart';

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'image_editor.dart';
import 'library_providers.dart';
import 'study_photo_intake.dart';

Future<List<XFile>> pickStudyImages(BuildContext context) => openFiles(
  acceptedTypeGroups: [
    XTypeGroup(
      label: context.tr("题目图片"),
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
                    child: Center(child: Text(context.tr("图片无法读取，原记录仍保留"))),
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
                              ? context.tr("原图 · 点击查看大图")
                              : context.tr("编辑副本 · 点击查看大图"),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Semantics(
                        label: context.tr("题目图片，点击查看"),
                        button: true,
                        child: InkWell(
                          onTap: () => showDialog<void>(
                            context: context,
                            builder: (context) => Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          image.role == 'original'
                                              ? context.tr("原图 · 点击查看大图")
                                              : context.tr("编辑副本 · 点击查看大图"),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        tooltip: context.tr("关闭预览"),
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                  Flexible(
                                    child: InteractiveViewer(
                                      child: picture(large: true),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: picture(),
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
                                  title: Text(context.tr("切换到分题对话？")),
                                  content: Text(
                                    context.tr(
                                      "当前会话有未发送的草稿或图片，开始分题会新建会话，草稿会保留在原会话中。",
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(context.tr("取消")),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.tr("开始分题")),
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
                            context.tr("AI 辅助分题"),
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
                                    context.tr("已单独创建分题记录，可在错题本查看。"),
                                  ),
                                ),
                              );
                            }
                          }),
                          icon: const Icon(Icons.crop, size: 16),
                          label: Text(
                            context.tr("裁剪 / 旋转 / 分题"),
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
                                  content: Text(context.tr("图片已移除，原文件仍保留")),
                                  action: SnackBarAction(
                                    label: context.tr("撤销"),
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
                            context.tr("移除图片"),
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
                        title: Text(context.tr("已移除的图片")),
                        content: SizedBox(
                          width: 480,
                          height: 300,
                          child: removed.isEmpty
                              ? Center(child: Text(context.tr("没有已移除的图片")))
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
                                                ? context.tr("原图")
                                                : context.tr("编辑副本"),
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
                                            child: Text(context.tr("恢复")),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text(context.tr("关闭")),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                child: Text(
                  context.tr("已移除的图片"),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (editable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Platform.isAndroid
                    ? PopupMenuButton<String>(
                        popUpAnimationStyle: menuAnimation(context),
                        tooltip: context.tr("添加题目图片"),
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
                            child: Text(context.tr("拍照")),
                          ),
                          PopupMenuItem(
                            value: 'gallery',
                            child: Text(context.tr("系统相册")),
                          ),
                          PopupMenuItem(
                            value: 'file',
                            child: Text(context.tr("图片文件")),
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
                              Text(context.tr("添加图片")),
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
                        label: Text(context.tr("添加图片")),
                      ),
              ),
          ],
        );
      },
    );
  }
}
