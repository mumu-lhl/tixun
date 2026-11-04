import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/learning_markdown.dart';
import 'library_providers.dart';
import 'study_editor.dart';
import 'study_store.dart';

const toolLabels = {
  'schedule_review': '加入复习',
  'create_quiz': '创建练习题',
  'create_knowledge': '新增知识',
  'update_knowledge': '修改知识',
  'delete_knowledge': '知识移入回收区',
  'create_mistake': '新增错题',
  'update_mistake': '修改错题',
  'delete_mistake': '错题移入回收区',
  'link_mistake_to_knowledge': '关联错题与知识',
};
const fieldLabels = {
  'title': '标题',
  'content': '知识正文',
  'subject': '科目',
  'kind': '知识类型',
  'chapter': '章节',
  'tags': '标签',
  'question': '题目',
  'correct_answer': '参考答案',
  'ai_analysis': 'AI 解析',
  'suggested_reason': 'AI 建议的原因（待确认）',
};

class ToolApprovalCard extends ConsumerWidget {
  const ToolApprovalCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final request = c.pendingTool;
    if (request == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('tool-approval'),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '请确认：${toolLabels[request.name] ?? '修改资料'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (request.target.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                request.target,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (request.name == 'create_mistake' && request.imageCount > 0)
            Text(
              '会同时保留本次上下文中的 ${request.imageCount} 张原题图片。',
              style: const TextStyle(fontSize: 12),
            ),
          if (request.name == 'schedule_review')
            const Text('加入后由应用根据作答安排日期。不会因阅读资料而增加掌握次数。'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in request.arguments.entries.where(
                    (e) => fieldLabels.containsKey(e.key),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fieldLabels[e.key]!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LearningMarkdown(
                            e.value is List
                                ? (e.value as List).join('、')
                                : e.value.toString(),
                          ),
                        ],
                      ),
                    ),
                  if (request.name.startsWith('delete'))
                    const Text('资料将移入回收区，可随时恢复。'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('reject-tool'),
                onPressed: () => c.decideTool(false),
                child: const Text('不执行'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('approve-tool'),
                onPressed: () => c.decideTool(true),
                child: const Text('确认执行'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatStudyMenu extends ConsumerWidget {
  const ChatStudyMenu({required this.message, super.key});
  final ChatMessage message;
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    tooltip: '保存学习资料',
    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
    enabled: message.status != 'generating',
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'knowledge', child: Text('保存到知识库')),
      const PopupMenuItem(value: 'mistake', child: Text('保存到错题本')),
      if (message.role == 'assistant')
        const PopupMenuItem(value: 'analysis', child: Text('写入关联错题的 AI 解析')),
    ],
    onSelected: (type) => act(context, () => _save(context, ref, type)),
  );
  Future<void> _save(BuildContext context, WidgetRef ref, String type) async {
    final c = ref.read(appControllerProvider);
    final store = ref.read(studyStoreProvider);
    final index = c.messages.indexWhere((m) => m.id == message.id);
    if (index < 0 || c.selected == null) {
      throw const FormatException('请重新打开此会话后保存。');
    }
    final question = message.role == 'user'
        ? message
        : c.messages.take(index).where((m) => m.role == 'user').lastOrNull;
    if (type == 'analysis') {
      final links =
          await (c.db.select(c.db.studyChatLinks)..where(
                (t) =>
                    t.sessionId.equals(c.selected!.id) &
                    t.mistakeId.isNotNull(),
              ))
              .get();
      final candidates = <MistakeDetail>[];
      for (final link in links) {
        try {
          final detail = await store.mistakeDetail(link.mistakeId!);
          if (!detail.item.deleted) candidates.add(detail);
        } on FormatException {
          /* Deleted relations are omitted. */
        }
      }
      if (candidates.isEmpty) {
        throw const FormatException('此对话没有关联错题，请先从错题详情发起学习对话。');
      }
      if (!context.mounted) return;
      var selected = candidates.first;
      if (candidates.length > 1) {
        final chosen = await showDialog<MistakeDetail>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('选择要更新的错题'),
            children: candidates
                .map(
                  (m) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, m),
                    child: Text(m.item.title),
                  ),
                )
                .toList(),
          ),
        );
        if (chosen == null || !context.mounted) return;
        selected = chosen;
      }
      await showDialog<String>(
        context: context,
        useSafeArea: false,
        builder: (_) => StudyEditor(
          isMistake: true,
          mistake: MistakeDetail(
            selected.item.copyWith(aiAnalysis: message.content),
            selected.tags,
            selected.images,
            selected.knowledge,
          ),
        ),
      );
      return;
    }
    final title = (question?.content ?? c.selected!.title)
        .replaceAll('\n', ' ')
        .characters
        .take(60)
        .toString();
    final sourceSession = c.selected!.id;
    final id = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (_) => StudyEditor(
        isMistake: type == 'mistake',
        sourceSessionId: sourceSession,
        sourceMessageId: message.id,
        initialKnowledge: type == 'knowledge'
            ? KnowledgeDraft(title: '学习笔记 · $title', content: message.content)
            : null,
        initialMistake: type == 'mistake'
            ? MistakeDraft(
                title: title,
                question: question?.content ?? '',
                aiAnalysis: message.role == 'assistant' ? message.content : '',
              )
            : null,
      ),
    );
    if (id == null || !context.mounted) return;
    if (type == 'mistake' && question != null) {
      try {
        for (final image in c.attachments.where(
          (a) => a.messageId == question.id,
        )) {
          await store.addImageReference(
            id,
            image.relativePath,
            image.mime,
            image.byteLength,
            isMistake: true,
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文字已保存，部分图片关联失败，请在详情中补充。')),
          );
        }
      }
    }
    if (context.mounted) {
      context.push('${type == 'mistake' ? '/mistakes' : '/knowledge'}/$id');
    }
  }
}

