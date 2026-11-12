import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/prompt_settings.dart';
import '../../core/l10n/app_strings.dart';

class PromptScreen extends ConsumerStatefulWidget {
  const PromptScreen({super.key});
  @override
  ConsumerState<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends ConsumerState<PromptScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final rows = promptDefinitions.where(
      (p) =>
          '${context.tr(p.title)}${context.tr(p.description)}${c.prompts.text(p.id)}'
              .toLowerCase()
              .contains(query.toLowerCase()),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.tr("返回设置"),
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr("提示词管理"),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    "调整教学方式和不同学习任务的提示词。保存后用于后续请求，不修改已有消息；应用的工具权限、保存确认和答题规则始终保留。",
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('prompt-search'),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: context.tr("搜索提示词"),
                  ),
                  onChanged: (v) => setState(() => query = v.trim()),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(context.tr("没有找到匹配的提示词。")),
                  ),
                for (final p in rows) ...[
                  ListTile(
                    key: Key('prompt-${p.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    title: Text(context.tr(p.title)),
                    subtitle: Text(
                      context.tr("{0} · {1}", [
                        context.tr(
                          c.prompts.overrides.containsKey(p.id) ? '已自定义' : '默认',
                        ),
                        context.tr(p.description),
                      ]),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/prompts/${p.id}'),
                  ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  late final PromptDefinition? definition = promptDefinitions
      .where((p) => p.id == widget.id)
      .firstOrNull;
  late final TextEditingController input = TextEditingController(
    text: definition == null
        ? ''
        : ref.read(appControllerProvider).prompts.text(widget.id),
  );
  bool saving = false;
  String? failure;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await ref.read(appControllerProvider).savePrompt(widget.id, input.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr("提示词已保存，将用于后续请求。"))));
        context.go('/settings/prompts');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is FormatException
              ? error.message
              : '提示词保存失败，请检查可用空间。',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> preview() async {
    try {
      final settings = ref
          .read(appControllerProvider)
          .prompts
          .update(widget.id, input.text);
      final mode = ['guided', 'direct', 'exam'].contains(widget.id)
          ? widget.id
          : ['knowledge_writing', 'knowledge_editing'].contains(widget.id)
          ? 'direct'
          : widget.id == 'quiz'
          ? 'exam'
          : 'guided';
      final system = teachingPrompt(
        mode,
        prompts: settings,
        toolsEnabled: [
          'knowledge_writing',
          'knowledge_editing',
        ].contains(widget.id),
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr("提示词预览")),
          scrollable: true,
          content: SizedBox(
            width: 700,
            child: SelectableText(
              context.tr("{0}{1}\n\n实际请求还会按当前工具授权、学习状态及所选资料补入必要内容。", [
                system,
                ['global', 'guided', 'direct', 'exam'].contains(widget.id)
                    ? ''
                    : context.tr("\n\n【任务提示词】\n{0}", [
                        settings.text(widget.id),
                      ]),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.tr("关闭")),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is FormatException ? error.message : '无法预览提示词。',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = definition;
    if (p == null) {
      return Center(
        child: TextButton(
          onPressed: () => context.go('/settings/prompts'),
          child: Text(context.tr("提示词不存在，返回管理页")),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.tr("返回提示词管理"),
                      onPressed: saving
                          ? null
                          : () => context.go('/settings/prompts'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr(p.title),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(context.tr(p.description)),
                const SizedBox(height: 8),
                Text(
                  context.tr("提示词会发送给模型，并随学习数据备份保存，请勿填写 API Key 等密钥。"),
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('prompt-content'),
                  controller: input,
                  enabled: !saving,
                  minLines: 12,
                  maxLines: 24,
                  maxLength: 6000,
                  decoration: InputDecoration(
                    labelText: context.tr("提示词内容"),
                    alignLabelWithHint: true,
                  ),
                ),
                if (failure != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      context.tr(failure!),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('save-prompt'),
                      onPressed: saving ? null : save,
                      child: Text(
                        saving ? context.tr("保存中…") : context.tr("保存提示词"),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: saving ? null : preview,
                      child: Text(context.tr("预览效果")),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final reset = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(context.tr("恢复默认提示词？")),
                                  content: Text(
                                    context.tr("将替换当前编辑内容，点击保存后生效。"),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.tr("取消")),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.tr("恢复默认")),
                                    ),
                                  ],
                                ),
                              );
                              if (reset == true && mounted) {
                                setState(() {
                                  input.text = ref
                                      .read(appControllerProvider)
                                      .prompts
                                      .defaultText(p.id);
                                  failure = null;
                                });
                              }
                            },
                      child: Text(context.tr("恢复默认")),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
