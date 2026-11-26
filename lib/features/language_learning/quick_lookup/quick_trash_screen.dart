import "dart:async";

import "package:material_ui/material_ui.dart";

import "../../../core/l10n/app_strings.dart";
import "../../../core/ui/actions.dart";
import "../language_store.dart";
import "quick_labels.dart";
import "quick_result.dart";
import "quick_store.dart";

class QuickLookupTrashScreen extends StatefulWidget {
  const QuickLookupTrashScreen({super.key, required this.store});

  final LanguageLearningStore store;

  @override
  State<QuickLookupTrashScreen> createState() => _QuickLookupTrashScreenState();
}

class _QuickLookupTrashScreenState extends State<QuickLookupTrashScreen> {
  final _rows = <QuickHistoryRow>[];
  final _selected = <String>{};
  var _loading = false;
  var _failed = false;
  var _hasMore = false;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.store.quickHistory(
        trashed: true,
        before: _rows.lastOrNull?.cursor,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(rows);
        _hasMore = rows.length == quickPageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _apply({required bool permanently}) async {
    if (_saving || _loading || _selected.isEmpty) return;
    setState(() => _saving = true);
    final ids = Set.of(_selected);
    await act(context, () async {
      if (permanently) {
        final l10n = context.l10n;
        final confirmed = await confirmQuickDelete(
          context,
          l10n.quickDeleteForeverConfirm(ids.length),
          confirmLabel: l10n.deletePermanently,
        );
        if (!mounted || !confirmed) return;
        await widget.store.deleteTrashedQuickLookups(ids);
      } else {
        await widget.store.restoreQuickLookups(ids);
      }
      if (!mounted) return;
      setState(() {
        _rows.removeWhere((row) => ids.contains(row.id));
        _selected.clear();
      });
      if (_rows.isEmpty && (_hasMore || _failed)) await _loadMore();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canApply = !_saving && !_loading && _selected.isNotEmpty;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.quickTrash)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              itemCount: _rows.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _rows.length) {
                  if (_loading) return const LinearProgressIndicator();
                  if (_failed || _hasMore) {
                    return Center(
                      child: TextButton(
                        onPressed: _saving ? null : _loadMore,
                        child: Text(_failed ? l10n.retry : l10n.quickLoadMore),
                      ),
                    );
                  }
                  return _rows.isEmpty
                      ? Text(l10n.trashIsEmpty)
                      : const SizedBox.shrink();
                }
                final row = _rows[index];
                return QuickHistorySelectionTile(
                  key: ValueKey(row.id),
                  row: row,
                  selected: _selected.contains(row.id),
                  onChanged: _saving
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            _selected.add(row.id);
                          } else {
                            _selected.remove(row.id);
                          }
                        }),
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: _rows.isEmpty
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text(l10n.selected(_selected.length.toString())),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: canApply
                                ? () => _apply(permanently: false)
                                : null,
                            child: Text(l10n.restore),
                          ),
                          OutlinedButton(
                            onPressed: canApply
                                ? () => _apply(permanently: true)
                                : null,
                            child: Text(l10n.deletePermanently),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
