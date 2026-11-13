import 'package:tixun/core/l10n/app_error.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_notifier.dart';
import '../../core/database/attachment_cleanup.dart';
import '../../core/platform/attachment_store.dart';

const mainExamSubjects = ['语文', '数学', '英语'];
const examImageRoles = {'paper': '试卷', 'sheet': '答题卡', 'answers': '参考答案'};

class ScoreDraft {
  ScoreDraft({
    String? id,
    this.parentId,
    required this.label,
    this.earned,
    this.maximum,
    this.note = '',
  }) : id = id ?? const Uuid().v4();
  final String id;
  final String? parentId;
  final String label, note;
  final double? earned, maximum;
}

void validateScores(List<ScoreDraft> rows) {
  if (rows.length > 500) {
    throw const AppFormatException(
      AppErrorCode.errorAScoreBreakdownCanHaveAt,
      '小分表最多 500 行。',
    );
  }
  final ids = <String, ScoreDraft>{};
  for (final row in rows) {
    if (row.id.isEmpty ||
        ids.containsKey(row.id) ||
        row.label.trim().isEmpty ||
        row.label.length > 60 ||
        row.note.length > 2000) {
      throw const AppFormatException(
        AppErrorCode.errorQuestionNumbersMustBeUniqueAnd,
        '题号不能为空或重复，题号最长 60 字。',
      );
    }
    ids[row.id] = row;
    validateScore(row.earned, row.maximum);
  }
  for (final row in rows) {
    if (row.parentId != null &&
        (ids[row.parentId] == null ||
            ids[row.parentId]!.parentId != null ||
            row.parentId == row.id)) {
      throw const AppFormatException(
        AppErrorCode.errorEachSubquestionMustBelongToA,
        '小题必须关联本表中的一道大题。',
      );
    }
  }
  final labels = <String>{};
  for (final row in rows) {
    if (!labels.add('${row.parentId ?? "root"}:${row.label.trim()}')) {
      throw const AppFormatException(
        AppErrorCode.errorQuestionNumbersAtTheSameLevel,
        '同一级的题号不能重复。',
      );
    }
  }
}

void validateScore(double? score, double? maximum) {
  for (final value in [score, maximum]) {
    if (value != null && (!value.isFinite || value < 0 || value > 10000)) {
      throw const AppFormatException(
        AppErrorCode.errorScoresMustBeValidNumbersFrom,
        '分数需为 0–10000 的有效数字。',
      );
    }
  }
  if (score != null && maximum != null && score > maximum) {
    throw const AppFormatException(
      AppErrorCode.errorTheScoreCannotExceedTheMaximum,
      '得分不能超过满分。',
    );
  }
}

/// A parent with children is a heading; its points are never counted twice.
(double, double, bool) scoreTotals(List<ScoreDraft> rows) {
  final parents = rows.map((r) => r.parentId).nonNulls.toSet();
  final leaves = rows.where((r) => !parents.contains(r.id));
  return (
    leaves.fold(0.0, (s, r) => s + (r.earned ?? 0)),
    leaves.fold(0.0, (s, r) => s + (r.maximum ?? 0)),
    leaves.isNotEmpty && leaves.every((r) => r.earned != null),
  );
}

class ExamStore extends DatabaseNotifier {
  ExamStore(this.db, this.files);
  final AppDatabase db;
  final AttachmentStore files;

