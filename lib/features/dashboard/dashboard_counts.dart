part of "dashboard_screen.dart";

class _DashboardCounts extends ConsumerWidget {
  const _DashboardCounts({required this.controller, required this.compact});

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = controller;
    final counts = ref.watch(studyCountsProvider);
    final colors = Theme.of(context).colorScheme;
    return compact
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                    "${c.allSessions.length}",
                  ),
                  (
                    context.l10n.knowledgeNotes,
                    counts.when(
                      data: (v) => "${v.knowledge}",
                      loading: () => "…",
                      error: (_, _) => "—",
                    ),
                  ),
                  (
                    context.l10n.mistakeRecords,
                    counts.when(
                      data: (v) => "${v.mistakes}",
                      loading: () => "…",
                      error: (_, _) => "—",
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
                          style: Theme.of(context).textTheme.headlineSmall
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
        : LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _info(
                  context,
                  width: (constraints.maxWidth - 32) / 3,
                  label: context.l10n.learningConversations,
                  value: "${c.allSessions.length}",
                  detail: c.demo
                      ? context.l10n.demoRecordsDetail
                      : context.l10n.deviceSessionsDetail,
                  icon: Icons.forum_outlined,
                ),
                _info(
                  context,
                  width: (constraints.maxWidth - 32) / 3,
                  label: context.l10n.knowledgeNotes,
                  value: counts.when(
                    data: (v) => "${v.knowledge}",
                    loading: () => "…",
                    error: (_, _) => "—",
                  ),
                  detail: context.l10n.knowledgeNotesDetail,
                  icon: Icons.bookmarks_outlined,
                ),
                _info(
                  context,
                  width: (constraints.maxWidth - 32) / 3,
                  label: context.l10n.mistakeRecords,
                  value: counts.when(
                    data: (v) => "${v.mistakes}",
                    loading: () => "…",
                    error: (_, _) => "—",
                  ),
                  detail: context.l10n.mistakeRecordsDetail,
                  icon: Icons.menu_book_outlined,
                ),
              ],
            ),
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
