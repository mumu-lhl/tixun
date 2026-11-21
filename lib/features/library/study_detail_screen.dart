import "package:tixun/core/l10n/app_error_localization.dart";
import "package:tixun/core/l10n/app_error.dart";

import "study_localization.dart";
import "module_widgets.dart";
import "../chat/message_reasoning.dart";
import "../scratchpad/scratchpad_screen.dart";

import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/page_content.dart";
import "../../core/ui/learning_markdown.dart";
import "../visual/study_visuals.dart";
import "../visual/visual_markdown.dart";
import "../../core/markdown/visual_references.dart";
import "../practice/question_spec.dart";
import "library_providers.dart";
import "study_editor.dart";
import "study_images.dart";
import "study_store.dart";
import "ai_study_actions.dart";

part "study_detail_actions.dart";

part "study_detail_sections.dart";

class StudyDetailScreen extends ConsumerWidget {
  const StudyDetailScreen({
    required this.id,
    required this.isMistake,
    super.key,
  });
  final String id;
  final bool isMistake;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Object> detail = isMistake
        ? ref.watch(mistakeDetailProvider(id))
        : ref.watch(knowledgeDetailProvider(id));
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              e is FormatException
                  ? failureText(context.l10n, e)
                  : context.l10n.couldNotLoadMaterial,
            ),
            TextButton(
              onPressed: () =>
                  context.go(isMistake ? "/mistakes" : "/knowledge"),
              child: Text(context.l10n.backToList),
            ),
          ],
        ),
      ),
      data: (data) {
        final k = data is KnowledgeDetail ? data : null;
        final m = data is MistakeDetail ? data : null;
        final title = k?.item.title ?? m!.item.title;
        final subject = k?.item.subject ?? m!.item.subject;
        final chapter = k?.item.chapter ?? m!.item.chapter;
        final deleted = k?.item.deleted ?? m!.item.deleted;
        final revision = k?.item.revision ?? m!.item.revision;
        final tags = k?.tags ?? m!.tags;
        final source = k?.item.sourceSessionId ?? m?.item.sourceSessionId;
        final store = ref.read(studyStoreProvider);
        final content = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.backToList,
                    onPressed: () =>
                        context.go(isMistake ? "/mistakes" : "/knowledge"),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  if (k != null && !deleted)
                    IconButton(
                      tooltip: context.l10n.textRevisionHistory,
                      onPressed: () =>
                          act(context, () => _history(context, ref, k)),
                      icon: const Icon(Icons.history),
                    ),
                  IconButton(
                    key: const Key("edit-study"),
                    tooltip: context.l10n.editMaterial,
                    onPressed: deleted
                        ? null
                        : () => showDialog<String>(
                            context: context,
                            useSafeArea: false,
                            builder: (_) => StudyEditor(
                              isMistake: isMistake,
                              knowledge: k,
                              mistake: m,
                            ),
                          ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: deleted
                        ? context.l10n.restoreMaterial
                        : context.l10n.moveToTrash,
                    onPressed: () => act(context, () async {
                      await store.setDeleted(
                        id,
                        isMistake: isMistake,
                        deleted: !deleted,
                        expectedRevision: revision,
                      );
                      if (context.mounted) {
                        if (!deleted) {
                          context.go(isMistake ? "/mistakes" : "/knowledge");
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              deleted
                                  ? context.l10n.materialRestored
                                  : context.l10n.movedToTrashYouCan,
                            ),
                          ),
                        );
                      }
                    }),
                    icon: Icon(
                      deleted
                          ? Icons.restore_from_trash_outlined
                          : Icons.delete_outline,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                label: Text(
                                  subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (chapter.isNotEmpty)
                                Chip(
                                  label: Text(
                                    chapter,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (k != null)
                                Chip(
                                  label: Text(
                                    knowledgeKindLabel(context, k.item.kind),
                                  ),
                                ),
                              ...tags.map(
                                (t) => Chip(
                                  label: Text(
                                    "#$t",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ModuleAssignment(
                            id: id,
                            subject: subject,
                            mistake: isMistake,
                            editable: !deleted,
                          ),
                          if (deleted)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(context.l10n.thisMaterialIsInTrash),
                            ),
                          if (!deleted)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    key: const Key("study-to-chat"),
                                    onPressed: () => act(
                                      context,
                                      () => _toChat(
                                        context,
                                        ref,
                                        k,
                                        m,
                                        direct: isMistake,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isMistake
                                          ? context.l10n.analyzeWithAI
                                          : context.l10n.askAI,
                                    ),
                                  ),
                                  if (k != null)
                                    OutlinedButton.icon(
                                      key: const Key("ai-edit-knowledge"),
                                      onPressed: () => act(
                                        context,
                                        () => startAiStudyWriting(
                                          context,
                                          ref,
                                          knowledge: k.item,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 18,
                                      ),
                                      label: Text(context.l10n.editWithAI),
                                    ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => act(context, () async {
                                      final id = await ref
                                          .read(appControllerProvider)
                                          .practice
                                          .create(
                                            QuestionSpec(
                                              kind: "short_answer",
                                              subject:
                                                  k?.item.subject ??
                                                  m!.item.subject,
                                              stem: m != null
                                                  ? (m.item.question.isEmpty
                                                        ? m.item.title
                                                        : m.item.question)
                                                  : "请先合上笔记，回忆并解释：${k!.item.title}",
                                              answers: const [],
                                              explanation:
                                                  k?.item.content ??
                                                  "${m!.item.correctAnswer}\n\n${m.item.ownAnalysis}\n\n${m.item.aiAnalysis}",
                                              topics: k != null
                                                  ? [
                                                      k.item.title.length > 120
                                                          ? k.item.title
                                                                .substring(
                                                                  0,
                                                                  120,
                                                                )
                                                          : k.item.title,
                                                    ]
                                                  : [],
                                            ),
                                            origin: m != null
                                                ? "mistake"
                                                : "recall",
                                            verification: "unverified",
                                            mistakeId: m?.item.id,
                                            knowledgeIds: k == null
                                                ? []
                                                : [k.item.id],
                                          );
                                      if (context.mounted) {
                                        context.go("/practice/$id");
                                      }
                                    }),
                                    icon: const Icon(Icons.edit_note, size: 18),
                                    label: Text(
                                      m != null
                                          ? context
                                                .l10n
                                                .retryWithoutTheExplanation
                                          : context.l10n.recallCheck,
                                    ),
                                  ),
                                  if (m != null)
                                    ScratchpadButton("mistake:$id"),
                                  if (m != null)
                                    TextButton.icon(
                                      onPressed: () => act(
                                        context,
                                        () => _toChat(
                                          context,
                                          ref,
                                          k,
                                          m,
                                          direct: false,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 16,
                                      ),
                                      label: Text(
                                        context.l10n.guideMeThroughIt,
                                      ),
                                    ),
                                  if (source != null)
                                    TextButton.icon(
                                      onPressed: () => act(
                                        context,
                                        () => _source(context, ref, source),
                                      ),
                                      icon: const Icon(Icons.link, size: 18),
                                      label: Text(
                                        context.l10n.sourceConversation,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if ((k?.item.sourceMessageId ??
                                  m?.item.sourceMessageId) !=
                              null)
                            SourceReasoning(
                              (k?.item.sourceMessageId ??
                                  m?.item.sourceMessageId)!,
                            ),
                          ..._materialSections(context, k, m, deleted),
                          ..._relatedMaterials(
                            context,
                            ref,
                            store,
                            k,
                            m,
                            deleted,
                            revision,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        return PageContent(maxWidth: 900, child: content);
      },
    );
  }

  Widget _section(BuildContext context, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _panel(context, title, LearningMarkdown(text)),
  );

  Widget _panel(BuildContext context, String title, Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
