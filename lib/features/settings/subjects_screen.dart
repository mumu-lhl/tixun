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
  late final selected = ref
      .read(appControllerProvider)
      .learningSubjects
      .toSet();
  late final available = {
    '语文',
    '数学',
    '英语',
    ...schoolSubjects,
    ...selected,
  }.toList();
  bool saving = false, dirty = false;
  String? error;
  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(appControllerProvider)
          .setLearningSubjects(available.where(selected.contains).toList());
      if (mounted) {
        setState(() {
          dirty = false;
          saving = false;
        });
        // Go back explicitly instead of popping: this page can be the
        // initial route of a deep link (/settings/subjects), where a
        // pop would exit the app instead of returning to Settings.
        context.go('/settings');
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = context.l10n.couldNotSaveSubjectsCheck;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    // Never pop this page directly: as a deep-link entry point it may
    // be the only route, where a pop would exit the app. Every exit
    // goes through context.go('/settings') below instead.
    canPop: false,
    onPopInvokedWithResult: (popped, _) async {
      if (popped || saving) return;
      if (dirty) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(d.l10n.discardSubjectSelectionChanges),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(d.l10n.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(d.l10n.discard),
              ),
            ],
          ),
        );
        if (yes != true || !context.mounted) return;
        setState(() => dirty = false);
      }
      if (context.mounted) context.go('/settings');
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studySubjects),
        actions: [
          TextButton(
            key: const Key('save-subjects'),
            onPressed: saving || selected.isEmpty || selected.length > 20
                ? null
                : save,
            child: Text(context.l10n.save),
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subject in available)
                    FilterChip(
                      key: ValueKey('study-subject-$subject'),
                      label: Text(context.subjectName(subject)),
                      selected: selected.contains(subject),
                      onSelected: saving
                          ? null
                          : (v) => setState(() {
                              v
                                  ? selected.add(subject)
                                  : selected.remove(subject);
                              dirty = true;
                            }),
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
              OutlinedButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.addSubject),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    setState(() {
      if (!available.contains(name)) available.add(name);
      selected.add(name);
      custom.clear();
      error = null;
      dirty = true;
    });
  }
}
