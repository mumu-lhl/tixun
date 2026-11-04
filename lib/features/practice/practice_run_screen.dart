import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
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
                Text(e is FormatException ? e.message : '小测读取失败。'),
                TextButton(
                  onPressed: () => act(context, () async {
                    await ref.read(practiceStoreProvider).clearRun();
                    if (context.mounted) context.go('/practice');
                  }),
                  child: const Text('结束本轮，保留记录'),
                ),
              ],
            ),
          ),
        ),
        data: (run) {
          if (run == null) {
            return Center(
              child: TextButton(
                onPressed: () => context.go('/practice'),
                child: const Text('返回题库开始小测'),
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
                    label: const Text('返回题库'),
                  ),
                  Text(
                    run.completed
                        ? '本轮小测已完成'
                        : '随机小测 · 第 ${run.index + 1} / ${run.ids.length} 题',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => act(context, () async {
                      await store.clearRun();
                      if (context.mounted) context.go('/practice');
                    }),
                    child: const Text('结束本轮'),
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
                  child: FilledButton(
                    key: const Key('next-run-question'),
                    onPressed: !graded
                        ? null
                        : () => act(context, () async {
                            await store.advanceRun(
                              expectedAttemptId: run.attempts[run.index],
                            );
                          }),
                    child: Text(
                      run.index + 1 == run.ids.length ? '完成本轮' : '下一题',
                    ),
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
                      error: (_, _) => const Text('汇总读取失败，单题记录仍保存在题库。'),
                      data: (attempts) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已保存 ${attempts.length} 次作答',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '与参考答案一致 ${attempts.where((a) => a.correct == true).length} 次 · 使用提示 ${attempts.where((a) => a.hintUsed).length} 次',
                          ),
                          Text(
                            '其中 ${attempts.where((a) => a.gradingBasis == 'ai_reference').length} 次依据待核对 AI 答案，${attempts.where((a) => a.gradingBasis == 'self').length} 次为自主判分。结果不等同于掌握程度。',
                          ),
                          const SizedBox(height: 16),
                          for (var i = 0; i < run.ids.length; i++)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('查看第 ${i + 1} 题的本次作答'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go(
                                '/practice/${run.ids[i]}?attempt=${run.attempts[i]}',
                              ),
                            ),
                        ],
                      ),
                    ),
            ],
          );
        },
      );
}
