import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../library/study_store.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});
  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsState();
}

class _SubjectsState extends ConsumerState<SubjectsScreen> {
  final custom = TextEditingController();
  late final selected = List<String>.of(
    ref.read(appControllerProvider).learningSubjects,
  );
  late final available = {
    '语文',
    '数学',
    '英语',
    ...schoolSubjects,
    ...selected,
  }.toList();
  bool saving = false;
  int _revision = 0;
  Future<void> _saveQueue = Future<void>.value();
  String? error;
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  void _saveSelection() {
    final revision = ++_revision;
    final snapshot = List<String>.of(selected);
    setState(() {
      saving = true;
      error = null;
    });
    _saveQueue = _saveQueue.then((_) async {
      // Coalesce quick successive edits; only the latest queued selection
      // needs to reach storage.
      if (revision != _revision) return;
      try {
        await ref.read(appControllerProvider).setLearningSubjects(snapshot);
      } catch (_) {
        if (mounted && revision == _revision) {
          setState(() => error = context.l10n.couldNotSaveSubjectsCheck);
        }
      } finally {
        if (mounted && revision == _revision) setState(() => saving = false);
      }
    });
  }

  Future<void> _leave() async {
    if (saving) await _saveQueue;
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotSaveSubjectsCheck)),
      );
      return;
    }
    // Use an explicit route because this page can be the app's deep-link
    // entry point; popping could exit instead of returning to Settings.
    context.go('/settings');
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Never pop directly: this route can be the app's deep-link entry point.
    canPop: false,
    onPopInvokedWithResult: (popped, _) async {
      if (popped) return;
      await _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studySubjects),
        actions: [
          if (saving)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Tooltip(
                message: context.l10n.savingEllipsis,
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.l10n.selectTheSubjectsYouStudy),
              const SizedBox(height: 12),
              Text(
                context.l10n.selectedSubjectsOutOf20(
                  l10nArgument((selected.length)),
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.selectedSubjects,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.l10n.selectAtLeastOneSubject),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: selected.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final subject = selected.removeAt(oldIndex);
                      selected.insert(newIndex, subject);
                    });
                    _saveSelection();
                  },
                  itemBuilder: (context, index) {
                    final subject = selected[index];
                    return Card(
                      key: ValueKey('selected-study-subject-$subject'),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      child: ListTile(
                        dense: true,
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(context.subjectName(subject)),
                        trailing: IconButton(
                          key: ValueKey('remove-study-subject-$subject'),
                          tooltip: context.l10n.removeSubject,
                          onPressed: saving || selected.length <= 1
                              ? null
                              : () {
                                  setState(() => selected.removeAt(index));
                                  _saveSelection();
                                },
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              Text(
                context.l10n.availableSubjects,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subject in available.where(
                    (subject) => !selected.contains(subject),
                  ))
                    FilterChip(
                      key: ValueKey('study-subject-$subject'),
                      label: Text(context.subjectName(subject)),
                      selected: false,
                      onSelected: saving
                          ? null
                          : (_) {
                              if (selected.length >= 20) {
                                setState(
                                  () =>
                                      error = context.l10n.selectUpTo20Subjects,
                                );
                                return;
                              }
                              setState(() {
                                selected.add(subject);
                                error = null;
                              });
                              _saveSelection();
                            },
                    ),
                ],
              ),
              const Divider(height: 24),
              TextField(
                key: const Key('custom-subject'),
                controller: custom,
                maxLength: 40,
                enabled: !saving,
                decoration: InputDecoration(
                  labelText: context.l10n.customSubject,
                  hintText: context.l10n.forExampleComputerScienceJapanese,
                ),
                onSubmitted: (_) => add(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.addSubject),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      if (error == context.l10n.couldNotSaveSubjectsCheck)
                        TextButton(
                          onPressed: saving ? null : _saveSelection,
                          child: Text(context.l10n.retry),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  void add() {
    final name = custom.text.trim();
    if (name.isEmpty || name.contains('\n') || name.length > 40) {
      setState(() => error = context.l10n.subjectNamesMustContain1);
      return;
    }
    if (!selected.contains(name) && selected.length >= 20) {
      setState(() => error = context.l10n.selectUpTo20Subjects);
      return;
    }
    final changed = !selected.contains(name);
    setState(() {
      if (!available.contains(name)) available.add(name);
      if (changed) selected.add(name);
      custom.clear();
      error = null;
    });
    if (changed) _saveSelection();
  }
}
