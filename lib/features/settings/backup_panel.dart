import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/backup/backup_actions.dart';
import '../../core/backup/backup_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/platform/backup_file_picker.dart';
import '../../core/ui/actions.dart';

class BackupPanel extends ConsumerStatefulWidget {
  const BackupPanel({super.key});
  @override
  ConsumerState<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends ConsumerState<BackupPanel> {
  /// Cached so the undo-availability lookup isn't re-issued on every
  /// rebuild. Reset to null after a restore/undo-clear so the next build
  /// re-checks whether an undo copy exists.
  Future<Directory?>? _previousRoot;

  /// True while an export/import/undo runs: buttons stay disabled and a
  /// progress row shows, so a double-tap can't start concurrent runs.
  bool _busy = false;

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(
    BuildContext context,
    BackupActions actions, {
    bool undo = false,
  }) async {
    PreparedBackup? prepared;
    try {
      if (undo) {
        prepared = await actions.prepareUndo();
      } else {
        final input = await BackupFilePicker.open();
        if (input == null) return;
        prepared = await actions.prepare(input);
      }
      if (!context.mounted) return;
      final info = prepared.preview;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            undo
                ? context.l10n.undoTheLastRestore
                : context.l10n.restoreThisBackup,
          ),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.backupDate(
                  l10nArgument(
                    (info.createdAt.toLocal().toString().substring(0, 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.includesConversationsKnowledgeNotesMistakes(
                  l10nArgument((info.counts['chats'] ?? 0)),
                  l10nArgument((info.counts['knowledge'] ?? 0)),
                  l10nArgument((info.counts['mistakes'] ?? 0)),
                  l10nArgument((info.counts['attempts'] ?? 0)),
                  l10nArgument((info.files)),
                ),
              ),
              const SizedBox(height: 12),
              Text(context.l10n.restoringReplacesCurrentLocalLearning),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              key: const Key('confirm-restore'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.l10n.restoreData),
            ),
          ],
        ),
      );
      if (ok == true) {
        await actions.restore(prepared);
        if (mounted) setState(() => _previousRoot = null);
      }
    } finally {
      await prepared?.discard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.watch(backupActionsProvider),
        c = ref.watch(appControllerProvider);
    _previousRoot ??= BackupService.previousRoot(c.files.root);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.backupAndRestore,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.includesTheDatabaseOriginalAnd,
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('export-backup'),
              onPressed: actions == null || _busy
                  ? null
                  : () => _run(() => act(context, actions.export)),
              icon: const Icon(Icons.save_alt, size: 18),
              label: Text(context.l10n.exportCompleteBackup),
            ),
            OutlinedButton.icon(
              key: const Key('import-backup'),
              onPressed: actions == null || _busy
                  ? null
                  : () => _run(
                      () => act(context, () => _import(context, actions)),
                    ),
              icon: const Icon(Icons.restore, size: 18),
              label: Text(context.l10n.restoreFromBackup),
            ),
          ],
        ),
        if (_busy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(context.l10n.workingOnTheBackup),
              ],
            ),
          ),
        FutureBuilder<Directory?>(
          future: _previousRoot,
          builder: (ctx, snapshot) => snapshot.data == null
              ? const SizedBox.shrink()
              : Wrap(
                  children: [
                    TextButton(
                      key: const Key('undo-restore'),
                      onPressed: actions == null || _busy
                          ? null
                          : () => _run(
                              () => act(
                                context,
                                () => _import(context, actions, undo: true),
                              ),
                            ),
                      child: Text(context.l10n.undoLastRestore),
                    ),
                    TextButton(
                      onPressed: actions == null || _busy
                          ? null
                          : () => _run(
                              () => act(context, () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(
                                      context.l10n.deleteTheRestoreSafetyCopy,
                                    ),
                                    content: Text(
                                      context.l10n.thisDeletesOnlyTheOld,
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
                                          context.l10n.deleteSafetyCopy,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await actions.clearUndo();
                                  if (mounted) {
                                    setState(() => _previousRoot = null);
                                  }
                                }
                              }),
                            ),
                      child: Text(context.l10n.deleteRestoreSafetyCopy),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
