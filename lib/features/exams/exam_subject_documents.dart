part of "exam_subject_screen.dart";

extension _ExamSubjectDocuments on ExamSubjectScreen {
  Widget _documents(
    AppController c,
    ExamSubject subject,
  ) => CachedStreamBuilder<List<ExamAttachment>>(
    owner: c.exams,
    cacheKey: ("attachments", id),
    stream:
        (c.db.select(c.db.examAttachments)
              ..where((t) => t.subjectId.equals(id))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .watch(),
    builder: (ctx, images) {
      if (images.hasError) {
        return Text(ctx.l10n.couldNotLoadPhotosPlease);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final role in examImageRoles.entries)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        examImageRoleLabel(ctx, role.key),
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    if (Platform.isAndroid)
                      IconButton(
                        tooltip: ctx.l10n.takePhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        onPressed: () => act(
                          ctx,
                          () => _pick(ctx, c, role.key, camera: true),
                        ),
                      ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(ctx.l10n.addPhotos),
                      onPressed: () => act(ctx, () => _pick(ctx, c, role.key)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final image
                        in (images.data ?? <ExamAttachment>[]).where(
                          (i) => i.role == role.key,
                        ))
                      SizedBox(
                        width: 140,
                        height: 110,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              InkWell(
                                key: Key("exam-image-preview-${image.id}"),
                                onTap: () {
                                  final roleImages =
                                      (images.data ?? <ExamAttachment>[])
                                          .where((i) => i.role == role.key)
                                          .toList();
                                  unawaited(
                                    showImageViewer(
                                      ctx,
                                      images: [
                                        for (final item in roleImages)
                                          ImageViewerItem(
                                            file: c.files.resolve(
                                              item.relativePath,
                                            ),
                                            heroTag: "exam-image-${item.id}",
                                            cacheWidth: 2000,
                                            errorText:
                                                ctx.l10n.couldNotReadImageThe,
                                          ),
                                      ],
                                      initialIndex: roleImages.indexWhere(
                                        (i) => i.id == image.id,
                                      ),
                                      title: examImageRoleLabel(ctx, role.key),
                                    ),
                                  );
                                },
                                child: Hero(
                                  tag: "exam-image-${image.id}",
                                  child: Image.file(
                                    c.files.resolve(image.relativePath),
                                    width: 140,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    cacheWidth: 400,
                                    errorBuilder: (_, _, _) => SizedBox(
                                      height: 110,
                                      child: Center(
                                        child: Text(
                                          ctx.l10n.couldNotReadImageThe,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Theme.of(ctx).colorScheme.surface
                                      .withValues(alpha: .92),
                                  shape: const CircleBorder(),
                                  child: PopupMenuButton<String>(
                                    key: Key("exam-image-menu-${image.id}"),
                                    tooltip: ctx.l10n.imageActions,
                                    popUpAnimationStyle: menuAnimation(ctx),
                                    position: PopupMenuPosition.under,
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (action) =>
                                        _imageAction(ctx, c, image, action),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: "edit",
                                        child: Text(ctx.l10n.cropRotateResize),
                                      ),
                                      if (image.originalPath != null)
                                        PopupMenuItem(
                                          value: "original",
                                          child: Text(
                                            ctx.l10n.viewPreservedOriginal,
                                          ),
                                        ),
                                      const PopupMenuDivider(),
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Text(
                                          ctx.l10n.deleteImage,
                                          style: TextStyle(
                                            color: Theme.of(ctx)
                                                .colorScheme
                                                .error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          const Divider(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key("exam-edit-scores"),
                onPressed: () => Navigator.of(ctx, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ScoreEditor(subject: subject),
                  ),
                ),
                icon: const Icon(Icons.table_rows_outlined),
                label: Text(ctx.l10n.editQuestionMarks),
              ),
              OutlinedButton.icon(
                onPressed: (images.data ?? []).isEmpty
                    ? null
                    : () => Navigator.of(ctx, rootNavigator: true).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ExamAiScreen(
                            subject: subject,
                            images: images.data!,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(ctx.l10n.extractQuestionMarksWithAI),
              ),
            ],
          ),
        ],
      );
    },
  );
}
