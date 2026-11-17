import 'package:tixun/core/l10n/app_error.dart';

import '../../core/ui/app_menu.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:go_router/go_router.dart';
import 'package:val_highlight/languages/python.dart';
import 'package:val_highlight_flutter/val_highlight_flutter.dart';

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

String? toolLabel(BuildContext context, String key) => switch (key) {
  'run_python' => context.l10n.runPython,
  'create_subject_module' => context.l10n.createSubjectDirectoryEntry,
  'link_study_module' => context.l10n.linkMaterialToModule,
  'schedule_review' => context.l10n.addToReviews,
  'create_quiz' => context.l10n.createPracticeQuestion,
  'suggest_question_regions' => context.l10n.suggestQuestionRegions,
  'create_knowledge' => context.l10n.createKnowledge,
  'update_knowledge' => context.l10n.updateKnowledge,
  'delete_knowledge' => context.l10n.moveKnowledgeToTrash,
  'create_mistake' => context.l10n.createMistake,
  'update_mistake' => context.l10n.updateMistake,
  'delete_mistake' => context.l10n.moveMistakeToTrash,
  'link_mistake_to_knowledge' => context.l10n.linkMistakeAndKnowledge,
  _ => null,
};

String? fieldLabel(BuildContext context, String key) => switch (key) {
  'purpose' => context.l10n.purpose,
  'code' => context.l10n.pythonCode,
  'timeout_seconds' => context.l10n.requestedTimeLimitSeconds,
  'name' => context.l10n.directoryName,
  'title' => context.l10n.titleLabel,
  'content' => context.l10n.knowledgeContent,
  'subject' => context.l10n.subject,
  'kind' => context.l10n.knowledgeType,
  'chapter' => context.l10n.chapter,
  'tags' => context.l10n.tagsLabel,
  'question' => context.l10n.question,
  'correct_answer' => context.l10n.referenceAnswers,
  'ai_analysis' => context.l10n.aiExplanation,
  'suggested_reason' => context.l10n.aiProposedCauseNeedsConfirmation,
  'expected_revision' => context.l10n.versionNumber,
  'image_indices' => context.l10n.referencedImageIndices,
  _ => null,
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
            context.l10n.pleaseConfirm(
              l10nArgument(
                (toolLabel(context, request.name) ??
                    context.l10n.modifyMaterial),
              ),
            ),
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
              context.l10n.theOriginalQuestionImagesIn(
                l10nArgument((request.imageCount)),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          if (request.name == 'schedule_review')
            Text(context.l10n.afterAddingAReviewThe),
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
                            fieldLabel(context, e.key)!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (e.key == 'code')
                            PythonCodeView(e.value.toString(), fontSize: 12)
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
                    Text(context.l10n.materialWillMoveToTrash),
                ],
              ),
            ),
          ),
          if (request.name == 'run_python') ...[
            Text(
              context.l10n.codeAccessWarningWithModelOutput,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () =>
                  showPythonCode(context, request.arguments['code'].toString()),
              child: Text(context.l10n.viewFullCode),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key('reject-tool'),
                onPressed: () => c.decideTool(false),
                child: Text(context.l10n.doNotApply),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('approve-tool'),
                onPressed: () => c.decideTool(true),
                child: Text(
                  (request.name == 'run_python'
                      ? context.l10n.allowExecution
                      : context.l10n.confirmAction),
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
      tooltip: context.l10n.saveLearningMaterial,
      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
      enabled: message.status != 'generating',
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'fork',
          enabled: !ref.read(appControllerProvider).busy,
          child: Text(context.l10n.forkFromHere),
        ),
        const PopupMenuDivider(),
        if (hasMistake && message.content.trim().isNotEmpty)
          PopupMenuItem(
            value: 'analysis',
            child: Text(context.l10n.saveAsAIExplanationFor),
          ),
        PopupMenuItem(
          value: 'knowledge',
          child: Text(context.l10n.saveToKnowledge),
        ),
        PopupMenuItem(
          value: 'mistake',
          child: Text(context.l10n.saveAsAMistake),
        ),
        if (message.role == 'assistant' &&
            message.content.trim().isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'ai-knowledge',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.l10n.organizeAsKnowledgeWithAI),
          ),
          PopupMenuItem(
            value: 'ai-merge',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.l10n.mergeIntoExistingKnowledgeWith),
          ),
          PopupMenuItem(
            value: 'ai-mistake',
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.l10n.organizeAsAMistakeWith),
          ),
        ],
      ],
      onSelected: (type) => act(context, () => _save(context, ref, type)),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, String type) async {
    final c = ref.read(appControllerProvider);
    final store = ref.read(studyStoreProvider);
    if (type == 'fork') {
      await c.forkChat(message);
      if (context.mounted) context.go('/chat');
      return;
    }
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
      throw const AppFormatException(
        AppErrorCode.errorReopenThisConversationBeforeSaving,
        '请重新打开此会话后保存。',
      );
    }
    final question = message.role == 'user'
        ? message
        : c.messages.take(index).where((m) => m.role == 'user').lastOrNull;
    if (type == 'analysis') {
      final candidates = await ref.read(
        linkedMistakesProvider(c.selected!.id).future,
      );
      if (candidates.isEmpty) {
        throw const AppFormatException(
          AppErrorCode.errorThisConversationHasNoLinkedMistake,
          '此对话没有关联错题，请先从错题详情发起学习对话。',
        );
      }
      if (!context.mounted) return;
      var selected = candidates.first;
      if (candidates.length > 1) {
        final chosen = await showDialog<Mistake>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(context.l10n.chooseAMistakeToUpdate),
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
            SnackBar(content: Text(context.l10n.textSavedButSomeImages)),
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
      return store.db
          .customSelect(
            'SELECT * FROM ai_tool_operations WHERE run_id = ? ORDER BY rowid',
            variables: [Variable.withString(id)],
            readsFrom: {store.db.aiToolOperations},
          )
          .watch()
          .map(
            (rows) => rows
                .map((row) => store.db.aiToolOperations.map(row.data))
                .toList(),
          );
    });

