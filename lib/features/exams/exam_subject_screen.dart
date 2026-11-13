import '../../core/ui/app_menu.dart';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/ai/ai_options.dart';
import '../../core/ai/ai_usage_store.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/reasoning_labels.dart';
import '../../core/ui/image_viewer.dart';
import '../../core/ui/reasoning_panel.dart';
import 'exam_photo_intake.dart';
import 'exam_ai.dart';
import 'exam_calendar.dart';
import 'exam_detail.dart';
import 'exam_localization.dart';
import 'exam_store.dart';
import 'score_editor.dart';
import 'exam_image_editor.dart';
import '../../core/platform/photo_picker.dart';

class ExamSubjectScreen extends ConsumerWidget {
  const ExamSubjectScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return StreamBuilder<ExamSubject?>(
      stream: (c.db.select(
        c.db.examSubjects,
      )..where((t) => t.id.equals(id))).watchSingleOrNull(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text(context.l10n.couldNotLoadExamRecords));
        }
        if (!snap.hasData) {
          return Center(
            child: Text(
              snap.connectionState == ConnectionState.waiting
                  ? context.l10n.loadingEllipsis
                  : context.l10n.recordNotFound,
            ),
          );
        }
        final subject = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BackButton(),
                        Expanded(
                          child: Text(
                            context.subjectName(subject.subject),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              editSubject(context, c, subject.eventId, subject),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(context.l10n.editScores),
                        ),
                        IconButton(
                          tooltip: context.l10n.deleteSubject,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: Text(d.l10n.deleteSubject),
                                content: Text(d.l10n.thisDeletesThisSubjectS),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: Text(d.l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(d, true),
                                    child: Text(d.l10n.delete),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true && context.mounted) {
                              await act(context, () async {
                                await c.exams.deleteSubject(id);
                                if (context.mounted) {
                                  context.go('/exams/${subject.eventId}');
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${context.l10n.rawScore} ${points(subject.rawScore)}${subject.maximum == null ? '' : ' / ${points(subject.maximum)}'}${subject.usesScaling ? ' · ${context.l10n.scaledScore} ${points(subject.scaledScore)}' : ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (subject.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(subject.notes),
                      ),
                    const Divider(height: 32),
                    Text(
                      context.l10n.examDocuments,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(context.l10n.originalPhotosAreStoredLocally),
                    StreamBuilder<List<ExamAttachment>>(
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
                                          style: Theme.of(ctx)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                      ),
                                      if (Platform.isAndroid)
                                        IconButton(
                                          tooltip: ctx.l10n.takePhoto,
                                          icon: const Icon(
                                            Icons.photo_camera_outlined,
                                          ),
                                          onPressed: () => act(
                                            ctx,
                                            () => _pick(
                                              ctx,
                                              c,
                                              role.key,
                                              camera: true,
                                            ),
                                          ),
                                        ),
                                      TextButton.icon(
                                        icon: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                        ),
                                        label: Text(ctx.l10n.addPhotos),
                                        onPressed: () => act(
                                          ctx,
                                          () => _pick(ctx, c, role.key),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final image
                                          in (images.data ?? <ExamAttachment>[])
                                              .where((i) => i.role == role.key))
                                        SizedBox(
                                          width: 140,
                                          height: 110,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                InkWell(
                                                  key: Key(
                                                    'exam-image-preview-${image.id}',
                                                  ),
                                                  onTap: () {
                                                    final roleImages =
                                                        (images.data ??
                                                                <
                                                                  ExamAttachment
                                                                >[])
                                                            .where(
                                                              (i) =>
                                                                  i.role ==
                                                                  role.key,
                                                            )
                                                            .toList();
                                                    showImageViewer(
                                                      ctx,
                                                      images: [
                                                        for (final item
                                                            in roleImages)
                                                          ImageViewerItem(
                                                            file: c.files.resolve(
                                                              item.relativePath,
                                                            ),
                                                            heroTag:
                                                                'exam-image-${item.id}',
                                                            cacheWidth: 2000,
                                                            errorText: ctx
                                                                .l10n
                                                                .couldNotReadImageThe,
                                                          ),
                                                      ],
                                                      initialIndex: roleImages
                                                          .indexWhere(
                                                            (i) =>
                                                                i.id ==
                                                                image.id,
                                                          ),
                                                      title: examImageRoleLabel(
                                                        ctx,
                                                        role.key,
                                                      ),
                                                    );
                                                  },
                                                  child: Hero(
                                                    tag:
                                                        'exam-image-${image.id}',
                                                    child: Image.file(
                                                      c.files.resolve(
                                                        image.relativePath,
                                                      ),
                                                      width: 140,
                                                      height: 110,
                                                      fit: BoxFit.cover,
                                                      cacheWidth: 400,
                                                      errorBuilder: (_, _, _) =>
                                                          SizedBox(
                                                            height: 110,
                                                            child: Center(
                                                              child: Text(
                                                                ctx
                                                                    .l10n
                                                                    .couldNotReadImageThe,
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
                                                    color: Theme.of(ctx)
                                                        .colorScheme
                                                        .surface
                                                        .withValues(alpha: .92),
                                                    shape: const CircleBorder(),
                                                    child: PopupMenuButton<String>(
                                                      key: Key(
                                                        'exam-image-menu-${image.id}',
                                                      ),
                                                      tooltip:
                                                          ctx.l10n.imageActions,
                                                      popUpAnimationStyle:
                                                          menuAnimation(ctx),
                                                      position:
                                                          PopupMenuPosition
                                                              .under,
                                                      icon: const Icon(
                                                        Icons.more_vert,
                                                        size: 20,
                                                      ),
                                                      onSelected: (action) =>
                                                          _imageAction(
                                                            ctx,
                                                            c,
                                                            image,
                                                            action,
                                                          ),
                                                      itemBuilder: (_) => [
                                                        PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text(
                                                            ctx
                                                                .l10n
                                                                .cropRotateResize,
                                                          ),
                                                        ),
                                                        if (image
                                                                .originalPath !=
                                                            null)
                                                          PopupMenuItem(
                                                            value: 'original',
                                                            child: Text(
                                                              ctx
                                                                  .l10n
                                                                  .viewPreservedOriginal,
                                                            ),
                                                          ),
                                                        const PopupMenuDivider(),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            ctx
                                                                .l10n
                                                                .deleteImage,
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
                                  key: const Key('exam-edit-scores'),
                                  onPressed: () =>
                                      Navigator.of(
                                        ctx,
                                        rootNavigator: true,
                                      ).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              ScoreEditor(subject: subject),
                                        ),
                                      ),
                                  icon: const Icon(Icons.table_rows_outlined),
                                  label: Text(ctx.l10n.editQuestionMarks),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (images.data ?? []).isEmpty
                                      ? null
                                      : () =>
                                            Navigator.of(
                                              ctx,
                                              rootNavigator: true,
                                            ).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) => ExamAiScreen(
                                                  subject: subject,
                                                  images: images.data!,
                                                ),
                                              ),
                                            ),
                                  icon: const Icon(Icons.auto_awesome_outlined),
                                  label: Text(
                                    ctx.l10n.extractQuestionMarksWithAI,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    if (subject.aiReasoning.isNotEmpty)
                      ReasoningPanel(text: subject.aiReasoning),
                    const SizedBox(height: 16),
                    StreamBuilder<List<ExamScoreRow>>(
                      stream:
                          (c.db.select(c.db.examScoreRows)
                                ..where((t) => t.subjectId.equals(id))
                                ..orderBy([
                                  (t) => OrderingTerm.asc(t.position),
                                ]))
                              .watch(),
                      builder: (ctx, snap) {
                        if (snap.hasError) {
                          return Text(ctx.l10n.couldNotLoadQuestionMarks);
                        }
                        final rows = snap.data ?? [];
                        final drafts = rows
                            .map(
                              (r) => ScoreDraft(
                                id: r.id,
                                parentId: r.parentId,
                                label: r.label,
                                earned: r.earned,
                                maximum: r.maximum,
                              ),
                            )
                            .toList();
                        final (earned, maximum, complete) = scoreTotals(drafts);
                        final parents = rows
                            .map((r) => r.parentId)
                            .nonNulls
                            .toSet();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rows.isEmpty)
                              Text(ctx.l10n.noQuestionMarksYetEnter),
                            if (rows.isNotEmpty)
                              Text(
                                '${ctx.l10n.breakdownTotal} ${points(earned)} / ${rows.any((r) => !parents.contains(r.id) && r.maximum == null) ? '—' : points(maximum)} · ${(complete ? ctx.l10n.allMarksEntered : ctx.l10n.unknownMarksTotalIsIncomplete)}',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            if (subject.rawScore != null &&
                                complete &&
                                (earned - subject.rawScore!).abs() > .001)
                              Text(
                                ctx.l10n.theBreakdownDiffersFromThe,
                                style: TextStyle(
                                  color: Theme.of(ctx).colorScheme.error,
                                ),
                              ),
                            for (final row in rows)
                              ListTile(
                                contentPadding: EdgeInsets.only(
                                  left: row.parentId == null ? 0 : 24,
                                ),
                                title: Text(row.label),
                                subtitle: row.note.isEmpty
                                    ? null
                                    : Text(row.note),
                                trailing: Text(
                                  parents.contains(row.id)
                                      ? ctx.l10n.subquestionTotal
                                      : '${points(row.earned)} / ${points(row.maximum)}',
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _imageAction(
    BuildContext context,
    AppController c,
    ExamAttachment image,
    String action,
  ) async {
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await act(context, () => editExamPhoto(context, c, image));
      case 'original':
        if (image.originalPath == null) return;
        await showImageViewer(
          context,
          images: [
            ImageViewerItem(
              file: c.files.resolve(image.originalPath!),
              cacheWidth: 1600,
              errorText: context.l10n.couldNotReadOriginalImage,
            ),
          ],
          title: context.l10n.preservedOriginal,
        );
      case 'delete':
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(d.l10n.deleteImage),
            content: Text(d.l10n.deleteThisLocallyStoredPhoto),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(d.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(d.l10n.delete),
              ),
            ],
          ),
        );
        if (yes == true && context.mounted) {
          await act(context, () => c.exams.deleteImage(image));
        }
    }
  }

  Future<void> _pick(
    BuildContext context,
    AppController c,
    String role, {
    bool camera = false,
  }) async {
    if (Platform.isAndroid) {
      await ExamPhotoIntake.pick(c, id, role, context: context, camera: camera);
    } else {
      final files = await pickPhotos(context);
      final added = <ExamAttachment>[];
      for (final file in files) {
        added.add(await c.exams.addImage(id, role, file.path));
      }
      for (final image in added) {
        if (!context.mounted) break;
        await editExamPhoto(context, c, image);
      }
    }
  }
}

class ExamAiScreen extends ConsumerStatefulWidget {
  const ExamAiScreen({required this.subject, required this.images, super.key});
  final ExamSubject subject;
  final List<ExamAttachment> images;
  @override
  ConsumerState<ExamAiScreen> createState() => _ExamAiState();
}

class _ExamAiState extends ConsumerState<ExamAiScreen> {
  final selected = <String>{};
  final cancel = CancelToken();
  bool busy = false;
  String reasoning = '', effort = '';
  String? error;
  List<ScoreDraft>? proposal;
  @override
  void initState() {
    super.initState();
    selected.addAll(
      widget.images.where((i) => i.role != 'paper').map((i) => i.id),
    );
  }

  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final config = AiOptions.forSession(c.config, effort);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.extractQuestionMarksWithAI)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.l10n.onlyTheSelectedPhotosWill),
          if (c.demo) Text(context.l10n.mockModeDoesNotGrade),
          if (!AiOptions(config).vision)
            Text(context.l10n.modelDoesNotSupportImages),
          AppSelectField<String>(
            initialValue: effort,
            decoration: InputDecoration(
              labelText: context.l10n.reasoningEffort,
            ),
            items: [
              for (final e in {
                '': context.l10n.useGlobalDefault,
                'off': reasoningOffLabel(
                  context,
                  AiOptions(c.config),
                  choice: true,
                ),
                for (final level in AiOptions(c.config).reasoningEfforts)
                  level: reasoningEffortLabel(
                    context,
                    AiOptions(c.config),
                    level,
                  ),
              }.entries)
                DropdownMenuItem(
                  value: e.key,
                  enabled:
                      e.key.isEmpty ||
                      e.key == 'off' ||
                      c.config.supportsThinking,
                  child: Text(e.value),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => effort = v ?? ''),
          ),
          for (final image in widget.images)
            CheckboxListTile(
              value: selected.contains(image.id),
              title: Text(examImageRoleLabel(context, image.role)),
              secondary: Image.file(
                c.files.resolve(image.relativePath),
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                cacheWidth: 150,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(image.id);
                      } else {
                        selected.remove(image.id);
                      }
                    }),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                busy || c.demo || !AiOptions(config).vision || selected.isEmpty
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                      proposal = null;
                      reasoning = '';
                    });
                    try {
                      final rows = await generateExamScores(
                        provider: c.provider,
                        config: config,
                        files: c.files,
                        images: widget.images
                            .where((i) => selected.contains(i.id))
                            .toList(),
                        subject: widget.subject.subject,
                        prompt: c.prompts.text('exam_scores'),
                        cancel: cancel,
                        usageStore: AiUsageStore(c.db),
                        onReasoning: (value) {
                          if (mounted && value != reasoning) {
                            setState(() => reasoning = value);
                          }
                        },
                      );
                      if (mounted) {
                        await (c.db.update(
                          c.db.examSubjects,
                        )..where((t) => t.id.equals(widget.subject.id))).write(
                          ExamSubjectsCompanion(
                            aiReasoning: Value(reasoning),
                            aiModel: Value(config.model),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            proposal = rows;
                            busy = false;
                          });
                        }
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error =
                              context.l10n.aiExtractionFailedWithoutChanging;
                        });
                      }
                    }
                  },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(context.l10n.uploadSelectedPhotosAndExtract),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.stopAndReturn),
            ),
          if (reasoning.isNotEmpty)
            ReasoningPanel(text: reasoning, generating: busy),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (proposal != null) ...[
            const SizedBox(height: 16),
            Text(context.l10n.extractionFinishedYourSavedMarks),
            for (final row in proposal!)
              ListTile(
                contentPadding: EdgeInsets.only(
                  left: row.parentId == null ? 0 : 20,
                ),
                title: Text(row.label),
                subtitle: row.note.isEmpty ? null : Text(row.note),
                trailing: Text(
                  '${points(row.earned)} / ${points(row.maximum)}',
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ScoreEditor(subject: widget.subject, proposal: proposal),
                ),
              ),
              child: Text(context.l10n.reviewAndEditMarks),
            ),
          ],
        ],
      ),
    );
  }
}
