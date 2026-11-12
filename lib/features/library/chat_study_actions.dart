import '../../core/ui/app_menu.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/learning_markdown.dart';
import 'library_providers.dart';
import 'split_suggestions.dart';
import 'study_editor.dart';
import 'study_store.dart';
import 'ai_study_actions.dart';

const toolLabels = {
  'run_python': '运行 Python',
  'create_subject_module': '新增科目目录',
  'link_study_module': '关联资料与模块',
  'schedule_review': '加入复习',
  'create_quiz': '创建练习题',
  'suggest_question_regions': '提出分题建议',
  'create_knowledge': '新增知识',
  'update_knowledge': '修改知识',
  'delete_knowledge': '知识移入回收区',
  'create_mistake': '新增错题',
  'update_mistake': '修改错题',
  'delete_mistake': '错题移入回收区',
  'link_mistake_to_knowledge': '关联错题与知识',
};
const fieldLabels = {
  'purpose': '运行用途',
  'code': 'Python 代码',
  'timeout_seconds': '期望执行时限（秒）',
  'name': '目录名称',
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
  // The remaining off-table parameters need no label: id / module_id /
  // knowledge_id / mistake_id / question_id / parent_id are opaque ids
  // already rendered human-readably as `target`, and `query` only occurs
  // in read tools that never ask for confirmation.
  'expected_revision': '版本号',
  'image_indices': '引用图片序号',
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
            context.tr("请确认：{0}", [toolLabels[request.name] ?? '修改资料']),
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
              context.tr("会同时保留本次上下文中的 {0} 张原题图片。", [request.imageCount]),
              style: const TextStyle(fontSize: 12),
            ),
          if (request.name == 'schedule_review')
            Text(context.tr("加入后由应用根据作答安排日期。不会因阅读资料而增加掌握次数。")),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in request.arguments.entries.where(
                    (e) =>
                        fieldLabels.containsKey(e.key) &&
                        !(request.name == 'link_study_module' &&
                            e.key == 'kind'),
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(fieldLabels[e.key]!),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (e.key == 'code')
                            SelectableText(
                              e.value.toString(),
                              style: const TextStyle(
                                fontFamily: 'TixunMono',
                                fontFamilyFallback: ['NotoSansSC'],
                                fontSize: 12,
                              ),
                            )
                          else
                            LearningMarkdown(
                              e.value is List
                                  ? (e.value as List).join('、')
                                  : e.value.toString(),
                            ),
                        ],
                      ),
                    ),
                  if (request.name.startsWith('delete'))
                    Text(context.tr("资料将移入回收区，可随时恢复。")),
                ],
              ),
            ),
          ),
          if (request.name == 'run_python') ...[
            Text(
              context.tr('代码可访问应用文件与网络，输出会发送给当前模型；只有你允许后才执行。'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () =>
                  showPythonCode(context, request.arguments['code'].toString()),
              child: Text(context.tr('查看完整代码')),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('reject-tool'),
                onPressed: () => c.decideTool(false),
                child: Text(context.tr("不执行")),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('approve-tool'),
                onPressed: () => c.decideTool(true),
                child: Text(
                  context.tr(request.name == 'run_python' ? '允许运行' : '确认执行'),
                ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(
      appControllerProvider.select((c) => c.selected?.id),
    );
    final hasMistake =
        message.role == 'assistant' &&
        sessionId != null &&
        (ref.watch(linkedMistakesProvider(sessionId)).value?.isNotEmpty ??
            false);
    return PopupMenuButton<String>(
      popUpAnimationStyle: menuAnimation(context),
      tooltip: context.tr("保存学习资料"),
      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
      enabled: message.status != 'generating',
      itemBuilder: (_) => [
        if (hasMistake && message.content.trim().isNotEmpty)
          PopupMenuItem(
            value: 'analysis',
            child: Text(context.tr('写入关联错题的 AI 解析')),
          ),
        PopupMenuItem(value: 'knowledge', child: Text(context.tr("保存到知识库"))),
        PopupMenuItem(value: 'mistake', child: Text(context.tr("保存到错题本"))),
        if (message.role == 'assistant' &&
            message.content.trim().isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'ai-knowledge',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.tr('AI 整理成知识')),
          ),
          PopupMenuItem(
            value: 'ai-merge',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.tr('AI 整合到已有知识')),
          ),
          PopupMenuItem(
            value: 'ai-mistake',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.tr('AI 整理成错题')),
          ),
        ],
      ],
      onSelected: (type) => act(context, () => _save(context, ref, type)),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String type) async {
    final c = ref.read(appControllerProvider);
    final store = ref.read(studyStoreProvider);
    if (type.startsWith('ai-')) {
      final target = type == 'ai-merge'
          ? await pickKnowledgeForAi(context, store)
          : null;
      if ((type == 'ai-merge' && target == null) || !context.mounted) return;
      await startAiStudyWriting(
        context,
        ref,
        source: message,
        knowledge: target,
        mistake: type == 'ai-mistake',
      );
      return;
    }
    final index = c.messages.indexWhere((m) => m.id == message.id);
    if (index < 0 || c.selected == null) {
      throw const FormatException('请重新打开此会话后保存。');
    }
    final question = message.role == 'user'
        ? message
        : c.messages.take(index).where((m) => m.role == 'user').lastOrNull;
    if (type == 'analysis') {
      final candidates = await ref.read(
        linkedMistakesProvider(c.selected!.id).future,
      );
      if (candidates.isEmpty) {
        throw const FormatException('此对话没有关联错题，请先从错题详情发起学习对话。');
      }
      if (!context.mounted) return;
      var selected = candidates.first;
      if (candidates.length > 1) {
        final chosen = await showDialog<Mistake>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(context.tr("选择要更新的错题")),
            children: candidates
                .map(
                  (m) => SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, m),
                    child: Text(m.title),
                  ),
                )
                .toList(),
          ),
        );
        if (chosen == null || !context.mounted) return;
        selected = chosen;
      }
      final detail = await store.mistakeDetail(selected.id);
      if (!context.mounted) return;
      await showDialog<String>(
        context: context,
        useSafeArea: false,
        builder: (_) => StudyEditor(
          isMistake: true,
          analysisOnly: true,
          sourceSessionId: message.sessionId,
          sourceMessageId: message.id,
          mistake: MistakeDetail(
            detail.item.copyWith(aiAnalysis: message.content),
            detail.tags,
            detail.images,
            detail.knowledge,
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
          await store.copyChatImage(id, image, isMistake: true);
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr("文字已保存，部分图片关联失败，请在详情中补充。"))),
          );
        }
      }
    }
    if (context.mounted) {
      context.push('${type == 'mistake' ? '/mistakes' : '/knowledge'}/$id');
    }
  }
}

