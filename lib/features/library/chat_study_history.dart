part of "chat_study_actions.dart";

final _toolHistoryProvider = StreamProvider.autoDispose
    .family<List<AiToolOperation>, String>((ref, id) {
      final store = ref.watch(studyStoreProvider);
      return store.db
          .customSelect(
            "SELECT * FROM ai_tool_operations WHERE run_id = ? ORDER BY rowid",
            variables: [Variable.withString(id)],
            readsFrom: {store.db.aiToolOperations},
          )
          .watch()
          .map(
            (rows) => rows
                .map((row) => store.db.aiToolOperations.map(row.data))
                .toList(),
          );
    });

class ToolHistory extends ConsumerWidget {
  const ToolHistory(this.messageId, {super.key});
  final String messageId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_toolHistoryProvider(messageId))
      .maybeWhen(
        data: (items) => ToolHistoryPanel(messageId: messageId, items: items),
        orElse: () => const SizedBox.shrink(),
      );
}

/// The operation log stays compact, while actionable split suggestions remain
/// visible as message results outside the collapsed history.
class ToolHistoryPanel extends StatelessWidget {
  const ToolHistoryPanel({
    required this.messageId,
    required this.items,
    super.key,
  });
  final String messageId;
  final List<AiToolOperation> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final ordered = items;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ExpansionTile(
              key: PageStorageKey("tool-history-$messageId"),
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: colors.surfaceContainerLow,
              collapsedBackgroundColor: colors.surfaceContainerLow,
              leading: Icon(
                Icons.build_circle_outlined,
                size: 20,
                color: colors.primary,
              ),
              title: Text(
                context.l10n.toolActivityCount("${items.length}"),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              subtitle: Text(
                _toolSummary(context, ordered.last),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              children: [
                for (final op in ordered) _toolHistoryItem(context, op),
              ],
            ),
          ),
        ),
        for (final op in ordered)
          if (op.status == "succeeded" && op.name == "suggest_question_regions")
            SplitSuggestionCard(op),
      ],
    );
  }
}

Map<String, dynamic> _toolMap(String? encoded) {
  if (encoded == null) return const {};
  try {
    final value = jsonDecode(encoded);
    return value is Map ? value.cast<String, dynamic>() : const {};
  } on FormatException {
    return const {};
  }
}

String _toolSummary(BuildContext context, AiToolOperation op) {
  final args = _toolMap(op.arguments);
  final result = _toolMap(op.result);
  final l = context.l10n;
  final label = switch (op.name) {
    "search_knowledge" => l.toolSearchKnowledge,
    "search_mistakes" => l.toolSearchMistakes,
    "get_knowledge" => l.toolReadKnowledge,
    "get_mistake" => l.toolReadMistake,
    "list_subject_modules" => l.toolSearchModules,
    "get_learning_progress" => l.toolReadProgress,
    "create_visual" => l.toolCreateVisual,
    "update_visual" => l.toolUpdateVisual,
    "get_visual" => l.toolReadVisual,
    _ => toolLabel(context, op.name) ?? l.toolActivityFallback,
  };
  String? detail;
  if (op.name == "search_knowledge" ||
      op.name == "search_mistakes" ||
      op.name == "list_subject_modules") {
    final query = args["query"];
    detail = query is String && query.trim().isNotEmpty
        ? query.trim()
        : l.toolSearchAll;
  } else {
    final scene = args["scene"];
    final value =
        result["title"] ??
        args["title"] ??
        (scene is Map ? scene["title"] : null) ??
        args["name"] ??
        (op.name == "run_python" ? args["purpose"] : null);
    if (value is String && value.trim().isNotEmpty) detail = value.trim();
  }
  // Never surface full code, document bodies, opaque identifiers, or results.
  return detail == null
      ? label
      : '$label ${detail.replaceAll(RegExp(r'\s+'), ' ')}';
}

