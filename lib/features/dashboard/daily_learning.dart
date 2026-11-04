import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../progress/profile_editor.dart';
import '../review/review_providers.dart';

class DailyLearning extends ConsumerWidget {
  const DailyLearning({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueCountProvider),
        progress = ref.watch(progressProvider),
        profile = ref.watch(learningProfileProvider);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '今天先做什么',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            profile.when(
              data: (p) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProfileEditor(p),
                ),
                child: const Text('学习设置'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16),
          ),
          child: due.when(
            loading: () => const Text('正在读取待复习任务…'),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(dueCountProvider),
              child: const Text('复习任务读取失败，重试'),
            ),
            data: (n) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n > 0 ? '有 $n 项到期复习' : '开始一次独立检测',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  n > 0 ? '先合上答案回忆和作答，再根据反馈订正。' : '当前没有到期复习。挑一道错题重做，或检测一个知识点。',
                ),
                if (profile.value case final p?) ...[
                  const SizedBox(height: 8),
                  Text(
                    '今日预算 ${p.dailyMinutes} 分钟 · 建议先用 ${p.dailyMinutes < 15 ? p.dailyMinutes : 15} 分钟${n > 0 ? '复习到期内容' : '独立练习'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (p.examDate != null)
                    Text(
                      p.examDate!.isBefore(DateTime.now())
                          ? '目标考试日期已过，可在学习设置中调整。'
                          : '${p.exam.isEmpty ? '目标考试' : p.exam}还有 ${p.examDate!.difference(DateTime.now()).inDays + 1} 天；优先处理到期任务和已有薄弱证据。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      key: const Key('today-review'),
                      onPressed: () =>
                          context.go(n > 0 ? '/review' : '/practice'),
                      icon: Icon(
                        n > 0 ? Icons.event_repeat : Icons.edit_note,
                        size: 18,
                      ),
                      label: Text(n > 0 ? '开始复习' : '开始训练'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/review'),
                      child: const Text('复习安排'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/progress'),
                      child: const Text('学习诊断'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        progress.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const Text('训练记录暂时无法读取。'),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.total == 0
                    ? '尚无训练数据，完成作答后再判断学习进展。'
                    : '已完成 ${p.total} 次作答 · 规则评分 ${p.checked} · 自主判分 ${p.self} · AI 参考待核对 ${p.unverified}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (p.topics
                      .where((t) => t.questions >= 3 && t.correct < t.questions)
                      .firstOrNull
                  case final weak?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '建议巩固：${weak.subject} · ${weak.name}（${weak.description}）',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
