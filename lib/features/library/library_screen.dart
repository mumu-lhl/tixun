import 'package:tixun/core/l10n/app_error_localization.dart';

import 'image_editor.dart';
import 'ai_study_actions.dart';
import 'module_widgets.dart';

import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/app_menu.dart';
import '../../core/ui/search_snippet.dart';
import 'library_providers.dart';
import 'study_editor.dart';
import 'study_images.dart';
import 'study_photo_intake.dart';
import 'study_store.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({required this.isMistake, this.initialModule, super.key});
  final bool isMistake;
  final String? initialModule;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = '';
  String _moduleId = '';
  @override
  void initState() {
    super.initState();
    _moduleId =
        widget.initialModule ??
        ref.read(libraryModuleFilterProvider(widget.isMistake));
    _appliedSubject = ref.read(appControllerProvider).subjectFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(libraryModuleFilterProvider(widget.isMistake).notifier).state =
            _moduleId;
      }
    });
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialModule != null &&
        widget.initialModule != oldWidget.initialModule) {
      _moduleId = widget.initialModule!;
      _epoch = -1;
    }
  }

  // Last global subject filter applied to the list; a change reloads.
  String _appliedSubject = '';
  bool _trash = false, _importing = false;
  int _importTotal = 0, _importDone = 0;
  int _epoch = -1;
  bool _selecting = false,
      _bulkBusy = false,
      _loadingMore = false,
      _hasMore = true;
  int _nextOffset = 100;
  final _selected = <String, int>{};
  final _extra = <_Entry>[];
  List<_Entry> _visible = [];
  Timer? _debounce;
  Future<List<_Entry>>? _future;
  final _searchController = TextEditingController();
  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _query = '';
      _epoch = -1;
    });
  }

  void _refresh() => setState(() => _epoch = -1);
  String _defaultSubject() {
    final filter = ref.read(appControllerProvider).subjectFilter;
    if (filter.isNotEmpty) return filter;
    final subjects = ref.read(appControllerProvider).learningSubjects;
    return subjects.contains('数学') ? '数学' : subjects.first;
  }

  Future<List<_Entry>> _load(StudyStore store, {int offset = 0}) async {
    final query = _query;
    final module = _moduleId;
    final subject = ref.read(appControllerProvider).subjectFilter;
    final trash = _trash;
    final entries = widget.isMistake
        ? (await store.searchMistakes(
                query: query,
                moduleId: module,
                subject: subject,
                trash: trash,
                limit: 100,
                offset: offset,
              ))
              .map(
                (m) => _Entry(
                  m.id,
                  m.title,
                  m.subject,
                  m.chapter,
                  [
                            m.title,
                            m.question,
                            m.chapter,
                            m.correctAnswer,
                            m.originalAnswer,
                            m.ownAnalysis,
                            m.aiAnalysis,
                            m.errorReason,
                            m.suggestedReason,
                          ]
                          .map((text) => searchExcerpt(text, query))
                          .whereType<String>()
                          .firstOrNull ??
                      m.question,
                  m.errorReason,
                  m.revision,
                ),
              )
              .toList()
        : (await store.searchKnowledge(
                query: query,
                moduleId: module,
                subject: subject,
                trash: trash,
                limit: 100,
                offset: offset,
              ))
              .map(
                (k) => _Entry(
                  k.id,
                  k.title,
                  k.subject,
                  k.chapter,
                  [k.title, k.content, k.chapter]
                          .map((text) => searchExcerpt(text, query))
                          .whereType<String>()
                          .firstOrNull ??
                      k.content,
                  k.kind,
                  k.revision,
                ),
              )
              .toList();
    final paths = await store.modules.paths(
      entries.map((e) => e.id),
      widget.isMistake,
    );
    final missingPreview = query.trim().isEmpty
        ? <_Entry>[]
        : entries
              .where((entry) => searchExcerpt(entry.preview, query) == null)
              .toList();
    final tags = await store.tagsForIds(
      missingPreview.map((entry) => entry.id),
      isMistake: widget.isMistake,
    );
    final tagMatches = <String, String>{
      for (final entry in missingPreview)
        entry.id:
            (tags[entry.id] ?? [])
                .map((tag) => searchExcerpt(tag, query))
                .whereType<String>()
                .firstOrNull ??
            entry.preview,
    };
    return entries
        .map(
          (e) => _Entry(
            e.id,
            e.title,
            e.subject,
            [e.chapter, ...?paths[e.id]].where((s) => s.isNotEmpty).join(' · '),
            tagMatches[e.id] ?? e.preview,
            e.badge,
            e.revision,
          ),
        )
        .toList();
  }

  void _toggle(_Entry e) {
    if (_bulkBusy) return;
    if (!_selected.containsKey(e.id) && _selected.length >= 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.selectUpTo200Items)));
      return;
    }
    setState(() {
      _selecting = true;
      _selected.containsKey(e.id)
          ? _selected.remove(e.id)
          : _selected[e.id] = e.revision;
    });
  }

  Future<void> _more() async {
    if (_loadingMore) return;
    final epoch = _epoch,
        query = _query,
        subject = ref.read(appControllerProvider).subjectFilter,
        trash = _trash,
        moduleId = _moduleId;
    setState(() => _loadingMore = true);
    try {
      final rows = await _load(
        ref.read(studyStoreProvider),
        offset: _nextOffset,
      );
      if (mounted &&
          epoch == _epoch &&
          query == _query &&
          subject == ref.read(appControllerProvider).subjectFilter &&
          trash == _trash &&
          moduleId == _moduleId) {
        setState(() {
          _nextOffset += rows.length;
          _hasMore = rows.length == 100;
          final ids = _visible.map((e) => e.id).toSet();
          _extra.addAll(rows.where((e) => !ids.contains(e.id)));
        });
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _batch({bool permanent = false}) async {
    if (_bulkBusy || _selected.isEmpty) return;
    final revisions = Map<String, int>.of(_selected),
        store = ref.read(studyStoreProvider);
    final wasTrash = _trash;
    if (permanent) {
      final names = _visible
          .where((e) => revisions.containsKey(e.id))
          .take(3)
          .map((e) => '• ${e.title}')
          .join('\n');
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            context.l10n.permanentlyDeleteItems(
              l10nArgument((revisions.length)),
            ),
          ),
          scrollable: true,
          content: Text(
            context.l10n.thisPermanentlyDeletesTheMaterial(
              l10nArgument((names)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.deletePermanently),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    setState(() => _bulkBusy = true);
    try {
      if (permanent) {
        final failed = await store.purge(
          revisions,
          isMistake: widget.isMistake,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                failed == 0
                    ? context.l10n.permanentlyDeletedItems(
                        l10nArgument((revisions.length)),
                      )
                    : context.l10n.materialRecordsDeletedUnusedImagesNotRemoved(
                        l10nArgument((failed)),
                      ),
              ),
            ),
          );
        }
      } else {
        final next = await store.batchSetDeleted(
          revisions,
          isMistake: widget.isMistake,
          deleted: !wasTrash,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.items(
                  l10nArgument(
                    (wasTrash
                        ? context.l10n.restore
                        : context.l10n.moveToTrash),
                  ),
                  l10nArgument((revisions.length)),
                ),
              ),
              action: SnackBarAction(
                label: context.l10n.undo,
                onPressed: () => act(context, () async {
                  await store.batchSetDeleted(
                    next,
                    isMistake: widget.isMistake,
                    deleted: wasTrash,
                  );
                }),
              ),
            ),
          );
        }
      }
      if (mounted) {
        setState(() {
          _selected.clear();
          _selecting = false;
        });
      }
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _create() async {
    final id = await showDialog<String>(
      context: context,
      useSafeArea: false,
      builder: (_) => StudyEditor(
        isMistake: widget.isMistake,
        initialKnowledge: widget.isMistake
            ? null
            : KnowledgeDraft(
                title: '',
                content: '',
                subject: _defaultSubject(),
              ),
        initialMistake: widget.isMistake
            ? MistakeDraft(title: '', subject: _defaultSubject())
            : null,
      ),
    );
    if (id != null && mounted) {
      context.push('${widget.isMistake ? '/mistakes' : '/knowledge'}/$id');
    }
  }

  Future<void> _pickMistakePhotos() =>
      Platform.isAndroid ? _nativeImport('gallery') : _import();

  void _showImportedMistakes(List<String> ids) {
    if (!mounted || ids.isEmpty) return;
    if (ids.length == 1) {
      context.push('/mistakes/${ids.single}');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.importedImageQuestionsAddAnswers(
            l10nArgument((ids.length)),
          ),
        ),
        action: SnackBarAction(
          label: context.l10n.view,
          onPressed: () => context.push('/mistakes/${ids.first}'),
        ),
      ),
    );
  }

  Future<void> _import() async {
    if (_importing) return;
    final picked = await pickStudyImages(context);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _importing = true;
      _importTotal = picked.length;
      _importDone = 0;
    });
    final imported = <String>[];
    try {
      for (final file in picked) {
        final c = ref.read(appControllerProvider);
        final row = await c.study.importMistake(
          file.path,
          file.name,
          subject: _defaultSubject(),
        );
        imported.add(row.id);
        if (mounted) setState(() => _importDone = imported.length);
        final detail = await c.study.mistakeDetail(row.id);
        if (mounted) {
          await cropImportedStudyPhoto(
            context,
            row.id,
            detail.images.single,
            isMistake: true,
          );
        }
      }
      _showImportedMistakes(imported);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.savedQuestions(
                l10nArgument((imported.length)),
                l10nArgument(
                  (e is FormatException
                      ? failureText(context.l10n, e)
                      : context.l10n.couldNotImportTheRemaining),
                ),
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importTotal = 0;
          _importDone = 0;
        });
      }
    }
  }

  Future<void> _nativeImport(String kind) async {
    if (kind == 'file') return _import();
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final ids = await StudyPhotoIntake.pick(
        ref.read(appControllerProvider),
        context: context,
        isMistake: true,
        camera: kind == 'camera',
        subject: _defaultSubject(),
      );
      if (mounted) {
        setState(() {
          _importTotal = ids.length;
          _importDone = ids.length;
        });
        _showImportedMistakes(ids);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importTotal = 0;
          _importDone = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(studyStoreProvider);
    final colors = Theme.of(context).colorScheme;
    final name = (widget.isMistake
        ? context.l10n.mistakeBook
        : context.l10n.knowledgeLibrary);
    // The list follows the global subject filter; a change reloads.
    final subjectFilter = ref.watch(
      appControllerProvider.select((c) => c.subjectFilter),
    );
    if (_appliedSubject != subjectFilter) {
      _appliedSubject = subjectFilter;
      _moduleId = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
                  .read(libraryModuleFilterProvider(widget.isMistake).notifier)
                  .state =
              '';
        }
      });
      // Only the UI filter changes; learning records keep their own subjects.
      _epoch = -1;
    }
    if (_epoch != store.epoch) {
      _epoch = store.epoch;
      _extra.clear();
      _visible = [];
      _nextOffset = 100;
      _hasMore = true;
      _selected.clear();
      _future = _load(store);
    }
    final small = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            small ? 20 : 32,
            20,
            small ? 16 : 32,
            12,
          ),
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
                      key: const Key('ai-create-knowledge'),
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
                      if (action == 'select') {
                        setState(() {
                          _selecting = !_selecting;
                          _selected.clear();
                        });
                      } else if (action == 'trash') {
                        setState(() {
                          _trash = !_trash;
                          _epoch = -1;
                        });
                      } else if (action == 'import-files') {
                        act(context, _import);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'select',
                        child: Text(
                          _selecting
                              ? context.l10n.cancel
                              : context.l10n.selectMultipleItems,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'trash',
                        child: Text(
                          _trash
                              ? context.l10n.backToMaterial
                              : context.l10n.openTrash,
                        ),
                      ),
                      if (widget.isMistake && Platform.isAndroid && !_trash)
                        PopupMenuItem(
                          value: 'import-files',
                          enabled: !_importing,
                          child: Text(context.l10n.importFromFiles),
                        ),
                    ],
                  ),
                  if (!widget.isMistake)
                    FilledButton.icon(
                      key: const Key('create-study'),
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
                        key: const Key('import-mistake'),
                        onPressed: _importing || _bulkBusy
                            ? null
                            : () => act(context, _pickMistakePhotos),
                        icon: _importing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                              : () =>
                                    act(context, () => _nativeImport('camera')),
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      TextButton.icon(
                        key: const Key('create-study'),
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
                key: const Key('library-search'),
                controller: _searchController,
                onChanged: (v) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) {
                      setState(() {
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
                            libraryModuleFilterProvider(widget.isMistake)
                                .notifier,
                          )
                          .state =
                      value;
                  setState(() {
                    _moduleId = value;
                    _epoch = -1;
                  });
                },
              ),
              if (_query.isNotEmpty || _moduleId.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('clear-library-filters'),
                    onPressed: () => act(context, () async {
                      _debounce?.cancel();
                      _searchController.clear();
                      ref
                              .read(
                                libraryModuleFilterProvider(widget.isMistake)
                                    .notifier,
                              )
                              .state =
                          '';
                      setState(() {
                        _query = '';
                        _moduleId = '';
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
                        value: _importTotal > 0
                            ? _importDone / _importTotal
                            : null,
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
                      : () => setState(() {
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
                                .prepareKnowledgePractice(
                                  _selected.keys.toList(),
                                );
                            if (context.mounted) context.go('/chat');
                          }),
                    child: Text(context.l10n.knowledgeQuizUpTo5),
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
        const Divider(),
        Expanded(
          child: FutureBuilder<List<_Entry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.couldNotLoadTapTo),
                  ),
                );
              }
              if (!snapshot.hasData ||
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = [...snapshot.data!, ..._extra];
              _visible = entries;
              final canLoadMore = snapshot.data!.length == 100 && _hasMore;
              final hasFilters = _query.isNotEmpty || _moduleId.isNotEmpty;
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
                                : context.l10n.startWith(
                                    l10nArgument(
                                      (widget.isMistake
                                          ? context.l10n.aMistake
                                          : context.l10n.aKnowledgePoint),
                                    ),
                                  ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            hasFilters
                                ? context.l10n.tryAnotherKeywordOrClear
                                : _trash
                                ? context.l10n.deletedMaterialCanBeRestored
                                : widget.isMistake
                                ? context.l10n.importAndCropAQuestion
                                : context.l10n.writeDownYourUnderstandingWith,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              height: 1.8,
                            ),
                          ),
                          if (subjectFilter.isNotEmpty) ...[
                            Text(
                              context.l10n.currentSubject(
                                l10nArgument(
                                  context.subjectName(subjectFilter),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => act(context, () async {
                                await ref
                                    .read(appControllerProvider)
                                    .setSubjectFilter('');
                              }),
                              child: Text(context.l10n.clearSubjectFilter),
                            ),
                          ],
                          if (hasFilters)
                            TextButton.icon(
                              key: const Key('clear-empty-library-filters'),
                              onPressed: () => act(context, () async {
                                _debounce?.cancel();
                                _searchController.clear();
                                ref
                                        .read(
                                          libraryModuleFilterProvider(
                                            widget.isMistake,
                                          ).notifier,
                                        )
                                        .state =
                                    '';
                                setState(() {
                                  _query = '';
                                  _moduleId = '';
                                  _epoch = -1;
                                });
                              }),
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
                        onPressed: _loadingMore
                            ? null
                            : () => act(context, _more),
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
                    key: ValueKey('card-${e.id}'),
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
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 12,
                              ),
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
            },
          ),
        ),
      ],
    );
  }
}

class _Entry {
  const _Entry(
    this.id,
    this.title,
    this.subject,
    this.chapter,
    this.preview,
    this.badge,
    this.revision,
  );
  final String id, title, subject, chapter, preview, badge;
  final int revision;
}
