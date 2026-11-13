import '../../core/ui/app_menu.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'study_store.dart';
import 'module_store.dart';

final libraryModuleFilterProvider = StateProvider.family<String, bool>(
  (ref, mistake) => '',
);

Future<String?> moduleNameDialog(
  BuildContext context,
  String title, [
  String initial = '',
]) async {
  final text = TextEditingController(text: initial);
  final route = DialogRoute<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(labelText: ctx.l10n.directoryName),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, text.text),
          child: Text(ctx.l10n.save),
        ),
      ],
    ),
  );
  try {
    final value = await Navigator.of(context, rootNavigator: true).push(route);
    await route.completed;
    return value;
  } finally {
    text.dispose();
  }
}

class ModuleManager extends ConsumerStatefulWidget {
  const ModuleManager({this.initialSubject = '数学', super.key});
  final String initialSubject;
  @override
  ConsumerState<ModuleManager> createState() => _ManagerState();
}

class _ManagerState extends ConsumerState<ModuleManager> {
  late final subject = TextEditingController(text: widget.initialSubject);
  late String discipline = widget.initialSubject;
  @override
  void dispose() {
    subject.dispose();
    super.dispose();
  }

  Future<void> create([String? parent]) async {
    final name = await moduleNameDialog(
      context,
      parent == null ? context.l10n.addModule : context.l10n.addSubmodule,
    );
    if (name != null && mounted) {
      await act(
        context,
        () => ref
            .read(appControllerProvider)
            .study
            .modules
            .create(
              discipline,
              name,
              parentId: parent,
              // A duplicate name is an error here, not a silent reuse:
              // the user must know they did not create a new directory.
              reuseExisting: false,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appControllerProvider).study.modules;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.subjectModules)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(context.l10n.organizeModulesAndSubmodulesLike),
              const SizedBox(height: 16),
              TextField(
                controller: subject,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: context.l10n.subjectCustomizable,
                ),
                onChanged: (v) => setState(() => discipline = v.trim()),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final name
                      in ref.read(appControllerProvider).learningSubjects)
                    ActionChip(
                      label: Text(context.subjectName(name)),
                      onPressed: () => setState(() {
                        subject.text = name;
                        discipline = name;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('module-add-root'),
                onPressed: discipline.isEmpty ? null : () => create(),
                icon: const Icon(Icons.create_new_folder_outlined),
                label: Text(context.l10n.addModule),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<SubjectModule>>(
                stream: store.watch(discipline),
                builder: (ctx, snapshot) {
                  if (snapshot.hasError) {
                    return Text(ctx.l10n.couldNotLoadTheDirectory);
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final all = snapshot.data!;
                  if (all.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(ctx.l10n.noModulesYetForExample),
                    );
                  }
                  Widget tile(SubjectModule module) => ListTile(
                    contentPadding: EdgeInsets.only(
                      left: module.parentId == null ? 0 : 24,
                    ),
                    leading: Icon(
                      module.parentId == null
                          ? Icons.folder_outlined
                          : Icons.subdirectory_arrow_right,
                    ),
                    title: Text(
                      '${discipline.isEmpty ? '${module.subject} · ' : ''}${module.name}',
                    ),
                    trailing: PopupMenuButton<String>(
                      popUpAnimationStyle: menuAnimation(context),
                      key: ValueKey('module-menu-${module.id}'),
                      tooltip: ctx.l10n.directoryActions,
                      onSelected: (action) async {
                        if (action == 'child') {
                          await create(module.id);
                          return;
                        }
                        if (action == 'rename') {
                          final name = await moduleNameDialog(
                            ctx,
                            ctx.l10n.renameDirectoryEntry,
                            module.name,
                          );
                          if (name != null && ctx.mounted) {
                            await act(ctx, () => store.rename(module.id, name));
                          }
                          return;
                        }
                        if (action == 'up' || action == 'down') {
                          await act(
                            ctx,
                            () =>
                                store.move(module.id, action == 'up' ? -1 : 1),
                          );
                          return;
                        }
                        if (action == 'delete') {
                          final yes = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                              title: Text(d.l10n.deleteDirectoryEntry),
                              content: Text(d.l10n.thisRemovesTheEntryIts),
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
                          if (yes == true && ctx.mounted) {
                            await act(ctx, () => store.delete(module.id));
                          }
                        }
                      },
                      itemBuilder: (ctx) {
                        final siblings = all
                            .where((m) => m.parentId == module.parentId)
                            .toList();
                        final index = siblings.indexWhere(
                          (m) => m.id == module.id,
                        );
                        return [
                          if (module.parentId == null)
                            PopupMenuItem(
                              value: 'child',
                              child: Text(ctx.l10n.addSubmodule),
                            ),
                          PopupMenuItem(
                            value: 'rename',
                            child: Text(ctx.l10n.renameDirectoryEntry),
                          ),
                          PopupMenuItem(
                            value: 'up',
                            enabled: index > 0,
                            child: Text(ctx.l10n.moveUp),
                          ),
                          PopupMenuItem(
                            value: 'down',
                            enabled: index >= 0 && index < siblings.length - 1,
                            child: Text(ctx.l10n.moveDown),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(ctx.l10n.deleteDirectoryEntry),
                          ),
                        ];
                      },
                    ),
                  );
                  return Column(
                    children: [
                      for (final root in all.where(
                        (m) => m.parentId == null,
                      )) ...[
                        tile(root),
                        for (final child in all.where(
                          (m) => m.parentId == root.id,
                        ))
                          tile(child),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModuleAssignment extends ConsumerWidget {
  const ModuleAssignment({
    required this.id,
    required this.subject,
    required this.mistake,
    this.editable = true,
    super.key,
  });
  final String id, subject;
  final bool mistake, editable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(appControllerProvider).study.modules;
    final linkTable = mistake
        ? 'mistake_module_links'
        : 'knowledge_module_links';
    final column = mistake ? 'mistake_id' : 'knowledge_id';
    return StreamBuilder<List<SubjectModule>>(
      stream: store.watch(subject),
      builder: (ctx, modules) => StreamBuilder<List<QueryRow>>(
        stream: store.db
            .customSelect(
              'SELECT module_id FROM $linkTable WHERE $column=?',
              variables: [Variable(id)],
              readsFrom: {
                store.db.mistakeModuleLinks,
                store.db.knowledgeModuleLinks,
              },
            )
            .watch(),
        builder: (ctx, links) {
          final all = modules.data ?? [];
          final ids = (links.data ?? [])
              .map((r) => r.read<String>('module_id'))
              .toSet();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      ctx.l10n.modules,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    if (modules.hasError || links.hasError)
                      Text(ctx.l10n.couldNotLoadTheDirectory),
                    for (final module in all.where((m) => ids.contains(m.id)))
                      ActionChip(
                        label: Text(modulePath(module, all)),
                        onPressed: () => act(ctx, () async {
                          final c = ref.read(appControllerProvider);
                          await c.setSubjectFilter(
                            schoolSubjects.contains(subject) ||
                                    c.learningSubjects.contains(subject)
                                ? subject
                                : '',
                          );
                          if (ctx.mounted) {
                            ctx.push(
                              '${mistake ? '/mistakes' : '/knowledge'}?module=${module.id}',
                            );
                          }
                        }),
                      ),
                    if (ids.isEmpty && links.hasData)
                      Text(ctx.l10n.unclassified),
                    if (editable)
                      TextButton.icon(
                        key: const Key('assign-modules'),
                        onPressed: modules.hasData && links.hasData
                            ? () => _pick(ctx, ref, all, ids.toList())
                            : null,
                        icon: const Icon(Icons.folder_copy_outlined, size: 18),
                        label: Text(ctx.l10n.chooseModules),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<SubjectModule> all,
    List<String> before,
  ) async {
    final selected = before.toSet();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(ctx.l10n.chooseModules),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView(
              children: [
                Text(ctx.l10n.selectMultipleEntriesIfNeeded),
                Text(
                  ctx.l10n.selectedEntriesOutOf20(
                    l10nArgument((selected.length)),
                  ),
                ),
                if (all.isEmpty) Text(ctx.l10n.thisSubjectHasNoModules),
                for (final root in all.where((m) => m.parentId == null)) ...[
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(root.name),
                    value: selected.contains(root.id),
                    onChanged: (v) => set(() {
                      v == true
                          ? selected.add(root.id)
                          : selected.remove(root.id);
                    }),
                  ),
                  for (final child in all.where((m) => m.parentId == root.id))
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(child.name),
                        value: selected.contains(child.id),
                        onChanged: (v) => set(() {
                          v == true
                              ? selected.add(child.id)
                              : selected.remove(child.id);
                        }),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.manageDirectory),
            ),
            FilledButton(
              onPressed: selected.length > 20
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.save),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (yes == false) {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => ModuleManager(initialSubject: subject),
        ),
      );
      if (context.mounted) {
        final store = ref.read(appControllerProvider).study.modules;
        final updated = await store.list(subject);
        // Only reopen the picker when the directory set actually changed;
        // if the user just looked, land back on the detail page.
        if (_moduleSignature(updated) != _moduleSignature(all)) {
          final current = await store.ids(id, mistake);
          if (context.mounted) await _pick(context, ref, updated, current);
        }
      }
      return;
    }
    if (yes == true) {
      await act(
        context,
        () => ref
            .read(appControllerProvider)
            .study
            .modules
            .assign(id, mistake, selected.toList(), expected: before),
      );
    }
  }
}

class ModuleFilter extends ConsumerWidget {
  const ModuleFilter({
    required this.value,
    required this.subject,
    required this.onChanged,
    required this.mistake,
    super.key,
  });
  final String value, subject;
  final bool mistake;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appControllerProvider);
    return StreamBuilder<List<SubjectModule>>(
      stream: c.study.modules.watch(subject),
      builder: (ctx, snap) {
        final all = snap.data ?? [];
        final selected = all.where((m) => m.id == value).firstOrNull;
        if (snap.hasData &&
            value.isNotEmpty &&
            value != 'unclassified' &&
            selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (ctx.mounted) onChanged('');
          });
        }
        return Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('module-filter'),
              icon: const Icon(Icons.folder_outlined),
              label: Text(
                value == 'unclassified'
                    ? ctx.l10n.unclassified
                    : selected == null
                    ? ctx.l10n.allModules
                    : '${subject.isEmpty ? '${context.subjectName(selected.subject)} · ' : ''}${modulePath(selected, all)}',
              ),
              onPressed: snap.hasData
                  ? () async {
                      final result = await showDialog<String>(
                        context: ctx,
                        builder: (d) => SimpleDialog(
                          title: Text(d.l10n.filterByDirectory),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(d, ''),
                              child: Text(d.l10n.allModules),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(d, 'unclassified'),
                              child: Text(d.l10n.unclassified),
                            ),
                            for (final root in all.where(
                              (m) => m.parentId == null,
                            )) ...[
                              SimpleDialogOption(
                                onPressed: () => Navigator.pop(d, root.id),
                                child: Text(
                                  '${subject.isEmpty ? '${context.subjectName(root.subject)} · ' : ''}${root.name}',
                                ),
                              ),
                              for (final child in all.where(
                                (m) => m.parentId == root.id,
                              ))
                                SimpleDialogOption(
                                  onPressed: () => Navigator.pop(d, child.id),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 20),
                                    child: Text(child.name),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      );
                      if (result != null && ctx.mounted) onChanged(result);
                    }
                  : null,
            ),
            TextButton(
              onPressed: () async {
                await Navigator.of(ctx, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ModuleManager(
                      initialSubject: subject.isEmpty
                          ? selected?.subject ??
                                (c.learningSubjects.contains('数学')
                                    ? '数学'
                                    : c.learningSubjects.first)
                          : subject,
                    ),
                  ),
                );
                // Keep the current filter when the user just looked: if the
                // selected directory was deleted, the build-time check above
                // already resets it via onChanged('').
              },
              child: Text(ctx.l10n.manageDirectory),
            ),
            if (selected != null)
              TextButton.icon(
                onPressed: c.busy
                    ? null
                    : () => act(ctx, () async {
                        await c.prepareModulePractice(value, mistake: mistake);
                        if (ctx.mounted) ctx.go('/chat');
                      }),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: Text(ctx.l10n.practiceThisModule),
              ),
          ],
        );
      },
    );
  }
}

/// Identity of a directory set for change detection after managing
/// directories: id, name and parent of every module, in list order.
String _moduleSignature(List<SubjectModule> modules) =>
    modules.map((m) => '${m.id}:${m.name}:${m.parentId}').join('|');
