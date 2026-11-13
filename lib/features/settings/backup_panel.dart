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
          title: Text(undo ? context.tr("撤销上次恢复？") : context.tr("恢复这份备份？")),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr("备份日期：{0}", [
                  info.createdAt.toLocal().toString().substring(0, 16),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  "包含 {0} 段对话、{1} 条知识、{2} 道错题、{3} 次作答及 {4} 个附件（含回收区）。",
                  [
                    info.counts['chats'] ?? 0,
                    info.counts['knowledge'] ?? 0,
                    info.counts['mistakes'] ?? 0,
                    info.counts['attempts'] ?? 0,
                    info.files,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  "恢复会替换当前本地学习数据。原数据保留为本设备上的撤销副本，只保留最近一次；下一次恢复会替换该副本。系统中保存的 API Key 不会更改；恢复后需要重新开启对话资料工具。",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr("取消")),
            ),
            FilledButton(
              key: const Key('confirm-restore'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr("恢复数据")),
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
          context.tr("备份与恢复"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            "包含数据库、原图与编辑图片、对话、知识、错题、训练、复习和必要配置。备份会检查文件和关联数据的完整性，始终排除系统密钥。",
          ),
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
              label: Text(context.tr("导出完整备份")),
            ),
            OutlinedButton.icon(
              key: const Key('import-backup'),
              onPressed: actions == null || _busy
                  ? null
                  : () => _run(
                      () => act(context, () => _import(context, actions)),
                    ),
              icon: const Icon(Icons.restore, size: 18),
              label: Text(context.tr("从备份恢复")),
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
                Text(context.tr("正在处理备份…")),
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
                      child: Text(context.tr("撤销上次恢复")),
                    ),
                    TextButton(
                      onPressed: actions == null || _busy
                          ? null
                          : () => _run(
                              () => act(context, () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(context.tr("删除恢复安全副本？")),
                                    content: Text(
                                      context.tr(
                                        "只删除本设备为上次恢复保留的旧数据。当前学习数据及已导出的备份不受影响；删除后将无法撤销上次恢复。",
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(context.tr("取消")),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(context.tr("删除安全副本")),
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
                      child: Text(context.tr("删除恢复安全副本")),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
