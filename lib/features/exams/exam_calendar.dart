import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';

String examDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String points(double? n) => n == null
    ? '—'
    : n == n.roundToDouble()
    ? n.toInt().toString()
    : n.toString();

class ExamCalendarScreen extends ConsumerStatefulWidget {
  const ExamCalendarScreen({super.key});
  @override
  ConsumerState<ExamCalendarScreen> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<ExamCalendarScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  Stream<List<ExamEvent>>? events;
  void move(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    selected = month;
    events = null;
  });
  @override
  Widget build(BuildContext context) {
    final store = ref.read(appControllerProvider).exams;
    events ??= store.watchMonth(month);
    return StreamBuilder<List<ExamEvent>>(
      stream: events,
      builder: (context, snap) {
        final all = snap.data ?? [];
        final dayEvents = all
            .where((e) => DateUtils.isSameDay(e.date, selected))
            .toList();
        final first = DateTime(month.year, month.month).weekday - 1;
        final days = DateUtils.getDaysInMonth(month.year, month.month);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr('考试记录'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        FilledButton.icon(
                          key: const Key('exam-add'),
                          onPressed: () => _create(selected),
                          icon: const Icon(Icons.add),
                          label: Text(context.tr('记录考试')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          tooltip: context.tr('上个月'),
                          onPressed: () => move(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '${month.year} / ${month.month}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            selected = DateUtils.dateOnly(DateTime.now());
                            month = DateTime(selected.year, selected.month);
                            events = null;
                          }),
                          child: Text(context.tr('今天')),
                        ),
                        IconButton(
                          tooltip: context.tr('下个月'),
                          onPressed: () => move(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        for (final day in ['一', '二', '三', '四', '五', '六', '日'])
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(context.tr(day)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ((first + days + 6) ~/ 7) * 7,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisExtent: 48,
                          ),
                      itemBuilder: (_, i) {
                        final day = i - first + 1;
                        if (day < 1 || day > days) return const SizedBox();
                        final date = DateTime(month.year, month.month, day);
                        final count = all
                            .where((e) => DateUtils.isSameDay(e.date, date))
                            .length;
                        final active = DateUtils.isSameDay(date, selected);
                        final colors = Theme.of(context).colorScheme;
                        return Semantics(
                          label:
                              '${examDate(date)}, $count ${context.tr('场考试')}',
                          selected: active,
                          child: InkWell(
                            onTap: () => setState(() => selected = date),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: active ? colors.primaryContainer : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$day',
                                    style: TextStyle(
                                      fontWeight: active
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                  if (count > 0)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 32),
                    Text(
                      examDate(selected),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (snap.hasError) Text(context.tr('考试记录读取失败，请重新打开。')),
                    if (snap.connectionState == ConnectionState.waiting)
                      const LinearProgressIndicator(),
                    if (dayEvents.isEmpty && snap.hasData)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(context.tr('这一天还没有考试记录，点击“记录考试”开始。')),
                      ),
                    for (final event in dayEvents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.title),
                        subtitle: Text(examDate(event.date)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/exams/${event.id}'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _create(DateTime date) async {
    final title = TextEditingController();
    try {
      final accepted = await showExamDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('记录考试')),
          content: TextField(
            controller: title,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: ctx.tr('考试名称'),
              hintText: ctx.tr('例如：高三上学期期中考试'),
            ),
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.tr('取消')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.tr('创建')),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) {
        await act(context, () async {
          final id = await ref
              .read(appControllerProvider)
              .exams
              .saveEvent(title: title.text, date: date);
          if (mounted) context.push('/exams/$id');
        });
      }
    } finally {
      title.dispose();
    }
  }
}

/// Keep form controllers alive until the dialog's exit animation is finished.
Future<T?> showExamDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) async {
  final route = DialogRoute<T>(context: context, builder: builder);
  final result = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  return result;
}
