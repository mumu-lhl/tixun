import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../practice/practice_providers.dart';
import 'review_providers.dart';
import 'review_store.dart';

String reviewDate(DateTime value, {BuildContext? context}) {
  final d = value.toLocal();
  if (context != null && AppStrings.of(context).locale.languageCode == 'en') {
    final local = MaterialLocalizations.of(context);
    return '${local.formatShortDate(d)} ${local.formatTimeOfDay(TimeOfDay.fromDateTime(d))}';
  }
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  if (d.year == DateTime.now().year) return '${d.month}月${d.day}日 $time';
  return '${d.year}年${d.month}月${d.day}日 $time';
}

/// A due date with an overdue marker when it is in the past.
String dueLabel(BuildContext context, DateTime dueAt) {
  final now = DateTime.now();
  var text = reviewDate(dueAt, context: context);
  if (dueAt.isBefore(now)) {
    final days = now.difference(dueAt).inDays;
    text += days > 0
        ? ' · ${context.tr("已逾期 {0} 天", [days])}'
        : ' · ${context.tr("已逾期")}';
  }
  return text;
}

/// Older records retain the explanation captured at grading time.
String reviewReason(BuildContext context, String reason) {
  final match = RegExp(r'^独立做对，(\d+) 天后再次检测。$').firstMatch(reason);
  return match == null
      ? context.tr(reason)
      : context.tr('独立做对，{0} 天后再次检测。', [match[1]]);
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
    final c = ref.watch(appControllerProvider);
    final key = (filter: filter, subject: c.subjectFilter);
    final rows = ref.watch(reviewListProvider(key));
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
                    tooltip: context.tr("返回学习"),
                    onPressed: () => context.go('/study'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.tr("间隔复习"),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(context.tr("先回忆，再核对。到期任务在应用内提醒，离线也能继续。")),
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
                      label: Text(context.tr(e.value)),
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
                onPressed: () => ref.invalidate(reviewListProvider(key)),
                child: Text(context.tr("复习安排读取失败，点击重试")),
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
                                ? context.tr("当前没有到期任务。完成一次训练后，系统会根据实际作答安排复习。")
                                : context.tr("还没有此类复习安排。"),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/practice'),
                            child: Text(context.tr("去训练")),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i], s = item.schedule;
                      final colors = Theme.of(context).colorScheme;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: .5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plainTextPreview(item.question.stem),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.tr("{0} · {1} · 独立通过 {2} 次", [
                                  item.question.subject,
                                  dueLabel(context, s.dueAt),
                                  s.repetitions,
                                ]),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                    child: Text(context.tr("开始复习")),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        showReviewHistory(context, ref, item),
                                    child: Text(context.tr("调度依据与历史")),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: context.tr("调整复习"),
                                    onSelected: (v) => act(context, () async {
                                      final store = ref.read(
                                        reviewStoreProvider,
                                      );
                                      if (v == 'pause') {
                                        await store.pause(s.id, s.enabled);
                                        return;
                                      }
                                      if (v == 'reset') {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(context.tr("重置复习进度？")),
                                            content: Text(
                                              context.tr(
                                                "下一次复习安排在今天。历史作答和调度记录会保留。",
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
                                                child: Text(context.tr("重置")),
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
                                      PopupMenuItem(
                                        value: 'date',
                                        child: Text(context.tr("调整日期")),
                                      ),
                                      PopupMenuItem(
                                        value: 'reset',
                                        child: Text(context.tr("重置进度")),
                                      ),
                                      PopupMenuItem(
                                        value: 'pause',
                                        child: Text(
                                          s.enabled
                                              ? context.tr("暂停复习")
                                              : context.tr("恢复复习"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
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
          Text(context.tr("调度依据"), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            context.tr(
              "独立做对：1 天、6 天，再按当前间隔 × 2.5；错误：10 分钟后重做；用过提示或 AI 答案未核对：次日检测且不增加独立通过次数。提前重复做对保留原日期。自主判分会单独标记，阅读不计入作答。",
            ),
          ),
          const Divider(height: 28),
          if (records.isEmpty) Text(context.tr("尚未完成复习；当前日期来自手动加入。")),
          for (final r in records)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(reviewReason(context, r.reason)),
              subtitle: Text(
                '${reviewDate(r.recordedAt, context: context)} → ${reviewDate(r.nextDueAt, context: context)}',
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
        error: (_, _) => Text(context.tr("复习安排暂时无法读取。")),
        data: (item) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item == null
                    ? context.tr("需要时可加入复习。")
                    : item.schedule.enabled
                    ? context.tr("下次复习：{0}", [
                        dueLabel(context, item.schedule.dueAt),
                      ])
                    : context.tr("复习已暂停"),
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
                child: Text(
                  item == null ? context.tr("加入复习") : context.tr("查看安排"),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Plain-text preview of a question stem for list rows: strips LaTeX
/// delimiters and common Markdown markers so rows don't show raw
/// `$3x+5=20$` or `**...**`. The detail card keeps full rendering.
String plainTextPreview(String text) {
  final out = text
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
      .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m[1] ?? '')
      .replaceAll(RegExp(r'\$\$?'), '')
      .replaceAll(RegExp(r'(`{1,3}|[*_]{1,2}|~~)'), '')
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^>\s?', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'<[^>]+>'), '');
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}
