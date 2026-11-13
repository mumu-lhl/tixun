import 'package:material_ui/material_ui.dart';
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
  bool listView = false;
  // Turning the page only moves the displayed month. The selected day is
  // kept even when it is not in the new month (the list below is then
  // empty), so "记录考试" still targets the day the user picked.
  void move(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    events = null;
  });
  @override
  Widget build(BuildContext context) {
    final store = ref.read(appControllerProvider).exams;
    events ??= store.watchEvents(month: listView ? null : month);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BackButton(
                        key: const Key('exam-calendar-back'),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/study'),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.examRecords,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('exam-add'),
                        onPressed: () => _create(
                          listView
                              ? DateUtils.dateOnly(DateTime.now())
                              : selected,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.recordExam),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<bool>(
                    key: const Key('exam-view'),
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(context.l10n.calendar),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.view_list_outlined),
                        label: Text(context.l10n.list),
                      ),
                    ],
                    selected: {listView},
                    onSelectionChanged: (value) => setState(() {
                      listView = value.single;
                      events = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ExamEvent>>(
            key: ValueKey((listView, month.year, month.month)),
            stream: events,
            builder: (context, snap) {
              final all = snap.data ?? [];
              final visible = listView
                  ? all
                  : all
                        .where(
                          (e) => DateUtils.isSameDay(e.date.toUtc(), selected),
                        )
                        .toList();
              final first = DateTime(month.year, month.month).weekday - 1;
              final days = DateUtils.getDaysInMonth(month.year, month.month);
              return ListView.builder(
                key: PageStorageKey(
                  listView ? 'exam-timeline' : 'exam-calendar',
                ),
                padding: const EdgeInsets.all(20),
                itemCount: visible.length + 1,
                itemBuilder: (context, index) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 850),
                    child: index > 0
                        ? ListTile(
                            key: ValueKey(
                              'exam-event-${visible[index - 1].id}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_note_outlined),
                            title: Text(visible[index - 1].title),
                            subtitle: Text(
                              examDate(visible[index - 1].date.toUtc()),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                context.push('/exams/${visible[index - 1].id}'),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (listView)
                                Text(
                                  context.l10n.newestExamDateFirst,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              if (!listView) ...[
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      tooltip: context.l10n.previousMonth,
                                      onPressed: () => move(-1),
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${month.year} / ${month.month}',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => setState(() {
                                        selected = DateUtils.dateOnly(
                                          DateTime.now(),
                                        );
                                        month = DateTime(
                                          selected.year,
                                          selected.month,
                                        );
                                        events = null;
                                      }),
                                      child: Text(context.l10n.today),
                                    ),
                                    IconButton(
                                      tooltip: context.l10n.nextMonth,
                                      onPressed: () => move(1),
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    for (final day in [
                                      context.l10n.mon,
                                      context.l10n.tue,
                                      context.l10n.wed,
                                      context.l10n.thu,
                                      context.l10n.fri,
                                      context.l10n.sat,
                                      context.l10n.sun,
                                    ])
                                      Expanded(
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(10),
                                            child: Text(day),
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
                                    if (day < 1 || day > days) {
                                      return const SizedBox();
                                    }
                                    final date = DateTime(
                                      month.year,
                                      month.month,
                                      day,
                                    );
                                    final count = all
                                        .where(
                                          (e) => DateUtils.isSameDay(
                                            e.date.toUtc(),
                                            date,
                                          ),
                                        )
                                        .length;
                                    final active = DateUtils.isSameDay(
                                      date,
                                      selected,
                                    );
                                    final colors = Theme.of(context)
                                        .colorScheme;
                                    return Semantics(
                                      label:
                                          '${examDate(date)}, $count ${context.l10n.exams}',
                                      selected: active,
                                      child: InkWell(
                                        onTap: () =>
                                            setState(() => selected = date),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          margin: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: active
                                                ? colors.primaryContainer
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                              if (snap.hasError)
                                Text(context.l10n.couldNotLoadExamRecords),
                              if (snap.connectionState ==
                                  ConnectionState.waiting)
                                const LinearProgressIndicator(),
                              if (visible.isEmpty && snap.hasData)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 30,
                                  ),
                                  child: Text(
                                    (listView
                                        ? context.l10n.noExamsYetSelectRecord
                                        : context.l10n.noExamsOnThisDate),
                                  ),
                                ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _create(DateTime date) async {
    final title = TextEditingController();
    var recordDate = date;
    String? error;
    try {
      final accepted = await showExamDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) {
            void submit() {
              if (title.text.trim().isEmpty || title.text.length > 120) {
                set(() => error = ctx.l10n.examNameMustBe1);
                return;
              }
              Navigator.pop(ctx, true);
            }

            return AlertDialog(
              title: Text(ctx.l10n.recordExam),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    autofocus: true,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: ctx.l10n.examName,
                      hintText: ctx.l10n.forExampleMidtermExam,
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  TextButton.icon(
                    key: const Key('exam-record-date'),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(examDate(recordDate)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: recordDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null && ctx.mounted) {
                        set(() => recordDate = picked);
                      }
                    },
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(onPressed: submit, child: Text(ctx.l10n.create)),
              ],
            );
          },
        ),
      );
      if (accepted == true && mounted) {
        await act(context, () async {
          final id = await ref
              .read(appControllerProvider)
              .exams
              .saveEvent(title: title.text, date: recordDate);
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
