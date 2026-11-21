import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";
import "package:url_launcher/url_launcher.dart";

import "../../app/controller.dart";
import "../../core/ai/web_activity.dart";
import "../../core/l10n/app_strings.dart";
import "chat_context_store.dart";

final _webActivityProvider = FutureProvider.autoDispose
    .family<List<WebActivity>, String>((ref, id) {
      final db = ref.watch(appControllerProvider.select((c) => c.db));
      return ChatContextStore(db).webActivity(id);
    });

class MessageWebActivity extends ConsumerWidget {
  const MessageWebActivity(this.messageId, {super.key});
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(_webActivityProvider(messageId)).value;
    if (reports == null || reports.isEmpty) return const SizedBox.shrink();
    final operations = reports.expand((report) => report.operations).toList();
    final searches = operations
        .where((op) => op.action == WebAction.search)
        .length;
    final reads = operations.length - searches;
    final sources = <Uri, WebSource>{};
    for (final report in reports) {
      for (final source in report.sources) {
        sources.putIfAbsent(source.url, () => source);
      }
    }
    final l = context.l10n;
    return ExpansionTile(
      key: PageStorageKey("web-activity-$messageId"),
      leading: const Icon(Icons.language, size: 20),
      title: Text(l.webActivityTitle),
      subtitle: searches + reads > 0
          ? Text(l.webActivityCounts(searches, reads))
          : null,
      children: [
        for (final operation in operations) _WebOperationTile(operation),
        if (sources.isNotEmpty)
          ListTile(dense: true, title: Text(l.webSourceList)),
        for (final source in sources.values.take(20))
          ListTile(
            dense: true,
            leading: const Icon(Icons.open_in_new, size: 16),
            title: Text(
              source.title.isEmpty ? source.url.host : source.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(source.url.host),
            onTap: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  source.url,
                  mode: LaunchMode.externalApplication,
                );
              } on Exception {
                // Platform launch failures are shown using the same message.
              }
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.couldNotOpenSystemBrowser)),
                );
              }
            },
          ),
      ],
    );
  }
}

class _WebOperationTile extends StatelessWidget {
  const _WebOperationTile(this.operation);
  final WebOperation operation;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final page = operation.page;
    final isSearch = operation.action == WebAction.search;
    final details = [
      if (isSearch) ...operation.queries,
      if (!isSearch && page != null) ...[
        if (page.title.isNotEmpty) page.title,
        page.url.toString(),
      ],
      if (operation.failed) l.webOperationFailed,
    ];
    return ListTile(
      dense: true,
      leading: Icon(isSearch ? Icons.search : Icons.article_outlined, size: 18),
      title: Text(isSearch ? l.webSearchOperation : l.webReadOperation),
      subtitle: details.isEmpty
          ? null
          : SelectionArea(child: Text(details.join("\n"))),
    );
  }
}
