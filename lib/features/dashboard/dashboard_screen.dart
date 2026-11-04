import 'daily_learning.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../library/library_providers.dart';
import '../../core/ui/actions.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(appControllerProvider);
    final counts = ref.watch(studyCountsProvider);
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return ListView(
      padding: EdgeInsets.all(compact ? 20 : 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1060),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '学习',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '每一次独立思考，都在向前一步。',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            const Text('本地优先', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const DailyLearning(),
                const SizedBox(height: 24),
                if (c.allSessions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(compact ? 24 : 32),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '理解 · 尝试 · 掌握',
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '把不懂，\n变成真正会。',
                          style: TextStyle(
                            fontSize: compact ? 30 : 38,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '从一道题、一个概念开始。\n让 AI 帮你理清思路，把关键一步留给自己。',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              key: const Key('start-chat'),
                              onPressed: () => act(context, () async {
                                await c.newSession();
                                if (context.mounted) context.go('/chat');
                              }),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('开始学习对话'),
                            ),
                            FilledButton.tonalIcon(
                              key: const Key('start-practice'),
                              onPressed: () => context.go('/practice'),
                              icon: const Icon(Icons.edit_note),
                              label: const Text('主动训练'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => context.go('/mistakes'),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              label: const Text('录入错题'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (c.allSessions.isNotEmpty)
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('start-chat'),
                        onPressed: () => act(context, () async {
                          await c.newSession();
                          if (context.mounted) context.go('/chat');
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('开始学习对话'),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/mistakes'),
                        icon: const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                        label: const Text('录入错题'),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                if (compact)
                  Row(
                    children: [
                      for (final (label, value) in [
                        ('学习对话', '${c.allSessions.length}'),
                        (
                          '知识积累',
                          counts.when(
                            data: (v) => '${v.knowledge}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                        ),
                        (
                          '错题记录',
                          counts.when(
                            data: (v) => '${v.mistakes}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                        ),
                      ])
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) => Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: '学习对话',
                          value: '${c.allSessions.length}',
                          detail: c.demo ? '独立演示记录' : '此设备上保存的会话',
                          icon: Icons.forum_outlined,
                        ),
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: '知识积累',
                          value: counts.when(
                            data: (v) => '${v.knowledge}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                          detail: '保存自己的理解与方法',
                          icon: Icons.bookmarks_outlined,
                        ),
                        _info(
                          context,
                          width: compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 32) / 3,
                          label: '错题记录',
                          value: counts.when(
                            data: (v) => '${v.mistakes}',
                            loading: () => '…',
                            error: (_, _) => '—',
                          ),
                          detail: '保留原题与反思',
                          icon: Icons.menu_book_outlined,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '继续探索',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/chat'),
                      child: const Text('全部对话'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (c.allSessions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '还没有学习记录。开始第一段对话，内容会自动保存在这里。',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                else
                  ...c.allSessions
                      .take(3)
                      .map(
                        (s) => Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              leading: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 22,
                                color: colors.primary,
                              ),
                              title: Text(
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${s.updatedAt.month}月${s.updatedAt.day}日 · 点击继续学习',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward,
                                size: 18,
                              ),
                              onTap: () => act(context, () async {
                                await c.selectSession(s);
                                if (context.mounted) context.go('/chat');
                              }),
                            ),
                            const Divider(),
                          ],
                        ),
                      ),
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '学习小提示：看懂解析之后，合上答案再做一次。能独立完成，才是更可靠的掌握证据。',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _info(
    BuildContext context, {
    required double width,
    required String label,
    required String value,
    required String detail,
    required IconData icon,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 144),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: value.length < 4
                    ? 26
                    : value.length > 12
                    ? 14
                    : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