Widget _toolHistoryItem(BuildContext context, AiToolOperation op) {
  if (op.name == "run_python") return PythonHistoryCard(op);
  final result = _toolMap(op.result);
  final summary = _toolSummary(context, op);
  final success = op.status == "succeeded";
  final read =
      op.name.startsWith("search_") ||
      op.name.startsWith("get_") ||
      op.name == "list_subject_modules";
  final status = switch (op.status) {
    "succeeded" => read ? context.l10n.completed : context.l10n.applied,
    "pending" =>
      read ? context.l10n.running : context.l10n.awaitingConfirmation,
    "running" => context.l10n.running,
    "rejected" => context.l10n.notApplied,
    _ => context.l10n.notCompleted,
  };
  final hasMaterial =
      success &&
      result["id"] is String &&
      (op.name.endsWith("knowledge") || op.name.endsWith("mistake"));
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 8),
          child: Icon(
            success
                ? Icons.check_circle_outline
                : op.status == "failed"
                ? Icons.error_outline
                : Icons.info_outline,
            size: 16,
            color: op.status == "failed"
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: summary,
                child: Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(status, style: Theme.of(context).textTheme.labelSmall),
              if (hasMaterial)
                TextButton(
                  onPressed: () => context.push(
                    '${op.name.endsWith('knowledge') ? '/knowledge' : '/mistakes'}/${result['id']}',
                  ),
                  child: Text(context.l10n.viewMaterial),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

final _pythonHighlighter = CodeHighlighter(
  cacheSize: 4,
  isolateThreshold: 12000,
);

class PythonCodeView extends StatelessWidget {
  const PythonCodeView(this.code, {super.key, this.fontSize = 13});
  final String code;
  final double fontSize;
  @override
  Widget build(BuildContext context) => CodeView(
    code,
    key: const Key("python-highlighted-code"),
    language: pythonLanguage,
    highlighter: _pythonHighlighter,
    selectable: true,
    padding: const EdgeInsets.all(8),
    textStyle: TextStyle(
      fontFamily: "TixunMono",
      fontFamilyFallback: const ["NotoSansSC"],
      fontSize: fontSize,
      height: 1.5,
    ),
  );
}

Future<void> showPythonCode(BuildContext context, String code) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.pythonCode),
        content: SizedBox(
          width: 760,
          height: MediaQuery.sizeOf(ctx).height * .6,
          child: SingleChildScrollView(child: PythonCodeView(code)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.close),
          ),
        ],
      ),
    );

class PythonHistoryCard extends StatelessWidget {
  const PythonHistoryCard(this.operation, {super.key});
  final AiToolOperation operation;
  @override
  Widget build(BuildContext context) {
    Map args = {}, result = {};
    try {
      args = jsonDecode(operation.arguments) as Map;
    } catch (_) {}
    try {
      result = jsonDecode(operation.result ?? "{}") as Map;
    } catch (_) {}
    final status = switch (operation.status) {
      "succeeded" => context.l10n.completed,
      "recording_failed" => context.l10n.executedRecordingError,
      "rejected" => context.l10n.executionDenied,
      "running" => context.l10n.running,
      "stop_requested" => context.l10n.stopRequested,
      "pending" => context.l10n.awaitingReview,
      _ => context.l10n.executionFailed,
    };
    return ExpansionTile(
      key: PageStorageKey("python-history-${operation.id}"),
      leading: const Icon(Icons.code, size: 20),
      title: Text(
        context.l10n.python(l10nArgument((status))),
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        args["purpose"]?.toString() ?? "",
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () =>
                showPythonCode(context, args["code"]?.toString() ?? ""),
            child: Text(context.l10n.viewFullCode),
          ),
        ),
        if (result.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              key: PageStorageKey("python-output-${operation.id}"),
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                [
                  if (result["stdout"] != null) result["stdout"],
                  if (result["stderr"] != null && result["stderr"] != "")
                    'stderr:\n${result['stderr']}',
                  if (result["traceback"] != null) result["traceback"],
                  if (result["error"] != null) result["error"].toString(),
                  if (result["output_truncated"] == true)
                    context.l10n.outputExceededTheDisplayLimit,
                ].join("\n"),
                style: const TextStyle(
                  fontFamily: "TixunMono",
                  fontFamilyFallback: ["NotoSansSC"],
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
