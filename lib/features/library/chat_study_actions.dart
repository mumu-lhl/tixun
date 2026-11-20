import "dart:async";

import "package:tixun/core/l10n/app_error.dart";

import "../../core/ui/app_menu.dart";

import "dart:convert";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:drift/drift.dart" show Variable;
import "package:go_router/go_router.dart";
import "package:val_highlight/languages/python.dart";
import "package:val_highlight_flutter/val_highlight_flutter.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/learning_markdown.dart";
import "library_providers.dart";
import "split_suggestions.dart";
import "study_editor.dart";
import "study_store.dart";
import "ai_study_actions.dart";

part "chat_study_history.dart";

const toolLabels = {
  "run_python": "运行 Python",
  "create_subject_module": "新增科目目录",
  "link_study_module": "关联资料与模块",
  "schedule_review": "加入复习",
  "create_quiz": "创建练习题",
  "suggest_question_regions": "提出分题建议",
  "create_knowledge": "新增知识",
  "update_knowledge": "修改知识",
  "delete_knowledge": "知识移入回收区",
  "create_mistake": "新增错题",
  "update_mistake": "修改错题",
  "delete_mistake": "错题移入回收区",
  "link_mistake_to_knowledge": "关联错题与知识",
};
const fieldLabels = {
  "purpose": "运行用途",
  "code": "Python 代码",
  "timeout_seconds": "期望执行时限（秒）",
  "name": "目录名称",
  "title": "标题",
  "content": "知识正文",
  "subject": "科目",
  "kind": "知识类型",
  "chapter": "章节",
  "tags": "标签",
  "question": "题目",
  "correct_answer": "参考答案",
  "ai_analysis": "AI 解析",
  "suggested_reason": "AI 建议的原因（待确认）",
  // The remaining off-table parameters need no label: id / module_id /
  // knowledge_id / mistake_id / question_id / parent_id are opaque ids
  // already rendered human-readably as `target`, and `query` only occurs
  // in read tools that never ask for confirmation.
  "expected_revision": "版本号",
  "image_indices": "引用图片序号",
};

String? toolLabel(BuildContext context, String key) => switch (key) {
  "run_python" => context.l10n.runPython,
  "create_subject_module" => context.l10n.createSubjectDirectoryEntry,
  "link_study_module" => context.l10n.linkMaterialToModule,
  "schedule_review" => context.l10n.addToReviews,
  "create_quiz" => context.l10n.createPracticeQuestion,
  "suggest_question_regions" => context.l10n.suggestQuestionRegions,
  "create_knowledge" => context.l10n.createKnowledge,
  "update_knowledge" => context.l10n.updateKnowledge,
  "delete_knowledge" => context.l10n.moveKnowledgeToTrash,
  "create_mistake" => context.l10n.createMistake,
  "update_mistake" => context.l10n.updateMistake,
  "delete_mistake" => context.l10n.moveMistakeToTrash,
  "link_mistake_to_knowledge" => context.l10n.linkMistakeAndKnowledge,
  _ => null,
};

