import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/python/python_tool.dart';
import '../../core/python/python_workspace_store.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/app_menu.dart';

class PythonSettings extends ConsumerStatefulWidget {
  const PythonSettings({super.key});
  @override
  ConsumerState<PythonSettings> createState() => _PythonSettingsState();
}

class _PythonSettingsState extends ConsumerState<PythonSettings> {
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
    ref
        .read(appControllerProvider)
        .db
        .preference(pythonPolicyKey)
        .then((v) {
          if (mounted) {
            setState(
              () => policy = ['ask', 'auto', 'off'].contains(v) ? v : 'ask',
            );
          }
        })
        .onError((error, stack) {
          if (mounted) setState(() => loadError = true);
        });
  }

  Future<void> change(String? next) async {
    if (next == null || next == policy) return;
    // Show the saved permission until confirmation and persistence succeed.
    setState(() => selection++);
    if (next == 'auto') {
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
              key: const Key('confirm-python-auto'),
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
          .db
          .setPreference(pythonPolicyKey, next);
      if (mounted) setState(() => policy = next);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
    appBar: AppBar(title: Text(context.l10n.pythonExecution)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(context.l10n.aiPythonCapabilities),
            const SizedBox(height: 20),
            if (loadError)
              Text(
                context.l10n.couldNotLoadExecutionPermissions,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (policy == null)
              const LinearProgressIndicator()
            else
              SizedBox(
                key: const Key('python-policy'),
                child: AppSelectField<String>(
                  key: ValueKey('$policy-$selection'),
                  initialValue: policy,
                  decoration: InputDecoration(
                    labelText: context.l10n.executionPermission,
                  ),
                  items: [
                    for (final pair in [
                      ('off', context.l10n.close),
                      ('ask', context.l10n.reviewEveryScript),
                      ('auto', context.l10n.automaticallyAllowArbitraryCode),
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
                        key: ValueKey('python-workspace-${entry.sessionId}'),
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