  Stream<List<ExamEvent>> watchEvents({DateTime? month}) {
    final query = db.select(db.examEvents)
      ..orderBy([
        (t) => OrderingTerm.desc(t.date),
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (month != null) {
      query.where(
        (t) =>
            t.date.isBiggerOrEqualValue(DateTime.utc(month.year, month.month)) &
            t.date.isSmallerThanValue(
              DateTime.utc(month.year, month.month + 1),
            ),
      );
    }
    return query.watch();
  }

  Future<String> saveEvent({
    String? id,
    required String title,
    required DateTime date,
  }) => runOperation(() async {
    if (title.trim().isEmpty || title.length > 120) {
      throw const AppFormatException(
        AppErrorCode.examNameMustBe1,
        '考试名称需为 1–120 字。',
      );
    }
    final key = id ?? const Uuid().v4();
    await db
        .into(db.examEvents)
        .insertOnConflictUpdate(
          ExamEventsCompanion.insert(
            id: key,
            title: title.trim(),
            date: DateTime.utc(date.year, date.month, date.day),
            updatedAt: DateTime.now(),
          ),
        );
    changed();
    return key;
  });

  Future<String> saveSubject({
    String? id,
    required String eventId,
    required String subject,
    double? raw,
    double? scaled,
    double? maximum,
    bool scaling = false,
    String notes = '',
  }) => runOperation(() async {
    if (subject.trim().isEmpty || subject.length > 40 || notes.length > 10000) {
      throw const AppFormatException(
        AppErrorCode.errorCheckTheLengthsOfTheSubject,
        '请检查科目名称和备注长度。',
      );
    }
    validateScore(raw, maximum);
    validateScore(scaled, null);
    final name = subject.trim();
    final key = id ?? const Uuid().v4();
    await db
        .into(db.examSubjects)
        .insertOnConflictUpdate(
          ExamSubjectsCompanion.insert(
            id: key,
            eventId: eventId,
            subject: name,
            rawScore: Value(raw),
            maximum: Value(maximum),
            usesScaling: Value(scaling && !mainExamSubjects.contains(name)),
            scaledScore: Value(
              scaling && !mainExamSubjects.contains(name) ? scaled : null,
            ),
            notes: Value(notes),
            updatedAt: DateTime.now(),
          ),
        );
    changed();
    return key;
  });

  Future<void> saveRows(
    String subjectId,
    List<ScoreDraft> rows, {
    int? expected,
  }) => runOperation(() async {
    validateScores(rows);
    await db.transaction(() async {
      final subject = await (db.select(
        db.examSubjects,
      )..where((t) => t.id.equals(subjectId))).getSingle();
      if (expected != null && subject.scoreRevision != expected) {
        throw const AppFormatException(
          AppErrorCode.errorThisRecordHasChangedReopenThe,
          '记录已更新，请重新打开小分表后编辑。',
        );
      }
      await (db.delete(
        db.examScoreRows,
      )..where((t) => t.subjectId.equals(subjectId))).go();
      for (final row in [
        ...rows.where((r) => r.parentId == null),
        ...rows.where((r) => r.parentId != null),
      ]) {
        await db
            .into(db.examScoreRows)
            .insert(
              ExamScoreRowsCompanion.insert(
                id: row.id,
                subjectId: subjectId,
                parentId: Value(row.parentId),
                position: rows.indexOf(row),
                label: row.label.trim(),
                earned: Value(row.earned),
                maximum: Value(row.maximum),
                note: Value(row.note),
              ),
            );
      }
      await (db.update(
        db.examSubjects,
      )..where((t) => t.id.equals(subjectId))).write(
        ExamSubjectsCompanion(
          updatedAt: Value(DateTime.now()),
          scoreRevision: Value(subject.scoreRevision + 1),
        ),
      );
    });
    changed();
  });

  Future<ExamAttachment> addImage(
    String subjectId,
    String role,
    String source,
  ) => runOperation(() async {
    if (!examImageRoles.containsKey(role)) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidImageCategory,
        '图片类别无效。',
      );
    }
    final image = await files.importFile(source);
    final id = const Uuid().v4();
    try {
      await db
          .into(db.examAttachments)
          .insert(
            ExamAttachmentsCompanion.insert(
              id: id,
              subjectId: subjectId,
              role: role,
              relativePath: image.path,
              mime: image.mime,
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {
      await cleanupPurgedAttachments(db, files, [image.path]);
      rethrow;
    }
    changed();
    return (await (db.select(
      db.examAttachments,
    )..where((t) => t.id.equals(id))).getSingle());
  });

  Future<void> deleteSubject(String id) => runOperation(() async {
    final images = await (db.select(
      db.examAttachments,
    )..where((t) => t.subjectId.equals(id))).get();
    await (db.delete(db.examSubjects)..where((t) => t.id.equals(id))).go();
    await cleanupPurgedAttachments(
      db,
      files,
      images.expand(
        (i) => [i.relativePath, if (i.originalPath != null) i.originalPath!],
      ),
    );
    changed();
  });

  Future<void> deleteEvent(String id) => runOperation(() async {
    final paths = await db
        .customSelect(
          'SELECT relative_path, original_path FROM exam_attachments WHERE subject_id IN (SELECT id FROM exam_subjects WHERE event_id=?)',
          variables: [Variable(id)],
        )
        .get();
    await (db.delete(db.examEvents)..where((t) => t.id.equals(id))).go();
    await cleanupPurgedAttachments(
      db,
      files,
      paths.expand(
        (r) => [
          r.read<String>('relative_path'),
          if (r.readNullable<String>('original_path') != null)
            r.read<String>('original_path'),
        ],
      ),
    );
    changed();
  });

  Future<String> replaceImage(ExamAttachment image, Uint8List bytes) =>
      runOperation(() async {
        if (bytes.length > 8 * 1024 * 1024) {
          throw const AppFormatException(
            AppErrorCode.theEditedImageExceeds8,
            '编辑副本超过 8 MB。',
          );
        }
        final (mime, extension) = AttachmentStore.identify(bytes);
        final path = 'attachments/${const Uuid().v4()}.$extension';
        String? discard;
        try {
          await db.transaction(() async {
            final row = await (db.select(
              db.examAttachments,
            )..where((t) => t.id.equals(image.id))).getSingleOrNull();
            if (row == null || row.relativePath != image.relativePath) {
              throw const AppFormatException(
                AppErrorCode.thePhotoChangedOrWas,
                '照片已更改或删除，请重新打开。',
              );
            }
            final file = files.resolve(path);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes, flush: true);
            await (db.update(
              db.examAttachments,
            )..where((t) => t.id.equals(row.id))).write(
              ExamAttachmentsCompanion(
                relativePath: Value(path),
                mime: Value(mime),
                originalPath: Value(row.originalPath ?? row.relativePath),
              ),
            );
            if (row.originalPath != null) discard = row.relativePath;
          });
        } catch (_) {
          await cleanupPurgedAttachments(db, files, [path]);
          rethrow;
        }
        if (discard != null) {
          await cleanupPurgedAttachments(db, files, [discard!]);
        }
        changed();
        return image.id;
      });

  Future<void> deleteImage(ExamAttachment image) => runOperation(() async {
    final row = await (db.select(
      db.examAttachments,
    )..where((t) => t.id.equals(image.id))).getSingleOrNull();
    if (row == null) return;
    await (db.delete(
      db.examAttachments,
    )..where((t) => t.id.equals(row.id))).go();
    await cleanupPurgedAttachments(db, files, [
      row.relativePath,
      if (row.originalPath != null) row.originalPath!,
    ]);
    changed();
  });
}
