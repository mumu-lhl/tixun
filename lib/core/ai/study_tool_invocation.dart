part of "study_tools.dart";

extension _StudyToolInvocation on StudyToolRunner {
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> a,
  ) async {
    String text(String key, [String fallback = ""]) =>
        a[key] as String? ?? fallback;
    List<String> labels(List<String> fallback) =>
        a["tags"] == null ? fallback : (a["tags"] as List).cast<String>();
    switch (name) {
      case "list_subject_modules":
        final all = await store.modules.list(text("subject"));
        final matches = all
            .where(
              (m) => m.name.toLowerCase().contains(text("query").toLowerCase()),
            )
            .toList();
        return {
          "modules": matches
              .take(100)
              .map(
                (m) => {
                  "id": m.id,
                  "name": m.name,
                  "subject": m.subject,
                  "parent_id": m.parentId,
                },
              )
              .toList(),
          "truncated": matches.length > 100,
        };
      case "create_subject_module":
        final id = await store.modules.create(
          text("subject"),
          text("name"),
          parentId: a["parent_id"] as String?,
        );
        return {"id": id, "subject": text("subject"), "name": text("name")};
      case "link_study_module":
        if (!["knowledge", "mistake"].contains(text("kind"))) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidMaterialType,
            "资料类型无效。",
          );
        }
        await store.modules.link(
          text("id"),
          text("kind") == "mistake",
          text("module_id"),
        );
        return {"id": text("id"), "module_id": text("module_id")};
      case "search_knowledge":
        final rows = await store.searchKnowledge(
          query: text("query"),
          subject: text("subject"),
          moduleId: text("module_id"),
          limit: 5,
        );
        return {
          "items": rows
              .map(
                (k) => {
                  "id": k.id,
                  "title": k.title,
                  "subject": k.subject,
                  "kind": k.kind,
                  "revision": k.revision,
                  "snippet": k.content.substring(
                    0,
                    k.content.length.clamp(0, 160),
                  ),
                },
              )
              .toList(),
        };
      case "get_knowledge":
        final k = await store.knowledge(text("id"));
        return {
          "id": k.id,
          "title": k.title,
          "content": k.content.substring(0, k.content.length.clamp(0, 12000)),
          "truncated": k.content.length > 12000,
          "subject": k.subject,
          "kind": k.kind,
          "chapter": k.chapter,
          "module_ids": await store.modules.ids(k.id, false),
          "tags": await store.tags(k.id, isMistake: false),
          "revision": k.revision,
        };
      case "create_knowledge":
      case "update_knowledge":
        final old = name == "update_knowledge"
            ? await store.knowledge(text("id"))
            : null;
        if (old != null &&
            a.keys.every((k) => ["id", "expected_revision"].contains(k))) {
          throw const AppFormatException(
            AppErrorCode.errorNoFieldsToUpdateWereProvided,
            "没有提供需要修改的字段。",
          );
        }
        final row = await store.saveKnowledge(
          KnowledgeDraft(
            title: text("title", old?.title ?? ""),
            content: text("content", old?.content ?? ""),
            subject: text("subject", old?.subject ?? ""),
            kind: text("kind", old?.kind ?? "个人笔记"),
            chapter: text("chapter", old?.chapter ?? ""),
            tags: labels(
              old == null ? [] : await store.tags(old.id, isMistake: false),
            ),
          ),
          id: old?.id,
          expectedRevision: a["expected_revision"] as int?,
          sourceSessionId: sessionId,
          sourceMessageId: runId,
        );
        return {"id": row.id, "revision": row.revision, "title": row.title};
      case "delete_knowledge":
        await store.setDeleted(
          text("id"),
          isMistake: false,
          deleted: true,
          expectedRevision: a["expected_revision"] as int,
        );
        return {"id": text("id"), "recoverable": true};
      case "search_mistakes":
        final rows = await store.searchMistakes(
          query: text("query"),
          subject: text("subject"),
          moduleId: text("module_id"),
          limit: 5,
        );
        return {
          "items": rows
              .map(
                (m) => {
                  "id": m.id,
                  "title": m.title,
                  "subject": m.subject,
                  "revision": m.revision,
                  "snippet": m.question.substring(
                    0,
                    m.question.length.clamp(0, 160),
                  ),
                },
              )
              .toList(),
        };
      case "get_mistake":
        final m = await store.mistake(text("id"));
        String bound(String v) => v.substring(0, v.length.clamp(0, 4000));
        return {
          "id": m.id,
          "title": m.title,
          "question": bound(m.question),
          "subject": m.subject,
          "chapter": m.chapter,
          "module_ids": await store.modules.ids(m.id, true),
          "correct_answer": bound(m.correctAnswer),
          "original_answer": bound(m.originalAnswer),
          "own_analysis": bound(m.ownAnalysis),
          "ai_analysis": bound(m.aiAnalysis),
          "error_reason": m.errorReason,
          "suggested_reason": m.suggestedReason,
          "tags": await store.tags(m.id, isMistake: true),
          "revision": m.revision,
          "image_access": "本工具未返回图片内容。需由用户从错题详情发送图片，才能进行视觉分析。",
          "images_available": (await store.images(
            m.id,
            isMistake: true,
          )).length,
        };
      case "create_mistake":
      case "update_mistake":
        final old = name == "update_mistake"
            ? await store.mistake(text("id"))
            : null;
        if (old != null &&
            a.keys.every((k) => ["id", "expected_revision"].contains(k))) {
          throw const AppFormatException(
            AppErrorCode.errorNoFieldsToUpdateWereProvided,
            "没有提供需要修改的字段。",
          );
        }
        final row = await store.saveMistake(
          MistakeDraft(
            title: text("title", old?.title ?? ""),
            question: text("question", old?.question ?? ""),
            subject: text("subject", old?.subject ?? ""),
            chapter: text("chapter", old?.chapter ?? ""),
            correctAnswer: text("correct_answer", old?.correctAnswer ?? ""),
            originalAnswer: old?.originalAnswer ?? "",
            ownAnalysis: old?.ownAnalysis ?? "",
            aiAnalysis: text("ai_analysis", old?.aiAnalysis ?? ""),
            errorReason: old?.errorReason ?? "暂未确定",
            suggestedReason: text(
              "suggested_reason",
              old?.suggestedReason ?? "",
            ),
            tags: labels(
              old == null ? [] : await store.tags(old.id, isMistake: true),
            ),
          ),
          id: old?.id,
          expectedRevision: a["expected_revision"] as int?,
          sourceSessionId: sessionId,
          sourceMessageId: runId,
        );
        if (old == null) {
          // Only copy the images the model referenced. Without
          // image_indices the mistake gets no images: copying the whole
          // session history attached unrelated pictures to every mistake.
          final indices = a["image_indices"];
          if (indices != null) {
            if (indices is! List ||
                indices.length > 4 ||
                indices.toSet().length != indices.length ||
                indices.any(
                  (i) =>
                      i is! int ||
                      i < 0 ||
                      i >= sourceImages.length ||
                      sourceImages[i].sessionId != sessionId,
                )) {
              throw const AppFormatException(
                AppErrorCode.errorInvalidQuestionImageReference,
                "题目图片引用无效。",
              );
            }
            for (final i in indices.cast<int>()) {
              await store.copyChatImage(
                row.id,
                sourceImages[i],
                isMistake: true,
              );
            }
          }
        }
        return {"id": row.id, "title": row.title, "revision": row.revision};
      case "delete_mistake":
        await store.setDeleted(
          text("id"),
          isMistake: true,
          deleted: true,
          expectedRevision: a["expected_revision"] as int,
        );
        return {"id": text("id"), "recoverable": true};
      case "link_mistake_to_knowledge":
        await store.link(text("knowledge_id"), mistakeId: text("mistake_id"));
        return {"linked": true};
      case "schedule_review":
        final service = reviews ?? ReviewStore(db);
        try {
          final schedule = await service.enroll(text("question_id"));
          return {
            "schedule_id": schedule.id,
            "question_id": schedule.questionId,
            "due_at": schedule.dueAt.toIso8601String(),
            "scheduler": "deterministic",
          };
        } finally {
          if (reviews == null) service.dispose();
        }
      case "get_learning_progress":
        Future<int> count(String table) async =>
            (await db
                    .customSelect(
                      'SELECT count(*) AS n FROM $table WHERE deleted = 0${subjectScope == null ? '' : ' AND subject=?'}',
                      variables: subjectScope == null
                          ? const []
                          : [Variable.withString(subjectScope!)],
                    )
                    .getSingle())
                .read<int>("n");
        final chatCount = await db
            .customSelect(
              'SELECT count(*) AS n FROM chat_sessions WHERE deleted=0${subjectScope == null ? '' : ' AND subject=?'}',
              variables: subjectScope == null
                  ? const []
                  : [Variable.withString(subjectScope!)],
            )
            .getSingle();
        return {
          "knowledge_count": await count("knowledge_items"),
          "mistake_count": await count("mistakes"),
          "chat_count": chatCount.read<int>("n"),
          ...(await LearningProgress.load(db, subject: subjectScope)).toJson(),
        };
      default:
        throw const AppFormatException(AppErrorCode.errorUnknownTool, "未知工具。");
    }
  }

  Future<void> _validateSubjectScope(
    String name,
    Map<String, dynamic> args,
  ) async {
    final scope = subjectScope;
    void check(String subject) {
      if (scope != null) requireStudySubject(subject, scope);
    }

    void checkRequestedSubject() {
      if (scope == null) return;
      final requested = args["subject"] as String?;
      if (requested != null && requested.trim().isNotEmpty) check(requested);
      args["subject"] = scope;
    }

    switch (name) {
      case "search_knowledge":
      case "search_mistakes":
      case "list_subject_modules":
      case "create_subject_module":
      case "create_knowledge":
      case "create_mistake":
        checkRequestedSubject();
        return;
      case "get_knowledge":
      case "update_knowledge":
      case "delete_knowledge":
        final row = await store.knowledge(
          args["id"] as String,
          includeDeleted: true,
        );
        check(row.subject);
        if (name == "update_knowledge") {
          final requested = args["subject"] as String?;
          if (requested != null && requested.trim().isNotEmpty) {
            requireStudySubject(requested, row.subject);
          }
          args["subject"] = scope ?? row.subject;
        }
        return;
      case "get_mistake":
      case "update_mistake":
      case "delete_mistake":
        final row = await store.mistake(
          args["id"] as String,
          includeDeleted: true,
        );
        check(row.subject);
        if (name == "update_mistake") {
          final requested = args["subject"] as String?;
          if (requested != null && requested.trim().isNotEmpty) {
            requireStudySubject(requested, row.subject);
          }
          args["subject"] = scope ?? row.subject;
        }
        return;
      case "link_mistake_to_knowledge":
        final knowledge = await store.knowledge(args["knowledge_id"] as String);
        final mistake = await store.mistake(args["mistake_id"] as String);
        check(knowledge.subject);
        check(mistake.subject);
        requireStudySubject(mistake.subject, knowledge.subject);
        return;
      case "link_study_module":
        final isMistake = args["kind"] == "mistake";
        final itemSubject = isMistake
            ? (await store.mistake(args["id"] as String)).subject
            : (await store.knowledge(args["id"] as String)).subject;
        check(itemSubject);
        final module = await (db.select(
          db.subjectModules,
        )..where((m) => m.id.equals(args["module_id"] as String))).getSingle();
        check(module.subject);
        requireStudySubject(module.subject, itemSubject);
        return;
      case "schedule_review":
        if (scope == null) return;
        final question =
            await (db.select(db.practiceQuestions)
                  ..where((q) => q.id.equals(args["question_id"] as String)))
                .getSingle();
        check(question.subject);
        return;
    }
  }
}
