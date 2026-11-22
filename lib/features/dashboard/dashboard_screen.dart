import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/app_menu.dart";
import "../library/library_providers.dart";
import "daily_learning.dart";
import "language_subject_action.dart";

part "dashboard_counts.dart";

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Semantics(
                      key: const Key("subject-switch"),
                      label: context.l10n.switchSubject,
                      child: AppSelectField<String>(
                        initialValue: c.subjectFilter,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.school_outlined, size: 19),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: "",
                            child: Text(context.l10n.allSubjects),
                          ),
                          for (final subject in [
                            ...c.learningSubjects,
                            if (c.subjectFilter.isNotEmpty &&
                                !c.learningSubjects.contains(c.subjectFilter))
                              c.subjectFilter,
                          ])
                            DropdownMenuItem(
                              value: subject,
                              child: Text(
                                context.subjectName(subject),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            // Filtering never switches the conversation.
                            unawaited(
                              act(context, () => c.setSubjectFilter(value)),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(compact ? 20 : 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1060),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.study,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key("open-timeline"),
                            onPressed: () => context.push("/timeline"),
                            icon: const Icon(Icons.event_note_outlined),
                            label: Text(context.l10n.timelineTitle),
                          ),
                          OutlinedButton.icon(
                            key: const Key("open-exams"),
                            onPressed: () => context.push("/exams"),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: Text(context.l10n.examRecords),
                          ),
                          if (isLanguageLearningSubject(c.subjectFilter))
                            LanguageSubjectAction(subject: c.subjectFilter),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const DailyLearning(),
                      const SizedBox(height: 24),
                      if (c.allSessions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(compact ? 24 : 32),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: .45,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                key: const Key("start-chat"),
                                onPressed: () => act(context, () async {
                                  await c.newSession();
                                  if (context.mounted) context.go("/chat");
                                }),
                                icon: const Icon(Icons.add, size: 18),
                                label: Text(
                                  context.l10n.startLearningConversation,
                                ),
                              ),
                              FilledButton.tonalIcon(
                                key: const Key("start-practice"),
                                onPressed: () => context.go("/practice"),
                                icon: const Icon(Icons.edit_note),
                                label: Text(context.l10n.practice),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.go("/mistakes"),
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 18,
                                ),
                                label: Text(context.l10n.addAMistake),
                              ),
                            ],
                          ),
                        ),
                      if (c.allSessions.isNotEmpty)
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              key: const Key("start-chat"),
                              onPressed: () => act(context, () async {
                                await c.newSession();
                                if (context.mounted) context.go("/chat");
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                context.l10n.startLearningConversation,
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go("/mistakes"),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              label: Text(context.l10n.addAMistake),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                      _DashboardCounts(controller: c, compact: compact),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.recentConversations,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 48),
                            ),
                            onPressed: () => act(context, () async {
                              await c.prepareSubjectChat();
                              if (context.mounted &&
                                  GoRouter.of(context).state.uri.path ==
                                      "/study") {
                                context.go("/chat");
                              }
                            }),
                            child: Text(context.l10n.allConversations),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (c.allSessions.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outlineVariant),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            context.l10n.noConversationsYet,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        )
                      else
                        ...c.allSessions
                            .take(3)
                            .map(
                              (s) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: colors.primaryContainer
                                            .withValues(alpha: .45),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 18,
                                        color: colors.primary,
                                      ),
                                    ),
                                    title: Text(
                                      s.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      context.l10n.continueLearning(
                                        l10nArgument((s.updatedAt.month)),
                                        l10nArgument((s.updatedAt.day)),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 14,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    onTap: () => act(context, () async {
                                      await c.selectSession(s);
                                      if (context.mounted) context.go("/chat");
                                    }),
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
