import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/backup/backup_actions.dart';
import '../../core/backup/backup_service.dart';
import '../../core/platform/backup_file_picker.dart';
import '../../core/ui/actions.dart';

class BackupPanel extends ConsumerWidget {
  const BackupPanel({super.key});
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
          title: Text(undo ? '撤销上次恢复？' : '恢复这份备份？'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '备份日期：${info.createdAt.toLocal().toString().substring(0, 16)}',
              ),
              const SizedBox(height: 12),
              Text(
                '包含 ${info.counts['chats'] ?? 0} 段对话、${info.counts['knowledge'] ?? 0} 条知识、${info.counts['mistakes'] ?? 0} 道错题、${info.counts['attempts'] ?? 0} 次作答及 ${info.files} 个附件（含回收区）。',
              ),
              const SizedBox(height: 12),
              const Text(
                '恢复会替换当前本地学习数据。原数据保留为本设备上的撤销副本，只保留最近一次；下一次恢复会替换该副本。系统中保存的 API Key 不会更改；恢复后需要重新开启对话资料工具。',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const Key('confirm-restore'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复数据'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await actions.restore(prepared);
      }
    } finally {
      await prepared?.discard();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(backupActionsProvider),
        c = ref.watch(appControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('备份与恢复', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          '包含数据库、原图与编辑图片、对话、知识、错题、训练、复习和必要配置。备份会检查文件和关联数据的完整性，始终排除系统密钥。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('export-backup'),
              onPressed: actions == null
                  ? null
                  : () => act(context, actions.export),
              icon: const Icon(Icons.save_alt, size: 18),
              label: const Text('导出完整备份'),
            ),
            OutlinedButton.icon(
              key: const Key('import-backup'),
              onPressed: actions == null
                  ? null
                  : () => act(context, () => _import(context, actions)),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('从备份恢复'),
            ),
          ],
        ),
        FutureBuilder<Directory?>(
          future: BackupService.previousRoot(c.files.root),
          builder: (ctx, snapshot) => snapshot.data == null
              ? const SizedBox.shrink()
              : Wrap(
                  children: [
                    TextButton(
                      key: const Key('undo-restore'),
                      onPressed: actions == null
                          ? null
                          : () => act(
                              context,
                              () => _import(context, actions, undo: true),
                            ),
                      child: const Text('撤销上次恢复'),
                    ),
                    TextButton(
                      onPressed: actions == null
                          ? null
                          : () => act(context, () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('删除恢复安全副本？'),
                                  content: const Text(
                                    '只删除本设备为上次恢复保留的旧数据。当前学习数据及已导出的备份不受影响；删除后将无法撤销上次恢复。',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('取消'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('删除安全副本'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) await actions.clearUndo();
                            }),
                      child: const Text('删除恢复安全副本'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
