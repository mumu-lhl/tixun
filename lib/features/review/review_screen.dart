import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
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
  if (context != null && context.l10n.localeName == 'en') {
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
        ? ' · ${context.l10n.overdueByDays(l10nArgument((days)))}'
        : ' · ${context.l10n.overdue}';
  }
  return text;
}

/// Older records retain the explanation captured at grading time.
String reviewReason(BuildContext context, String reason) {
  final match = RegExp(r'^独立做对，(\d+) 天后再次检测。$').firstMatch(reason);
  if (match != null) {
    return context.l10n.answeredIndependentlyReviewAgainIn(match[1]!);
  }
  // Historic records store Chinese text. Translate only known app-generated
  // reasons; preserve unknown or user-supplied data verbatim.
  return switch (reason) {
    '本次需要订正，10 分钟后再尝试。' => context.l10n.reviewThisAnswerAndTry,
    '使用了提示，明天再独立检测。' => context.l10n.aHintWasUsedTry,
    '参考答案尚未核对，明天再检测；不增加独立掌握次数。' => context.l10n.theReferenceAnswerIsUnchecked,
    '用户重置复习进度；历史作答仍保留。' => context.l10n.reviewResetReason,
    '用户手动调整复习日期。' => context.l10n.reviewDateAdjustedReason,
    _ => reason,
  };
}

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});
  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  String filter = 'due';
  int limit = 200;
  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final key = (filter: filter, subject: c.subjectFilter, limit: limit);
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
                    tooltip: context.l10n.backToStudy,
                    onPressed: () => context.go('/study'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.l10n.spacedReview,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(context.l10n.recallFirstThenCheckDue),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in {
                    'due': context.l10n.reviewFilterDue,
                    'all': context.l10n.all,
                    'paused': context.l10n.reviewFilterPaused,
                  }.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: filter == e.key,
                      onSelected: (_) => setState(() {
                        filter = e.key;
                        limit = 200;
                      }),
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
                child: Text(context.l10n.couldNotReadReviewsTap),
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
                                ? context.l10n.nothingIsDueAfterPractice
                                : context.l10n.noReviewsInThisCategory,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/practice'),
                            child: Text(context.l10n.practiceNow),
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
                    itemCount: items.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == items.length) {
                        // A full page may hide later-due reviews, which
                        // have no search to reach them otherwise.
                        if (items.length < limit) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: TextButton(
                              onPressed: () => setState(() => limit += 200),
                              child: Text(context.l10n.loadMore),
                            ),
                          ),
                        );
                      }
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
                                context.l10n.independentPasses(
                                  l10nArgument((item.question.subject)),
                                  l10nArgument((dueLabel(context, s.dueAt))),
                                  l10nArgument((s.repetitions)),
                                ),
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
                                    child: Text(context.l10n.startReview),
                                  ),
                                  TextButton(
                                    onPressed: () => act(
                                      context,
                                      () =>
                                          showReviewHistory(context, ref, item),
                                    ),
                                    child: Text(
                                      context.l10n.schedulingBasisAndHistory,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    popUpAnimationStyle: menuAnimation(context),
                                    tooltip: context.l10n.adjustReview,
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
                                            title: Text(
                                              context.l10n.resetReviewProgress,
                                            ),
                                            content: Text(
                                              context.l10n.theNextReviewWillBe,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text(
                                                  context.l10n.cancel,
                                                ),
                                              ),
                                              FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text(context.l10n.reset),
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
                                        child: Text(context.l10n.adjustDate),
                                      ),
                                      PopupMenuItem(
                                        value: 'reset',
                                        child: Text(context.l10n.resetProgress),
                                      ),
                                      PopupMenuItem(
                                        value: 'pause',
                                        child: Text(
                                          s.enabled
                                              ? context.l10n.pauseReviews
                                              : context.l10n.resumeReviews,
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
          Text(
            context.l10n.schedulingBasis,
            style: Theme.of(ctx).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(context.l10n.independentCorrectAnswers1Day),
          const Divider(height: 28),
          if (records.isEmpty) Text(context.l10n.noCompletedReviewYetThe),
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
        error: (_, _) =>
            Text(context.l10n.reviewScheduleIsTemporarilyUnavailable),
        data: (item) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item == null
                    ? context.l10n.addToReviewsWhenNeeded
                    : item.schedule.enabled
                    ? context.l10n.nextReview(
                        l10nArgument((dueLabel(context, item.schedule.dueAt))),
                      )
                    : context.l10n.reviewsPaused,
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
                  item == null
                      ? context.l10n.addToReviews
                      : context.l10n.viewSchedule,
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
