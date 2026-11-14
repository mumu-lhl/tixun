import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:tixun/core/l10n/app_error.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database.dart';
import '../../core/database/database_notifier.dart';
import '../../core/visual/validation/visual_validator.dart';

/// Persistent storage for Visual DSL scenes and their links to chat
/// messages, practice questions and study records.
///
/// The store only persists the scene JSON; scene validation lives in the
/// validator slice. The only content check here is that the JSON is
/// non-empty. Every revision of a scene has one immutable snapshot row in
/// [VisualSceneRevisions], so a quiz question can reference
/// (`visualId`, `revision`) without later edits changing its figure.
class VisualStore extends DatabaseNotifier {
  VisualStore(this.db);
  final AppDatabase db;

  Future<StoredVisualScene?> get(String id) => (db.select(
    db.visualScenes,
  )..where((s) => s.id.equals(id) & s.deleted.equals(false))).getSingleOrNull();

  /// Returns the scene JSON snapshotted at [revision], or null when that
  /// revision does not exist.
  Future<String?> getRevisionSceneJson(String visualId, int revision) async {
    final row =
        await (db.select(db.visualSceneRevisions)..where(
              (r) => r.visualId.equals(visualId) & r.revision.equals(revision),
            ))
            .getSingleOrNull();
    return row?.sceneJson;
  }

