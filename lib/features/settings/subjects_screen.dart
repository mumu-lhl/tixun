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
          error = context.tr('科目保存失败，请检查选择或稍后重试。');
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
            title: Text(d.tr('放弃科目设置的修改？')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(d),
                child: Text(d.tr('继续编辑')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(d, true),
                child: Text(d.tr('放弃')),
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
        title: Text(context.tr('学习科目')),
        actions: [
          TextButton(
            key: const Key('save-subjects'),
            onPressed: saving || selected.isEmpty || selected.length > 20
                ? null
                : save,
            child: Text(context.tr('保存')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                context.tr(
                  '只选择你正在学习的科目。取消选择只影响快捷切换，不会删除已有资料；“全部科目”始终可以查看所有资料。',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('已选 {0} / 20 个科目', [selected.length]),
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
                  labelText: context.tr('自定义科目'),
                  hintText: context.tr('例如：信息技术、日语、竞赛数学'),
                ),
                onSubmitted: (_) => add(),
              ),
              OutlinedButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.add),
                label: Text(context.tr('添加科目')),
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
      setState(() => error = context.tr('科目名称需为 1–40 字。'));
      return;
    }
    if (!selected.contains(name) && selected.length >= 20) {
      setState(() => error = context.tr('最多选择 20 个科目。'));
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
