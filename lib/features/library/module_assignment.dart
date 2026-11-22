part of "module_widgets.dart";

class ModuleAssignment extends ConsumerWidget {
  const ModuleAssignment({
    required this.id,
    required this.subject,
    required this.mistake,
    this.editable = true,
    super.key,
  });
  final String id, subject;
  final bool mistake, editable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(appControllerProvider).study.modules;
    final linkTable = mistake
        ? "mistake_module_links"
        : "knowledge_module_links";
    final column = mistake ? "mistake_id" : "knowledge_id";
    return StreamBuilder<List<SubjectModule>>(
      stream: store.watch(subject),
      builder: (ctx, modules) => StreamBuilder<List<QueryRow>>(
        stream: store.db
            .customSelect(
              "SELECT module_id FROM $linkTable WHERE $column=?",
              variables: [Variable(id)],
              readsFrom: {
                store.db.mistakeModuleLinks,
                store.db.knowledgeModuleLinks,
              },
            )
            .watch(),
        builder: (ctx, links) {
          final all = modules.data ?? [];
          final ids = (links.data ?? [])
              .map((r) => r.read<String>("module_id"))
              .toSet();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      ctx.l10n.modules,
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    if (modules.hasError || links.hasError)
                      Text(ctx.l10n.couldNotLoadTheDirectory),
                    for (final module in all.where((m) => ids.contains(m.id)))
                      ActionChip(
                        label: Text(modulePath(module, all)),
                        onPressed: () => act(ctx, () async {
                          final c = ref.read(appControllerProvider);
                          await c.setSubjectFilter(
                            schoolSubjects.contains(subject) ||
                                    c.learningSubjects.contains(subject)
                                ? subject
                                : "",
                          );
                          if (ctx.mounted) {
                            unawaited(
                              ctx.push(
                                '${mistake ? '/mistakes' : '/knowledge'}?module=${module.id}',
                              ),
                            );
                          }
                        }),
                      ),
                    if (ids.isEmpty && links.hasData)
                      Text(ctx.l10n.unclassified),
                    if (editable)
                      TextButton.icon(
                        key: const Key("assign-modules"),
                        onPressed: modules.hasData && links.hasData
                            ? () => _pick(ctx, ref, ids.toList())
                            : null,
                        icon: const Icon(Icons.folder_copy_outlined, size: 18),
                        label: Text(ctx.l10n.chooseModules),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    List<String> before,
  ) async {
    final selected = await pickModules(
      context,
      ref.read(appControllerProvider).study.modules,
      subject,
      before,
    );
    if (selected != null && context.mounted) {
      await act(
        context,
        () => ref
            .read(appControllerProvider)
            .study
            .modules
            .assign(id, mistake, selected, expected: before),
      );
    }
  }
}
