import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/prompt_settings.dart';
import '../../core/l10n/app_strings.dart';
import 'prompt_localization.dart';

class PromptScreen extends ConsumerStatefulWidget {
  const PromptScreen({super.key});
  @override
  ConsumerState<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends ConsumerState<PromptScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final rows = promptDefinitions.where(
      (p) =>
          '${promptTitle(context, p)}${promptDescription(context, p)}${c.prompts.text(p.id)}'
              .toLowerCase()
              .contains(query.toLowerCase()),
    );
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
                      tooltip: context.l10n.backToSettings,
                      onPressed: () => context.go('/settings'),
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
                Text(context.l10n.editTeachingStylesAndTask),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('prompt-search'),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: context.l10n.searchPrompts,
                  ),
                  onChanged: (v) => setState(() => query = v.trim()),
                ),
                const SizedBox(height: 16),
                if (rows.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(context.l10n.noMatchingPrompts),
                  ),
                for (final p in rows) ...[
                  ListTile(
                    key: Key('prompt-${p.id}'),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    title: Text(promptTitle(context, p)),
                    subtitle: Text(
                      '${c.prompts.overrides.containsKey(p.id) ? context.l10n.customized : context.l10n.defaultLabel} · ${promptDescription(context, p)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/settings/prompts/${p.id}'),
                  ),
                  const Divider(),
                ],
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
        ? ''
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

  Future<void> leave() async {
    if (saving) return;
    if (!isDirty) {
      context.go('/settings/prompts');
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.unsavedPromptChanges),
        content: Text(context.l10n.savePromptBeforeLeaving),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(context.l10n.discardChanges),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(context.l10n.savePrompt),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'discard') context.go('/settings/prompts');
    if (choice == 'save') await save();
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
        context.go('/settings/prompts');
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
      final mode = ['guided', 'direct', 'exam'].contains(widget.id)
          ? widget.id
          : ['knowledge_writing', 'knowledge_editing'].contains(widget.id)
          ? 'direct'
          : widget.id == 'quiz'
          ? 'exam'
          : 'guided';
      final system = teachingPrompt(
        mode,
        prompts: settings,
        toolsEnabled: [
          'knowledge_writing',
          'knowledge_editing',
        ].contains(widget.id),
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.promptPreview),
          scrollable: true,
          content: SizedBox(
            width: 700,
            child: SelectableText(
              context.l10n.actualRequestsAlsoIncludeThe(
                l10nArgument((system)),
                l10nArgument(
                  (['global', 'guided', 'direct', 'exam'].contains(widget.id)
                      ? ''
                      : context.l10n.taskPrompt(
                          l10nArgument((settings.text(widget.id))),
                        )),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.close),
            ),
          ],
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final p = definition;
    if (p == null) {
      return Center(
        child: TextButton(
          onPressed: () => context.go('/settings/prompts'),
          child: Text(context.l10n.promptNotFoundReturnTo),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
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
                        key: const Key('prompt-back'),
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
                  const SizedBox(height: 18),
                  TextField(
                    key: const Key('prompt-content'),
                    controller: input,
                    enabled: !saving,
                    minLines: 12,
                    maxLines: 24,
                    maxLength: 6000,
                    decoration: InputDecoration(
                      labelText: context.l10n.promptContent,
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
                    children: [
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          key: const Key('save-prompt'),
                          onPressed: saving ? null : save,
                          child: Text(
                            saving
                                ? context.l10n.savingEllipsis
                                : context.l10n.savePrompt,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: saving ? null : preview,
                          child: Text(context.l10n.preview),
                        ),
                      ),
                      SizedBox(
                        height: 48,
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