final _toolHistoryProvider = StreamProvider.autoDispose
    .family<List<AiToolOperation>, String>((ref, id) {
      final store = ref.watch(studyStoreProvider);
      return (store.db.select(
        store.db.aiToolOperations,
      )..where((t) => t.runId.equals(id))).watch();
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
            if (op.name == 'run_python') return PythonHistoryCard(op);
            if (success && op.name == 'suggest_question_regions') {
              return SplitSuggestionCard(op);
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
                    context.tr("{0} · {1}", [
                      name,
                      success
                          ? context.tr("已执行")
                          : op.status == 'pending'
                          ? context.tr("等待确认")
                          : op.status == 'rejected'
                          ? context.tr("未执行")
                          : context.tr("未完成"),
                    ]),
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (success &&
                      result['id'] is String &&
                      (op.name.endsWith('knowledge') ||
                          op.name.endsWith('mistake')))
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.push(
                        '${op.name.endsWith('knowledge') ? '/knowledge' : '/mistakes'}/${result['id']}',
                      ),
                      child: Text(
                        context.tr("查看资料"),
                        style: TextStyle(fontSize: 11),
                      ),
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
      title: Text(context.tr("关联学习资料")),
      content: SizedBox(
        width: 480,
        height: 280,
        child: entries.isEmpty
            ? Center(
                child: Text(
                  context.tr("还没有关联资料。\n可以从消息菜单保存知识或错题。"),
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
          child: Text(context.tr("关闭")),
        ),
      ],
    ),
  );
  if (path != null && context.mounted) context.push(path);
}

Future<void> showPythonCode(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('Python 代码')),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(ctx).height * .6,
          child: SingleChildScrollView(
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'TixunMono',
                fontFamilyFallback: ['NotoSansSC'],
                fontSize: 13,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('关闭')),
          ),
        ],
      ),
    );

class PythonHistoryCard extends StatelessWidget {
  const PythonHistoryCard(this.operation, {super.key});
  final AiToolOperation operation;
  @override
  Widget build(BuildContext context) {
    Map args = {}, result = {};
    try {
      args = jsonDecode(operation.arguments) as Map;
    } catch (_) {}
    try {
      result = jsonDecode(operation.result ?? '{}') as Map;
    } catch (_) {}
    final status = switch (operation.status) {
      'succeeded' => '执行完成',
      'recording_failed' => '执行完成，记录异常',
      'rejected' => '未允许运行',
      'running' => '执行中',
      'stop_requested' => '已请求停止',
      'pending' => '等待审查',
      _ => '执行失败',
    };
    return ExpansionTile(
      key: PageStorageKey('python-history-${operation.id}'),
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.code, size: 20),
      title: Text(
        context.tr('Python · {0}', [context.tr(status)]),
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        args['purpose']?.toString() ?? '',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                showPythonCode(context, args['code']?.toString() ?? ''),
            child: Text(context.tr('查看完整代码')),
          ),
        ),
        if (result.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              key: PageStorageKey('python-output-${operation.id}'),
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                [
                  if (result['stdout'] != null) result['stdout'],
                  if (result['stderr'] != null && result['stderr'] != '')
                    'stderr:\n${result['stderr']}',
                  if (result['traceback'] != null) result['traceback'],
                  if (result['error'] != null)
                    context.tr(result['error'].toString()),
                  if (result['output_truncated'] == true)
                    context.tr('输出过长，已截断展示。'),
                ].join('\n'),
                style: const TextStyle(
                  fontFamily: 'TixunMono',
                  fontFamilyFallback: ['NotoSansSC'],
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
