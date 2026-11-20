import "package:drift/drift.dart";
import "package:uuid/uuid.dart";

import "../../core/database/database.dart";
import "../../core/database/database_notifier.dart";

DateTime timelineDate(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

enum TimelinePhase { upcoming, today, inProgress, endsToday, past }

/// Calculate in calendar days, independent of daylight-saving transitions.
({TimelinePhase phase, int days}) timelineStatus(
  DateTime start,
  DateTime? end,
  DateTime now,
) {
  final today = timelineDate(now);
  final first = timelineDate(start);
  final last = timelineDate(end ?? start);
  if (today.isBefore(first)) {
    return (
      phase: TimelinePhase.upcoming,
      days: first.difference(today).inDays,
    );
  }
  if (today.isAfter(last)) {
    return (phase: TimelinePhase.past, days: today.difference(last).inDays);
  }
  if (first == last) return (phase: TimelinePhase.today, days: 0);
  final left = last.difference(today).inDays;
  return (
    phase: left == 0 ? TimelinePhase.endsToday : TimelinePhase.inProgress,
    days: left,
  );
}

class TimelineStore extends DatabaseNotifier {
  TimelineStore(this.db);
  final AppDatabase db;

  Stream<List<TimelineEvent>> watchEvents() =>
      (db.select(db.timelineEvents)..orderBy([
            (t) => OrderingTerm.asc(t.startDate),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch();

  Future<String> save({
    String? id,
    required String title,
    required DateTime start,
    DateTime? end,
    String notes = "",
  }) => runOperation(() async {
    final startDate = timelineDate(start);
    final endDate = end == null ? null : timelineDate(end);
    if (title.trim().isEmpty ||
        title.length > 120 ||
        notes.length > 2000 ||
        (endDate != null && endDate.isBefore(startDate))) {
      throw const FormatException("Invalid timeline event");
    }
    final key = id ?? const Uuid().v4();
    await db
        .into(db.timelineEvents)
        .insertOnConflictUpdate(
          TimelineEventsCompanion.insert(
            id: key,
            title: title.trim(),
            startDate: startDate,
            endDate: Value(endDate),
            notes: Value(notes.trim()),
            updatedAt: DateTime.now(),
          ),
        );
    changed();
    return key;
  });

  Future<void> delete(String id) => runOperation(() async {
    await (db.delete(db.timelineEvents)..where((t) => t.id.equals(id))).go();
    changed();
  });
}
