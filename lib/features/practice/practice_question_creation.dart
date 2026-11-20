part of "practice_store.dart";

extension _PracticeQuestionCreation on PracticeStore {
  Future<String> _createQuestion(
    QuestionSpec spec, {
    String origin = "manual",
    String verification = "user_checked",
    String? sessionId,
    String? messageId,
    String? operation,
    String? mistakeId,
    List<String> knowledgeIds = const [],
    String? parentId,
    List<Attachment> sourceImages = const [],
  }) => runOperation(() async {
    spec.validate();
    if (!["manual", "ai", "template", "mistake", "recall"].contains(origin) ||
        ![
          "unverified",
          "user_checked",
          "template_checked",
        ].contains(verification) ||
        (origin == "ai" && verification != "unverified")) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidQuestionSource,
        "题目来源无效。",
      );
    }
    final id = await db.transaction(() async {
      if (operation != null) {
        final old = await (db.select(
          db.practiceQuestions,
        )..where((q) => q.sourceOperation.equals(operation))).getSingleOrNull();
        if (old != null) {
          // Same operation replayed: return the old question only when the
          // content matches. Changed content must never be silently dropped.
          String canonical(Object? value) {
            Object? sort(Object? v) {
              if (v is Map) {
                final keys = v.keys.cast<String>().toList()..sort();
                return {for (final k in keys) k: sort(v[k])};
              }
              if (v is List) return v.map(sort).toList();
              return v;
            }

            return jsonEncode(sort(value));
          }

          Map<String, dynamic> normalized(QuestionSpec s) {
            final json = s.toJson();
            json["topics"] = (List<String>.from(json["topics"] as List)
              ..sort());
            return json;
          }

          final oldOptions =
              await (db.select(db.practiceOptions)
                    ..where((o) => o.questionId.equals(old.id))
                    ..orderBy([(o) => OrderingTerm.asc(o.position)]))
                  .get();
          final oldKeys =
              await (db.select(db.practiceAnswerKeys)
                    ..where((a) => a.questionId.equals(old.id))
                    ..orderBy([(a) => OrderingTerm.asc(a.position)]))
                  .get();
          final oldAnswers = <List<String>>[];
          for (final k in oldKeys) {
            while (oldAnswers.length <= k.position) {
              oldAnswers.add([]);
            }
            oldAnswers[k.position].add(k.answer);
          }
          final oldTopics = await db
              .customSelect(
                "SELECT t.name FROM learning_topics t JOIN practice_question_topics l ON t.id=l.topic_id WHERE l.question_id=?",
                variables: [Variable(old.id)],
              )
              .get();
          final oldVisual =
              await (db.select(db.visualQuestionLinks)..where(
                    (l) =>
                        l.questionId.equals(old.id) & l.role.equals("question"),
                  ))
                  .getSingleOrNull();
          final oldSolution =
              await (db.select(db.visualQuestionLinks)..where(
                    (l) =>
                        l.questionId.equals(old.id) & l.role.equals("solution"),
                  ))
                  .getSingleOrNull();
          final oldSpec = QuestionSpec(
            kind: old.kind,
            stem: old.stem,
            subject: old.subject,
            options: {for (final o in oldOptions) o.optionId: o.content},
            answers: oldAnswers,
            explanation: old.explanation,
            hint: old.hint,
            topics: oldTopics.map((t) => t.read<String>("name")).toList(),
            absoluteTolerance: old.absoluteTolerance,
            relativeTolerance: old.relativeTolerance,
            caseSensitive: old.caseSensitive,
            timeLimitSeconds: old.timeLimitSeconds,
            visualId: oldVisual?.visualId,
            visualRevision: oldVisual?.revision,
            solutionVisualId: oldSolution?.visualId,
            solutionVisualRevision: oldSolution?.revision,
          );
          final incoming = normalized(spec);
          // An unspecified revision means "freeze at creation", not
          // "resnapshot on replay". Explicit pins must still match.
          if (spec.visualId != null && spec.visualRevision == null) {
            incoming["visual_revision"] = oldVisual?.revision;
          }
          if (spec.solutionVisualId != null &&
              spec.solutionVisualRevision == null) {
            incoming["solution_visual_revision"] = oldSolution?.revision;
          }
          final previous = normalized(oldSpec);
          for (final (sceneKey, idKey, revisionKey, link) in [
            ("question_scene", "visual_id", "visual_revision", oldVisual),
            (
              "solution_scene",
              "solution_visual_id",
              "solution_visual_revision",
              oldSolution,
            ),
          ]) {
            if (!incoming.containsKey(sceneKey) || link == null) continue;
            final json = await _visual.getRevisionSceneJson(
              link.visualId,
              link.revision,
            );
            previous.remove(idKey);
            previous.remove(revisionKey);
            previous[sceneKey] = json == null ? null : jsonDecode(json);
          }
          if (canonical(previous) != canonical(incoming)) {
            throw const AppFormatException(
              AppErrorCode.errorThisOperationAlreadyCreatedAQuestion,
              "该操作已创建过题目，内容与之前不一致，未覆盖旧题。",
            );
          }
          if (old.deleted) {
            await (db.update(db.practiceQuestions)
                  ..where((q) => q.id.equals(old.id)))
                .write(const PracticeQuestionsCompanion(deleted: Value(false)));
          }
          return old.id;
        }
      }
      if (spec.questionScene != null || spec.solutionScene != null) {
        final resolved = spec.toJson();
        for (final (sceneKey, idKey, revisionKey) in [
          ("question_scene", "visual_id", "visual_revision"),
          ("solution_scene", "solution_visual_id", "solution_visual_revision"),
        ]) {
          final json = resolved.remove(sceneKey) as Map<String, dynamic>?;
          if (json == null) continue;
          final scene = VisualScene.fromJson(json);
          if (sceneKey == "question_scene") validateAssessmentScene(scene);
          final visualId = await _visual.create(
            sceneJson: jsonEncode(json),
            source: "assessment",
          );
          resolved[idKey] = visualId;
          resolved[revisionKey] = 1;
        }
        spec = QuestionSpec.fromJson(resolved);
      }
      final id = const Uuid().v4();
      await db
          .into(db.practiceQuestions)
          .insert(
            PracticeQuestionsCompanion.insert(
              id: id,
              kind: spec.kind,
              stem: spec.stem,
              subject: spec.subject,
              origin: origin,
              explanation: Value(spec.explanation),
              hint: Value(spec.hint),
              verification: Value(verification),
              absoluteTolerance: Value(spec.absoluteTolerance),
              relativeTolerance: Value(spec.relativeTolerance),
              caseSensitive: Value(spec.caseSensitive),
              timeLimitSeconds: Value(spec.timeLimitSeconds),
              sourceSessionId: Value(sessionId),
              sourceMessageId: Value(messageId),
              sourceOperation: Value(operation),
              mistakeId: Value(mistakeId),
              parentQuestionId: Value(parentId),
              createdAt: DateTime.now(),
            ),
          );
      if (messageId != null) {
        await db
            .into(db.practiceChatLinks)
            .insert(
              PracticeChatLinksCompanion.insert(
                questionId: id,
                messageId: messageId,
              ),
            );
      }
      var position = 0;
      for (final e in spec.options.entries) {
        await db
            .into(db.practiceOptions)
            .insert(
              PracticeOptionsCompanion.insert(
                questionId: id,
                optionId: e.key,
                content: e.value,
                position: position++,
              ),
            );
      }
      for (var i = 0; i < spec.answers.length; i++) {
        for (final a in spec.answers[i]) {
          await db
              .into(db.practiceAnswerKeys)
              .insert(
                PracticeAnswerKeysCompanion.insert(
                  questionId: id,
                  position: i,
                  answer: a,
                ),
              );
        }
      }
      for (final name in spec.topics) {
        var topic =
            await (db.select(db.learningTopics)..where(
                  (t) => t.name.equals(name) & t.subject.equals(spec.subject),
                ))
                .getSingleOrNull();
        if (topic == null) {
          final tid = const Uuid().v4();
          await db
              .into(db.learningTopics)
              .insert(
                LearningTopicsCompanion.insert(
                  id: tid,
                  name: name,
                  subject: spec.subject,
                ),
              );
          topic = await (db.select(
            db.learningTopics,
          )..where((t) => t.id.equals(tid))).getSingle();
        }
        await db
            .into(db.practiceQuestionTopics)
            .insert(
              PracticeQuestionTopicsCompanion.insert(
                questionId: id,
                topicId: topic.id,
              ),
            );
      }
      for (final kid in knowledgeIds.toSet()) {
        await db
            .into(db.practiceQuestionKnowledge)
            .insert(
              PracticeQuestionKnowledgeCompanion.insert(
                questionId: id,
                knowledgeId: kid,
              ),
            );
      }
      final imageRefs = <({String path, String mime, int bytes})>[];
      if (origin == "ai") {
        imageRefs.addAll(
          sourceImages.map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      } else if (parentId != null) {
        final images = await (db.select(
          db.practiceImages,
        )..where((a) => a.questionId.equals(parentId))).get();
        imageRefs.addAll(
          images.map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      } else if (mistakeId != null) {
        final images =
            await (db.select(db.studyAttachments)
                  ..where((a) => a.mistakeId.equals(mistakeId))
                  ..orderBy([(a) => OrderingTerm.asc(a.rowId)]))
                .get();
        imageRefs.addAll(
          preferredStudyImages(images).map(
            (a) => (path: a.relativePath, mime: a.mime, bytes: a.byteLength),
          ),
        );
      }
      for (final a in imageRefs) {
        await db
            .into(db.practiceImages)
            .insert(
              PracticeImagesCompanion.insert(
                id: const Uuid().v4(),
                questionId: id,
                relativePath: a.path,
                mime: a.mime,
                byteLength: a.bytes,
              ),
            );
      }
      if (spec.visualId != null) {
        final visualId = spec.visualId!;
        final current = await _visual.get(visualId);
        if (current == null) {
          throw const AppFormatException(
            AppErrorCode.errorVisualSceneDoesNotExist,
            "图形不存在。",
          );
        }
        final json = spec.visualRevision == null
            ? current.sceneJson
            : await _visual.getRevisionSceneJson(
                visualId,
                spec.visualRevision!,
              );
        if (json == null) {
          throw const AppFormatException(
            AppErrorCode.errorVisualSceneRevisionDoesNotExist,
            "图形修订不存在。",
          );
        }
        validateQuestionVisual(
          spec,
          VisualScene.fromJson(
            (jsonDecode(json) as Map).cast<String, dynamic>(),
          ),
        );
        final revision =
            spec.visualRevision ??
            (await _visual.snapshotForQuestion(visualId)).revision;
        await _visual.linkToQuestion(visualId, id, revision);
      }
      if (spec.solutionVisualId != null) {
        final visualId = spec.solutionVisualId!;
        final revision =
            spec.solutionVisualRevision ??
            (await _visual.snapshotForQuestion(visualId)).revision;
        final json = await _visual.getRevisionSceneJson(visualId, revision);
        if (json == null) {
          throw const AppFormatException(
            AppErrorCode.errorVisualSceneRevisionDoesNotExist,
            "图形修订不存在。",
          );
        }
        VisualScene.fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
        if (visualId == spec.visualId) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "题面图与解析图必须独立保存。",
          );
        }
        await _visual.linkToQuestion(visualId, id, revision, role: "solution");
      }
      return id;
    });
    changed();
    return id;
  });
}
