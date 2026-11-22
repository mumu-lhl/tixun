import "dart:async";

import "../../core/ui/app_menu.dart";

import "package:drift/drift.dart" hide Column;
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "study_store.dart";
import "module_store.dart";

part "module_assignment.dart";
part "module_selection.dart";

Future<String?> moduleNameDialog(
  BuildContext context,
  String title, [
  String initial = "",
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
  const ModuleManager({this.initialSubject = "数学", super.key});
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
                key: const Key("module-add-root"),
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
                      key: ValueKey("module-menu-${module.id}"),
                      tooltip: ctx.l10n.directoryActions,
                      onSelected: (action) async {
                        if (action == "child") {
                          await create(module.id);
                          return;
                        }
                        if (action == "rename") {
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
                        if (action == "up" || action == "down") {
                          await act(
                            ctx,
                            () =>
                                store.move(module.id, action == "up" ? -1 : 1),
                          );
                          return;
                        }
                        if (action == "delete") {
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
                              value: "child",
                              child: Text(ctx.l10n.addSubmodule),
                            ),
                          PopupMenuItem(
                            value: "rename",
                            child: Text(ctx.l10n.renameDirectoryEntry),
                          ),
                          PopupMenuItem(
                            value: "up",
                            enabled: index > 0,
                            child: Text(ctx.l10n.moveUp),
                          ),
                          PopupMenuItem(
                            value: "down",
                            enabled: index >= 0 && index < siblings.length - 1,
                            child: Text(ctx.l10n.moveDown),
                          ),
                          PopupMenuItem(
                            value: "delete",
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
