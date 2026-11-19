import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/ai/chat_provider.dart' show CancelGuard;
import '../../core/database/database.dart';
import 'exam_material.dart';
import 'language_store.dart';
import 'sentence_content.dart';

class ExamMaterial {
  ExamMaterial(this.row)
    : target = ExamTarget(
        kind: ExamKind.values.byName(row.kind),
        level: SentenceLevel.values.byName(row.level),
        count: (jsonDecode(row.items) as List).length,
        profile: ExamProfile.values.firstWhere(
          (profile) => profile.id == row.profile,
        ),
        skill: SentenceSkill.values.asNameMap()[row.targetSkill],
        topic: row.topic,
      ),
      source = ExamSource.values.byName(row.source),
      verification = ExamVerification.values.byName(row.verification) {
    paper = ExamPaper.parse(
      {
        'title': row.title,
        'paragraphs': jsonDecode(row.paragraphs),
        if (target.kind == ExamKind.sentenceInsertion)
          'candidates': jsonDecode(row.candidates),
        'items': jsonDecode(row.items),
      },
      target,
      requireDistractors:
          source == ExamSource.aiGenerated && row.model != 'Mock',
    );
  }

  final LearningExamMaterialRow row;
  final ExamTarget target;
  final ExamSource source;
  final ExamVerification verification;
  late final ExamPaper paper;
}

class ExamResult {
  ExamResult(LearningExamAttemptRow row)
    : id = row.id,
      responses = (jsonDecode(row.responses) as List).cast<String>(),
      matched = row.matched,
      confidence = ExamConfidence.values.asNameMap()[row.confidence],
      disputed = (jsonDecode(row.disputedPositions) as List)
          .cast<int>()
          .toSet(),
      submittedAt = row.submittedAt;

  final String id;
  final List<String> responses;
  final int matched;
  final ExamConfidence? confidence;
  final Set<int> disputed;
  final DateTime submittedAt;
}

extension ExamLearningStore on LanguageLearningStore {
  Stream<List<LearningExamMaterialRow>> examLibrary(ExamKind kind) =>
      (db.select(db.learningExamMaterials)
            ..where(
              (row) =>
                  row.kind.equals(kind.name) &
                  row.source.equals(ExamSource.bundled.name).not() &
                  (row.model.isNull() | row.model.equals('Mock').not()),
            )
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
            ..limit(40))
          .watch();

