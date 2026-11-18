import 'dart:async';

import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/search_snippet.dart';

/// One row in the history list: a recency header or a session tile.
sealed class _HistoryRow {
  const _HistoryRow();
}

class _HistoryHeader extends _HistoryRow {
  const _HistoryHeader(this.label);
  final String label;
}

class _HistorySession extends _HistoryRow {
  const _HistorySession(this.session);
  final ChatSession session;
}

/// Groups already newest-first sessions by how recently they were updated:
/// today, yesterday, the last 7 days, earlier. Sessions arrive ordered by
/// `updated_at DESC`, so groups come out in that order too.
List<_HistoryRow> _groupedRows(
  List<ChatSession> sessions,
  DateTime now, {
  required String today,
  required String yesterday,
  required String last7Days,
  required String earlier,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  var currentLabel = '';
  final rows = <_HistoryRow>[];
  for (final s in sessions) {
    final day = DateTime(s.updatedAt.year, s.updatedAt.month, s.updatedAt.day);
    final diff = todayStart.difference(day).inDays;
    final label = diff <= 0
        ? today
        : diff == 1
        ? yesterday
        : diff <= 7
        ? last7Days
        : earlier;
    if (label != currentLabel) {
      currentLabel = label;
      rows.add(_HistoryHeader(label));
    }
    rows.add(_HistorySession(s));
  }
  return rows;
}

class SessionList extends ConsumerStatefulWidget {
  const SessionList({this.onSelected, super.key});
  final VoidCallback? onSelected;
  @override
  ConsumerState<SessionList> createState() => _SessionListState();
}

class _SessionListState extends ConsumerState<SessionList> {
  late final TextEditingController _search;
  Timer? _searchDebounce;
  String _snippetQuery = '';
  int _selectionEpoch = 0;
  final _snippetFutures = <String, Future<ChatMessage?>>{};

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(
      text: ref.read(appControllerProvider).search,
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    if (_snippetQuery != c.search) {
      _snippetQuery = c.search;
      _snippetFutures.clear();
    }
    final liveSnippetKeys = c.sessions
        .map((s) => '${s.id}:${s.updatedAt.microsecondsSinceEpoch}')
        .toSet();
    _snippetFutures.removeWhere((key, _) => !liveSnippetKeys.contains(key));
    // The query can be cleared outside this widget (e.g. starting a new
    // session resets it); keep the field in sync without clobbering text
    // the user is typing. Programmatic changes do not fire onChanged, so
    // this cannot loop.
    if (_searchDebounce?.isActive != true && _search.text != c.search) {
      _search.value = TextEditingValue(
        text: c.search,
        selection: TextSelection.collapsed(offset: c.search.length),
      );
    }
    // Group by recency only for the plain list. A search ranks title
    // matches first, so grouping would scramble that order.
    final rows = c.search.trim().isEmpty
        ? _groupedRows(
            c.sessions,
            DateTime.now(),
            today: context.l10n.today,
            yesterday: context.l10n.yesterday,
            last7Days: context.l10n.last7Days,
            earlier: context.l10n.earlier,
          )
        : c.sessions.map(_HistorySession.new).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.learningConversations,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: context.l10n.newConversation,
                key: const Key('new-session'),
                onPressed: () => act(context, () async {
                  _searchDebounce?.cancel();
                  await c.newSession();
                  widget.onSelected?.call();
                }),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        if (c.subjectFilter.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.currentSubject(
                      l10nArgument((context.subjectName(c.subjectFilter))),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  key: const Key('session-show-all'),
                  onPressed: () => act(context, () async {
                    _searchDebounce?.cancel();
                    await c.searchSessions('');
                    await c.setSubjectFilter('');
                  }),
                  child: Text(context.l10n.showAllConversations),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const Key('session-search'),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
            controller: _search,
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                if (mounted) c.searchSessions(value);
              });
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: context.l10n.searchTitlesOrMessages,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.clearSearch,
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () {
                        _searchDebounce?.cancel();
                        _search.clear();
                        c.searchSessions('');
                      },
                    ),
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: .45),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: c.sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.search.isNotEmpty
                              ? Icons.search_off_outlined
                              : Icons.forum_outlined,
                          size: 40,
                          color: colors.onSurfaceVariant.withValues(alpha: .6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          c.search.isNotEmpty
                              ? context.l10n.noMatchingConversations
                              : c.subjectFilter.isNotEmpty
                              ? context.l10n.noConversationsInThisSubject
                              : context.l10n.noConversationsYetStartWith,
                          textAlign: TextAlign.center,
                        ),
                        if (c.search.isNotEmpty && c.subjectFilter.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                act(context, () => c.setSubjectFilter('')),
                            child: Text(context.l10n.clearSubjectFilter),
                          ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is _HistoryHeader) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final s = (row as _HistorySession).session;
                    final active = c.selected?.id == s.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Material(
                        color: active
                            ? colors.primaryContainer.withValues(alpha: .55)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.only(
                            left: 12,
                            right: 0,
                          ),
                          leading: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: active
                                  ? colors.primary.withValues(alpha: .12)
                                  : colors.surfaceContainerHighest.withValues(
                                      alpha: .6,
                                    ),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 17,
                              color: active
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                          minLeadingWidth: 0,
                          horizontalTitleGap: 10,
                          title: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: active
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: active
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.monthDayWithLabel(
                                  l10nArgument((s.updatedAt.month)),
                                  l10nArgument((s.updatedAt.day)),
                                  l10nArgument(
                                    (s.mode == 'guided'
                                        ? context.l10n.guidedLearning
                                        : s.mode == 'direct'
                                        ? context.l10n.directAnswer
                                        : context.l10n.examMode),
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              if (c.search.trim().isNotEmpty)
                                FutureBuilder<ChatMessage?>(
                                  future: _snippetFutures.putIfAbsent(
                                    '${s.id}:${s.updatedAt.microsecondsSinceEpoch}',
                                    () => c.db.matchingMessage(s.id, c.search),
                                  ),
                                  builder: (context, snapshot) {
                                    final excerpt = searchExcerpt(
                                      snapshot.data?.content ?? '',
                                      c.search,
                                    );
                                    return excerpt == null
                                        ? const SizedBox.shrink()
                                        : SearchSnippet(excerpt, c.search);
                                  },
                                ),
                            ],
                          ),
                          onTap: () => act(context, () async {
                            final selection = ++_selectionEpoch;
                            final query = c.search;
                            final match = query.isEmpty
                                ? null
                                : await _snippetFutures.putIfAbsent(
                                    '${s.id}:${s.updatedAt.microsecondsSinceEpoch}',
                                    () => c.db.matchingMessage(s.id, query),
                                  );
                            if (!mounted || selection != _selectionEpoch) {
                              return;
                            }
                            await c.selectSession(s);
                            if (!mounted || selection != _selectionEpoch) {
                              return;
                            }
                            if (match != null) {
                              c.showSearchMessage(s.id, match.id);
                            }
                            widget.onSelected?.call();
                          }),
                          trailing: PopupMenuButton<String>(
                            popUpAnimationStyle: menuAnimation(context),
                            tooltip: context.l10n.conversationActions,
                            onSelected: (action) =>
                                _action(context, c, s, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(context.l10n.rename),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.l10n.deleteConversation),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => act(context, () => _trash(context, c)),
                icon: const Icon(Icons.restore_from_trash_outlined, size: 17),
                label: Text(context.l10n.trash, style: TextStyle(fontSize: 12)),
              ),
              Text(
                context.l10n.storedOnThisDeviceTrash,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _action(
    BuildContext context,
    AppController c,
    ChatSession s,
    String action,
  ) async {
    if (action == 'rename') {
      final title = await editText(
        context,
        title: context.l10n.renameConversation,
        initial: s.title,
      );
      if (title != null && context.mounted) {
        await act(context, () => c.renameSession(s, title));
      }
    } else {
      await act(context, () async {
        await c.deleteSession(s);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.conversationMovedToTrash),
              action: SnackBarAction(
                label: context.l10n.undo,
                onPressed: () => act(context, () => c.restoreSession(s)),
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _trash(BuildContext context, AppController c) async {
    final items = await c.db.trash();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(context.l10n.trash),
          content: SizedBox(
            width: 480,
            height: 320,
            child: items.isEmpty
                ? Center(child: Text(context.l10n.trashIsEmpty))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          popUpAnimationStyle: menuAnimation(context),
                          tooltip: context.l10n.deletedConversationActions,
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'restore',
                              child: Text(context.l10n.restoreConversation),
                            ),
                            PopupMenuItem(
                              value: 'purge',
                              child: Text(
                                context.l10n.deleteConversationPermanently,
                              ),
                            ),
                          ],
                          onSelected: (action) => act(context, () async {
                            if (action == 'restore') {
                              await c.restoreSession(item);
                            } else {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(
                                    context.l10n.permanentlyDeleteConversation,
                                  ),
                                  content: Text(
                                    context.l10n
                                        .permanentlyDeleteMessagesImageReferences(
                                          l10nArgument((item.title)),
                                        ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.l10n.cancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(
                                        context.l10n.deletePermanently,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              final failed = await c.purgeSession(item.id);
                              if (context.mounted && failed > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n
                                          .recordsDeletedUnusedImagesNotRemoved(
                                            l10nArgument((failed)),
                                          ),
                                    ),
                                  ),
                                );
                              }
                            }
                            if (context.mounted) {
                              update(
                                () => items.removeWhere((s) => s.id == item.id),
                              );
                            }
                          }),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      ),
    );
  }
}