final _toolHistoryProvider = FutureProvider.autoDispose
    .family<List<AiToolOperation>, String>((ref, id) {
      final store = ref.watch(studyStoreProvider);
      return (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.runId.equals(id))).get();
    });

class ToolHistory extends ConsumerWidget {
  const ToolHistory(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_toolHistoryProvider(messageId))
      .maybeWhen(
        data: (items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items.map((op) {
            final success = op.status == 'succeeded';
            Map result = {};
            try {
              if (op.result != null) result = jsonDecode(op.result!) as Map;
            } catch (_) {
              /* Audit display must not break chat history. */
            }
            final name =
                toolLabels[op.name] ??
                (op.name.startsWith('search') ? '检索学习资料' : '读取学习资料');
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Icon(
                    success ? Icons.check_circle_outline : Icons.info_outline,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Text(
                    '$name · ${success
                        ? '已执行'
                        : op.status == 'pending'
                        ? '等待确认'
                        : op.status == 'rejected'
                        ? '未执行'
                        : '未完成'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (success &&
                      result['id'] is String &&
                      (op.name.endsWith('knowledge') ||
                          op.name.endsWith('mistake')))
                    TextButton(
                      onPressed: () => context.push(
                        '${op.name.endsWith('knowledge') ? '/knowledge' : '/mistakes'}/${result['id']}',
                      ),
                      child: const Text('查看资料', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        orElse: () => const SizedBox.shrink(),
      );
}

Future<void> openChatStudyLinks(BuildContext context, WidgetRef ref) async {
  final c = ref.read(appControllerProvider);
  if (c.selected == null) return;
  final links = await (c.db.select(
    c.db.studyChatLinks,
  )..where((t) => t.sessionId.equals(c.selected!.id))).get();
  final entries = <({String title, String path})>[];
  for (final link in links) {
    try {
      if (link.knowledgeId != null) {
        final k = await c.study.knowledge(link.knowledgeId!);
        entries.add((title: k.title, path: '/knowledge/${k.id}'));
      }
      if (link.mistakeId != null) {
        final m = await c.study.mistake(link.mistakeId!);
        entries.add((title: m.title, path: '/mistakes/${m.id}'));
      }
    } on FormatException {
      /* Hidden deleted records can be restored from their library. */
    }
  }
  if (!context.mounted) return;
  final path = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('关联学习资料'),
      content: SizedBox(
        width: 480,
        height: 280,
        child: entries.isEmpty
            ? const Center(
                child: Text(
                  '还没有关联资料。\n可以从消息菜单保存知识或错题。',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView(
                children: entries
                    .map(
                      (e) => ListTile(
                        title: Text(e.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, e.path),
                      ),
                    )
                    .toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
  if (path != null && context.mounted) context.push(path);
}
