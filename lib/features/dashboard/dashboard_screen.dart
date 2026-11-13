import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../library/library_providers.dart';
import 'daily_learning.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final counts = ref.watch(studyCountsProvider);
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: EdgeInsets.all(compact ? 20 : 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.study,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.l10n.everyIndependentAttemptIsA,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.localFirst,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  key: const Key('open-exams'),
                  onPressed: () => context.push('/exams'),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(context.l10n.examRecords),
                ),
                const SizedBox(height: 12),
                const DailyLearning(),
                const SizedBox(height: 24),
                if (c.allSessions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(compact ? 24 : 32),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.understandTryMaster,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.turnConfusionIntoUnderstanding,
                          style: TextStyle(
                            fontSize: compact ? 30 : 38,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          context.l10n.startWithOneQuestionOr,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              key: const Key('start-chat'),
                              onPressed: () => act(context, () async {
                                await c.newSession();
                                if (context.mounted) context.go('/chat');
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: Text(
                                context.l10n.startLearningConversation,
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const Key('start-practice'),
                              onPressed: () => context.go('/practice'),
                              icon: const Icon(Icons.edit_note),
                              label: Text(context.l10n.practice),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/mistakes'),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              label: Text(context.l10n.addAMistake),
                            ),
                          ],
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
                        key: const Key('start-chat'),
                        onPressed: () => act(context, () async {
                          await c.newSession();
                          if (context.mounted) context.go('/chat');
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(context.l10n.startLearningConversation),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.go('/mistakes'),
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.addAMistake),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (compact)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .5),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final (label, value) in [
                          (
                            context.l10n.learningConversations,
                            '${c.allSessions.length}',
                          ),
                          (
                            context.l10n.knowledgeNotes,
                            counts.when(
                              data: (v) => '${v.knowledge}',
                              loading: () => '…',
                              error: (_, _) => '—',
                            ),
                          ),
                          (
                            context.l10n.mistakeRecords,
                            counts.when(
                              data: (v) => '${v.mistakes}',
                              loading: () => '…',
                              error: (_, _) => '—',
                            ),
                          ),
                        ])
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: context.l10n.learningConversations,
                          value: '${c.allSessions.length}',
                          detail: c.demo
                              ? context.l10n.demoRecordsDetail
                              : context.l10n.deviceSessionsDetail,
                          icon: Icons.forum_outlined,
                        ),
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: context.l10n.knowledgeNotes,
                          value: counts.when(
                            data: (v) => '${v.knowledge}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                          detail: context.l10n.knowledgeNotesDetail,
                          icon: Icons.bookmarks_outlined,
                        ),
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: context.l10n.mistakeRecords,
                          value: counts.when(
                            data: (v) => '${v.mistakes}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                          detail: context.l10n.mistakeRecordsDetail,
                          icon: Icons.menu_book_outlined,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.keepExploring,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.go('/chat'),
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
                      context.l10n.noLearningRecordsYetStart,
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
                                  color: colors.primaryContainer.withValues(
                                    alpha: .45,
                                  ),
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
                                if (context.mounted) context.go('/chat');
                              }),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.studyTipAfterUnderstandingAn,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(
    BuildContext context, {
    required double width,
    required String label,
    required String value,
    required String detail,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 144),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: .5),
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: colors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: value.length < 4
                    ? 28
                    : value.length > 12
                    ? 16
                    : 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
