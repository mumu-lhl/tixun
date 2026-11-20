part of "timeline_screen.dart";

extension _TimelineEventEditor on _TimelineScreenState {
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
    final title = TextEditingController(text: event?.title ?? "");
    final notes = TextEditingController(text: event?.notes ?? "");
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
                        key: const Key("timeline-name"),
                        controller: title,
                        autofocus: true,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: ctx.l10n.timelineName,
                          hintText: ctx.l10n.timelineNameHint,
                        ),
                      ),
                      TextField(
                        key: const Key("timeline-notes"),
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
                        key: const Key("timeline-start"),
                        onPressed: () async {
                          final value = await pick(start);
                          if (value != null && ctx.mounted) {
                            set(() => start = value);
                          }
                        },
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(
                          "${ctx.l10n.timelineStart}: ${examDate(start)}",
                        ),
                      ),
                      TextButton.icon(
                        key: const Key("timeline-end"),
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
                              : "${ctx.l10n.timelineEnd}: ${examDate(end!)}",
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
                  key: const Key("timeline-save"),
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
          _selectEventDay(DateTime(start.year, start.month, start.day));
        }
      }
    } finally {
      title.dispose();
      notes.dispose();
    }
  }
}
