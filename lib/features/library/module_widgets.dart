import '../../core/ui/app_menu.dart';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
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
      title: Text(ctx.tr(title)),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(labelText: ctx.tr('目录名称')),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(ctx.tr('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, text.text),
          child: Text(ctx.tr('保存')),
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
      parent == null ? '新增模块' : '新增子模块',
    );
    if (name != null && mounted) {
      await act(
        context,
        () => ref
            .read(appControllerProvider)
            .study
            .modules
            .create(discipline, name, parentId: parent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appControllerProvider).study.modules;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('科目目录'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.tr(
                  '按教辅目录整理模块和子模块，知识与错题共用。目录名称由你决定，也可以在授权资料工具后请 AI 创建。',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subject,
                maxLength: 40,
                decoration: InputDecoration(labelText: context.tr('科目（可以自定义）')),
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
                label: Text(context.tr('新增模块')),
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<SubjectModule>>(
                stream: store.watch(discipline),
                builder: (ctx, snapshot) {
                  if (snapshot.hasError) return Text(ctx.tr('目录读取失败，请重新打开。'));
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  final all = snapshot.data!;
                  if (all.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(ctx.tr('还没有目录。例如：函数 → 单调性与最值。')),
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
                      tooltip: ctx.tr('目录操作'),
                      onSelected: (action) async {
                        if (action == 'child') {
                          await create(module.id);
                          return;
                        }
                        if (action == 'rename') {
                          final name = await moduleNameDialog(
                            ctx,
                            '重命名目录',
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
                              title: Text(d.tr('删除目录')),
                              content: Text(
                                d.tr(
                                  '将删除此目录及子目录，并解除资料关联。知识、错题和练习不会删除。此操作无法撤销。',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d),
                                  child: Text(d.tr('取消')),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  child: Text(d.tr('删除')),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && ctx.mounted) {
                            await act(ctx, () => store.delete(module.id));
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (module.parentId == null)
                          PopupMenuItem(
                            value: 'child',
                            child: Text(ctx.tr('新增子模块')),
                          ),
                        PopupMenuItem(
                          value: 'rename',
                          child: Text(ctx.tr('重命名目录')),
                        ),
                        PopupMenuItem(value: 'up', child: Text(ctx.tr('上移'))),
                        PopupMenuItem(value: 'down', child: Text(ctx.tr('下移'))),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(ctx.tr('删除目录')),
                        ),
                      ],
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
                      ctx.tr('目录分类'),
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    if (modules.hasError || links.hasError)
                      Text(ctx.tr('目录读取失败，请重新打开。')),
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
                    if (ids.isEmpty && links.hasData) Text(ctx.tr('未归类')),
                    if (editable)
                      TextButton.icon(
                        key: const Key('assign-modules'),
                        onPressed: modules.hasData && links.hasData
                            ? () => _pick(ctx, ref, all, ids.toList())
                            : null,
                        icon: const Icon(Icons.folder_copy_outlined, size: 18),
                        label: Text(ctx.tr('选择模块')),
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
          title: Text(ctx.tr('选择模块')),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView(
              children: [
                Text(ctx.tr('可选择多个模块；选择子模块后，按上级模块筛选时也能找到。')),
                Text(ctx.tr('已选 {0} / 20 个目录', [selected.length])),
                if (all.isEmpty) Text(ctx.tr('此科目还没有目录，请先新增模块。')),
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
              child: Text(ctx.tr('取消')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.tr('管理目录')),
            ),
            FilledButton(
              onPressed: selected.length > 20
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('保存')),
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
        final current = await store.ids(id, mistake);
        if (context.mounted) await _pick(context, ref, updated, current);
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
                    ? ctx.tr('未归类')
                    : selected == null
                    ? ctx.tr('全部模块')
                    : '${subject.isEmpty ? '${context.subjectName(selected.subject)} · ' : ''}${modulePath(selected, all)}',
              ),
              onPressed: snap.hasData
                  ? () async {
                      final result = await showDialog<String>(
                        context: ctx,
                        builder: (d) => SimpleDialog(
                          title: Text(d.tr('按目录筛选')),
                          children: [
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(d, ''),
                              child: Text(d.tr('全部模块')),
                            ),
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(d, 'unclassified'),
                              child: Text(d.tr('未归类')),
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
                if (ctx.mounted) onChanged('');
              },
              child: Text(ctx.tr('管理目录')),
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
                label: Text(ctx.tr('本模块专项训练')),
              ),
          ],
        );
      },
    );
  }
}
