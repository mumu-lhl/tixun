part of "library_screen.dart";

extension _LibraryFilterPickers on _LibraryScreenState {
  Widget _filterButtons(BuildContext context, String subject) {
    final directories = ref.watch(_libraryDirectoriesProvider(subject));
    final all = directories.value ?? [];
    final selected = all.where((m) => m.id == _moduleId).firstOrNull;
    final id = _moduleId;
    if (directories.hasValue &&
        id.isNotEmpty &&
        id != "unclassified" &&
        selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _moduleId == id && _appliedSubject == subject) {
          _setModule("");
        }
      });
    }
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key("module-filter"),
                icon: const Icon(Icons.folder_outlined, size: 18),
                label: Text(
                  id == "unclassified"
                      ? l10n.unclassified
                      : selected == null
                      ? l10n.directoryLabel
                      : modulePath(selected, all),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _pickDirectory(context, subject),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key("tag-filter"),
                icon: const Icon(Icons.label_outline, size: 18),
                label: Text(
                  _tags.isEmpty
                      ? l10n.tagsLabel
                      : l10n.tagsFilterCount(_tags.length),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _pickTags(context, subject),
              ),
            ),
          ],
        ),
        if (_hasFilters)
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                key: const Key("clear-library-filters"),
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(l10n.clearFilters),
              ),
              if (selected != null)
                TextButton.icon(
                  icon: const Icon(Icons.quiz_outlined, size: 18),
                  label: Text(l10n.practiceThisModule),
                  onPressed:
                      ref.watch(appControllerProvider.select((c) => c.busy))
                      ? null
                      : () => act(context, () async {
                          await ref
                              .read(appControllerProvider)
                              .prepareModulePractice(
                                id,
                                mistake: widget.isMistake,
                              );
                          if (context.mounted) context.go("/chat");
                        }),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickDirectory(BuildContext context, String subject) async {
    FocusScope.of(context).unfocus();
    var query = "";
    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, update) => Consumer(
          builder: (ctx, ref, _) {
            final options = ref.watch(_libraryDirectoriesProvider(subject));
            final all = options.value ?? [];
            final l10n = ctx.l10n;
            Widget choice(
              String value,
              String label,
              IconData icon, {
              bool indent = false,
            }) => ListTile(
              key: ValueKey("directory-option-$value"),
              contentPadding: EdgeInsetsDirectional.only(
                start: indent ? 36 : 16,
                end: 16,
              ),
              leading: Icon(icon),
              title: Text(label),
              selected: _moduleId == value,
              trailing: _moduleId == value ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(ctx, value),
            );
            final rows = _directoryRows(ctx, all, subject, query, choice);
            final fixedChoices = [
              choice("", l10n.allDirectories, Icons.folder_open_outlined),
              choice(
                "unclassified",
                l10n.unclassified,
                Icons.folder_off_outlined,
              ),
            ];
            return _FilterPicker(
              title: l10n.filterByDirectory,
              searchKey: const Key("directory-filter-search"),
              query: query,
              searchLabel: l10n.searchDirectories,
              onSearch: (text) =>
                  update(() => query = text.trim().toLowerCase()),
              pinned: [...fixedChoices, const Divider(height: 1)],
              options: [
                if (options.hasError)
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(_libraryDirectoriesProvider(subject)),
                    child: Text(l10n.couldNotLoadTapTo),
                  )
                else if (!options.hasValue)
                  const Center(child: CircularProgressIndicator())
                else if (rows.isEmpty)
                  _NoFilterOptions(
                    query.isEmpty
                        ? l10n.noDirectoriesYet
                        : l10n.noMatchingDirectories,
                  )
                else
                  ...rows,
              ],
              actions: [
                TextButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ModuleManager(
                        initialSubject:
                            all
                                .where((m) => m.id == _moduleId)
                                .firstOrNull
                                ?.subject ??
                            _defaultSubject(),
                      ),
                    ),
                  ),
                  label: Text(l10n.manageDirectory),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (result != null && mounted && subject == _appliedSubject) {
      _setModule(result);
    }
  }

  Future<void> _pickTags(BuildContext context, String subject) async {
    FocusScope.of(context).unfocus();
    final trash = _trash;
    final store = ref.read(studyStoreProvider);
    final isMistake = widget.isMistake;
    final selected = _tags.toSet();
    var query = "";
    Future<List<({String tag, int count})>> load() =>
        store.tagUsage(isMistake: isMistake, subject: subject, trash: trash);
    var usage = load();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, update) => FutureBuilder(
          future: usage,
          builder: (ctx, snapshot) {
            final l10n = ctx.l10n;
            final rows =
                snapshot.data?.where(
                  (item) => item.tag.toLowerCase().contains(query),
                ) ??
                [];
            void remove(String tag) => update(() => selected.remove(tag));
            return _FilterPicker(
              title: l10n.tagsLabel,
              searchKey: const Key("tag-filter-search"),
              query: query,
              searchLabel: l10n.searchTags,
              onSearch: (text) =>
                  update(() => query = text.trim().toLowerCase()),
              options: [
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final tag in selected)
                          InputChip(
                            label: Text(tag),
                            deleteButtonTooltipMessage: l10n.removeFilterTag(
                              tag,
                            ),
                            onDeleted: () => remove(tag),
                          ),
                      ],
                    ),
                  ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  TextButton(
                    onPressed: () => update(() => usage = load()),
                    child: Text(l10n.couldNotLoadTapTo),
                  )
                else if (rows.isEmpty)
                  _NoFilterOptions(
                    query.isEmpty ? l10n.noTagsYet : l10n.noMatchingTags,
                  )
                else
                  for (final item in rows)
                    CheckboxListTile(
                      key: ValueKey("tag-option-${item.tag}"),
                      value: selected.contains(item.tag),
                      onChanged: (checked) => update(() {
                        if (checked == true) {
                          selected.add(item.tag);
                        } else {
                          selected.remove(item.tag);
                        }
                      }),
                      title: Row(
                        children: [
                          Expanded(child: Text(item.tag)),
                          const SizedBox(width: 8),
                          Text(
                            "${item.count}",
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
              ],
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: Text(l10n.applyFilters),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (result != null &&
        mounted &&
        subject == _appliedSubject &&
        trash == _trash &&
        (result.length != _tags.length || !_tags.containsAll(result))) {
      _updateLibraryView(() {
        _tags = Set.unmodifiable(result);
        _epoch = -1;
      });
    }
  }
}

List<Widget> _directoryRows(
  BuildContext context,
  List<SubjectModule> all,
  String subject,
  String query,
  Widget Function(String, String, IconData, {bool indent}) choice,
) {
  final roots = <String, List<SubjectModule>>{};
  final children = <String, List<SubjectModule>>{};
  for (final module in all) {
    final parent = module.parentId;
    if (parent == null) {
      roots.putIfAbsent(module.subject, () => []).add(module);
    } else {
      children.putIfAbsent(parent, () => []).add(module);
    }
  }
  final rows = <Widget>[];
  for (final group in roots.entries) {
    final name = context.subjectName(group.key);
    bool matches(String path) =>
        query.isEmpty || "$name $path".toLowerCase().contains(query);
    final items = <Widget>[];
    for (final root in group.value) {
      if (matches(root.name)) {
        items.add(choice(root.id, root.name, Icons.folder_outlined));
      }
      for (final child in children[root.id] ?? const <SubjectModule>[]) {
        final path = "${root.name} / ${child.name}";
        if (matches(path)) {
          items.add(
            choice(
              child.id,
              query.isEmpty ? child.name : path,
              Icons.folder_outlined,
              indent: query.isEmpty,
            ),
          );
        }
      }
    }
    if (items.isNotEmpty) {
      if (subject.isEmpty) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(name, style: Theme.of(context).textTheme.titleSmall),
          ),
        );
      }
      rows.addAll(items);
    }
  }
  return rows;
}

class _FilterPicker extends StatelessWidget {
  const _FilterPicker({
    required this.title,
    required this.searchKey,
    required this.query,
    required this.searchLabel,
    required this.onSearch,
    required this.options,
    required this.actions,
    this.pinned = const [],
  });
  final String title, searchLabel, query;
  final Key searchKey;
  final ValueChanged<String> onSearch;
  final List<Widget> options, actions, pinned;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: SizedBox(
      width: 500,
      height: 560,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final pinChoices = constraints.maxHeight >= 360;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxHeight >= 220)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.close,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: searchKey,
                  onChanged: onSearch,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: searchLabel,
                    prefixIcon: const Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (pinChoices) ...pinned,
              Expanded(
                child: ListView(
                  key: ValueKey(query),
                  padding: EdgeInsets.zero,
                  children: [if (!pinChoices) ...pinned, ...options],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: OverflowBar(
                  spacing: 8,
                  alignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _NoFilterOptions extends StatelessWidget {
  const _NoFilterOptions(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      label,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}
