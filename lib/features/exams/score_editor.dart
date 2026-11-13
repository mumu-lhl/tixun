import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import 'exam_calendar.dart';
import 'exam_detail.dart';
import 'exam_store.dart';

class ScoreEditor extends ConsumerStatefulWidget {
  const ScoreEditor({required this.subject, this.proposal, super.key});
  final ExamSubject subject;
  final List<ScoreDraft>? proposal;
  @override
  ConsumerState<ScoreEditor> createState() => _ScoreEditorState();
}

class _Row {
  _Row(ScoreDraft draft)
    : id = draft.id,
      parentId = draft.parentId,
      label = TextEditingController(text: draft.label),
      earned = TextEditingController(
        text: draft.earned == null ? '' : points(draft.earned),
      ),
      max = TextEditingController(
        text: draft.maximum == null ? '' : points(draft.maximum),
      ),
      note = TextEditingController(text: draft.note),
      // The note field stays visible once opened, even after the note is
      // cleared: without this, clearing a note removed its only way back.
      showNote = draft.note.isNotEmpty;
  final String id;
  final String? parentId;
  final TextEditingController label, earned, max, note;
  bool showNote;
  final focus = FocusNode();
  ScoreDraft get draft => ScoreDraft(
    id: id,
    parentId: parentId,
    label: label.text,
    earned: parsePoints(earned.text),
    maximum: parsePoints(max.text),
    note: note.text,
  );
  void dispose() {
    for (final c in [label, earned, max, note]) {
      c.dispose();
    }
    focus.dispose();
  }
}

