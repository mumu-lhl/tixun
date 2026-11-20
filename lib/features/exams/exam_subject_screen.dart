import "dart:async";

import "../../core/ui/app_menu.dart";

import "dart:io";

import "package:dio/dio.dart";
import "package:drift/drift.dart" hide Column;
import "package:material_ui/material_ui.dart";
import "package:go_router/go_router.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/controller.dart";
import "../../core/ai/ai_options.dart";
import "../../core/ai/ai_usage_store.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/cached_stream_builder.dart";
import "../../core/ui/reasoning_labels.dart";
import "../../core/ui/image_viewer.dart";
import "../../core/ui/reasoning_panel.dart";
import "exam_photo_intake.dart";
import "exam_ai.dart";
import "exam_calendar.dart";
import "exam_detail.dart";
import "exam_localization.dart";
import "exam_store.dart";
import "score_editor.dart";
import "exam_image_editor.dart";
import "../../core/platform/photo_picker.dart";

part "exam_marks_ai.dart";

part "exam_subject_documents.dart";

class ExamSubjectScreen extends ConsumerWidget {
  const ExamSubjectScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return CachedStreamBuilder<ExamSubject?>(
      owner: c.exams,
      cacheKey: ("subject", id),
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
                                  context.go("/exams/${subject.eventId}");
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
                    _documents(c, subject),
                    if (subject.aiReasoning.isNotEmpty)
                      ReasoningPanel(text: subject.aiReasoning),
                    const SizedBox(height: 16),
                    CachedStreamBuilder<List<ExamScoreRow>>(
                      owner: c.exams,
                      cacheKey: ("scores", id),
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
                                      : "${points(row.earned)} / ${points(row.maximum)}",
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
      case "edit":
        await act(context, () => editExamPhoto(context, c, image));
      case "original":
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
      case "delete":
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
