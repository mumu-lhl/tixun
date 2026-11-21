import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "tool_call_limit_setting.dart";
import "../../core/python/python_runtime.dart";
import "../../core/python/python_workspace_store.dart";
import "../../core/ui/actions.dart";
import "../../core/ui/app_menu.dart";

class AiToolsSettings extends ConsumerStatefulWidget {
  const AiToolsSettings({super.key});
  @override
  ConsumerState<AiToolsSettings> createState() => _AiToolsSettingsState();
}

class _AiToolsSettingsState extends ConsumerState<AiToolsSettings> {
  String? policy;
  bool loadError = false;
  bool saving = false;
  int selection = 0;
  late final PythonWorkspaceStore workspaceStore;
  Future<List<PythonWorkspaceInfo>>? workspaceFuture;
  bool managingWorkspaces = false;
  @override
  void initState() {
    super.initState();
    workspaceStore = PythonWorkspaceStore(
      ref.read(appControllerProvider).files.root,
    );
    workspaceFuture = workspaceStore.list();
    unawaited(
      ref
          .read(appControllerProvider)
          .preferences
          .pythonExecutionPolicy()
          .then((value) {
            if (mounted) setState(() => policy = value);
          })
          .onError((error, stack) {
            if (mounted) setState(() => loadError = true);
          }),
    );
  }

  Future<void> change(String? next) async {
    if (next == null || next == policy) return;
    // Show the saved permission until confirmation and persistence succeed.
    setState(() => selection++);
    if (next == "auto") {
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.automaticallyAllowArbitraryPythonCode),
          content: Text(ctx.l10n.pythonHasTheSameFile),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              key: const Key("confirm-python-auto"),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.allowAutomaticallyAnyway),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(appControllerProvider)
          .preferences
          .setPythonExecutionPolicy(next);
      if (mounted) setState(() => policy = next);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  Future<void> deleteWorkspace(PythonWorkspaceInfo workspace) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deletePythonWorkspace),
        content: Text(
          ctx.l10n.deletePythonWorkspaceConfirmation(workspace.sessionId),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => managingWorkspaces = true);
    try {
      await workspaceStore.delete(workspace.sessionId);
      if (mounted) setState(() => workspaceFuture = workspaceStore.list());
    } finally {
      if (mounted) setState(() => managingWorkspaces = false);
    }
  }

  Future<void> deleteAllWorkspaces() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteAllPythonWorkspaces),
        content: Text(ctx.l10n.deleteAllPythonWorkspacesConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => managingWorkspaces = true);
    try {
      await workspaceStore.deleteAll();
      if (mounted) setState(() => workspaceFuture = workspaceStore.list());
    } finally {
      if (mounted) setState(() => managingWorkspaces = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.aiToolsSettings)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _GlobalToolPreferences(),
            const SizedBox(height: 24),
            Text(
              context.l10n.pythonExecution,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.aiPythonCapabilities),
            const SizedBox(height: 20),
            if (!PythonRuntime.isSupportedPlatform)
              Text(
                context.l10n.pythonSandboxNotAvailable,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (loadError)
              Text(
                context.l10n.couldNotLoadExecutionPermissions,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (policy == null)
              const LinearProgressIndicator()
            else
              SizedBox(
                key: const Key("python-policy"),
                child: AppSelectField<String>(
                  key: ValueKey("$policy-$selection"),
                  initialValue: policy,
                  decoration: InputDecoration(
                    labelText: context.l10n.executionPermission,
                  ),
                  items: [
                    for (final pair in [
                      ("off", context.l10n.close),
                      ("ask", context.l10n.reviewEveryScript),
                      ("auto", context.l10n.automaticallyAllowArbitraryCode),
                    ])
                      DropdownMenuItem(value: pair.$1, child: Text(pair.$2)),
                  ],
                  onChanged: saving
                      ? null
                      : (v) => act(context, () => change(v)),
                ),
              ),
            const SizedBox(height: 20),
            Text(context.l10n.thisIsNotASecurity),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.pythonWorkspaces,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.refresh,
                  onPressed: managingWorkspaces
                      ? null
                      : () => setState(
                          () => workspaceFuture = workspaceStore.list(),
                        ),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(context.l10n.pythonWorkspaceExplanation),
            const SizedBox(height: 8),
            FutureBuilder<List<PythonWorkspaceInfo>>(
              future: workspaceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LinearProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text(context.l10n.pythonWorkspaceLoadFailed);
                }
                final entries = snapshot.data ?? const <PythonWorkspaceInfo>[];
                if (entries.isEmpty) {
                  return Text(context.l10n.noPythonWorkspaces);
                }
                final total = entries.fold<int>(
                  0,
                  (sum, entry) => sum + entry.bytes,
                );
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.pythonWorkspaceTotal(
                          entries.length,
                          formatBytes(total),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: managingWorkspaces
                            ? null
                            : () => act(context, deleteAllWorkspaces),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(context.l10n.deleteAllPythonWorkspaces),
                      ),
                    ),
                    for (final entry in entries)
                      ListTile(
                        key: ValueKey("python-workspace-${entry.sessionId}"),
                        title: Text(entry.sessionId),
                        subtitle: Text(
                          context.l10n.pythonWorkspaceDetails(
                            entry.files,
                            formatBytes(entry.bytes),
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: context.l10n.delete,
                          onPressed: managingWorkspaces
                              ? null
                              : () =>
                                    act(context, () => deleteWorkspace(entry)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _GlobalToolPreferences extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            key: const Key("settings-ai-web"),
            secondary: const Icon(Icons.language),
            title: Text(context.l10n.aiWebAccess),
            subtitle: Text(context.l10n.aiWebAccessHelp),
            value: c.preferences.aiWebEnabled,
            onChanged: (value) =>
                act(context, () => c.preferences.setAiWebEnabled(value)),
          ),
          SwitchListTile(
            key: const Key("settings-ai-drawing"),
            secondary: const Icon(Icons.draw_outlined),
            title: Text(context.l10n.aiDrawing),
            subtitle: Text(context.l10n.aiDrawingHelp),
            value: c.aiDrawingEnabled,
            onChanged: (value) =>
                act(context, () => c.setAiDrawingEnabled(value)),
          ),
          SwitchListTile(
            key: const Key("settings-ai-a2ui"),
            secondary: const Icon(Icons.widgets_outlined),
            title: Text(context.l10n.aiA2ui),
            subtitle: Text(context.l10n.aiA2uiHelp),
            value: c.aiA2uiEnabled,
            onChanged: (value) => act(context, () => c.setAiA2uiEnabled(value)),
          ),
          ListTile(
            key: const Key("settings-tool-call-limit"),
            leading: const Icon(Icons.tune),
            title: Text(context.l10n.maxToolCalls),
            subtitle: Text(
              "${c.maxToolCalls == 0 ? context.l10n.toolCallsUnlimited : c.maxToolCalls}\n${context.l10n.maxToolCallsHelp}",
            ),
            onTap: () => editToolCallLimit(context, c),
          ),
        ],
      ),
    );
  }
}