  Future<StoredVisualScene> _scene(String id) async {
    final row = await get(id);
    if (row == null) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneDoesNotExist,
        '图形不存在。',
      );
    }
    return row;
  }

  /// Creates a scene, its revision-1 snapshot and the link to [messageId]
  /// in one transaction. Returns the new scene id.
  Future<String> create({
    required String sceneJson,
    required String messageId,
    String? title,
    String source = 'ai',
    String verification = 'unverified',
  }) => runOperation(() async {
    if (sceneJson.trim().isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneJsonEmpty,
        '图形场景内容不能为空。',
      );
    }
    final now = DateTime.now();
    final id = const Uuid().v4();
    await db.transaction(() async {
      await db
          .into(db.visualScenes)
          .insert(
            VisualScenesCompanion.insert(
              id: id,
              sceneJson: sceneJson,
              title: Value(title),
              verificationStatus: Value(verification),
              source: Value(source),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.visualSceneRevisions)
          .insert(
            VisualSceneRevisionsCompanion.insert(
              visualId: id,
              revision: 1,
              sceneJson: sceneJson,
              createdAt: now,
            ),
          );
      await db
          .into(db.visualMessageLinks)
          .insert(
            VisualMessageLinksCompanion.insert(
              visualId: id,
              messageId: messageId,
            ),
          );
    });
    changed();
    return id;
  });

  Future<List<StoredVisualScene>> listByMessage(String messageId) async {
    final joined = db.select(db.visualScenes).join([
      innerJoin(
        db.visualMessageLinks,
        db.visualMessageLinks.visualId.equalsExp(db.visualScenes.id),
      ),
    ]);
    joined.where(
      db.visualMessageLinks.messageId.equals(messageId) &
          db.visualScenes.deleted.equals(false),
    );
    joined.orderBy([OrderingTerm.asc(db.visualScenes.createdAt)]);
    return (await joined.get())
        .map((r) => r.readTable(db.visualScenes))
        .toList();
  }

  Future<List<StoredVisualScene>> listByQuestion(String questionId) async {
    final joined = db.select(db.visualScenes).join([
      innerJoin(
        db.visualQuestionLinks,
        db.visualQuestionLinks.visualId.equalsExp(db.visualScenes.id),
      ),
    ]);
    joined.where(
      db.visualQuestionLinks.questionId.equals(questionId) &
          db.visualScenes.deleted.equals(false),
    );
    joined.orderBy([OrderingTerm.asc(db.visualScenes.createdAt)]);
    return (await joined.get())
        .map((r) => r.readTable(db.visualScenes))
        .toList();
  }

  Future<List<StoredVisualScene>> listByStudy({
    String? knowledgeId,
    String? mistakeId,
  }) async {
    if ((knowledgeId == null) == (mistakeId == null)) {
      throw const AppFormatException(
        AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
        '请指定一条知识或一个错题。',
      );
    }
    final joined = db.select(db.visualScenes).join([
      innerJoin(
        db.visualStudyLinks,
        db.visualStudyLinks.visualId.equalsExp(db.visualScenes.id),
      ),
    ]);
    joined.where(
      (knowledgeId == null
              ? db.visualStudyLinks.knowledgeId.isNull()
              : db.visualStudyLinks.knowledgeId.equals(knowledgeId)) &
          (mistakeId == null
              ? db.visualStudyLinks.mistakeId.isNull()
              : db.visualStudyLinks.mistakeId.equals(mistakeId)) &
          db.visualScenes.deleted.equals(false),
    );
    joined.orderBy([OrderingTerm.asc(db.visualScenes.createdAt)]);
    return (await joined.get())
        .map((r) => r.readTable(db.visualScenes))
        .toList();
  }

  /// Pins a scene revision to a question: the question shows exactly
  /// this snapshot, never later edits. Re-linking the same pair moves
  /// the pin to the new revision.
  Future<void> linkToQuestion(
    String visualId,
    String questionId,
    int revision,
  ) => runOperation(() async {
    if (revision < 1) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        '图形修订号无效。',
      );
    }
    final scene = await _scene(visualId);
    if (revision > scene.revision) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneDoesNotExist,
        '图形修订不存在。',
      );
    }
    await db
        .into(db.visualQuestionLinks)
        .insertOnConflictUpdate(
          VisualQuestionLinksCompanion.insert(
            visualId: visualId,
            questionId: questionId,
            revision: Value(revision),
          ),
        );
    changed();
  });

  /// The pinned (`visualId`, `revision`) pairs for a question, oldest
  /// scene first. Render with [getRevisionSceneJson], never the live row.
  Future<List<({String visualId, int revision})>> questionVisualLinks(
    String questionId,
  ) async {
    final joined = db.select(db.visualScenes).join([
      innerJoin(
        db.visualQuestionLinks,
        db.visualQuestionLinks.visualId.equalsExp(db.visualScenes.id),
      ),
    ]);
    joined.where(db.visualQuestionLinks.questionId.equals(questionId));
    joined.orderBy([OrderingTerm.asc(db.visualScenes.createdAt)]);
    return (await joined.get())
        .map(
          (r) => (
            visualId: r.readTable(db.visualQuestionLinks).visualId,
            revision: r.readTable(db.visualQuestionLinks).revision,
          ),
        )
        .toList();
  }

  /// Links a scene to exactly one study owner: a knowledge item or a
  /// mistake. Which section the visual renders in follows its `source`:
  /// 'original' renders under the original material, 'ai' under the AI
  /// analysis, 'student' under the student's own analysis.
  Future<void> linkToStudy(
    String visualId, {
    String? knowledgeId,
    String? mistakeId,
  }) => runOperation(() async {
    if ((knowledgeId == null) == (mistakeId == null)) {
      throw const AppFormatException(
        AppErrorCode.errorVisualStudyLinkNeedsOneOwner,
        '请指定一条知识或一个错题。',
      );
    }
    await _scene(visualId);
    await db
        .into(db.visualStudyLinks)
        .insertOnConflictUpdate(
          VisualStudyLinksCompanion.insert(
            visualId: visualId,
            knowledgeId: Value(knowledgeId),
            mistakeId: Value(mistakeId),
          ),
        );
    changed();
  });

  /// Freezes the scene's current JSON for immutable quiz reference: bumps
  /// the scene revision, snapshots the current JSON at the new revision and
  /// returns the (`visualId`, `revision`) pair the question records.
  Future<({String visualId, int revision})> snapshotForQuestion(
    String visualId,
  ) => runOperation(() async {
    final result = await db.transaction(() async {
      final scene = await _scene(visualId);
      final revision = scene.revision + 1;
      final now = DateTime.now();
      await (db.update(
        db.visualScenes,
      )..where((s) => s.id.equals(visualId))).write(
        VisualScenesCompanion(revision: Value(revision), updatedAt: Value(now)),
      );
      await db
          .into(db.visualSceneRevisions)
          .insert(
            VisualSceneRevisionsCompanion.insert(
              visualId: visualId,
              revision: revision,
              sceneJson: scene.sceneJson,
              createdAt: now,
            ),
          );
      return (visualId: visualId, revision: revision);
    });
    changed();
    return result;
  });

  /// Replaces the scene JSON, bumps the revision and appends a snapshot
  /// row for the new revision. Returns the updated scene.
  Future<StoredVisualScene> revise(
    String id,
    String newSceneJson,
  ) => runOperation(() async {
    if (newSceneJson.trim().isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorVisualSceneJsonEmpty,
        '图形场景内容不能为空。',
      );
    }
    final result = await db.transaction(() async {
      final scene = await _scene(id);
      final revision = scene.revision + 1;
      final now = DateTime.now();
      // Keep the row's title / verification columns in sync with the
      // new scene JSON (the JSON is the source of truth; the caller
      // already validated it). If parsing fails here, leave the
      // columns alone rather than failing the revision.
      var titleValue = const Value<String?>.absent();
      var verificationValue = const Value<String>.absent();
      try {
        final json = jsonDecode(newSceneJson) as Map<String, dynamic>;
        final title = json['title'];
        titleValue = Value(title is String && title.isNotEmpty ? title : null);
        verificationValue = Value(validateVisualScene(json).verificationStatus);
      } catch (_) {
        // Columns stay as they were; sceneJson/revision still update.
      }
      await (db.update(db.visualScenes)..where((s) => s.id.equals(id))).write(
        VisualScenesCompanion(
          sceneJson: Value(newSceneJson),
          revision: Value(revision),
          title: titleValue,
          verificationStatus: verificationValue,
          updatedAt: Value(now),
        ),
      );
      await db
          .into(db.visualSceneRevisions)
          .insert(
            VisualSceneRevisionsCompanion.insert(
              visualId: id,
              revision: revision,
              sceneJson: newSceneJson,
              createdAt: now,
            ),
          );
      return scene.copyWith(
        sceneJson: newSceneJson,
        revision: revision,
        title: titleValue.present ? titleValue : Value(scene.title),
        verificationStatus: verificationValue.present
            ? verificationValue.value
            : scene.verificationStatus,
        updatedAt: now,
      );
    });
    changed();
    return result;
  });
}
