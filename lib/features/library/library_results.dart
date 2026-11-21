part of "library_screen.dart";

extension _LibraryResults on _LibraryScreenState {
  Widget _libraryResults(
    StudyStore store,
    ColorScheme colors,
    bool small,
    String subjectFilter,
  ) => Expanded(
    child: FutureBuilder<List<_Entry>>(
      future: _future,
      initialData: _cached,
      builder: (context, snapshot) {
        Widget content() {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.couldNotLoadTapTo),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const SizedBox.expand();
          }
          // FutureBuilder retains the previous future's result when filters
          // change; only use it when it belongs to the current query.
          final base = snapshot.connectionState == ConnectionState.waiting
              ? _cached
              : snapshot.data;
          if (base == null) return const SizedBox.expand();
          final entries = [...base, ..._extra];
          _visible = entries;
          final canLoadMore = base.length == 100 && _hasMore;
          final hasFilters = _hasFilters;
          if (entries.isEmpty) {
            // Scrollable so the empty state fits short screens
            // (the shell subject bar takes 48px of height).
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isMistake
                            ? Icons.menu_book_outlined
                            : Icons.bookmarks_outlined,
                        size: 40,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _trash && !hasFilters
                            ? context.l10n.trashIsEmpty
                            : hasFilters
                            ? context.l10n.noMatchingMaterial
                            : widget.isMistake
                            ? context.l10n.noMistakesYet
                            : context.l10n.noKnowledgeNotesYet,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subjectFilter.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.currentSubject(
                            l10nArgument(context.subjectName(subjectFilter)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => act(context, () async {
                            await ref
                                .read(appControllerProvider)
                                .setSubjectFilter("");
                          }),
                          child: Text(context.l10n.clearSubjectFilter),
                        ),
                      ],
                      if (hasFilters)
                        TextButton.icon(
                          key: const Key("clear-empty-library-filters"),
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: Text(context.l10n.clearFilters),
                        ),
                      if (!_trash)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: OutlinedButton(
                            onPressed: _importing
                                ? null
                                : () => act(
                                    context,
                                    widget.isMistake
                                        ? _pickMistakePhotos
                                        : _create,
                                  ),
                            child: Text(
                              widget.isMistake
                                  ? context.l10n.importPhotos
                                  : context.l10n.newKnowledge,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: small ? 12 : 28,
              vertical: 8,
            ),
            itemCount: entries.length + (canLoadMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == entries.length) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _loadingMore ? null : () => act(context, _more),
                    child: Text(
                      _loadingMore
                          ? context.l10n.loading
                          : context.l10n.loadMore,
                    ),
                  ),
                );
              }
              final e = entries[index];
              return Card(
                key: ValueKey("card-${e.id}"),
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: ValueKey(e.id),
                  selected: _selected.containsKey(e.id),
                  leading: _selecting
                      ? Checkbox(
                          value: _selected.containsKey(e.id),
                          onChanged: _bulkBusy ? null : (_) => _toggle(e),
                        )
                      : Icon(
                          widget.isMistake
                              ? Icons.error_outline
                              : Icons.lightbulb_outline,
                          color: widget.isMistake
                              ? colors.tertiary
                              : colors.primary,
                        ),
                  onLongPress: () => _toggle(e),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  title: Text(
                    e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.subject}${e.chapter.isEmpty ? '' : ' · ${e.chapter}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.primary, fontSize: 12),
                        ),
                        if (e.badge.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              e.badge,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (e.preview.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: SearchSnippet(e.preview, _query),
                          ),
                      ],
                    ),
                  ),
                  trailing: _selecting
                      ? null
                      : _trash
                      ? TextButton(
                          onPressed: () => act(
                            context,
                            () => store.setDeleted(
                              e.id,
                              isMistake: widget.isMistake,
                              deleted: false,
                              expectedRevision: e.revision,
                            ),
                          ),
                          child: Text(context.l10n.restore),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _selecting
                      ? () => _toggle(e)
                      : _trash
                      ? null
                      : () => context.push(
                          '${widget.isMistake ? '/mistakes' : '/knowledge'}/${e.id}',
                        ),
                ),
              );
            },
          );
        }

        final shown = snapshot.connectionState == ConnectionState.waiting
            ? _cached
            : snapshot.data;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey((
              snapshot.hasError,
              shown?.map((e) => e.id).join("|"),
              _extra.map((e) => e.id).join("|"),
            )),
            child: content(),
          ),
        );
      },
    ),
  );
}