String? fieldLabel(BuildContext context, String key) => switch (key) {
  "purpose" => context.l10n.purpose,
  "code" => context.l10n.pythonCode,
  "timeout_seconds" => context.l10n.requestedTimeLimitSeconds,
  "name" => context.l10n.directoryName,
  "title" => context.l10n.titleLabel,
  "content" => context.l10n.knowledgeContent,
  "subject" => context.l10n.subject,
  "kind" => context.l10n.knowledgeType,
  "chapter" => context.l10n.chapter,
  "tags" => context.l10n.tagsLabel,
  "question" => context.l10n.question,
  "correct_answer" => context.l10n.referenceAnswers,
  "ai_analysis" => context.l10n.aiExplanation,
  "suggested_reason" => context.l10n.aiProposedCauseNeedsConfirmation,
  "expected_revision" => context.l10n.versionNumber,
  "image_indices" => context.l10n.referencedImageIndices,
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
      key: const Key("tool-approval"),
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
          if (request.name == "create_mistake" && request.imageCount > 0)
            Text(
              context.l10n.theOriginalQuestionImagesIn(
                l10nArgument((request.imageCount)),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          if (request.name == "schedule_review")
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
                        !(request.name == "link_study_module" &&
                            e.key == "kind"),
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
                          if (e.key == "code")
                            PythonCodeView(e.value.toString(), fontSize: 12)
                          else
                            LearningMarkdown(
                              e.value is List
                                  ? (e.value as List).join("、")
                                  : e.value.toString(),
                            ),
                        ],
                      ),
                    ),
                  if (request.name.startsWith("delete"))
                    Text(context.l10n.materialWillMoveToTrash),
                ],
              ),
            ),
          ),
          if (request.name == "run_python") ...[
            Text(
              context.l10n.codeAccessWarningWithModelOutput,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () =>
                  showPythonCode(context, request.arguments["code"].toString()),
              child: Text(context.l10n.viewFullCode),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const Key("reject-tool"),
                onPressed: () => c.decideTool(false),
                child: Text(context.l10n.doNotApply),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key("approve-tool"),
                onPressed: () => c.decideTool(true),
                child: Text(
                  (request.name == "run_python"
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
        message.role == "assistant" &&
        sessionId != null &&
        (ref.watch(linkedMistakesProvider(sessionId)).value?.isNotEmpty ??
            false);
    return PopupMenuButton<String>(
      popUpAnimationStyle: menuAnimation(context),
      tooltip: context.l10n.saveLearningMaterial,
      icon: const Icon(Icons.bookmark_add_outlined, size: 18),
      enabled: message.status != "generating",
      itemBuilder: (_) => [
        PopupMenuItem(
          value: "fork",
          enabled: !ref.read(appControllerProvider).busy,
          child: Text(context.l10n.forkFromHere),
        ),
        const PopupMenuDivider(),
        if (hasMistake && message.content.trim().isNotEmpty)
          PopupMenuItem(
            value: "analysis",
            child: Text(context.l10n.saveAsAIExplanationFor),
          ),
        PopupMenuItem(
          value: "knowledge",
          child: Text(context.l10n.saveToKnowledge),
        ),
        PopupMenuItem(
          value: "mistake",
          child: Text(context.l10n.saveAsAMistake),
        ),
        if (message.role == "assistant" &&
            message.content.trim().isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: "ai-knowledge",
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.l10n.organizeAsKnowledgeWithAI),
          ),
          PopupMenuItem(
            value: "ai-merge",
            enabled: !ref.read(appControllerProvider).busy,
            child: Text(context.l10n.mergeIntoExistingKnowledgeWith),
          ),
          PopupMenuItem(
            value: "ai-mistake",
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
    if (type == "fork") {
      await c.forkChat(message);
      if (context.mounted) context.go("/chat");
      return;
    }
    if (type.startsWith("ai-")) {
      final target = type == "ai-merge"
          ? await pickKnowledgeForAi(context, store)
          : null;
      if ((type == "ai-merge" && target == null) || !context.mounted) return;
      await startAiStudyWriting(
        context,
        ref,
        source: message,
        knowledge: target,
        mistake: type == "ai-mistake",
      );
      return;
    }
    final index = c.messages.indexWhere((m) => m.id == message.id);
    if (index < 0 || c.selected == null) {
      throw const AppFormatException(
        AppErrorCode.errorReopenThisConversationBeforeSaving,
        "请重新打开此会话后保存。",
      );
    }
    final question = message.role == "user"
        ? message
        : c.messages.take(index).where((m) => m.role == "user").lastOrNull;
    if (type == "analysis") {
      final candidates = await ref.read(
        linkedMistakesProvider(c.selected!.id).future,
      );
      if (candidates.isEmpty) {
        throw const AppFormatException(
          AppErrorCode.errorThisConversationHasNoLinkedMistake,
          "此对话没有关联错题，请先从错题详情发起学习对话。",
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
        .replaceAll("\n", " ")
        .characters
        .take(60)
        .toString();
    final sourceSession = c.selected!.id;
    final id = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (_) => StudyEditor(
        isMistake: type == "mistake",
        sourceSessionId: sourceSession,
        sourceMessageId: message.id,
        initialKnowledge: type == "knowledge"
            ? KnowledgeDraft(title: "学习笔记 · $title", content: message.content)
            : null,
        initialMistake: type == "mistake"
            ? MistakeDraft(
                title: title,
                question: question?.content ?? "",
                aiAnalysis: message.role == "assistant" ? message.content : "",
              )
            : null,
      ),
    );
    if (id == null || !context.mounted) return;
    if (type == "mistake" && question != null) {
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
      unawaited(
        context.push('${type == 'mistake' ? '/mistakes' : '/knowledge'}/$id'),
      );
    }
  }
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
        entries.add((title: k.title, path: "/knowledge/${k.id}"));
      }
      if (link.mistakeId != null) {
        final m = await c.study.mistake(link.mistakeId!);
        entries.add((title: m.title, path: "/mistakes/${m.id}"));
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
  if (path != null && context.mounted) unawaited(context.push(path));
}

// A small shared cache avoids retaining an unbounded history of model code.
