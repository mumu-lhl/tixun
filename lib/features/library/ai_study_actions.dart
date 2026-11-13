import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import 'study_store.dart';

Future<void> startAiStudyWriting(
  BuildContext context,
  WidgetRef ref, {
  ChatMessage? source,
  KnowledgeItem? knowledge,
  bool mistake = false,
}) async {
  final c = ref.read(appControllerProvider);
  if (c.busy) throw const FormatException('请先停止生成，再整理资料。');
  final title = knowledge != null
      ? source == null
            ? 'AI 编辑知识'
            : 'AI 整合到已有知识'
      : mistake
      ? 'AI 整理成错题'
      : 'AI 生成知识';
  final instruction = await showDialog<String>(
    context: context,
    builder: (_) => _WritingRequest(
      title: title,
      target: knowledge?.title,
      requiredInput: source == null,
      initial: knowledge != null && source == null
          ? context.tr('整理结构，保留原意并补充必要的适用条件。')
          : '',
    ),
  );
  if (instruction == null || !context.mounted) return;
  final prompt = await c.prepareStudyWriting(
    sourceMessageId: source?.id,
    knowledgeId: knowledge?.id,
    mistake: mistake,
    instruction: instruction,
  );
  if (!context.mounted) return; // The prepared draft remains available.
  context.go('/chat');
  await c.send(prompt);
}

class _WritingRequest extends StatefulWidget {
  const _WritingRequest({
    required this.title,
    required this.requiredInput,
    required this.initial,
    this.target,
  });
  final String title, initial;
  final String? target;
  final bool requiredInput;
  @override
  State<_WritingRequest> createState() => _WritingRequestState();
}

class _WritingRequestState extends State<_WritingRequest> {
  late final input = TextEditingController(text: widget.initial);
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr(widget.title)),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.target!),
            ),
          TextField(
            key: const Key('ai-study-instruction'),
            controller: input,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.tr(
                widget.requiredInput ? '希望生成或修改什么？' : '整理要求（可选）',
              ),
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('使用当前模型，在对话中整理并按需检索相关资料。每项保存或修改仍需你确认。'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('取消')),
      ),
      FilledButton(
        key: const Key('start-ai-study-writing'),
        onPressed: () {
          if (widget.requiredInput && input.text.trim().isEmpty) {
            setState(() => error = context.tr('请填写希望生成或修改的内容。'));
            return;
          }
          Navigator.pop(context, input.text.trim());
        },
        child: Text(context.tr('开始整理')),
      ),
    ],
  );
}

Future<KnowledgeItem?> pickKnowledgeForAi(
  BuildContext context,
  StudyStore store,
) => showDialog<KnowledgeItem>(
  context: context,
  builder: (_) => _KnowledgePicker(store),
);

class _KnowledgePicker extends StatefulWidget {
  const _KnowledgePicker(this.store);
  final StudyStore store;
  @override
  State<_KnowledgePicker> createState() => _KnowledgePickerState();
}

class _KnowledgePickerState extends State<_KnowledgePicker> {
  late Future<List<KnowledgeItem>> items = widget.store.searchKnowledge(
    limit: 100,
  );
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 540,
      height: 560,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('选择要整合的知识'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai-knowledge-target-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.tr('搜索知识，或从最近记录中选择'),
              ),
              onChanged: (q) => setState(
                () => items = widget.store.searchKnowledge(
                  query: q.trim(),
                  limit: 100,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<KnowledgeItem>>(
                future: items,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(context.tr('知识读取失败，请重新打开。')));
                  }
                  if (snap.data!.isEmpty) {
                    return Center(child: Text(context.tr('没有匹配的知识')));
                  }
                  return ListView.builder(
                    itemCount: snap.data!.length,
                    itemBuilder: (_, i) {
                      final k = snap.data![i];
                      return ListTile(
                        key: ValueKey('ai-knowledge-target-${k.id}'),
                        title: Text(
                          k.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(context.subjectName(k.subject)),
                        onTap: () => Navigator.pop(context, k),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
