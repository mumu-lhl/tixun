import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'practice_providers.dart';

class PracticeHistoryScreen extends ConsumerStatefulWidget {
  const PracticeHistoryScreen(this.id, {super.key});
  final String id;
  @override
  ConsumerState<PracticeHistoryScreen> createState() =>
      _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends ConsumerState<PracticeHistoryScreen> {
  final rows = <PracticeAttempt>[];
  bool busy = false, more = true;
  String? failure;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (busy || !more) return;
    setState(() => busy = true);
    try {
      final next = await ref
          .read(practiceStoreProvider)
          .history(widget.id, offset: rows.length);
      if (mounted) {
        setState(() {
          rows.addAll(next);
          more = next.length == 50;
          failure = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failure = '历史记录读取失败，请重试。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              tooltip: context.tr("返回题目"),
              onPressed: () => context.go('/practice/${widget.id}'),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                context.tr("作答历史"),
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: rows.length + 1,
          itemBuilder: (ctx, i) {
            if (i == rows.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (rows.isEmpty && !busy && failure == null)
                      Text(context.tr("还没有作答记录。")),
                    if (failure != null) Text(context.tr(failure!)),
                    if (more)
                      TextButton(
                        onPressed: busy ? null : () => act(context, _load),
                        child: Text(
                          busy ? context.tr("正在读取…") : context.tr("加载更多"),
                        ),
                      ),
                  ],
                ),
              );
            }
            final a = rows[i];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 0,
              ),
              title: Text(
                a.status == 'draft'
                    ? context.tr("未完成的作答")
                    : a.status == 'awaiting_self_grade'
                    ? context.tr("等待自主判分")
                    : a.correct == true
                    ? context.tr("作答正确")
                    : context.tr("需要订正"),
              ),
              subtitle: Text(
                context.tr("{0} · {1}{2}", [
                  a.startedAt.toLocal().toString().substring(0, 16),
                  a.gradingBasis == 'ai_reference'
                      ? context.tr("AI 参考待核对")
                      : a.gradingBasis == 'self'
                      ? context.tr("自主判分")
                      : a.gradingBasis == 'deterministic'
                      ? context.tr("已核对的规则判分")
                      : context.tr("草稿"),
                  a.hintUsed ? context.tr(" · 有提示") : '',
                ]),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/practice/${widget.id}?attempt=${a.id}'),
            );
          },
        ),
      ),
    ],
  );
}