class _ScoreEditorState extends ConsumerState<ScoreEditor> {
  final rows = <_Row>[];
  bool loading = true, saving = false, dirty = false;
  String? error;
  int? revision;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appControllerProvider).db;
      final current = await (db.select(
        db.examSubjects,
      )..where((t) => t.id.equals(widget.subject.id))).getSingle();
      final saved =
          await (db.select(db.examScoreRows)
                ..where((t) => t.subjectId.equals(widget.subject.id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (!mounted) return;
      revision = current.scoreRevision;
      rows.addAll(
        (widget.proposal ??
                saved
                    .map(
                      (r) => ScoreDraft(
                        id: r.id,
                        parentId: r.parentId,
                        label: r.label,
                        earned: r.earned,
                        maximum: r.maximum,
                        note: r.note,
                      ),
                    )
                    .toList())
            .map(_Row.new),
      );
      setState(() {
        loading = false;
        dirty = widget.proposal != null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = context.l10n.couldNotLoadQuestionMarks;
        });
      }
    }
  }

  void add(_Row? after, {bool child = false}) {
    final root = child ? after!.id : null;
    final siblings = rows.where((r) => r.parentId == root).toList();
    final labels = siblings.map((r) => r.label.text).toSet();
    var next = siblings.length + 1;
    while (labels.contains('$next')) {
      next++;
    }
    final previousMax = siblings.isEmpty
        ? null
        : double.tryParse(siblings.last.max.text);
    final row = _Row(
      ScoreDraft(parentId: root, label: '$next', maximum: previousMax),
    );
    var position = rows.length;
    if (after != null) {
      final parent = child ? after.id : after.parentId ?? after.id;
      final last = rows.lastIndexWhere(
        (r) => r.id == parent || r.parentId == parent,
      );
      position = last + 1;
    }
    setState(() {
      rows.insert(position, row);
      dirty = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focus.requestFocus();
    });
  }

  Future<bool> leave() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.discardUnsavedQuestionMarks),
            content: Text(ctx.l10n.yourPreviouslySavedDataWill),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.discard),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    for (final row in rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !saving,
    onPopInvokedWithResult: (didPop, _) async {
      if (!didPop && !saving && await leave() && mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.proposal == null
              ? context.l10n.editQuestionMarks
              : context.l10n.reviewAIQuestionMarks),
        ),
        actions: [
          TextButton(
            onPressed: loading || saving || error != null && revision == null
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(appControllerProvider)
                          .exams
                          .saveRows(
                            widget.subject.id,
                            rows.map((r) => r.draft).toList(),
                            expected: revision,
                          );
                      if (context.mounted) {
                        setState(() {
                          dirty = false;
                          saving = false;
                        });
                        Navigator.pop(context);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        setState(() {
                          saving = false;
                          error = context.l10n.couldNotSaveCheckQuestion;
                        });
                      }
                    }
                  },
            child: Text(context.l10n.save),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.proposal != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(context.l10n.aiSuggestionsAreUnverifiedCheck),
                  ),
                Text(context.l10n.blankMeansUnknown0Means),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                for (final row in rows)
                  Padding(
                    key: ValueKey(row.id),
                    padding: EdgeInsets.only(
                      left: row.parentId == null ? 0 : 20,
                      top: 12,
                    ),
                    child: _buildRow(row),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const Key('score-next-question'),
                  onPressed: saving ? null : () => add(null),
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.nextQuestion),
                ),
              ],
            ),
    ),
  );
  Widget _buildRow(_Row row) {
    final children = rows.where((r) => r.parentId == row.id).toList();
    final parent = children.isNotEmpty;
    String subtotal(bool maximum) {
      final values = children
          .map((r) => double.tryParse(maximum ? r.max.text : r.earned.text))
          .toList();
      return values.any((v) => v == null || !v.isFinite)
          ? '—'
          : points(values.fold<double>(0.0, (s, v) => s + v!));
    }

    return Material(
      color: row.parentId == null
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 62,
                  child: TextField(
                    controller: row.label,
                    onChanged: (_) => setState(() => dirty = true),
                    decoration: InputDecoration(
                      labelText: (row.parentId == null
                          ? context.l10n.questionNumber
                          : context.l10n.subquestion),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: parent
                      ? InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.l10n.subquestionTotal,
                          ),
                          child: Text(subtotal(false)),
                        )
                      : TextField(
                          controller: row.earned,
                          focusNode: row.focus,
                          enabled: !parent && !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() => dirty = true),
                          decoration: InputDecoration(
                            labelText: (parent
                                ? context.l10n.subquestionTotal
                                : context.l10n.marks),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: parent
                      ? InputDecorator(
                          decoration: InputDecoration(
                            labelText: context.l10n.maximumScore,
                          ),
                          child: Text(subtotal(true)),
                        )
                      : TextField(
                          controller: row.max,
                          enabled: !parent && !saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() => dirty = true),
                          onSubmitted: (_) => row.parentId == null
                              ? add(row)
                              : add(
                                  rows.firstWhere((r) => r.id == row.parentId),
                                  child: true,
                                ),
                          decoration: InputDecoration(
                            labelText: context.l10n.maximumScore,
                          ),
                        ),
                ),
                IconButton(
                  tooltip: context.l10n.deleteQuestion,
                  onPressed: saving
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(ctx.l10n.deleteQuestion),
                              content: Text(ctx.l10n.itsSubquestionsWillAlsoBe),
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
                          if (yes == true && mounted) {
                            setState(() {
                              final removed = rows
                                  .where(
                                    (r) =>
                                        r.id == row.id || r.parentId == row.id,
                                  )
                                  .toList();
                              rows.removeWhere(removed.contains);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                for (final r in removed) {
                                  r.dispose();
                                }
                              });
                              dirty = true;
                            });
                          }
                        },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            if (row.showNote)
              TextField(
                controller: row.note,
                onChanged: (_) => setState(() => dirty = true),
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.l10n.reviewNotes,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: saving
                      ? null
                      : () => setState(() => row.showNote = true),
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: Text(context.l10n.addNote),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: saving ? null : () => add(row),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: Text(context.l10n.nextQuestion),
                  ),
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => add(
                            row.parentId == null
                                ? row
                                : rows.firstWhere((r) => r.id == row.parentId),
                            child: true,
                          ),
                    icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                    label: Text(context.l10n.nextSubquestion),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
