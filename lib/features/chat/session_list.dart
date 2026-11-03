import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
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
              const Expanded(
                child: Text(
                  '学习对话',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: '新建会话',
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
            decoration: const InputDecoration(
              hintText: '搜索标题或消息',
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
                      c.search.isEmpty ? '还没有对话\n从一个问题开始吧' : '没有找到相关对话',
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
                            '${s.updatedAt.month}月${s.updatedAt.day}日 · ${s.mode == 'guided'
                                ? '引导教学'
                                : s.mode == 'direct'
                                ? '直接解答'
                                : '考试对话'}',
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
                            tooltip: '会话操作',
                            onSelected: (action) =>
                                _action(context, c, s, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('重命名'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('删除会话'),
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
                label: const Text('回收区', style: TextStyle(fontSize: 12)),
              ),
              Text(
                '保存在此设备 · 不自动清空回收区',
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
      final title = await editText(context, title: '重命名会话', initial: s.title);
      if (title != null && context.mounted) {
        await act(context, () => c.renameSession(s, title));
      }
    } else {
      await act(context, () async {
        await c.deleteSession(s);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('会话已移入回收区'),
              action: SnackBarAction(
                label: '撤销',
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
          title: const Text('回收区'),
          content: SizedBox(
            width: 480,
            height: 320,
            child: items.isEmpty
                ? const Center(child: Text('回收区为空'))
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
                        trailing: TextButton(
                          onPressed: () => act(context, () async {
                            await c.restoreSession(item);
                            if (context.mounted) {
                              update(
                                () => items.removeWhere((s) => s.id == item.id),
                              );
                            }
                          }),
                          child: const Text('恢复'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}
