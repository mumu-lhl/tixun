import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
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
          return Center(child: Text(context.tr('考试记录读取失败，请重新打开。')));
        }
        if (!snap.hasData) {
          return Center(
            child: Text(
              context.tr(
                snap.connectionState == ConnectionState.waiting
                    ? '正在加载…'
                    : '记录不存在',
              ),
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
                          tooltip: context.tr('返回'),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        Expanded(
                          child: Text(
                            event.title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: context.tr('编辑考试'),
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => editExam(context, c, event),
                        ),
                        IconButton(
                          tooltip: context.tr('删除考试'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(ctx.tr('删除考试')),
                                content: Text(
                                  ctx.tr('将删除本次考试的科目、小分表和照片。此操作无法撤销。'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(ctx.tr('取消')),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(ctx.tr('删除')),
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
                            Text(ctx.tr('考试记录读取失败，请重新打开。')),
                          if (subjects.hasData && subjects.data!.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(ctx.tr('添加科目，记录成绩、试卷与小分表。')),
                            ),
                          for (final subject
                              in subjects.data ?? <ExamSubject>[])
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ctx.tr(subject.subject)),
                              subtitle: Text(
                                '${ctx.tr('裸分')} ${points(subject.rawScore)}${subject.maximum == null ? '' : ' / ${points(subject.maximum)}'}${subject.usesScaling ? ' · ${ctx.tr('赋分')} ${points(subject.scaledScore)}' : ''}',
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
                      label: Text(context.tr('添加科目')),
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
          title: Text(ctx.tr('编辑考试')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                maxLength: 120,
                decoration: InputDecoration(labelText: ctx.tr('考试名称')),
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
              child: Text(ctx.tr('取消')),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || title.text.length > 120) {
                  set(() => error = ctx.tr('考试名称需为 1–120 字。'));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(ctx.tr('保存')),
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
            title: Text(ctx.tr(existing == null ? '添加科目' : '编辑成绩')),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subject,
                      enabled: !saving && existing == null,
                      decoration: InputDecoration(labelText: ctx.tr('科目')),
                      onChanged: (_) => set(() {}),
                    ),
                    if (existing == null)
                      Wrap(
                        spacing: 4,
                        children: [
                          for (final name in c.learningSubjects)
                            ActionChip(
                              label: Text(ctx.tr(name)),
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
                              labelText: ctx.tr('裸分'),
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
                              labelText: ctx.tr('满分'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!mainExamSubjects.contains(subject.text.trim()))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(ctx.tr('记录赋分')),
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
                        decoration: InputDecoration(labelText: ctx.tr('赋分')),
                      ),
                    TextField(
                      controller: notes,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: ctx.tr('备注')),
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
                child: Text(ctx.tr('取消')),
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
                              error = ctx.tr('保存失败，请检查分数或是否重复添加了科目。');
                            });
                          }
                        }
                      },
                child: Text(ctx.tr('保存')),
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
  if (value == null || !value.isFinite) throw const FormatException('分数格式无效。');
  return value;
}
