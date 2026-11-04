import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../review/review_providers.dart';
import '../review/review_screen.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(progressProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(progressProvider),
            child: const Text('记录读取失败，点击重试'),
          ),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/study'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回学习'),
              ),
            ),
            Text('学习诊断', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('只依据此设备上的真实记录。阅读解析不会增加掌握程度；暂不预测考试分数。'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _metric(context, '完成作答', '${p.total}'),
                _metric(context, '已核对答案的规则评分', '${p.checked}'),
                _metric(context, '自主判分', '${p.self}'),
                _metric(context, '待核对的 AI 参考评分', '${p.unverified}'),
                _metric(context, '使用过提示', '${p.hinted}'),
              ],
            ),
            const Divider(height: 40),
            Text('知识点检测证据', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            const Text(
              '每道题仅取最近一次已评分作答；以下只纳入已核对答案、未用提示的规则判分。题量少于 3 道不显示比例，反复重做同一题不扩充样本数。',
              style: TextStyle(fontSize: 12),
            ),
            if (p.topics.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('暂时没有足够的独立检测证据。可以先核对参考答案，再独立做几道不同的题。'),
              ),
            for (final t in p.topics)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${t.subject} · ${t.name}'),
                subtitle: Text(t.description),
                trailing: t.questions >= 3 && t.correct < t.questions
                    ? const Icon(Icons.priority_high)
                    : null,
              ),
            const Divider(height: 32),
            Text('已记录的错误原因', style: Theme.of(context).textTheme.titleLarge),
            if (p.errorReasons.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('还没有用户确认的错误原因。AI 的建议不会直接当作结论。'),
              ),
            for (final e in p.errorReasons.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text('${e.value} 道错题'),
              ),
            const Divider(height: 32),
            Text('最近训练', style: Theme.of(context).textTheme.titleLarge),
            if (p.recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('完成第一次训练后，这里会出现真实记录。'),
              ),
            for (final a in p.recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  a.stem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${reviewDate(a.time)} · ${a.basis == 'self'
                      ? '自主判分'
                      : a.basis == 'ai_reference'
                      ? 'AI 参考待核对'
                      : '规则评分'}${a.hint ? ' · 有提示' : ''}',
                ),
                trailing: Text(a.correct ? '正确' : '需订正'),
              ),
          ],
        ),
      );
  Widget _metric(BuildContext context, String label, String value) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
