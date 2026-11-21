import "dart:async";

import "../../core/ui/app_menu.dart";
import "../scratchpad/scratchpad_screen.dart";

import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/ai/study_tools.dart";
import "../../core/ai/web_activity.dart";
import "../../core/ai/ai_usage_store.dart";
import "../../core/ai/ai_usage_summary.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/usage_token_breakdown.dart";
import "../../core/ui/markdown_editor.dart";
import "../../core/platform/photo_picker.dart";
import "../../core/ui/image_viewer.dart";
import "../library/chat_study_actions.dart";
import "../library/image_editor.dart";
import "../practice/question_card.dart";
import "../visual/visual_markdown.dart";
import "../settings/tool_call_limit_setting.dart";
import "reasoning_menu.dart";
import "drawing_menu.dart";
import "message_reasoning.dart";
import "message_web_activity.dart";
import "chat_web_settings.dart";
import "chat_failure.dart";
import "session_list.dart";

part "chat_conversation.dart";
part "chat_message_panel.dart";
part "chat_composer.dart";
part "message_view.dart";
part "message_usage.dart";
part "chat_attachment.dart";

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Row(
      children: [
        if (wide) ...[
          SizedBox(
            width: 268,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const SessionList(),
            ),
          ),
          const VerticalDivider(width: 1),
        ],
        Expanded(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .45),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (MediaQuery.sizeOf(context).width < 800)
                      IconButton(
                        key: const Key("chat-back"),
                        tooltip: context.l10n.back,
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go("/study");
                          }
                        },
                      ),
                    if (!wide)
                      IconButton(
                        tooltip: context.l10n.conversations,
                        icon: const Icon(Icons.menu_book_outlined),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (context) => SizedBox(
                            height: MediaQuery.sizeOf(context).height * .85,
                            child: SessionList(
                              onSelected: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.selected?.title ??
                                context.l10n.aiLearningAssistant,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            c.demo
                                ? context.l10n.mockIsolatedDataNoAPI
                                : c.config.kind == "chatgpt"
                                ? context.l10n.usingChatGPTPlan(
                                    c.config.model,
                                    c.busy
                                        ? context.l10n.responding
                                        : context.l10n.savedLocally,
                                  )
                                : "${c.config.model} · ${c.busy ? context.l10n.responding : context.l10n.savedLocally}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: (c.selected?.toolsEnabled == true
                            ? context.l10n.manageMaterialTools
                            : context.l10n.enableMaterialTools),
                        onPressed: c.busy || c.selected == null
                            ? null
                            : () => act(
                                context,
                                () => _toggleStudyTools(context, c),
                              ),
                        icon: Icon(
                          c.selected?.toolsEnabled == true
                              ? Icons.auto_stories
                              : Icons.auto_stories_outlined,
                          size: 21,
                        ),
                      ),
                    if (!compact)
                      IconButton(
                        tooltip: context.l10n.linkedLearningMaterial,
                        onPressed: () => act(
                          context,
                          () => openChatStudyLinks(context, ref),
                        ),
                        icon: const Icon(Icons.link, size: 21),
                      ),
                    const ReasoningMenu(),
                    if (c.selected != null)
                      ScratchpadButton("chat:${c.selected!.id}"),
                    if (!compact)
                      IconButton(
                        tooltip: context.l10n.modelSettings,
                        onPressed: () => context.push("/settings/ai"),
                        icon: const Icon(Icons.tune, size: 21),
                      ),
                    PopupMenuButton<String>(
                      popUpAnimationStyle: menuAnimation(context),
                      key: const Key("chat-more"),
                      tooltip: context.l10n.moreChatActions,
                      icon: Badge(
                        isLabelVisible: c.selected?.toolsEnabled == true,
                        smallSize: 6,
                        child: const Icon(Icons.more_vert),
                      ),
                      onSelected: (action) {
                        if (handleDrawingMenuSelection(context, c, action)) {
                          return;
                        }
                        if (action == "web") {
                          unawaited(showChatWebSettings(context, c));
                          return;
                        }
                        if (action == "tool-call-limit") {
                          unawaited(editToolCallLimit(context, c));
                          return;
                        }
                        if (action == "tools") {
                          unawaited(
                            act(context, () => _toggleStudyTools(context, c)),
                          );
                        }
                        if (action == "links") {
                          unawaited(
                            act(
                              context,
                              () => openChatStudyLinks(context, ref),
                            ),
                          );
                        }
                        if (action == "settings") {
                          unawaited(context.push("/settings/ai"));
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (c.selected != null)
                          CheckedPopupMenuItem(
                            key: const Key("chat-web-settings"),
                            value: "web",
                            checked: c.sessionWebEnabled,
                            enabled: !c.busy,
                            child: Text(ctx.l10n.aiWebAccess),
                          ),
                        ...drawingMenuItems(ctx, c),
                        if (compact) const PopupMenuDivider(),
                        if (compact)
                          CheckedPopupMenuItem(
                            value: "tools",
                            checked: c.selected?.toolsEnabled == true,
                            enabled: !c.busy && c.selected != null,
                            child: Text(
                              (c.selected?.toolsEnabled == true
                                  ? ctx.l10n.manageMaterialTools
                                  : ctx.l10n.enableMaterialTools),
                            ),
                          ),
                        if (compact)
                          PopupMenuItem(
                            value: "links",
                            enabled: c.selected != null,
                            child: Text(ctx.l10n.linkedLearningMaterial),
                          ),
                        if (compact)
                          PopupMenuItem(
                            value: "settings",
                            child: Text(ctx.l10n.modelSettings),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (c.error != null)
                MaterialBanner(
                  content: Text(c.error!.text(context.l10n)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        c.error = null;
                        c.changed();
                      },
                      child: Text(context.l10n.close),
                    ),
                  ],
                ),
              Expanded(
                child: c.selected == null
                    ? _NoSession(onStart: () => act(context, c.newSession))
                    : Conversation(key: ValueKey(c.selected!.id)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _toggleStudyTools(BuildContext context, AppController c) async {
  final session = c.selected;
  if (session == null || c.busy) return;
  final selection = session.toolsEnabled
      ? {...c.studyToolCategories}
      : <StudyToolCategory>{};
  final categories = await showDialog<Set<StudyToolCategory>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        scrollable: true,
        title: Text(ctx.l10n.materialTools),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.onlySelectedCategoriesAreAvailable),
            const SizedBox(height: 12),
            for (final (category, label) in [
              (StudyToolCategory.knowledge, ctx.l10n.knowledge),
              (StudyToolCategory.mistakes, ctx.l10n.mistakeQuestions),
              (StudyToolCategory.modules, ctx.l10n.subjectModules),
              (StudyToolCategory.progress, ctx.l10n.learningProgress),
              (StudyToolCategory.review, ctx.l10n.reviewSchedule),
            ])
              CheckboxListTile(
                key: Key("study-tools-${category.name}"),
                value: selection.contains(category),
                title: Text(label),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onChanged: (enabled) => update(() {
                  enabled == true
                      ? selection.add(category)
                      : selection.remove(category);
                }),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, <StudyToolCategory>{}),
            child: Text(ctx.l10n.disableAll),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, allStudyToolCategories),
            child: Text(ctx.l10n.enableAll),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, selection),
            child: Text(ctx.l10n.save),
          ),
        ],
      ),
    ),
  );
  if (categories != null && context.mounted && c.selected?.id == session.id) {
    await c.setStudyToolCategories(categories);
  }
}

class _NoSession extends StatelessWidget {
  const _NoSession({required this.onStart});
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 44,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.everyQuestionIsWorthUnderstanding,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(context.l10n.typeAQuestionOrAdd, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onStart,
            child: Text(context.l10n.startANewConversation),
          ),
        ],
      ),
    ),
  );
}
