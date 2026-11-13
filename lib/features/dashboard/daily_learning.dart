import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../progress/profile_editor.dart';
import '../review/review_providers.dart';

/// Whether [examDate] is already past, comparing calendar dates only.
/// Exam dates come from a date picker at midnight, so comparing against
/// the current time would mark the exam day itself as past from 00:00.
bool examDatePassed(DateTime examDate, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final examDay = DateTime(examDate.year, examDate.month, examDate.day);
  return examDay.isBefore(today);
}

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
                context.tr("今天先做什么"),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            profile.when(
              data: (p) => TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ProfileEditor(p),
                ),
                child: Text(context.tr("学习设置")),
              ),
              loading: () => const SizedBox.shrink(),
              // Keep a retry here instead of hiding the button: the
              // editor needs the loaded profile, and opening it with
              // defaults could overwrite real settings on save.
              error: (_, _) => TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => ref.invalidate(learningProfileProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(context.tr("重试")),
              ),
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
            loading: () => Text(context.tr("正在读取待复习任务…")),
            error: (_, _) => TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => ref.invalidate(dueCountProvider),
              child: Text(context.tr("复习任务读取失败，重试")),
            ),
            data: (n) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n > 0
                      ? context.tr("有 {0} 项到期复习", [n])
                      : context.tr("开始一次独立检测"),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  n > 0
                      ? context.tr("先合上答案回忆和作答，再根据反馈订正。")
                      : context.tr("当前没有到期复习。挑一道错题重做，或检测一个知识点。"),
                ),
                if (profile.value case final p?) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr("今日预算 {0} 分钟 · 建议先用 {1} 分钟{2}", [
                      p.dailyMinutes,
                      p.dailyMinutes < 15 ? p.dailyMinutes : 15,
                      n > 0 ? context.tr("复习到期内容") : context.tr("独立练习"),
                    ]),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (p.examDate != null)
                    Text(
                      examDatePassed(p.examDate!, DateTime.now())
                          ? context.tr("目标考试日期已过，可在学习设置中调整。")
                          : context.tr("{0}还有 {1} 天；优先处理到期任务和已有薄弱证据。", [
                              p.exam.isEmpty ? context.tr("目标考试") : p.exam,
                              p.examDate!.difference(DateTime.now()).inDays + 1,
                            ]),
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
                      label: Text(
                        n > 0 ? context.tr("开始复习") : context.tr("开始训练"),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.go('/review'),
                      child: Text(context.tr("复习安排")),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => context.go('/progress'),
                      child: Text(context.tr("学习诊断")),
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
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr("训练记录暂时无法读取。")),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => ref.invalidate(progressProvider),
                child: Text(context.tr("重试")),
              ),
            ],
          ),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.total == 0
                    ? context.tr("尚无训练数据，完成作答后再判断学习进展。")
                    : context.tr(
                        "已完成 {0} 次作答 · 规则评分 {1} · 自主判分 {2} · AI 参考待核对 {3}",
                        [p.total, p.checked, p.self, p.unverified],
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (p.topics
                      .where((t) => t.questions >= 3 && t.correct < t.questions)
                      .firstOrNull
                  case final weak?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    context.tr("建议巩固：{0} · {1}（{2}）", [
                      context.subjectName(weak.subject),
                      weak.name,
                      context.tr('最近独立检测 {0} / {1} 道正确', [
                        weak.correct,
                        weak.questions,
                      ]),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
