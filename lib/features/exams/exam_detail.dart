import 'package:tixun/core/l10n/app_error.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'exam_calendar.dart';
import 'exam_store.dart';

class ExamDetailScreen extends ConsumerWidget {
  const ExamDetailScreen(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return StreamBuilder<ExamEvent?>(
      stream: (c.db.select(
        c.db.examEvents,
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
        final event = snap.data!;
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
                        IconButton(
                          onPressed: () => context.go('/exams'),
                          tooltip: context.l10n.back,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.editExam,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => editExam(context, c, event),
                        ),
                        IconButton(
                          tooltip: context.l10n.deleteExam,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(ctx.l10n.deleteExam),
                                content: Text(
                                  ctx.l10n.thisDeletesTheExamSubjects,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(ctx.l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(ctx.l10n.delete),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true && context.mounted) {
                              await act(context, () async {
                                await c.exams.deleteEvent(id);
                                if (context.mounted) context.go('/exams');
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    Text(examDate(event.date.toUtc())),
                    const SizedBox(height: 24),
                    StreamBuilder<List<ExamSubject>>(
                      stream:
                          (c.db.select(c.db.examSubjects)
                                ..where((t) => t.eventId.equals(id))
                                ..orderBy([(t) => OrderingTerm.asc(t.subject)]))
                              .watch(),
                      builder: (ctx, subjects) => Column(
                        children: [
                          if (subjects.hasError)
                            Text(ctx.l10n.couldNotLoadExamRecords),
                          if (subjects.hasData && subjects.data!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(ctx.l10n.addASubjectToRecord),
                            ),
                          for (final subject
                              in subjects.data ?? <ExamSubject>[])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ctx.subjectName(subject.subject)),
                              subtitle: Text(
                                '${ctx.l10n.rawScore} ${points(subject.rawScore)}${subject.maximum == null ? '' : ' / ${points(subject.maximum)}'}${subject.usesScaling ? ' · ${ctx.l10n.scaledScore} ${points(subject.scaledScore)}' : ''}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '/exams/$id/subject/${subject.id}',
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => editSubject(context, c, id),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.addSubject),
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
}

Future<void> editExam(
  BuildContext context,
  AppController c,
  ExamEvent event,
) async {
  final title = TextEditingController(text: event.title);
  final storedDate = event.date.toUtc();
  var date = DateTime(storedDate.year, storedDate.month, storedDate.day);
  String? error;
  try {
    final yes = await showExamDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(ctx.l10n.editExam),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(labelText: ctx.l10n.examName),
              ),
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(examDate(date)),
                onPressed: () async {
                  final next = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (next != null && ctx.mounted) set(() => date = next);
                },
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || title.text.length > 120) {
                  set(() => error = ctx.l10n.examNameMustBe1);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(ctx.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (yes == true && context.mounted) {
      await act(
        context,
        () => c.exams.saveEvent(id: event.id, title: title.text, date: date),
      );
    }
  } finally {
    title.dispose();
  }
}

Future<void> editSubject(
  BuildContext context,
  AppController c,
  String eventId, [
  ExamSubject? existing,
]) async {
  final subject = TextEditingController(
    text:
        existing?.subject ??
        (c.subjectFilter.isNotEmpty
            ? c.subjectFilter
            : c.learningSubjects.contains('数学')
            ? '数学'
            : c.learningSubjects.first),
  );
  final raw = TextEditingController(
    text: existing?.rawScore == null ? '' : points(existing!.rawScore),
  );
  final scaled = TextEditingController(
    text: existing?.scaledScore == null ? '' : points(existing!.scaledScore),
  );
  final max = TextEditingController(
    text: existing?.maximum == null ? '' : points(existing!.maximum),
  );
  final notes = TextEditingController(text: existing?.notes ?? '');
  var scaling = existing?.usesScaling ?? false;
  String? error;
  bool saving = false;
  try {
    final saved = await showExamDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              (existing == null ? ctx.l10n.addSubject : ctx.l10n.editScores),
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subject,
                      enabled: !saving && existing == null,
                      decoration: InputDecoration(labelText: ctx.l10n.subject),
                      onChanged: (_) => set(() {}),
                    ),
                    if (existing == null)
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final name in c.learningSubjects)
                            ActionChip(
                              label: Text(ctx.subjectName(name)),
                              onPressed: saving
                                  ? null
                                  : () => set(() => subject.text = name),
                            ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: raw,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: ctx.l10n.rawScore,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: max,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: ctx.l10n.maximumScore,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!mainExamSubjects.contains(subject.text.trim()))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ctx.l10n.recordScaledScore),
                        value: scaling,
                        onChanged: saving
                            ? null
                            : (v) => set(() => scaling = v),
                      ),
                    if (scaling &&
                        !mainExamSubjects.contains(subject.text.trim()))
                      TextField(
                        controller: scaled,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: ctx.l10n.scaledScore,
                        ),
                      ),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: ctx.l10n.notes),
                    ),
                    if (error != null)
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: Text(ctx.l10n.cancel),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        set(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          final id = await c.exams.saveSubject(
                            id: existing?.id,
                            eventId: eventId,
                            subject: subject.text,
                            raw: parsePoints(raw.text),
                            maximum: parsePoints(max.text),
                            scaled: scaling ? parsePoints(scaled.text) : null,
                            scaling: scaling,
                            notes: notes.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, id);
                        } catch (_) {
                          if (ctx.mounted) {
                            set(() {
                              saving = false;
                              error = ctx.l10n.couldNotSaveCheckScores;
                            });
                          }
                        }
                      },
                child: Text(ctx.l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != null && context.mounted && existing == null) {
      context.push('/exams/$eventId/subject/$saved');
    }
  } finally {
    for (final t in [subject, raw, scaled, max, notes]) {
      t.dispose();
    }
  }
}

double? parsePoints(String text) {
  if (text.trim().isEmpty) return null;
  final value = double.tryParse(text.trim());
  if (value == null || !value.isFinite)
    throw const AppFormatException(
      AppErrorCode.errorInvalidScoreFormat,
      '分数格式无效。',
    );
  return value;
}
