import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../../app/controller.dart";
import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "../../core/l10n/app_strings.dart";
import "prompt_localization.dart";
import "prompt_groups.dart";

class PromptScreen extends ConsumerStatefulWidget {
  const PromptScreen({super.key});
  @override
  ConsumerState<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends ConsumerState<PromptScreen> {
  String query = "";
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key("prompt-manager-back"),
                      tooltip: context.l10n.back,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go("/settings"),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.promptManager,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key("prompt-search"),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: context.l10n.searchPrompts,
                  ),
                  onChanged: (v) => setState(() => query = v.trim()),
                ),
                const SizedBox(height: 16),
                PromptGroups(
                  settings: c.prompts,
                  language: c.language,
                  query: query,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class PromptEditorScreen extends ConsumerStatefulWidget {
  const PromptEditorScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<PromptEditorScreen> createState() => _PromptEditorScreenState();
}

enum _PromptUiError { saveFailed, previewFailed }

class _PromptEditorScreenState extends ConsumerState<PromptEditorScreen> {
  late final PromptDefinition? definition = promptDefinitions
      .where((p) => p.id == widget.id)
      .firstOrNull;
  late final TextEditingController input = TextEditingController(
    text: definition == null
        ? ""
        : ref.read(appControllerProvider).prompts.text(widget.id),
  );
  bool saving = false;
  late final String initialText;
  Object? failure;

  bool get isDirty => input.text != initialText;

  @override
  void initState() {
    super.initState();
    initialText = input.text;
  }

  String _failureText(Object issue) => switch (issue) {
    PromptError.invalidEntry => context.l10n.eachPromptMustHaveA,
    PromptError.totalTooLong => context.l10n.customPromptsCannotExceed24,
    PromptError.invalidFormat => context.l10n.invalidPromptConfiguration,
    PromptError.invalidValues => context.l10n.promptNamesAndContentMust,
    _PromptUiError.saveFailed => context.l10n.couldNotSaveThePrompt,
    _PromptUiError.previewFailed => context.l10n.couldNotPreviewThePrompt,
    _ => issue.toString(),
  };
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  void _returnToManager() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go("/settings/prompts");
    }
  }

  Future<void> leave() async {
    if (saving) return;
    if (!isDirty) {
      _returnToManager();
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.unsavedPromptChanges),
        content: Text(context.l10n.savePromptBeforeLeaving),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, "stay"),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, "discard"),
            child: Text(context.l10n.discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, "save"),
            child: Text(context.l10n.savePrompt),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == "discard") _returnToManager();
    if (choice == "save") await save();
  }

  Future<void> save() async {
    setState(() {
      saving = true;
      failure = null;
    });
    try {
      await ref.read(appControllerProvider).savePrompt(widget.id, input.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.promptSavedForFutureRequests)),
        );
        _returnToManager();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is PromptSettingsException
              ? error.code
              : error is FormatException
              ? error.message
              : _PromptUiError.saveFailed,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> preview() async {
    try {
      final settings = ref
          .read(appControllerProvider)
          .prompts
          .update(widget.id, input.text);
      final prompt = definition!;
      final hasContract = prompt.requestContract != null;
      final sections = hasContract
          ? [
              (promptId: null, text: languagePromptContract(prompt)),
              (promptId: prompt.id, text: settings.text(prompt.id)),
            ]
          : _chatPreview(settings);
      final target = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.promptPreview),
          scrollable: true,
          content: SizedBox(
            width: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                for (final section in sections)
                  Card(
                    child: switch (section.promptId) {
                      final String id => ListTile(
                        key: Key("prompt-preview-$id"),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        title: Text(
                          promptTitle(
                            ctx,
                            promptDefinitions.firstWhere((p) => p.id == id),
                          ),
                        ),
                        subtitle: Text(section.text),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(ctx, id),
                      ),
                      null => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            Text(
                              hasContract
                                  ? ctx.l10n.promptPreviewRequestContract
                                  : ctx.l10n.promptPreviewApplicationRules,
                              style: Theme.of(ctx).textTheme.titleMedium,
                            ),
                            SelectableText(section.text),
                          ],
                        ),
                      ),
                    },
                  ),
                if (!hasContract)
                  Text(
                    ctx.l10n.promptPreviewContextNotice,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.close),
            ),
          ],
        ),
      );
      if (mounted && target != null && target != widget.id) {
        await context.push<void>("/settings/prompts/$target");
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => failure = error is PromptSettingsException
              ? error.code
              : error is FormatException
              ? error.message
              : _PromptUiError.previewFailed,
        );
      }
    }
  }

  List<({String? promptId, String text})> _chatPreview(
    PromptSettings settings,
  ) {
    final mode = ["guided", "direct", "exam"].contains(widget.id)
        ? widget.id
        : ["knowledge_writing", "knowledge_editing"].contains(widget.id)
        ? "direct"
        : widget.id == "quiz"
        ? "exam"
        : "guided";
    final sections = teachingPromptSections(
      mode,
      prompts: settings,
      toolsEnabled: [
        "knowledge_writing",
        "knowledge_editing",
      ].contains(widget.id),
    );
    return [
      ...sections,
      if (!sections.any((section) => section.promptId == widget.id))
        (promptId: widget.id, text: settings.text(widget.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = definition;
    if (p == null) {
      return Center(
        child: TextButton(
          onPressed: _returnToManager,
          child: Text(context.l10n.promptNotFoundReturnTo),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(leave());
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key("prompt-back"),
                        tooltip: context.l10n.backToPromptManager,
                        onPressed: saving ? null : leave,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          promptTitle(context, p),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(promptDescription(context, p)),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.promptsAreSentToThe,
                    style: TextStyle(fontSize: 12),
                  ),
                  if (p.requestContract != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.languagePromptContractNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key("prompt-content"),
                    controller: input,
                    enabled: !saving,
                    minLines: 12,
                    maxLines: 24,
                    maxLength: 6000,
                    decoration: InputDecoration(
                      labelText: p.requestContract == null
                          ? context.l10n.promptContent
                          : context.l10n.languagePromptPreferences,
                      alignLabelWithHint: true,
                    ),
                  ),
                  if (failure != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _failureText(failure!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: FilledButton(
                          key: const Key("save-prompt"),
                          onPressed: saving ? null : save,
                          child: Text(
                            saving
                                ? context.l10n.savingEllipsis
                                : context.l10n.savePrompt,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: OutlinedButton(
                          onPressed: saving ? null : preview,
                          child: Text(context.l10n.preview),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: TextButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final reset = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(context.l10n.resetThisPrompt),
                                      content: Text(
                                        context
                                            .l10n
                                            .thisReplacesTheCurrentEditor,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: Text(context.l10n.cancel),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: Text(
                                            context.l10n.resetToDefault,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (reset == true && mounted) {
                                    setState(() {
                                      input.text = ref
                                          .read(appControllerProvider)
                                          .prompts
                                          .defaultText(p.id);
                                      failure = null;
                                    });
                                  }
                                },
                          child: Text(context.l10n.resetToDefault),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
