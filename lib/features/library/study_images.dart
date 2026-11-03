import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/ui/actions.dart';
import 'library_providers.dart';
import 'image_editor.dart';
import 'study_photo_intake.dart';

Future<List<XFile>> pickStudyImages() => openFiles(
  acceptedTypeGroups: [
    const XTypeGroup(
      label: '题目图片',
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
                    child: Center(child: Text('图片无法读取，原记录仍保留')),
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
                              ? '原图 · 点击查看大图'
                              : '编辑副本 · 点击查看大图',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      Semantics(
                        label: '题目图片，点击查看',
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
                                              ? '原图 · 点击查看大图'
                                              : '编辑副本 · 点击查看大图',
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => Navigator.pop(context),
                                        tooltip: '关闭预览',
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
                      if (editable)
                        TextButton.icon(
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
                                const SnackBar(
                                  content: Text('已单独创建分题记录，可在错题本查看。'),
                                ),
                              );
                            }
                          }),
                          icon: const Icon(Icons.crop, size: 16),
                          label: const Text(
                            '裁剪 / 旋转 / 分题',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (editable)
                        TextButton.icon(
                          onPressed: () => act(context, () async {
                            await store.removeImage(image);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('图片已移除，原文件仍保留'),
                                  action: SnackBarAction(
                                    label: '撤销',
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
                          label: const Text(
                            '移除图片',
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
                        title: const Text('已移除的图片'),
                        content: SizedBox(
                          width: 480,
                          height: 300,
                          child: removed.isEmpty
                              ? const Center(child: Text('没有已移除的图片'))
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
                                                ? '原图'
                                                : '编辑副本',
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
                                            child: const Text('恢复'),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                child: const Text('已移除的图片', style: TextStyle(fontSize: 12)),
              ),
            if (editable)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Platform.isAndroid
                    ? PopupMenuButton<String>(
                        tooltip: '添加题目图片',
                        onSelected: (kind) => act(context, () async {
                          if (kind == 'file') {
                            for (final file in await pickStudyImages()) {
                              await store.importImage(
                                id,
                                file.path,
                                isMistake: isMistake,
                              );
                            }
                          } else {
                            await StudyPhotoIntake.pick(
                              ref.read(appControllerProvider),
                              ownerId: id,
                              isMistake: isMistake,
                              camera: kind == 'camera',
                            );
                          }
                        }),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'camera', child: Text('拍照')),
                          PopupMenuItem(value: 'gallery', child: Text('系统相册')),
                          PopupMenuItem(value: 'file', child: Text('图片文件')),
                        ],
                        child: const Padding(
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
                              Text('添加图片'),
                            ],
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => act(context, () async {
                          for (final file in await pickStudyImages()) {
                            await store.importImage(
                              id,
                              file.path,
                              isMistake: isMistake,
                            );
                          }
                        }),
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: const Text('添加图片'),
                      ),
              ),
          ],
        );
      },
    );
  }
}