class ToolHistory extends ConsumerWidget {
  const ToolHistory(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_toolHistoryProvider(messageId))
      .maybeWhen(
        data: (items) => ToolHistoryPanel(messageId: messageId, items: items),
        orElse: () => const SizedBox.shrink(),
      );
}

/// The operation log stays compact, while actionable split suggestions remain
/// visible as message results outside the collapsed history.
class ToolHistoryPanel extends StatelessWidget {
  const ToolHistoryPanel({
    required this.messageId,
    required this.items,
    super.key,
  });
  final String messageId;
  final List<AiToolOperation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ordered = items;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExpansionTile(
              key: PageStorageKey('tool-history-$messageId'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: colors.surfaceContainerLow,
              collapsedBackgroundColor: colors.surfaceContainerLow,
              leading: Icon(
                Icons.build_circle_outlined,
                size: 20,
                color: colors.primary,
              ),
              title: Text(
                context.l10n.toolActivityCount('${items.length}'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              subtitle: Text(
                _toolSummary(context, ordered.last),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                for (final op in ordered) _toolHistoryItem(context, op),
              ],
            ),
          ),
        ),
        for (final op in ordered)
          if (op.status == 'succeeded' && op.name == 'suggest_question_regions')
            SplitSuggestionCard(op),
      ],
    );
  }
}

Map<String, dynamic> _toolMap(String? encoded) {
  if (encoded == null) return const {};
  try {
    final value = jsonDecode(encoded);
    return value is Map ? value.cast<String, dynamic>() : const {};
  } on FormatException {
    return const {};
  }
}

String _toolSummary(BuildContext context, AiToolOperation op) {
  final args = _toolMap(op.arguments);
  final result = _toolMap(op.result);
  final l = context.l10n;
  final label = switch (op.name) {
    'search_knowledge' => l.toolSearchKnowledge,
    'search_mistakes' => l.toolSearchMistakes,
    'get_knowledge' => l.toolReadKnowledge,
    'get_mistake' => l.toolReadMistake,
    'list_subject_modules' => l.toolSearchModules,
    'get_learning_progress' => l.toolReadProgress,
    'create_visual' => l.toolCreateVisual,
    'update_visual' => l.toolUpdateVisual,
    'get_visual' => l.toolReadVisual,
    _ => toolLabel(context, op.name) ?? l.toolActivityFallback,
  };
  String? detail;
  if (op.name == 'search_knowledge' ||
      op.name == 'search_mistakes' ||
      op.name == 'list_subject_modules') {
    final query = args['query'];
    detail = query is String && query.trim().isNotEmpty
        ? query.trim()
        : l.toolSearchAll;
  } else {
    final scene = args['scene'];
    final value =
        result['title'] ??
        args['title'] ??
        (scene is Map ? scene['title'] : null) ??
        args['name'] ??
        (op.name == 'run_python' ? args['purpose'] : null);
    if (value is String && value.trim().isNotEmpty) detail = value.trim();
  }
  // Never surface full code, document bodies, opaque identifiers, or results.
  return detail == null
      ? label
      : '$label ${detail.replaceAll(RegExp(r'\s+'), ' ')}';
}

