import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ui/actions.dart';
import 'review_providers.dart';
import 'review_store.dart';
import '../practice/practice_providers.dart';

String reviewDate(DateTime value) {
  final d = value.toLocal();
  return '${d.month}月${d.day}日 ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String filter = 'due';
  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(reviewListProvider(filter));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '返回学习',
                    onPressed: () => context.go('/study'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '间隔复习',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('先回忆，再核对。到期任务在应用内提醒，离线也能继续。'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in {
                    'due': '到期',
                    'all': '全部',
                    'paused': '已暂停',
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: filter == e.key,
                      onSelected: (_) => setState(() => filter = e.key),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton(
                onPressed: () => ref.invalidate(reviewListProvider(filter)),
                child: const Text('复习安排读取失败，点击重试'),
              ),
            ),
            data: (items) => items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            filter == 'due'
                                ? '当前没有到期任务。完成一次训练后，系统会根据实际作答安排复习。'
                                : '还没有此类复习安排。',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/practice'),
                            child: const Text('去训练'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (ctx, i) {
                      final item = items[i], s = item.schedule;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.question.stem,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${item.question.subject} · ${reviewDate(s.dueAt)} · 独立通过 ${s.repetitions} 次',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilledButton.tonal(
                                  key: Key('review-start-${s.id}'),
                                  onPressed: () => act(context, () async {
                                    await ref
                                        .read(appControllerProvider)
                                        .practice
                                        .begin(s.questionId, retry: true);
                                    if (context.mounted) {
                                      context.go('/practice/${s.questionId}');
                                    }
                                  }),
                                  child: const Text('开始复习'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      showReviewHistory(context, ref, item),
                                  child: const Text('调度依据与历史'),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: '调整复习',
                                  onSelected: (v) => act(context, () async {
                                    final store = ref.read(reviewStoreProvider);
                                    if (v == 'pause') {
                                      await store.pause(s.id, s.enabled);
                                      return;
                                    }
                                    if (v == 'reset') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('重置复习进度？'),
                                          content: const Text(
                                            '下一次复习安排在今天。历史作答和调度记录会保留。',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('取消'),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('重置'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await store.adjust(s.id, reset: true);
                                      }
                                      return;
                                    }
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: s.dueAt.isBefore(now)
                                          ? now
                                          : s.dueAt,
                                      firstDate: DateTime(
                                        now.year,
                                        now.month,
                                        now.day,
                                      ),
                                      lastDate: now.add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      await store.adjust(
                                        s.id,
                                        dueAt: DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          now.hour,
                                          now.minute,
                                        ),
                                      );
                                    }
                                  }),
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'date',
                                      child: Text('调整日期'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'reset',
                                      child: Text('重置进度'),
                                    ),
                                    PopupMenuItem(
                                      value: 'pause',
                                      child: Text(s.enabled ? '暂停复习' : '恢复复习'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

Future<void> showReviewHistory(
  BuildContext context,
  WidgetRef ref,
  ReviewItem item,
) async {
  final records = await ref.read(reviewStoreProvider).history(item.schedule.id);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      minChildSize: .3,
      maxChildSize: .9,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text('调度依据', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 10),
          const Text(
            '独立做对：1 天、6 天，再按当前间隔 × 2.5；错误：10 分钟后重做；用过提示或 AI 答案未核对：次日检测且不增加独立通过次数。提前重复做对保留原日期。自主判分会单独标记，阅读不计入作答。',
          ),
          const Divider(height: 28),
          if (records.isEmpty) const Text('尚未完成复习；当前日期来自手动加入。'),
          for (final r in records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.reason),
              subtitle: Text(
                '${reviewDate(r.recordedAt)} → ${reviewDate(r.nextDueAt)}',
              ),
            ),
        ],
      ),
    ),
  );
}

final questionReviewProvider = FutureProvider.autoDispose
    .family<ReviewItem?, String>((ref, id) async {
      ref.watch(practiceStoreProvider);
      final store = ref.watch(reviewStoreProvider);
      final s = await store.forQuestion(id);
      if (s == null) return null;
      final q = await (store.db.select(
        store.db.practiceQuestions,
      )..where((q) => q.id.equals(id))).getSingle();
      return ReviewItem(s, q);
    });

class QuestionReviewStatus extends ConsumerWidget {
  const QuestionReviewStatus(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(questionReviewProvider(id))
      .when(
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const Text('复习安排暂时无法读取。'),
        data: (item) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item == null
                    ? '需要时可加入复习。'
                    : item.schedule.enabled
                    ? '下次复习：${reviewDate(item.schedule.dueAt)}'
                    : '复习已暂停',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              TextButton(
                onPressed: () => act(context, () async {
                  if (item == null) {
                    await ref.read(reviewStoreProvider).enroll(id);
                  } else {
                    context.go('/review');
                  }
                }),
                child: Text(item == null ? '加入复习' : '查看安排'),
              ),
            ],
          ),
        ),
      );
}
