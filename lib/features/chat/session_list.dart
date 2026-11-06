import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';

class SessionList extends ConsumerWidget {
  const SessionList({this.onSelected, super.key});
  final VoidCallback? onSelected;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr("学习对话"),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: context.tr("新建会话"),
                key: const Key('new-session'),
                onPressed: () => act(context, () async {
                  await c.newSession();
                  onSelected?.call();
                }),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: TextFormField(
            initialValue: c.search,
            onChanged: c.searchSessions,
            decoration: InputDecoration(
              hintText: context.tr("搜索标题或消息"),
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        const Divider(),
        Expanded(
          child: c.sessions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      c.search.isEmpty
                          ? context.tr("还没有对话\n从一个问题开始吧")
                          : context.tr("没有找到相关对话"),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: c.sessions.length,
                  itemBuilder: (context, index) {
                    final s = c.sessions[index];
                    final active = c.selected?.id == s.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      child: Material(
                        color: active
                            ? colors.primaryContainer.withValues(alpha: .65)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.only(
                            left: 12,
                            right: 0,
                          ),
                          title: Text(
                            s.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            context.tr("{0}月{1}日 · {2}", [
                              s.updatedAt.month,
                              s.updatedAt.day,
                              s.mode == 'guided'
                                  ? context.tr("引导教学")
                                  : s.mode == 'direct'
                                  ? context.tr("直接解答")
                                  : context.tr("考试对话"),
                            ]),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          onTap: () => act(context, () async {
                            await c.selectSession(s);
                            onSelected?.call();
                          }),
                          trailing: PopupMenuButton<String>(
                            tooltip: context.tr("会话操作"),
                            onSelected: (action) =>
                                _action(context, c, s, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text(context.tr("重命名")),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.tr("删除会话")),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextButton.icon(
                onPressed: () => act(context, () => _trash(context, c)),
                icon: const Icon(Icons.restore_from_trash_outlined, size: 17),
                label: Text(context.tr("回收区"), style: TextStyle(fontSize: 12)),
              ),
              Text(
                context.tr("保存在此设备 · 不自动清空回收区"),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _action(
    BuildContext context,
    AppController c,
    ChatSession s,
    String action,
  ) async {
    if (action == 'rename') {
      final title = await editText(
        context,
        title: context.tr("重命名会话"),
        initial: s.title,
      );
      if (title != null && context.mounted) {
        await act(context, () => c.renameSession(s, title));
      }
    } else {
      await act(context, () async {
        await c.deleteSession(s);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr("会话已移入回收区")),
              action: SnackBarAction(
                label: context.tr("撤销"),
                onPressed: () => act(context, () => c.restoreSession(s)),
              ),
            ),
          );
        }
      });
    }
  }

  Future<void> _trash(BuildContext context, AppController c) async {
    final items = await c.db.trash();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(context.tr("回收区")),
          content: SizedBox(
            width: 480,
            height: 320,
            child: items.isEmpty
                ? Center(child: Text(context.tr("回收区为空")))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return ListTile(
                        title: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: context.tr("回收会话操作"),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'restore',
                              child: Text(context.tr("恢复会话")),
                            ),
                            PopupMenuItem(
                              value: 'purge',
                              child: Text(context.tr("永久删除会话")),
                            ),
                          ],
                          onSelected: (action) => act(context, () async {
                            if (action == 'restore') {
                              await c.restoreSession(item);
                            } else {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(context.tr("永久删除会话？")),
                                  content: Text(
                                    context.tr(
                                      "将永久删除“{0}”的消息、图片引用和工具执行记录。独立保存的知识、错题及训练记录仍保留，其他记录使用的图片也会保留。已导出的备份和恢复安全副本需另行管理。",
                                      [item.title],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: Text(context.tr("取消")),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(context.tr("永久删除")),
                                    ),
                                  ],
                                ),
                              );
                              if (ok != true) return;
                              final failed = await c.purgeSession(item.id);
                              if (context.mounted && failed > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        "记录已删除，{0} 个未引用图片未能清理，请检查目录权限。",
                                        [failed],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                            if (context.mounted) {
                              update(
                                () => items.removeWhere((s) => s.id == item.id),
                              );
                            }
                          }),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr("关闭")),
            ),
          ],
        ),
      ),
    );
  }
}