  Future<ExamMaterial?> reusableExam(ExamTarget target) async {
    final rows =
        await (db.select(db.learningExamMaterials)
              ..where(
                (row) =>
                    row.kind.equals(target.kind.name) &
                    row.profile.equals(target.profile.id) &
                    row.source.equals(ExamSource.bundled.name).not() &
                    (row.model.isNull() | row.model.equals('Mock').not()) &
                    row.level.equals(target.level.name) &
                    row.topic.equals(target.topic.trim()) &
                    (target.skill == null
                        ? const Constant(true)
                        : row.targetSkill.equals(target.skill!.name)),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(30))
            .get();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final attempts = db.learningExamAttempts;
    for (final row in rows) {
      final material = ExamMaterial(row);
      if (material.paper.items.length != target.count) continue;
      final recent =
          await (db.selectOnly(attempts)
                ..addColumns([attempts.id])
                ..where(
                  attempts.materialId.equals(row.id) &
                      attempts.submittedAt.isBiggerOrEqualValue(cutoff),
                )
                ..limit(1))
              .getSingleOrNull();
      if (recent == null) return material;
    }
    return null;
  }

  Future<List<String>> examExclusions(ExamTarget target) async {
    final table = db.learningExamMaterials;
    final query = db.selectOnly(table)
      ..addColumns([table.title])
      ..where(table.kind.equals(target.kind.name))
      ..orderBy([OrderingTerm.desc(table.createdAt)])
      ..limit(8);
    return (await query.get()).map((row) => row.read(table.title)!).toList();
  }

  Future<SentenceSkill?> recommendedExamSkill(ExamKind kind) async {
    final material = db.learningExamMaterials;
    final attempt = db.learningExamAttempts;
    final query =
        db.select(attempt).join([
            innerJoin(material, material.id.equalsExp(attempt.materialId)),
          ])
          ..where(
            material.kind.equals(kind.name) &
                material.verification.equals(ExamVerification.aiReviewed.name) &
                attempt.hintUsed.equals(false),
          )
          ..orderBy([
            OrderingTerm.desc(attempt.submittedAt),
            OrderingTerm.desc(attempt.rowId),
          ])
          ..limit(24);
    final seen = <(String, int)>{};
    final scores = <SentenceSkill, ({int correct, int total})>{};
    for (final row in await query.get()) {
      final entry = ExamMaterial(row.readTable(material));
      final result = ExamResult(row.readTable(attempt));
      for (final (position, item) in entry.paper.items.indexed) {
        if (result.disputed.contains(position) ||
            !seen.add((entry.row.id, position))) {
          continue;
        }
        final prior = scores[item.skill] ?? (correct: 0, total: 0);
        scores[item.skill] = (
          correct:
              prior.correct +
              (item.matches(result.responses[position]) ? 1 : 0),
          total: prior.total + 1,
        );
      }
    }
    final weak =
        scores.entries
            .where(
              (entry) =>
                  entry.value.total >= 2 &&
                  entry.value.correct * 2 <= entry.value.total,
            )
            .toList()
          ..sort(
            (a, b) => (a.value.correct * b.value.total).compareTo(
              b.value.correct * a.value.total,
            ),
          );
    return weak.firstOrNull?.key;
  }

  Future<ExamMaterial> saveExamMaterial({
    required ExamTarget target,
    required ExamPaper paper,
    required ExamSource source,
    required String id,
    String? model,
    int? promptVersion,
    CancelToken? cancel,
  }) => runOperation(
    () => db.transaction(() async {
      cancel?.checkCancelled();
      if (source == ExamSource.aiGenerated &&
          (model == null ||
              model.isEmpty ||
              promptVersion == null ||
              promptVersion < 1)) {
        throw const FormatException('Missing exam generation provenance');
      }
      final validated = ExamPaper.parse(
        paper.toJson(),
        target,
        requireDistractors: source == ExamSource.aiGenerated && model != 'Mock',
      );
      final paragraphs = jsonEncode(validated.paragraphs);
      final candidates = jsonEncode(validated.candidates);
      final items = jsonEncode(
        validated.items.map((item) => item.toJson()).toList(),
      );
      final table = db.learningExamMaterials;
      final existing = await (db.select(
        table,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (existing != null) {
        if (existing.fingerprint != validated.fingerprint ||
            existing.title != validated.title ||
            existing.paragraphs != paragraphs ||
            existing.candidates != candidates ||
            existing.items != items ||
            existing.profile != target.profile.id ||
            existing.kind != target.kind.name ||
            existing.source != source.name) {
          throw const FormatException('Exam revision identifier conflict');
        }
        return ExamMaterial(existing);
      }
      final duplicate =
          await (db.selectOnly(table)
                ..addColumns([table.id])
                ..where(table.fingerprint.equals(validated.fingerprint)))
              .getSingleOrNull();
      if (duplicate != null) {
        throw const FormatException('Duplicate exam passage');
      }
      cancel?.checkCancelled();
      final row = await db
          .into(table)
          .insertReturning(
            LearningExamMaterialsCompanion.insert(
              id: id,
              fingerprint: validated.fingerprint,
              language: 'en',
              profile: target.profile.id,
              kind: target.kind.name,
              level: target.level.name,
              topic: target.topic.trim(),
              targetSkill: Value(target.skill?.name),
              title: validated.title,
              paragraphs: paragraphs,
              candidates: candidates,
              items: items,
              source: source.name,
              model: Value(model),
              promptVersion: Value(promptVersion),
              revision: 1,
              verification:
                  (source == ExamSource.bundled
                          ? ExamVerification.bundled
                          : ExamVerification.structureChecked)
                      .name,
              createdAt: DateTime.now(),
            ),
          );
      cancel?.checkCancelled();
      return ExamMaterial(row);
    }),
  );

  Future<ExamMaterial> markExamAiReviewed(
    ExamMaterial material, {
    CancelToken? cancel,
  }) => runOperation(
    () => db.transaction(() async {
      cancel?.checkCancelled();
      if (material.source != ExamSource.aiGenerated ||
          material.row.model == 'Mock') {
        throw const FormatException('Only AI exam material can be AI reviewed');
      }
      final table = db.learningExamMaterials;
      final scope = db.update(table)
        ..where(
          (row) =>
              row.id.equals(material.row.id) &
              row.revision.equals(material.row.revision) &
              row.fingerprint.equals(material.row.fingerprint),
        );
      final rows = await scope.writeReturning(
        LearningExamMaterialsCompanion(
          verification: Value(ExamVerification.aiReviewed.name),
        ),
      );
      cancel?.checkCancelled();
      return ExamMaterial(rows.single);
    }),
  );

  Stream<List<ExamResult>> examHistory(String materialId) =>
      (db.select(db.learningExamAttempts)
            ..where((row) => row.materialId.equals(materialId))
            ..orderBy([
              (row) => OrderingTerm.desc(row.submittedAt),
              (row) => OrderingTerm.desc(row.rowId),
            ])
            ..limit(15))
          .watch()
          .map((rows) => rows.map(ExamResult.new).toList());

  Future<ExamResult> submitExam({
    required ExamMaterial material,
    required String attemptId,
    required List<String> responses,
    required ExamConfidence? confidence,
    required bool hintUsed,
  }) => runOperation(
    () => db.transaction(() async {
      final paper = material.paper;
      if (responses.length != paper.items.length ||
          responses.indexed.any(
            (entry) =>
                entry.$2.trim().isEmpty ||
                entry.$2.length > 100 ||
                paper.optionsFor(entry.$1).isNotEmpty &&
                    !paper.optionsFor(entry.$1).containsKey(entry.$2),
          ) ||
          (material.target.kind == ExamKind.sentenceInsertion &&
              responses.toSet().length != responses.length)) {
        throw const FormatException('Invalid exam submission');
      }
      final table = db.learningExamAttempts;
      final old = await (db.select(
        table,
      )..where((row) => row.id.equals(attemptId))).getSingleOrNull();
      final encoded = jsonEncode(responses);
      if (old != null) {
        if (old.materialId != material.row.id ||
            old.responses != encoded ||
            old.confidence != confidence?.name ||
            old.hintUsed != hintUsed) {
          throw const FormatException('Exam submission identifier conflict');
        }
        return ExamResult(old);
      }
      final row = await db
          .into(table)
          .insertReturning(
            LearningExamAttemptsCompanion.insert(
              id: attemptId,
              materialId: material.row.id,
              responses: encoded,
              confidence: Value(confidence?.name),
              hintUsed: hintUsed,
              matched: responses.indexed
                  .where((entry) => paper.items[entry.$1].matches(entry.$2))
                  .length,
              submittedAt: DateTime.now(),
            ),
          );
      return ExamResult(row);
    }),
  );

  Future<ExamResult> flagExamResponse(ExamResult result, int position) =>
      runOperation(
        () => db.transaction(() async {
          final table = db.learningExamAttempts;
          final row = await (db.select(
            table,
          )..where((row) => row.id.equals(result.id))).getSingle();
          final current = ExamResult(row);
          if (position < 0 || position >= current.responses.length) {
            throw const FormatException('Invalid disputed position');
          }
          final positions = {...current.disputed, position}.toList()..sort();
          final updated =
              await (db.update(
                table,
              )..where((row) => row.id.equals(result.id))).writeReturning(
                LearningExamAttemptsCompanion(
                  disputedPositions: Value(jsonEncode(positions)),
                ),
              );
          return ExamResult(updated.single);
        }),
      );

  String newExamAttemptId() => const Uuid().v4();
}
