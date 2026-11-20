part of "session_list.dart";

extension _SessionListTrash on _SessionListState {
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
                              value: "restore",
                              child: Text(context.l10n.restoreConversation),
                            ),
                            PopupMenuItem(
                              value: "purge",
                              child: Text(
                                context.l10n.deleteConversationPermanently,
                              ),
                            ),
                          ],
                          onSelected: (action) => act(context, () async {
                            if (action == "restore") {
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
