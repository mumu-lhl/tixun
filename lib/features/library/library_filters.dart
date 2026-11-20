part of "library_screen.dart";

extension _LibraryFilters on _LibraryScreenState {
  List<Widget> _libraryFilters(
    BuildContext context,
    String name,
    ColorScheme colors,
    bool small,
    String subjectFilter,
  ) => [
    Padding(
      padding: EdgeInsets.fromLTRB(small ? 20 : 32, 20, small ? 16 : 32, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _trash
                      ? context.l10n.itemInTrash(l10nArgument((name)))
                      : name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (!widget.isMistake && !_trash)
                IconButton(
                  key: const Key("ai-create-knowledge"),
                  tooltip: context.l10n.createKnowledgeWithAI,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  onPressed: _bulkBusy
                      ? null
                      : () => act(
                          context,
                          () => startAiStudyWriting(context, ref),
                        ),
                ),
              PopupMenuButton<String>(
                tooltip: context.l10n.moreActions,
                enabled: !_bulkBusy,
                popUpAnimationStyle: menuAnimation(context),
                onSelected: (action) {
                  FocusScope.of(context).unfocus();
                  if (action == "select") {
                    _updateLibraryView(() {
                      _selecting = !_selecting;
                      _selected.clear();
                    });
                  } else if (action == "trash") {
                    _updateLibraryView(() {
                      _trash = !_trash;
                      _epoch = -1;
                    });
                  } else if (action == "import-files") {
                    unawaited(act(context, _import));
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: "select",
                    child: Text(
                      _selecting
                          ? context.l10n.cancel
                          : context.l10n.selectMultipleItems,
                    ),
                  ),
                  PopupMenuItem(
                    value: "trash",
                    child: Text(
                      _trash
                          ? context.l10n.backToMaterial
                          : context.l10n.openTrash,
                    ),
                  ),
                  if (widget.isMistake && Platform.isAndroid && !_trash)
                    PopupMenuItem(
                      value: "import-files",
                      enabled: !_importing,
                      child: Text(context.l10n.importFromFiles),
                    ),
                ],
              ),
              if (!widget.isMistake)
                FilledButton.icon(
                  key: const Key("create-study"),
                  onPressed: _trash || _bulkBusy
                      ? null
                      : () => act(context, _create),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.newItem),
                ),
            ],
          ),
          if (widget.isMistake && !_trash)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key("import-mistake"),
                    onPressed: _importing || _bulkBusy
                        ? null
                        : () => act(context, _pickMistakePhotos),
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 18,
                          ),
                    label: Text(context.l10n.importPhotos),
                  ),
                  if (Platform.isAndroid)
                    IconButton.outlined(
                      tooltip: context.l10n.photographAQuestion,
                      onPressed: _importing || _bulkBusy
                          ? null
                          : () => act(context, () => _nativeImport("camera")),
                      icon: const Icon(Icons.camera_alt_outlined),
                    ),
                  TextButton.icon(
                    key: const Key("create-study"),
                    onPressed: _importing || _bulkBusy
                        ? null
                        : () => act(context, _create),
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(context.l10n.textEntry),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            widget.isMistake
                ? context.l10n.keepTheOriginalQuestionAnd
                : context.l10n.keepConceptsFormulasAndYour,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key("library-search"),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: _searchController,
            onChanged: (v) {
              _updateLibraryView(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) {
                  _updateLibraryView(() {
                    _query = v;
                    _epoch = -1;
                  });
                }
              });
            },
            decoration: InputDecoration(
              hintText: context.l10n.searchTitlesContentChaptersOr,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.clearSearch,
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          ModuleFilter(
            value: _moduleId,
            subject: subjectFilter,
            mistake: widget.isMistake,
            onChanged: (value) {
              ref
                      .read(
                        libraryModuleFilterProvider(widget.isMistake).notifier,
                      )
                      .state =
                  value;
              _updateLibraryView(() {
                _moduleId = value;
                _epoch = -1;
              });
            },
          ),
          if (_query.isNotEmpty || _moduleId.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key("clear-library-filters"),
                onPressed: () => act(context, () async {
                  _debounce?.cancel();
                  _searchController.clear();
                  ref
                          .read(
                            libraryModuleFilterProvider(widget.isMistake)
                                .notifier,
                          )
                          .state =
                      "";
                  _updateLibraryView(() {
                    _query = "";
                    _moduleId = "";
                    _epoch = -1;
                  });
                }),
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: Text(context.l10n.clearFilters),
              ),
            ),
          const SizedBox(height: 10),
          if (_importing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _importTotal > 0 ? _importDone / _importTotal : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _importTotal > 0
                        ? context.l10n.importingImageProgress(
                            l10nArgument((_importDone)),
                            l10nArgument((_importTotal)),
                          )
                        : context.l10n.importInProgress,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    if (_selecting)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(context.l10n.selected(l10nArgument((_selected.length)))),
            TextButton(
              onPressed: _bulkBusy
                  ? null
                  : () => _updateLibraryView(() {
                      for (final e in _visible.take(200)) {
                        _selected[e.id] = e.revision;
                      }
                    }),
              child: Text(context.l10n.selectLoadedItems),
            ),
            FilledButton.tonal(
              onPressed: _bulkBusy || _selected.isEmpty
                  ? null
                  : () => act(context, _batch),
              child: Text(
                _trash
                    ? context.l10n.restoreSelected
                    : context.l10n.moveToTrash,
              ),
            ),
            if (!_trash && !widget.isMistake)
              TextButton(
                onPressed:
                    _bulkBusy || _selected.isEmpty || _selected.length > 5
                    ? null
                    : () => act(context, () async {
                        await ref
                            .read(appControllerProvider)
                            .prepareKnowledgePractice(_selected.keys.toList());
                        if (context.mounted) context.go("/chat");
                      }),
                child: Text(context.l10n.knowledgeQuizUpTo5),
              ),
            if (!_trash && !widget.isMistake)
              TextButton.icon(
                onPressed: _bulkBusy || _selected.isEmpty
                    ? null
                    : _exportSelected,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(context.l10n.exportForPrint),
              ),
            if (_trash)
              TextButton(
                onPressed: _bulkBusy || _selected.isEmpty
                    ? null
                    : () => act(context, () => _batch(permanent: true)),
                child: Text(context.l10n.deletePermanently),
              ),
          ],
        ),
      ),
  ];
}
