import "dart:async";
import "dart:convert";

import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/platform/usage_file_picker.dart";
import "../../core/ui/actions.dart";
import "generation_provider.dart";
import "generation_store.dart";
import "language_data.dart";
import "language_layout.dart";

ChatProvider languageGenerationProvider(
  BuildContext context,
  AppController c, {
  bool compareVersions = true,
}) {
  if (c.provider is MockChatProvider) return c.provider;
  return LanguageGenerationProvider(
    provider: () => c.provider,
    configuration: () => c.config,
    promptSettings: () => c.prompts,
    history: LanguageGenerationStore(c.db),
    compare: compareVersions
        ? (old, fresh, cancel) =>
              compareLanguageGenerations(context, old, fresh, cancel)
        : null,
  );
}

String generationText(String output, String format) {
  if (format != "json") return output;
  Object? data;
  try {
    data = jsonDecode(output);
  } on FormatException {
    return output;
  }
  String readable(Object? v) {
    if (v is List) {
      return v.map(readable).where((s) => s.isNotEmpty).join("\n\n");
    }
    if (v is Map) {
      return v.entries
          .where((e) => !{"id", "revision"}.contains(e.key))
          .map(
            (e) => e.value is num || e.value is bool
                ? "${e.key}: ${e.value}"
                : readable(e.value),
          )
          .where((s) => s.isNotEmpty)
          .join("\n");
    }
    return v?.toString() ?? "";
  }

  return readable(data);
}

Future<bool> compareLanguageGenerations(
  BuildContext context,
  LanguageGenerationRun original,
  LanguageGenerationRun candidate,
  CancelToken cancel,
) async {
  if (!context.mounted) {
    cancel.cancel();
    cancel.checkCancelled();
  }
  final route = DialogRoute<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final l10n = ctx.l10n;
      Widget version(LanguageGenerationRun run, bool fresh) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                fresh ? l10n.languageNewVersion : l10n.languageOriginalVersion,
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              Text(
                "${run.model} · ${run.thinking == null
                    ? l10n.languageLegacyGeneration
                    : run.thinking == true
                    ? ((run.effort?.isEmpty ?? true) ? l10n.languageModelDefault : run.effort)
                    : 'off'}",
              ),
              const SizedBox(height: 12),
              SelectableText(generationText(run.output, run.format)),
            ],
          ),
        ),
      );
      return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(l10n.languageGenerationCompare),
          content: SizedBox(
            width: 960,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.languageGenerationNotice),
                  const SizedBox(height: 12),
                  if (MediaQuery.sizeOf(ctx).width >= 900)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: version(original, false)),
                        Expanded(child: version(candidate, true)),
                      ],
                    )
                  else ...[
                    version(original, false),
                    version(candidate, true),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.languageUseOriginal),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.languageUseNew),
            ),
          ],
        ),
      );
    },
  );
  unawaited(
    cancel.whenCancel.then((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    }),
  );
  return await Navigator.of(context).push(route) ?? false;
}

class LanguageGenerationHistoryScreen extends StatefulWidget {
  const LanguageGenerationHistoryScreen({required this.db, super.key});
  final AppDatabase db;
  @override
  State<LanguageGenerationHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<LanguageGenerationHistoryScreen> {
  late final _store = LanguageGenerationStore(widget.db);
  bool _exporting = false;
  Future<void> _export(String extension) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    await act(context, () async {
      final text = extension == "jsonl"
          ? await _store.exportJsonl()
          : await _store.exportCsv();
      await UsageFilePicker.save(
        text,
        extension: extension,
        namePrefix: "tixun-language-analysis",
        label: "Language generation analysis",
      );
    });
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.languageGenerationHistory),
      actions: [
        PopupMenuButton<String>(
          enabled: !_exporting,
          tooltip: context.l10n.languageAnalysisExport,
          icon: const Icon(Icons.download_outlined),
          onSelected: (value) => unawaited(_export(value)),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: "jsonl",
              child: Text(context.l10n.languageExportJsonl),
            ),
            PopupMenuItem(
              value: "csv",
              child: Text(context.l10n.languageExportCsv),
            ),
          ],
        ),
      ],
    ),
    body: LanguageDataBuilder<List<LanguageGenerationRun>>(
      load: _store.watch,
      builder: (ctx, rows) => languagePage(
        children: [
          if (_exporting) const LinearProgressIndicator(),
          if (rows.isEmpty) Text(ctx.l10n.languageNoGenerations),
          for (final run in rows)
            Card(
              child: ListTile(
                title: Text(run.model),
                subtitle: Text(
                  "${run.createdAt.toLocal()}\n${generationText(run.output, run.format)}",
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => unawaited(_detail(run)),
              ),
            ),
        ],
      ),
    ),
  );
  Future<void> _detail(LanguageGenerationRun run) async {
    final prompt = run.promptId == null
        ? null
        : await (widget.db.select(
            widget.db.languagePromptSnapshots,
          )..where((p) => p.id.equals(run.promptId!))).getSingle();
    final adopted = (await _store.active(run.taskId))?.id == run.id;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: Text(ctx.l10n.languageGenerationOutput)),
          body: languagePage(
            children: [
              Text(
                adopted
                    ? ctx.l10n.languageGenerationAdopted
                    : ctx.l10n.languageGenerationArchived,
              ),
              SelectableText(generationText(run.output, run.format)),
              ExpansionTile(
                title: Text(ctx.l10n.languageGenerationSettings),
                children: [
                  SelectableText(
                    "${run.provider} · ${run.endpoint}\n${run.model}\n${run.thinking} · ${run.effort}\n${run.optionsJson}",
                  ),
                ],
              ),
              ExpansionTile(
                title: Text(ctx.l10n.languageGenerationPrompt),
                children: [
                  SelectableText(
                    prompt?.content ?? ctx.l10n.languageLegacyGeneration,
                  ),
                ],
              ),
              ExpansionTile(
                title: Text(ctx.l10n.languageGenerationInput),
                children: [SelectableText(run.inputJson)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
