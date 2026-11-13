import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';
import 'practice_run.dart';
import 'question_card.dart';

final practiceRunProvider = FutureProvider<PracticeRun?>(
  (ref) => ref.watch(practiceStoreProvider).loadRun(),
);
final runAttemptsProvider = FutureProvider.autoDispose
    .family<List<PracticeAttempt>, String>((ref, key) {
      final db = ref.watch(practiceStoreProvider).db;
      return (db.select(
        db.practiceAttempts,
      )..where((a) => a.id.isIn(key.split('|')))).get();
    });

class PracticeRunScreen extends ConsumerWidget {
  const PracticeRunScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(practiceRunProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e is FormatException ? e.message : context.tr("小测读取失败。")),
                TextButton(
                  onPressed: () => act(context, () async {
                    await ref.read(practiceStoreProvider).clearRun();
                    if (context.mounted) context.go('/practice');
                  }),
                  child: Text(context.tr("结束本轮，保留记录")),
                ),
              ],
            ),
          ),
        ),
        data: (run) {
          if (run == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr("还没有进行中的小测。先在题库开始一轮随机小测，完成后可在此查看汇总。"),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/practice'),
                      child: Text(context.tr("返回题库开始小测")),
                    ),
                  ],
                ),
              ),
            );
          }
          final store = ref.read(practiceStoreProvider);
          final graded =
              run.completed ||
              ref
                      .watch(runAttemptsProvider(run.attempts[run.index]!))
                      .value
                      ?.singleOrNull
                      ?.status ==
                  'graded';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => context.go('/practice'),
                    icon: const Icon(Icons.arrow_back),
                    label: Text(context.tr("返回题库")),
                  ),
                  Text(
                    run.completed
                        ? context.tr("本轮小测已完成")
                        : context.tr("随机小测 · 第 {0} / {1} 题", [
                            run.index + 1,
                            run.ids.length,
                          ]),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => act(context, () async {
                      await store.clearRun();
                      if (context.mounted) context.go('/practice');
                    }),
                    child: Text(context.tr("结束本轮")),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!run.completed) ...[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: QuestionCard(
                      run.ids[run.index],
                      attemptId: run.attempts[run.index],
                      key: ValueKey(run.attempts[run.index]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton(
                        key: const Key('next-run-question'),
                        onPressed: !graded
                            ? null
                            : () => act(context, () async {
                                await store.advanceRun(
                                  expectedAttemptId: run.attempts[run.index],
                                );
                              }),
                        child: Text(
                          run.index + 1 == run.ids.length
                              ? context.tr("完成本轮")
                              : context.tr("下一题"),
                        ),
                      ),
                      if (!graded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            context.tr("提交答案或自主判分后可继续下一题"),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else
                ref
                    .watch(
                      runAttemptsProvider(
                        run.attempts.whereType<String>().join('|'),
                      ),
                    )
                    .when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(context.tr("汇总读取失败，单题记录仍保存在题库。")),
                      data: (attempts) {
                        final colors = Theme.of(context).colorScheme;
                        final byId = {for (final a in attempts) a.id: a};
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr("已保存 {0} 次作答", [attempts.length]),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.tr("与参考答案一致 {0} 次 · 使用提示 {1} 次", [
                                attempts.where((a) => a.correct == true).length,
                                attempts.where((a) => a.hintUsed).length,
                              ]),
                            ),
                            Text(
                              context.tr(
                                "其中 {0} 次依据待核对 AI 答案，{1} 次为自主判分。结果不等同于掌握程度。",
                                [
                                  attempts
                                      .where(
                                        (a) => a.gradingBasis == 'ai_reference',
                                      )
                                      .length,
                                  attempts
                                      .where((a) => a.gradingBasis == 'self')
                                      .length,
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(run.ids.length, (i) {
                              final attemptId = run.attempts[i];
                              final attempt = attemptId == null
                                  ? null
                                  : byId[attemptId];
                              final outcome = attempt == null
                                  ? null
                                  : attempt.status == 'graded'
                                  ? (attempt.correct == true
                                        ? 'correct'
                                        : 'wrong')
                                  : 'pending';
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  outcome == 'correct'
                                      ? Icons.check_circle
                                      : outcome == 'wrong'
                                      ? Icons.cancel
                                      : Icons.help_outline,
                                  color: outcome == 'correct'
                                      ? colors.primary
                                      : outcome == 'wrong'
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                                ),
                                title: Text(
                                  context.tr("查看第 {0} 题的本次作答", [i + 1]),
                                ),
                                subtitle: outcome == null
                                    ? null
                                    : Text(
                                        outcome == 'correct'
                                            ? context.tr("作答正确")
                                            : outcome == 'wrong'
                                            ? context.tr("需要订正")
                                            : context.tr("尚未判分"),
                                      ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.go(
                                  '/practice/${run.ids[i]}?attempt=${run.attempts[i]}',
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
            ],
          );
        },
      );
}
