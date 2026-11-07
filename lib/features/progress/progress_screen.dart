import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
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
            child: Text(context.tr("记录读取失败，点击重试")),
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
                label: Text(context.tr("返回学习")),
              ),
            ),
            Text(
              context.tr("学习诊断"),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(context.tr("只依据此设备上的真实记录。阅读解析不会增加掌握程度；暂不预测考试分数。")),
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
            Text(
              context.tr("知识点检测证据"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                "每道题仅取最近一次已评分作答；以下只纳入已核对答案、未用提示的规则判分。题量少于 3 道不显示比例，反复重做同一题不扩充样本数。",
              ),
              style: TextStyle(fontSize: 12),
            ),
            if (p.topics.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(context.tr("暂时没有足够的独立检测证据。可以先核对参考答案，再独立做几道不同的题。")),
              ),
            for (final t in p.topics)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${context.subjectName(t.subject)} · ${t.name}'),
                subtitle: Text(
                  t.questions < 3
                      ? context.tr('样本不足：{0} 道独立检测题', [t.questions])
                      : context.tr('最近独立检测 {0} / {1} 道正确', [
                          t.correct,
                          t.questions,
                        ]),
                ),
                trailing: t.questions >= 3 && t.correct < t.questions
                    ? const Icon(Icons.priority_high)
                    : null,
              ),
            const Divider(height: 32),
            Text(
              context.tr("已记录的错误原因"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (p.errorReasons.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.tr("还没有用户确认的错误原因。AI 的建议不会直接当作结论。")),
              ),
            for (final e in p.errorReasons.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr(e.key)),
                trailing: Text(context.tr("{0} 道错题", [e.value])),
              ),
            const Divider(height: 32),
            Text(
              context.tr("最近训练"),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (p.recent.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(context.tr("完成第一次训练后，这里会出现真实记录。")),
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
                  context.tr("{0} · {1}{2}", [
                    reviewDate(a.time, context: context),
                    a.basis == 'self'
                        ? context.tr("自主判分")
                        : a.basis == 'ai_reference'
                        ? context.tr("AI 参考待核对")
                        : context.tr("规则评分"),
                    a.hint ? context.tr(" · 有提示") : '',
                  ]),
                ),
                trailing: Text(
                  a.correct ? context.tr("正确") : context.tr("需订正"),
                ),
              ),
          ],
        ),
      );
  Widget _metric(BuildContext context, String label, String value) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: colors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr(label),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