Widget _toolHistoryItem(BuildContext context, AiToolOperation op) {
  if (op.name == 'run_python') return PythonHistoryCard(op);
  final result = _toolMap(op.result);
  final summary = _toolSummary(context, op);
  final success = op.status == 'succeeded';
  final read =
      op.name.startsWith('search_') ||
      op.name.startsWith('get_') ||
      op.name == 'list_subject_modules';
  final status = switch (op.status) {
    'succeeded' => read ? context.l10n.completed : context.l10n.applied,
    'pending' =>
      read ? context.l10n.running : context.l10n.awaitingConfirmation,
    'running' => context.l10n.running,
    'rejected' => context.l10n.notApplied,
    _ => context.l10n.notCompleted,
  };
  final hasMaterial =
      success &&
      result['id'] is String &&
      (op.name.endsWith('knowledge') || op.name.endsWith('mistake'));
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 8),
          child: Icon(
            success
                ? Icons.check_circle_outline
                : op.status == 'failed'
                ? Icons.error_outline
                : Icons.info_outline,
            size: 16,
            color: op.status == 'failed'
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: summary,
                child: Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(status, style: Theme.of(context).textTheme.labelSmall),
              if (hasMaterial)
                TextButton(
                  onPressed: () => context.push(
                    '${op.name.endsWith('knowledge') ? '/knowledge' : '/mistakes'}/${result['id']}',
                  ),
                  child: Text(context.l10n.viewMaterial),
                ),
            ],
          ),
        ),
      ],
    ),
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
      title: Text(context.l10n.linkedLearningMaterial),
      content: SizedBox(
        width: 480,
        height: 280,
        child: entries.isEmpty
            ? Center(
                child: Text(
                  context.l10n.noLinkedMaterialYetSave,
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
          child: Text(context.l10n.close),
        ),
      ],
    ),
  );
  if (path != null && context.mounted) context.push(path);
}

// A small shared cache avoids retaining an unbounded history of model code.
final _pythonHighlighter = CodeHighlighter(
  cacheSize: 4,
  isolateThreshold: 12000,
);

class PythonCodeView extends StatelessWidget {
  const PythonCodeView(this.code, {super.key, this.fontSize = 13});
  final String code;
  final double fontSize;
  @override
  Widget build(BuildContext context) => CodeView(
    code,
    key: const Key('python-highlighted-code'),
    language: pythonLanguage,
    highlighter: _pythonHighlighter,
    selectable: true,
    padding: const EdgeInsets.all(8),
    textStyle: TextStyle(
      fontFamily: 'TixunMono',
      fontFamilyFallback: const ['NotoSansSC'],
      fontSize: fontSize,
      height: 1.5,
    ),
  );
}

Future<void> showPythonCode(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.pythonCode),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(ctx).height * .6,
          child: SingleChildScrollView(child: PythonCodeView(code)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
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
      'succeeded' => context.l10n.completed,
      'recording_failed' => context.l10n.executedRecordingError,
      'rejected' => context.l10n.executionDenied,
      'running' => context.l10n.running,
      'stop_requested' => context.l10n.stopRequested,
      'pending' => context.l10n.awaitingReview,
      _ => context.l10n.executionFailed,
    };
    return ExpansionTile(
      key: PageStorageKey('python-history-${operation.id}'),
      tilePadding: EdgeInsets.zero,
      leading: const Icon(Icons.code, size: 20),
      title: Text(
        context.l10n.python(l10nArgument((status))),
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
            child: Text(context.l10n.viewFullCode),
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
                  if (result['error'] != null) result['error'].toString(),
                  if (result['output_truncated'] == true)
                    context.l10n.outputExceededTheDisplayLimit,
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
