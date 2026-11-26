import "dart:async";

import "package:dio/dio.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../../app/controller.dart";
import "../../../app/preferences.dart";
import "../../../core/ai/ai_usage_store.dart";
import "../../../core/l10n/app_error.dart";
import "../../../core/database/database.dart";
import "../../../core/l10n/app_error_localization.dart";
import "../../../core/l10n/app_strings.dart";
import "../../../core/l10n/generated/app_localizations.dart";
import "../../../core/ui/app_menu.dart";
import "../../../core/ui/actions.dart";
import "../generation_ui.dart";
import "quick_action_editor.dart";
import "quick_ai.dart";
import "quick_labels.dart";
import "quick_learning.dart";
import "quick_models.dart";
import "quick_result.dart";
import "quick_store.dart";
import "quick_trash_screen.dart";

class QuickLookupScreen extends ConsumerStatefulWidget {
  const QuickLookupScreen({super.key, this.initialInput = ""});

  final String initialInput;

  @override
  ConsumerState<QuickLookupScreen> createState() => _QuickLookupScreenState();
}

class _QuickLookupScreenState extends ConsumerState<QuickLookupScreen> {
  late final _controller = ref.read(appControllerProvider);
  late final _store = _controller.language;
  late final _input = TextEditingController(text: widget.initialInput);
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _expandedId;
  Future<LanguageQuickLookup?>? _detail;
  final _rows = <QuickHistoryRow>[];
  final _selected = <String>{};
  var _selecting = false;
  var _movingHistory = false;
  List<LanguageQuickAction>? _actions;
  Map<String, String> _deletedLabels = {};
  late String? _actionId = widget.initialInput.isEmpty
      ? null
      : "language_meaning";
  String? _filterId;
  String _keyword = "";
  var _searchOpen = false;
  var _loadingHistory = false;
  var _historyFailed = false;
  var _hasMore = false;
  var _historyVersion = 0;
  var _usingResult = false;
  var _loadingActions = false;
  var _actionsFailed = false;
  Timer? _debounce;
  CancelToken? _cancel;
  LanguageQuickLookup? _result;
  QuickQuery? _failedQuery;
  ({int current, int total})? _regenerating;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshActions());
    unawaited(_refreshHistory());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancel?.cancel();
    _searchFocus.dispose();
    _search.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refreshActions() async {
    if (_loadingActions) return;
    setState(() {
      _loadingActions = true;
      _actionsFailed = false;
    });
    try {
      await _store.ensureQuickActions();
      final actions = await _store.quickActions();
      final deleted = await _store.deletedQuickActionLabels();
      if (!mounted) return;
      final enabled = actions.where((action) => action.enabled).toList();
      setState(() {
        _actions = actions;
        _deletedLabels = deleted;
        if (_filterId != null &&
            !deleted.containsKey(_filterId) &&
            actions.every((action) => action.id != _filterId)) {
          _filterId = null;
        }
        if (enabled.every((action) => action.id != _actionId)) {
          _actionId = enabled.firstOrNull?.id;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _actionsFailed = true);
    } finally {
      if (mounted) setState(() => _loadingActions = false);
    }
  }

  Future<void> _refreshHistory({bool append = false}) async {
    if (append && (_loadingHistory || _rows.isEmpty)) return;
    final version = ++_historyVersion;
    final before = append ? _rows.last.cursor : null;
    setState(() {
      _historyFailed = false;
      _loadingHistory = true;
      if (!append) {
        _rows.clear();
        _hasMore = false;
      }
    });
    try {
      final rows = await _store.quickHistory(
        actionId: _filterId,
        search: _keyword,
        before: before,
      );
      if (!mounted || version != _historyVersion) return;
      setState(() {
        _rows.addAll(rows);
        _hasMore = rows.length == quickPageSize;
      });
    } catch (_) {
      if (mounted && version == _historyVersion) {
        setState(() => _historyFailed = true);
      }
    } finally {
      if (mounted && version == _historyVersion) {
        setState(() => _loadingHistory = false);
      }
    }
  }

  void _toggleSearch() {
    if (_searchOpen) {
      _debounce?.cancel();
      _search.clear();
      _keyword = "";
      _searchFocus.unfocus();
      setState(() {
        _selected.clear();
        _searchOpen = false;
      });
      unawaited(_refreshHistory());
    } else {
      setState(() => _searchOpen = true);
      _searchFocus.requestFocus();
    }
  }

  void _searchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 200),
      () => _applySearch(text),
    );
  }

  void _applySearch(String text) {
    if (text == _keyword) return;
    setState(() {
      _keyword = text;
      _selected.clear();
    });
    unawaited(_refreshHistory());
  }

  void _toggleSelection({String? firstId}) => setState(() {
    _selecting = !_selecting;
    _selected.clear();
    if (firstId != null) _selected.add(firstId);
    _expandedId = null;
    _detail = null;
  });

  Future<void> _openTrash() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuickLookupTrashScreen(store: _store),
      ),
    );
    if (!mounted) return;
    await _refreshActions();
    if (mounted) await _refreshHistory();
  }

  Future<void> _manageActions() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => QuickActionManager(_store)));
    if (!mounted) return;
    await _refreshActions();
    if (mounted) await _refreshHistory();
  }

  void _submit(LanguageQuickAction action) {
    final settings = _controller.preferences.languageStudy;
    final language = Localizations.localeOf(context).languageCode;
    final gloss = action.glossLanguage != "app"
        ? action.glossLanguage
        : settings.feedbackLanguage == LanguageFeedbackLanguage.app
        ? language
        : settings.feedbackLanguage.name;
    unawaited(
      _lookup(
        QuickQuery(
          actionId: action.id,
          actionName: quickName(context, action),
          actionRevision: action.revision,
          prompt: action.prompt,
          input: _input.text,
          sourceLanguage: action.sourceLanguage,
          targetLanguage: action.targetLanguage,
          glossLanguage: gloss,
          level: settings.level.name,
          detailed: action.detailed,
        ),
      ),
    );
  }

  Future<void> _lookup(QuickQuery query) async {
    if (_cancel != null || _movingHistory) return;
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _error = null;
      _failedQuery = null;
    });
    try {
      final row = await _lookupAi().lookup(query, cancel);
      if (!mounted) return;
      setState(() => _result = row);
      await _refreshHistory();
    } catch (error) {
      if (!mounted || cancel.isCancelled) return;
      final l10n = context.l10n;
      setState(() {
        _error = _lookupError(l10n, error);
        _failedQuery = query;
      });
    } finally {
      if (mounted) setState(() => _cancel = null);
    }
  }

  String _lookupError(AppLocalizations l10n, Object error) => switch (error) {
    LocalizedAppFailure() => failureText(l10n, error),
    FormatException() => l10n.quickInvalidResponse,
    _ => l10n.quickUnavailable,
  };

  QuickLookupAi _lookupAi() => QuickLookupAi(
    _store,
    languageGenerationProvider(context, _controller, compareVersions: false),
    _controller.config,
    AiUsageStore(_controller.db),
  );

  Future<void> _regenerate(List<String> ids) async {
    if (!_canMoveHistory || ids.isEmpty) return;
    final cancel = CancelToken();
    final total = ids.length;
    FocusScope.of(context).unfocus();
    final ai = _lookupAi();
    setState(() {
      _cancel = cancel;
      _regenerating = (current: 1, total: total);
      _error = null;
      _failedQuery = null;
    });

    var completed = 0;
    var failed = 0;
    Object? lastError;
    LanguageQuickLookup? latest;
    try {
      final actions = {
        for (final action in await _store.quickActions()) action.id: action,
      };
      for (final (index, id) in ids.indexed) {
        if (!mounted || cancel.isCancelled) break;
        setState(() => _regenerating = (current: index + 1, total: total));
        try {
          final original = await _store.quickLookup(id);
          if (!mounted || cancel.isCancelled) break;
          if (original == null) {
            failed++;
            continue;
          }
          final current = actions[original.actionId];
          latest = await ai.lookup(
            QuickQuery.fromLookup(
              original,
              action: current,
              actionName: current == null ? null : quickName(context, current),
            ),
            cancel,
            regenerate: true,
            original: original,
          );
          completed++;
        } catch (error) {
          if (cancel.isCancelled) break;
          lastError = error;
          failed++;
        }
      }
    } catch (error) {
      if (!cancel.isCancelled) {
        lastError = error;
        failed = total;
      }
    }
    if (!mounted) return;
    setState(() {
      if (latest != null) _result = latest;
      _selected.clear();
      _selecting = false;
    });
    if (completed > 0) await _refreshHistory();
    if (!mounted) return;
    setState(() {
      _cancel = null;
      _regenerating = null;
    });
    final l10n = context.l10n;
    final summary = l10n.quickRegenerationSummary(completed, total, failed);
    final message = cancel.isCancelled && completed + failed < total
        ? "${l10n.generationStopped} $summary"
        : total == 1 && lastError != null
        ? _lookupError(l10n, lastError)
        : summary;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  bool get _canMoveHistory =>
      !_movingHistory && !_usingResult && _cancel == null;

  Future<void> _moveToTrash(Set<String> ids) async {
    if (ids.isEmpty || !_canMoveHistory) return;
    setState(() => _movingHistory = true);
    await act(context, () async {
      await _store.trashQuickLookups(ids);
      if (!mounted) return;
      setState(() {
        if (ids.contains(_expandedId)) {
          _expandedId = null;
          _detail = null;
        }
        if (ids.contains(_result?.id)) _result = null;
        _selected.removeAll(ids);
        if (_selected.isEmpty) _selecting = false;
      });
      await _refreshActions();
      if (mounted) await _refreshHistory();
    });
    if (mounted) setState(() => _movingHistory = false);
  }

  Future<void> _withResult(Future<void> Function() use) async {
    if (_usingResult || _movingHistory || _regenerating != null) return;
    setState(() => _usingResult = true);
    try {
      await act(context, use);
    } finally {
      if (mounted) setState(() => _usingResult = false);
    }
  }

  Widget _answer(LanguageQuickLookup row) => QuickResult(
    row: row,
    onVocabulary: (candidates) => _withResult(
      () => learnQuickVocabulary(context, _store, row, candidates),
    ),
    onSentence: (candidate) =>
        _withResult(() => learnQuickSentence(context, _store, row, candidate)),
    onDiscuss: _usingResult || _controller.busy
        ? null
        : () =>
              _withResult(() => discussQuickLookup(context, _controller, row)),
    onRegenerate: _canMoveHistory ? () => _regenerate([row.id]) : null,
    onDelete: _canMoveHistory ? () => _moveToTrash({row.id}) : null,
  );

  Widget _composer(BuildContext context) {
    final l10n = context.l10n;
    final enabled = _actions?.where((action) => action.enabled).toList() ?? [];
    final current = enabled
        .where((action) => action.id == _actionId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final action in enabled)
              ChoiceChip(
                key: ValueKey(action.id),
                avatar: Icon(quickIcon(action.icon), size: 18),
                label: Text(
                  quickName(context, action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: current?.id == action.id,
                onSelected: _cancel != null
                    ? null
                    : (_) => setState(() => _actionId = action.id),
              ),
            TextButton.icon(
              onPressed: _actions != null && !_loadingActions
                  ? () async {
                      await editQuickAction(context, _store);
                      if (mounted) await _refreshActions();
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.quickAddAction),
            ),
          ],
        ),
        if (_actionsFailed)
          TextButton(onPressed: _refreshActions, child: Text(l10n.retry)),
        if (current != null) ...[
          const SizedBox(height: 16),
          if (quickDescription(context, current).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(quickDescription(context, current)),
            ),
          TextField(
            key: const ValueKey("quick-input"),
            controller: _input,
            readOnly: _cancel != null,
            maxLength: quickInputLimit,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: quickHint(context, current),
              counterText: "",
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ValueListenableBuilder(
              valueListenable: _input,
              builder: (context, value, _) =>
                  _cancel != null && _regenerating == null
                  ? OutlinedButton(
                      onPressed: () => _cancel?.cancel(),
                      child: Text(l10n.stopGenerating),
                    )
                  : FilledButton(
                      onPressed:
                          value.text.trim().isEmpty ||
                              value.text.length > quickInputLimit ||
                              _movingHistory ||
                              _cancel != null
                          ? null
                          : () {
                              FocusScope.of(context).unfocus();
                              _submit(current);
                            },
                      child: Text(l10n.quickSubmit),
                    ),
            ),
          ),
        ],
        if (_cancel != null && _regenerating == null) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(l10n.quickLoading),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_error!),
            trailing: TextButton(
              onPressed: _failedQuery == null || _cancel != null
                  ? null
                  : () => _lookup(_failedQuery!),
              child: Text(l10n.retry),
            ),
          ),
        ],
        if (_result case final row?) ...[
          const SizedBox(height: 16),
          Card(
            key: const ValueKey("quick-current-result"),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(title: Text(row.input), subtitle: Text(row.summary)),
                _answer(row),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _historyControls(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      for (final action in _actions ?? <LanguageQuickAction>[])
        action.id: quickName(context, action),
      for (final entry in _deletedLabels.entries)
        entry.key: "${entry.value} (${l10n.quickDeletedAction})",
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _searchOpen
                  ? TextField(
                      key: const ValueKey("quick-search"),
                      controller: _search,
                      focusNode: _searchFocus,
                      maxLength: quickSearchLimit,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r"\x00")),
                      ],
                      textInputAction: TextInputAction.search,
                      readOnly: _regenerating != null,
                      onChanged: _searchChanged,
                      onSubmitted: (text) {
                        _debounce?.cancel();
                        _applySearch(text);
                      },
                      decoration: InputDecoration(
                        hintText: l10n.quickHistorySearch,
                        counterText: "",
                      ),
                    )
                  : Text(
                      l10n.quickHistory,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
            ),
            IconButton(
              tooltip: _searchOpen ? l10n.close : l10n.quickHistorySearch,
              onPressed: _regenerating == null ? _toggleSearch : null,
              icon: Icon(_searchOpen ? Icons.close : Icons.search),
            ),
            IconButton(
              tooltip: _selecting ? l10n.cancel : l10n.quickSelectHistory,
              onPressed:
                  _movingHistory ||
                      _regenerating != null ||
                      (!_selecting && _rows.isEmpty)
                  ? null
                  : _toggleSelection,
              icon: Icon(_selecting ? Icons.close : Icons.checklist),
            ),
            IconButton(
              tooltip: l10n.quickTrash,
              onPressed: _movingHistory || _regenerating != null
                  ? null
                  : _openTrash,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 340,
            child: Semantics(
              label: l10n.quickHistoryFilter,
              child: AppSelectField<String>(
                key: const ValueKey("quick-filter"),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.filter_list_rounded),
                ),
                initialValue: labels.containsKey(_filterId) ? _filterId : "",
                items: [
                  DropdownMenuItem(
                    value: "",
                    child: Text(l10n.quickAllActions),
                  ),
                  for (final entry in labels.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: _regenerating != null
                    ? null
                    : (value) {
                        _debounce?.cancel();
                        setState(() {
                          _filterId = value == "" ? null : value;
                          _keyword = _search.text;
                          _selected.clear();
                        });
                        unawaited(_refreshHistory());
                      },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _historyItem(QuickHistoryRow row) {
    if (_selecting) {
      return QuickHistorySelectionTile(
        key: ValueKey(row.id),
        row: row,
        selected: _selected.contains(row.id),
        onChanged: _movingHistory || _regenerating != null
            ? null
            : (checked) => setState(() {
                if (checked == true) {
                  _selected.add(row.id);
                } else {
                  _selected.remove(row.id);
                }
              }),
      );
    }
    return QuickHistoryTile(
      key: ValueKey(row.id),
      row: row,
      detail: _expandedId == row.id ? _detail : null,
      answer: _answer,
      onSelect: _movingHistory || _regenerating != null
          ? null
          : () => _toggleSelection(firstId: row.id),
      onToggle: () => setState(() {
        final expanding = _expandedId != row.id;
        _expandedId = expanding ? row.id : null;
        _detail = expanding ? _store.quickLookup(row.id) : null;
      }),
    );
  }

  Widget _historyActionBar(BuildContext context) {
    final l10n = context.l10n;
    final progress = _regenerating;
    final canApply = _canMoveHistory && _selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            if (progress != null) ...[
              LinearProgressIndicator(
                value: (progress.current - 1) / progress.total,
              ),
              Text(
                l10n.quickRegenerationProgress(
                  progress.current,
                  progress.total,
                ),
              ),
              OutlinedButton(
                onPressed: _cancel!.isCancelled
                    ? null
                    : () => setState(() => _cancel!.cancel()),
                child: Text(l10n.stopGenerating),
              ),
            ] else ...[
              Text(l10n.selected(_selected.length.toString())),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: canApply
                        ? () => _regenerate(_selected.toList())
                        : null,
                    child: Text(l10n.quickRegenerate),
                  ),
                  OutlinedButton(
                    onPressed: canApply
                        ? () => _moveToTrash(Set.of(_selected))
                        : null,
                    child: Text(l10n.moveToTrash),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop:
          !_searchOpen &&
          !_selecting &&
          !_movingHistory &&
          _regenerating == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _movingHistory || _regenerating != null) return;
        if (_selecting) {
          _toggleSelection();
        } else if (_searchOpen) {
          _toggleSearch();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.quickLookup),
          leading: BackButton(
            onPressed: () {
              if (_movingHistory || _regenerating != null) return;
              if (_selecting) {
                _toggleSelection();
              } else if (_searchOpen) {
                _toggleSearch();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go("/language");
              }
            },
          ),
          actions: [
            IconButton(
              onPressed: _actions == null || _regenerating != null
                  ? null
                  : _manageActions,
              tooltip: l10n.quickActions,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        bottomNavigationBar: _selecting || _regenerating != null
            ? _historyActionBar(context)
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sides = (constraints.maxWidth - 760) / 2;
            return CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    sides.clamp(18, double.infinity),
                    12,
                    sides.clamp(18, double.infinity),
                    24,
                  ),
                  sliver: SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(child: _composer(context)),
                      SliverToBoxAdapter(child: _historyControls(context)),
                      SliverList.builder(
                        itemCount: _rows.length,
                        itemBuilder: (_, index) => Padding(
                          padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                          child: _historyItem(_rows[index]),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _loadingHistory
                            ? const LinearProgressIndicator()
                            : _historyFailed
                            ? TextButton(
                                onPressed: _refreshHistory,
                                child: Text(l10n.retry),
                              )
                            : _hasMore
                            ? TextButton(
                                onPressed: () => _refreshHistory(append: true),
                                child: Text(l10n.quickLoadMore),
                              )
                            : _rows.isEmpty
                            ? Text(
                                _filterId == null && _keyword.isEmpty
                                    ? l10n.quickNoHistory
                                    : l10n.quickNoResults,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
