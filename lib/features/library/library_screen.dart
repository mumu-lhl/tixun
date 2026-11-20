import "package:tixun/core/l10n/app_error_localization.dart";

import "image_editor.dart";
import "ai_study_actions.dart";
import "module_widgets.dart";

import "dart:async";
import "dart:io";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/app_menu.dart";
import "../../core/ui/search_snippet.dart";
import "library_providers.dart";
import "study_editor.dart";
import "study_export.dart";
import "study_export_dialog.dart";
import "study_images.dart";
import "study_photo_intake.dart";
import "study_store.dart";

part "library_filters.dart";

part "library_results.dart";

// Keep only a few first pages per store; full records and image bytes stay on disk.
final _libraryCache = Expando<Map<Object, List<_Entry>>>();
final _libraryRequests = Expando<Map<Object, Object>>();

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({required this.isMistake, this.initialModule, super.key});
  final bool isMistake;
  final String? initialModule;
  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _query = "";
  String _moduleId = "";
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

  String _appliedSubject = "";
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
  List<_Entry>? _cached;
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
      _query = "";
      _epoch = -1;
    });
  }

  void _refresh() => setState(() => _epoch = -1);
  String _defaultSubject() {
    final filter = ref.read(appControllerProvider).subjectFilter;
    if (filter.isNotEmpty) return filter;
    final subjects = ref.read(appControllerProvider).learningSubjects;
    return subjects.contains("数学") ? "数学" : subjects.first;
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
            [e.chapter, ...?paths[e.id]].where((s) => s.isNotEmpty).join(" · "),
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

  /// Prints the current selection. The database read stops as soon as a note
  /// leaves the selection, so the file always matches what the bar reported.
  Future<void> _exportSelected() async {
    final choice = await showStudyExportDialog(context);
    if (choice == null || !mounted || _selected.isEmpty) return;
    await exportStudySelection(
      context,
      store: ref.read(studyStoreProvider),
      ids: _selected.keys.toList(growable: false),
      format: choice.format,
      includeImages: choice.includeImages,
    );
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
          .map((e) => "• ${e.title}")
          .join("\n");
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
                title: "",
                content: "",
                subject: _defaultSubject(),
              ),
        initialMistake: widget.isMistake
            ? MistakeDraft(title: "", subject: _defaultSubject())
            : null,
      ),
    );
    if (id != null && mounted) {
      unawaited(
        context.push('${widget.isMistake ? '/mistakes' : '/knowledge'}/$id'),
      );
    }
  }

  Future<void> _pickMistakePhotos() =>
      Platform.isAndroid ? _nativeImport("gallery") : _import();

  void _showImportedMistakes(List<String> ids) {
    if (!mounted || ids.isEmpty) return;
    if (ids.length == 1) {
      unawaited(context.push("/mistakes/${ids.single}"));
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
          onPressed: () => context.push("/mistakes/${ids.first}"),
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
    if (kind == "file") return _import();
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final ids = await StudyPhotoIntake.pick(
        ref.read(appControllerProvider),
        context: context,
        isMistake: true,
        camera: kind == "camera",
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

  void _updateLibraryView(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(studyStoreProvider);
    final colors = Theme.of(context).colorScheme;
    final name = (widget.isMistake
        ? context.l10n.mistakeBook
        : context.l10n.knowledgeLibrary);
    final subjectFilter = ref.watch(
      appControllerProvider.select((c) => c.subjectFilter),
    );
    if (_appliedSubject != subjectFilter) {
      _appliedSubject = subjectFilter;
      _moduleId = "";
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
                  .read(libraryModuleFilterProvider(widget.isMistake).notifier)
                  .state =
              "";
        }
      });
      // Only the UI filter changes; learning records keep their own subjects.
      _epoch = -1;
    }
    if (_epoch != store.epoch) {
      _epoch = store.epoch;
      _extra.clear();
      final key = (widget.isMistake, _query, _moduleId, subjectFilter, _trash);
      final cache = _libraryCache[store] ??= {};
      _cached = cache.remove(key);
      if (_cached != null) cache[key] = _cached!;
      _visible = _cached ?? [];
      _nextOffset = 100;
      _hasMore = true;
      _selected.clear();
      final requests = _libraryRequests[store] ??= {};
      final request = Object();
      requests[key] = request;
      _future = _load(store).then(
        (entries) {
          if (identical(requests[key], request)) {
            requests.remove(key);
            cache.remove(key);
            cache[key] = entries
                .map(
                  (e) => _Entry(
                    e.id,
                    e.title,
                    e.subject,
                    e.chapter,
                    e.preview.length > 1000
                        ? String.fromCharCodes(e.preview.runes.take(500))
                        : e.preview,
                    e.badge,
                    e.revision,
                  ),
                )
                .toList();
            while (cache.length > 4) {
              cache.remove(cache.keys.first);
            }
          }
          return entries;
        },
        onError: (Object error, StackTrace stack) {
          if (identical(requests[key], request)) requests.remove(key);
          Error.throwWithStackTrace(error, stack);
        },
      );
    }
    final small = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        ..._libraryFilters(context, name, colors, small, subjectFilter),
        const Divider(),
        _libraryResults(store, colors, small, subjectFilter),
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
