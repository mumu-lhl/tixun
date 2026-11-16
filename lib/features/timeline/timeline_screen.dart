import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/cached_stream_builder.dart';
import '../exams/exam_calendar.dart' show examDate, showExamDialog;
import 'timeline_store.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen>
    with WidgetsBindingObserver {
  late DateTime selected;
  late DateTime month;
  late Stream<List<TimelineEvent>> events;
  Timer? midnight;
  bool listView = false;

  @override
  void initState() {
    super.initState();
    selected = DateUtils.dateOnly(DateTime.now());
    month = DateTime(selected.year, selected.month);
    events = ref.read(appControllerProvider).timeline.watchEvents();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    midnight = Timer(
      next.difference(now) + const Duration(milliseconds: 50),
      () {
        if (!mounted) return;
        setState(() {});
        _scheduleMidnight();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _moveMonth(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    selected = DateTime(month.year, month.month);
  });

  bool _onDay(TimelineEvent event, DateTime day) {
    final date = timelineDate(day);
    return !date.isBefore(event.startDate.toUtc()) &&
        !date.isAfter((event.endDate ?? event.startDate).toUtc());
  }

  String _countdown(TimelineEvent event, DateTime now) {
    final status = timelineStatus(
      event.startDate.toUtc(),
      event.endDate?.toUtc(),
      now,
    );
    return switch (status.phase) {
      TimelinePhase.upcoming => context.l10n.timelineDaysUntil(
        '${status.days}',
      ),
      TimelinePhase.past => context.l10n.timelineDaysSince('${status.days}'),
      TimelinePhase.today => context.l10n.timelineToday,
      TimelinePhase.endsToday => context.l10n.timelineEndsToday,
      TimelinePhase.inProgress => context.l10n.timelineInProgress(
        '${status.days}',
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appControllerProvider).timeline;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 20, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      BackButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/study'),
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.timelineTitle,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const Key('timeline-add'),
                        tooltip: context.l10n.timelineAdd,
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 48, bottom: 12),
                    child: Text(
                      context.l10n.timelineHelp,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  SegmentedButton<bool>(
                    key: const Key('timeline-view'),
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
                    onSelectionChanged: (value) =>
                        setState(() => listView = value.single),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: CachedStreamBuilder<List<TimelineEvent>>(
            owner: store,
            cacheKey: 'timeline',
            stream: events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(context.l10n.timelineLoadError));
              }
              if (!snapshot.hasData) return const SizedBox.expand();
              final all = snapshot.data!;
              final today = timelineDate(DateTime.now());
              final visible = listView
                  ? [...all]
                  : all.where((event) => _onDay(event, selected)).toList();
              if (listView) {
                visible.sort((a, b) {
                  final aPast = (a.endDate ?? a.startDate).toUtc().isBefore(
                    today,
                  );
                  final bPast = (b.endDate ?? b.startDate).toUtc().isBefore(
                    today,
                  );
                  if (aPast != bPast) return aPast ? 1 : -1;
                  final order = a.startDate.compareTo(b.startDate);
                  return aPast ? -order : order;
                });
              }
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey((listView, visible.map((e) => e.id).join('|'))),
                  child: ListView.builder(
                    key: PageStorageKey(
                      listView ? 'timeline-list' : 'timeline-calendar',
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    itemCount: visible.length + 1,
                    itemBuilder: (context, index) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 850),
                        child: index == 0
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!listView) _calendar(all),
                                  if (visible.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 40,
                                      ),
                                      child: Text(
                                        all.isEmpty
                                            ? context.l10n.timelineEmpty
                                            : context.l10n.timelineEmptyDay,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : _eventCard(visible[index - 1]),
                      ),
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

  Widget _calendar(List<TimelineEvent> events) {
    final first = DateTime(month.year, month.month).weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: context.l10n.previousMonth,
              onPressed: () => _moveMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${month.year} / ${month.month}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                selected = DateUtils.dateOnly(DateTime.now());
                month = DateTime(selected.year, selected.month);
              }),
              child: Text(context.l10n.today),
            ),
            IconButton(
              tooltip: context.l10n.nextMonth,
              onPressed: () => _moveMonth(1),
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
              Expanded(child: Center(child: Text(day))),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48,
          ),
          itemCount: ((first + days + 6) ~/ 7) * 7,
          itemBuilder: (context, index) {
            final day = index - first + 1;
            if (day < 1 || day > days) return const SizedBox();
            final date = DateTime(month.year, month.month, day);
            final count = events.where((event) => _onDay(event, date)).length;
            final active = DateUtils.isSameDay(date, selected);
            return Semantics(
              label: '${examDate(date)}, $count',
              selected: active,
              child: InkWell(
                key: ValueKey('timeline-day-${examDate(date)}'),
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
                          fontWeight: active ? FontWeight.bold : null,
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
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _eventCard(TimelineEvent event) {
    final colors = Theme.of(context).colorScheme;
    final start = event.startDate.toUtc();
    final end = event.endDate?.toUtc();
    return Padding(
      key: ValueKey('timeline-event-${event.id}'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${examDate(start)}${end == null ? '' : ' — ${examDate(end)}'}',
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.timelineEdit,
                    onPressed: () => _edit(event),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: context.l10n.timelineDelete,
                    onPressed: () => _delete(event),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _countdown(event, DateTime.now()),
                key: ValueKey('timeline-countdown-${event.id}'),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (event.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(event.notes),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(TimelineEvent event) async {
    final yes = await showExamDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.timelineDelete),
        content: Text(ctx.l10n.timelineDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.delete),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await act(
        context,
        () => ref.read(appControllerProvider).timeline.delete(event.id),
      );
    }
  }

  Future<void> _edit([TimelineEvent? event]) async {
    final title = TextEditingController(text: event?.title ?? '');
    final notes = TextEditingController(text: event?.notes ?? '');
    var start =
        event?.startDate.toUtc() ??
        (listView ? DateUtils.dateOnly(DateTime.now()) : selected);
    var end = event?.endDate?.toUtc();
    String? error;
    try {
      final accepted = await showExamDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, set) {
            Future<DateTime?> pick(DateTime initial) => showDatePicker(
              context: ctx,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            return AlertDialog(
              title: Text(
                event == null ? ctx.l10n.timelineAdd : ctx.l10n.timelineEdit,
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const Key('timeline-name'),
                        controller: title,
                        autofocus: true,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: ctx.l10n.timelineName,
                          hintText: ctx.l10n.timelineNameHint,
                        ),
                      ),
                      TextField(
                        key: const Key('timeline-notes'),
                        controller: notes,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 2000,
                        decoration: InputDecoration(
                          labelText: ctx.l10n.timelineNotes,
                          hintText: ctx.l10n.timelineNotesHint,
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('timeline-start'),
                        onPressed: () async {
                          final value = await pick(start);
                          if (value != null && ctx.mounted) {
                            set(() => start = value);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          '${ctx.l10n.timelineStart}: ${examDate(start)}',
                        ),
                      ),
                      TextButton.icon(
                        key: const Key('timeline-end'),
                        onPressed: () async {
                          final value = await pick(end ?? start);
                          if (value != null && ctx.mounted) {
                            set(() => end = value);
                          }
                        },
                        icon: const Icon(Icons.date_range_outlined),
                        label: Text(
                          end == null
                              ? ctx.l10n.timelineAddEnd
                              : '${ctx.l10n.timelineEnd}: ${examDate(end!)}',
                        ),
                      ),
                      if (end != null)
                        TextButton(
                          onPressed: () => set(() => end = null),
                          child: Text(ctx.l10n.timelineRemoveEnd),
                        ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(ctx.l10n.cancel),
                ),
                FilledButton(
                  key: const Key('timeline-save'),
                  onPressed: () {
                    if (title.text.trim().isEmpty) {
                      set(() => error = ctx.l10n.timelineNameRequired);
                      return;
                    }
                    if (end != null &&
                        timelineDate(end!).isBefore(timelineDate(start))) {
                      set(() => error = ctx.l10n.timelineBadRange);
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(ctx.l10n.save),
                ),
              ],
            );
          },
        ),
      );
      if (accepted == true && mounted) {
        await act(
          context,
          () => ref
              .read(appControllerProvider)
              .timeline
              .save(
                id: event?.id,
                title: title.text,
                notes: notes.text,
                start: start,
                end: end,
              ),
        );
        if (mounted && !listView) {
          setState(() {
            selected = DateTime(start.year, start.month, start.day);
            month = DateTime(start.year, start.month);
          });
        }
      }
    } finally {
      title.dispose();
      notes.dispose();
    }
  }
}
