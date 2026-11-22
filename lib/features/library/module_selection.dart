part of "module_widgets.dart";

class ModuleSelectionField extends ConsumerWidget {
  const ModuleSelectionField({
    required this.subject,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });
  final String subject;
  final Set<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.read(appControllerProvider).study.modules;
    return StreamBuilder<List<SubjectModule>>(
      stream: store.watch(subject),
      builder: (context, snapshot) => Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(context.l10n.modules),
          for (final module in snapshot.data ?? <SubjectModule>[])
            if (selected.contains(module.id))
              InputChip(
                label: Text(modulePath(module, snapshot.data!)),
                onDeleted: enabled
                    ? () => onChanged(
                        selected.where((id) => id != module.id).toList(),
                      )
                    : null,
              ),
          if (selected.isEmpty) Text(context.l10n.unclassified),
          if (snapshot.hasError) Text(context.l10n.couldNotLoadTheDirectory),
          TextButton.icon(
            key: const Key("choose-study-modules"),
            onPressed: !enabled || subject.isEmpty
                ? null
                : () async {
                    final ids = await pickModules(
                      context,
                      store,
                      subject,
                      selected.toList(),
                    );
                    if (context.mounted && ids != null) onChanged(ids);
                  },
            icon: const Icon(Icons.folder_copy_outlined),
            label: Text(context.l10n.chooseModules),
          ),
        ],
      ),
    );
  }
}

Future<List<String>?> pickModules(
  BuildContext context,
  ModuleStore store,
  String subject,
  List<String> initial,
) {
  final selected = initial.toSet();
  var query = "";
  var source = store.watch(subject);
  return showDialog<List<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, set) => StreamBuilder<List<SubjectModule>>(
        stream: source,
        builder: (context, snapshot) {
          final all = snapshot.data ?? <SubjectModule>[];
          if (snapshot.hasData) {
            selected.removeWhere((id) => !all.any((m) => m.id == id));
          }
          final filtered = all.where(
            (m) => modulePath(m, all).toLowerCase().contains(query),
          );
          return AlertDialog(
            title: Text(context.l10n.chooseModules),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key("module-search"),
                    decoration: InputDecoration(
                      labelText: context.l10n.searchModules,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) =>
                        set(() => query = value.trim().toLowerCase()),
                  ),
                  Text(
                    context.l10n.selectedEntriesOutOf20(
                      l10nArgument(selected.length),
                    ),
                  ),
                  if (snapshot.hasError)
                    TextButton(
                      onPressed: () => set(() => source = store.watch(subject)),
                      child: Text(context.l10n.retry),
                    )
                  else if (!snapshot.hasData)
                    const LinearProgressIndicator()
                  else if (all.isEmpty)
                    Text(context.l10n.thisSubjectHasNoModules),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final module in filtered)
                          CheckboxListTile(
                            title: Text(modulePath(module, all)),
                            value: selected.contains(module.id),
                            onChanged:
                                snapshot.hasError ||
                                    (!selected.contains(module.id) &&
                                        selected.length >= 20)
                                ? null
                                : (checked) => set(() {
                                    if (checked == true) {
                                      selected.add(module.id);
                                    } else {
                                      selected.remove(module.id);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () async {
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ModuleManager(initialSubject: subject),
                    ),
                  );
                },
                child: Text(context.l10n.manageDirectory),
              ),
              FilledButton(
                onPressed: !snapshot.hasData || snapshot.hasError
                    ? null
                    : () => Navigator.pop(context, selected.toList()),
                child: Text(context.l10n.save),
              ),
            ],
          );
        },
      ),
    ),
  );
}
