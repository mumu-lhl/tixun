part of "database.dart";

extension _DatabaseMigrations on AppDatabase {
  Future<void> _createA2uiIndexes() async {
    await customStatement(
      "CREATE INDEX chat_a2ui_message ON chat_a2ui_surfaces(message_id)",
    );
    await customStatement(
      "CREATE INDEX chat_a2ui_action_revision ON chat_a2ui_actions(session_id, surface_id)",
    );
  }

  MigrationStrategy get _migrationStrategy => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createStudyIndexes();
      await _createPracticeIndexes();
      await _createReviewIndexes();
      await _createPracticeLinkIndex();
      await _createModuleIndexes();
      await _createExamIndexes();
      await _createLanguageExamIndexes();
      await _createLanguageQuickSearch();
      await _createTimelineIndex();
      await _createVisualIndexes();
      await _createA2uiIndexes();
      await customStatement(
        "CREATE INDEX learning_due ON learning_review_schedules(due_at)",
      );
      await customStatement(
        "CREATE INDEX ai_usage_occurred ON ai_usage_events(occurred_at)",
      );
      await customStatement(
        "CREATE INDEX ai_usage_action ON ai_usage_events(action_id)",
      );
      await customStatement(
        "CREATE INDEX messages_session_time ON chat_messages(session_id, created_at)",
      );
      await customStatement(
        "CREATE INDEX attachments_message ON attachments(message_id)",
      );
      await customStatement(
        "CREATE VIRTUAL TABLE message_search USING fts5(content, session_id UNINDEXED, content='chat_messages', content_rowid='rowid', tokenize='trigram')",
      );
      await customStatement(
        "CREATE TRIGGER messages_ai AFTER INSERT ON chat_messages BEGIN INSERT INTO message_search(rowid, content, session_id) VALUES (new.rowid, new.content, new.session_id); END",
      );
      await customStatement(
        "CREATE TRIGGER messages_ad AFTER DELETE ON chat_messages BEGIN INSERT INTO message_search(message_search, rowid, content, session_id) VALUES ('delete', old.rowid, old.content, old.session_id); END",
      );
      await customStatement(
        "CREATE TRIGGER messages_au AFTER UPDATE ON chat_messages BEGIN INSERT INTO message_search(message_search, rowid, content, session_id) VALUES ('delete', old.rowid, old.content, old.session_id); INSERT INTO message_search(rowid, content, session_id) VALUES (new.rowid, new.content, new.session_id); END",
      );
    },
    onUpgrade: (m, from, to) async {
      if (from >= 25 && from < 33) {
        await m.addColumn(languageQuickLookups, languageQuickLookups.deletedAt);
      }
      if (from >= 22 && from < 32) {
        await m.addColumn(
          learningLexicalSenses,
          learningLexicalSenses.deletedAt,
        );
      }
      if (from >= 22 && from < 31) {
        await m.addColumn(learningEvidence, learningEvidence.recallKind);
        await m.addColumn(
          learningReviewSchedules,
          learningReviewSchedules.fsrsVersion,
        );
        await m.addColumn(
          learningReviewSchedules,
          learningReviewSchedules.stability,
        );
        await m.addColumn(
          learningReviewSchedules,
          learningReviewSchedules.difficulty,
        );
      }
      if (from < 30) {
        await m.createTable(languagePromptSnapshots);
        await m.createTable(languageGenerationTasks);
        await m.createTable(languageGenerationRuns);
        await m.createTable(languageGenerationChoices);
        await m.createTable(languageGenerationLinks);
        if (from >= 22) {
          await m.addColumn(learningEvidence, learningEvidence.generationRunId);
        }
        if (from >= 25) {
          await m.addColumn(
            languageQuickLookups,
            languageQuickLookups.promptSnapshotId,
          );
        }
      }
      if (from < 29) {
        await m.createTable(chatA2uiSurfaces);
        await m.createTable(chatA2uiActions);
        await _createA2uiIndexes();
      }
      if (from < 25) {
        await m.createTable(languageQuickActions);
        await m.createTable(languageQuickLookups);
        await _createLanguageQuickSearch();
      }
      if (from < 24) await m.createTable(learningWritingTasks);
      if (from < 23) {
        await m.createTable(learningExamMaterials);
        await m.createTable(learningExamAttempts);
        await _createLanguageExamIndexes();
      }
      if (from >= 23 && from < 26) {
        await m.addColumn(
          learningExamMaterials,
          learningExamMaterials.reviewIssue,
        );
        await m.addColumn(
          learningExamAttempts,
          learningExamAttempts.reviewedAtSubmission,
        );
      }
      if (from < 21) await m.createTable(chatContextEvents);
      if (from < 27) await m.createTable(learningLexicalForms);
      if (from >= 22 && from < 27) {
        await m.addColumn(learningEvidence, learningEvidence.formId);
      }
      if (from < 22) {
        for (final table in <TableInfo>[
          learningLexicalItems,
          learningLexicalSenses,
          learningVocabularyGroups,
          learningGroupItems,
          learningEvidence,
          learningReviewSchedules,
          learningSentenceBatches,
          learningSentenceAttempts,
          learningInlineExplanations,
          learningWritingDrafts,
          learningWritingVersions,
          learningWritingEvaluations,
          learningWritingNotes,
        ]) {
          await m.createTable(table);
        }
        await customStatement(
          "CREATE INDEX learning_due ON learning_review_schedules(due_at)",
        );
      }
      if (from >= 14 && from < 20) {
        await m.addColumn(aiUsageEvents, aiUsageEvents.tokenBreakdownJson);
      }
      if (from < 19) {
        await m.createTable(timelineEvents);
        await _createTimelineIndex();
      }
      if (from < 2) {
        await m.addColumn(chatSessions, chatSessions.toolsEnabled);
        await m.addColumn(providerConfigs, providerConfigs.supportsTools);
        await customStatement(
          "UPDATE provider_configs SET supports_tools = 0 WHERE kind <> 'deepseek'",
        );
        for (final table in <TableInfo>[
          knowledgeItems,
          knowledgeRevisions,
          mistakes,
          knowledgeTags,
          mistakeTags,
          knowledgeRelations,
          mistakeKnowledgeLinks,
          studyAttachments,
          aiToolOperations,
          studyChatLinks,
        ]) {
          await m.createTable(table);
        }
        await _createStudyIndexes();
      }
      if (from < 3) {
        for (final table in <TableInfo>[
          learningTopics,
          practiceQuestions,
          practiceOptions,
          practiceAnswerKeys,
          practiceQuestionTopics,
          practiceQuestionKnowledge,
          practiceAttempts,
          practiceResponses,
          practiceImages,
        ]) {
          await m.createTable(table);
        }
        await _createPracticeIndexes();
      }
      if (from < 4) {
        await customStatement("DROP INDEX IF EXISTS tool_write_dedup");
        await customStatement(
          "CREATE UNIQUE INDEX tool_write_dedup ON ai_tool_operations(run_id,name,arguments) WHERE name IN ('create_knowledge','update_knowledge','delete_knowledge','create_mistake','update_mistake','delete_mistake','link_mistake_to_knowledge','schedule_review') AND status IN ('pending','running','succeeded')",
        );
        await m.createTable(reviewSchedules);
        await m.createTable(reviewRecords);
        await _createReviewIndexes();
      }
      if (from < 5) {
        await m.addColumn(attachments, attachments.originalPath);
        await m.createTable(practiceChatLinks);
        await _createPracticeLinkIndex();
        await customStatement(
          "INSERT INTO practice_chat_links(question_id,message_id) SELECT id,source_message_id FROM practice_questions WHERE source_message_id IS NOT NULL",
        );
      }
      if (from < 6) {
        await m.addColumn(chatMessages, chatMessages.reasoningContent);
      }
      if (from < 7) {
        await m.addColumn(chatSessions, chatSessions.subject);
        // Backfill from the '<subject> · ' title prefix; anything else
        // stays unclassified (null) and only shows under "全部".
        await customStatement(
          "UPDATE chat_sessions SET subject = CASE "
          "WHEN title LIKE '语文 · %' THEN '语文' "
          "WHEN title LIKE '数学 · %' THEN '数学' "
          "WHEN title LIKE '英语 · %' THEN '英语' "
          "WHEN title LIKE '物理 · %' THEN '物理' "
          "WHEN title LIKE '化学 · %' THEN '化学' "
          "WHEN title LIKE '生物 · %' THEN '生物' "
          "WHEN title LIKE '历史 · %' THEN '历史' "
          "WHEN title LIKE '地理 · %' THEN '地理' "
          "WHEN title LIKE '政治 · %' THEN '政治' "
          "ELSE NULL END",
        );
      }
      if (from < 13) {
        await m.addColumn(chatSessions, chatSessions.contextSummary);
        await m.addColumn(chatSessions, chatSessions.contextSummaryUpToId);
      }
      if (from < 14) {
        await m.createTable(aiUsageEvents);
        await m.createTable(aiModelPrices);
        await customStatement(
          "INSERT INTO ai_usage_events (id,action_id,session_id,message_id,provider_kind,endpoint,model,feature,status,usage_source,occurred_at,total_tokens,cost_basis) SELECT 'legacy:' || id,id,session_id,id,'unknown','',COALESCE(model,'unknown'),'chat',status,'legacy_total',created_at,total_tokens,'unknown' FROM chat_messages WHERE role='assistant' AND total_tokens IS NOT NULL",
        );
        await customStatement(
          "CREATE INDEX ai_usage_occurred ON ai_usage_events(occurred_at)",
        );
        await customStatement(
          "CREATE INDEX ai_usage_action ON ai_usage_events(action_id)",
        );
      }
      if (from >= 14 && from < 15) {
        await m.addColumn(aiModelPrices, aiModelPrices.offPeakDiscountPercent);
        // Built-in DeepSeek rows hold peak rates. Existing user-edited rows
        // stay peak-only until the user opts into an off-peak discount.
        await customStatement(
          "UPDATE ai_model_prices SET off_peak_discount_percent = 50 WHERE source = 'deepseek_official_peak'",
        );
      }
      if (from < 16) {
        for (final table in <TableInfo>[
          visualScenes,
          visualSceneRevisions,
          visualMessageLinks,
          visualQuestionLinks,
          visualStudyLinks,
        ]) {
          await m.createTable(table);
        }
        await _createVisualIndexes();
      }
      if (from >= 16 && from < 17) {
        // Question links gain the pinned snapshot revision (v17): the
        // table was created by v16 without it, so only existing v16
        // databases need the column added.
        await m.addColumn(visualQuestionLinks, visualQuestionLinks.revision);
      }
      if (from >= 16 && from < 18) {
        // Existing pins remain question figures; solutions get separate pins.
        await m.addColumn(visualQuestionLinks, visualQuestionLinks.role);
      }
      if (from >= 9 && from < 12) {
        await m.addColumn(examAttachments, examAttachments.originalPath);
      }
      if (from < 11) {
        await m.addColumn(providerConfigs, providerConfigs.reasoningLevels);
        // Before v11 the ChatGPT UI's "max" was an alias for xhigh. Preserve
        // existing request behavior while making new max a distinct API level.
        await customStatement(
          "UPDATE preferences SET value='xhigh' WHERE name GLOB 'ai_reasoning:*' AND value='max' AND EXISTS(SELECT 1 FROM provider_configs WHERE id=1 AND kind='chatgpt')",
        );
        await customStatement(
          "UPDATE provider_configs SET effort='xhigh' WHERE kind='chatgpt' AND effort='max'",
        );
      }
      if (from < 10) {
        for (final table in <TableInfo>[
          subjectModules,
          knowledgeModuleLinks,
          mistakeModuleLinks,
        ]) {
          await m.createTable(table);
        }
        await _createModuleIndexes();
      }
      if (from < 9) {
        for (final table in <TableInfo>[
          examEvents,
          examSubjects,
          examScoreRows,
          examAttachments,
        ]) {
          await m.createTable(table);
        }
        await _createExamIndexes();
      }
      if (from < 25) await m.createTable(languageQuickLearningLinks);
      if (from < 28) {
        await m.createTable(learningWrittenExams);
        await m.createTable(learningWrittenExamSections);
        await m.createTable(learningCourseAttempts);
      }
      if (from < 8) {
        await m.addColumn(chatMessages, chatMessages.reasoningTrace);
        await m.createTable(scratchpads);
      }
    },
    beforeOpen: (_) async {
      await customStatement("PRAGMA foreign_keys = ON");
      for (final owner in {
        "chat_sessions": "chat",
        "mistakes": "mistake",
        "practice_questions": "practice",
      }.entries) {
        await customStatement(
          "CREATE TRIGGER IF NOT EXISTS scratch_delete_${owner.value} AFTER DELETE ON ${owner.key} BEGIN DELETE FROM scratchpads WHERE context_key = '${owner.value}:' || old.id; END",
        );
      }
      await customStatement("PRAGMA journal_mode = WAL");
      await (update(
        aiToolOperations,
      )..where((t) => t.status.isIn(["pending", "running"]))).write(
        const AiToolOperationsCompanion(
          status: Value("cancelled"),
          result: Value('{"ok":false,"error":"应用关闭，未完成的操作已取消。"}'),
        ),
      );
      await (update(
        chatMessages,
      )..where((t) => t.status.equals("generating"))).write(
        const ChatMessagesCompanion(
          status: Value("interrupted"),
          error: Value(interruptedChatFailure),
        ),
      );
    },
  );

  Future<void> _createVisualIndexes() async {
    await customStatement(
      "CREATE INDEX visual_message_lookup ON visual_message_links(message_id)",
    );
    await customStatement(
      "CREATE INDEX visual_question_lookup ON visual_question_links(question_id)",
    );
    await customStatement(
      "CREATE INDEX visual_study_knowledge ON visual_study_links(knowledge_id)",
    );
    await customStatement(
      "CREATE INDEX visual_study_mistake ON visual_study_links(mistake_id)",
    );
  }

  Future<void> _createModuleIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX subject_module_name ON subject_modules(subject,ifnull(parent_id,''),name COLLATE NOCASE)",
    );
    await customStatement(
      "CREATE INDEX knowledge_module_lookup ON knowledge_module_links(module_id,knowledge_id)",
    );
    await customStatement(
      "CREATE INDEX mistake_module_lookup ON mistake_module_links(module_id,mistake_id)",
    );
  }

  Future<void> _createTimelineIndex() async {
    await customStatement(
      "CREATE INDEX timeline_event_start ON timeline_events(start_date)",
    );
  }

  Future<void> _createLanguageExamIndexes() async {
    await customStatement(
      "CREATE INDEX language_exam_materials_lookup ON learning_exam_materials(kind, profile, level, created_at)",
    );
    await customStatement(
      "CREATE INDEX language_exam_attempts_lookup ON learning_exam_attempts(material_id, submitted_at)",
    );
  }

  Future<void> _createExamIndexes() async {
    await customStatement("CREATE INDEX exam_event_date ON exam_events(date)");
    await customStatement(
      "CREATE INDEX exam_rows_subject ON exam_score_rows(subject_id,position)",
    );
    await customStatement(
      "CREATE INDEX exam_photos_subject ON exam_attachments(subject_id,created_at)",
    );
  }

  Future<void> _createPracticeLinkIndex() async {
    await customStatement(
      "CREATE INDEX practice_chat_message ON practice_chat_links(message_id)",
    );
  }

  Future<void> _createReviewIndexes() async {
    await customStatement(
      "CREATE INDEX review_due ON review_schedules(enabled, due_at)",
    );
    await customStatement(
      "CREATE INDEX review_history ON review_records(schedule_id, recorded_at)",
    );
  }

  Future<void> _createPracticeIndexes() async {
    await customStatement(
      "CREATE UNIQUE INDEX one_pending_attempt ON practice_attempts(question_id) WHERE status IN ('draft','awaiting_self_grade')",
    );
    await customStatement(
      "CREATE INDEX attempts_question_time ON practice_attempts(question_id, started_at)",
    );
    await customStatement(
      "CREATE INDEX questions_source ON practice_questions(source_message_id, deleted)",
    );
    await customStatement(
      "CREATE INDEX questions_subject ON practice_questions(deleted, subject, created_at)",
    );
    await customStatement(
      "CREATE INDEX question_topic_lookup ON practice_question_topics(topic_id)",
    );
  }

  Future<void> _createStudyIndexes() async {
    await customStatement(
      "CREATE INDEX knowledge_subject_updated ON knowledge_items(deleted, subject, updated_at)",
    );
    await customStatement(
      "CREATE INDEX mistakes_subject_updated ON mistakes(deleted, subject, updated_at)",
    );
    await customStatement(
      "CREATE INDEX study_attachments_knowledge ON study_attachments(knowledge_id)",
    );
    await customStatement(
      "CREATE INDEX study_attachments_mistake ON study_attachments(mistake_id)",
    );
    await customStatement(
      "CREATE UNIQUE INDEX tool_write_dedup ON ai_tool_operations(run_id, name, arguments) WHERE name IN ('create_knowledge','update_knowledge','delete_knowledge','create_mistake','update_mistake','delete_mistake','link_mistake_to_knowledge','schedule_review') AND status IN ('pending','running','succeeded')",
    );
    for (final (table, fts, content) in [
      ("knowledge_items", "knowledge_search", "title, content, chapter"),
      (
        "mistakes",
        "mistake_search",
        "title, question, chapter, correct_answer, original_answer, own_analysis, ai_analysis, error_reason, suggested_reason",
      ),
    ]) {
      final names = content.split(", ");
      final newValues = names.map((n) => "new.$n").join(", ");
      final oldValues = names.map((n) => "old.$n").join(", ");
      await customStatement(
        "CREATE VIRTUAL TABLE $fts USING fts5($content, content='$table', content_rowid='rowid', tokenize='trigram')",
      );
      await customStatement(
        "CREATE TRIGGER ${fts}_ai AFTER INSERT ON $table BEGIN INSERT INTO $fts(rowid, $content) VALUES(new.rowid, $newValues); END",
      );
      await customStatement(
        "CREATE TRIGGER ${fts}_ad AFTER DELETE ON $table BEGIN INSERT INTO $fts($fts, rowid, $content) VALUES('delete', old.rowid, $oldValues); END",
      );
      await customStatement(
        "CREATE TRIGGER ${fts}_au AFTER UPDATE ON $table BEGIN INSERT INTO $fts($fts, rowid, $content) VALUES('delete', old.rowid, $oldValues); INSERT INTO $fts(rowid, $content) VALUES(new.rowid, $newValues); END",
      );
    }
  }
}

extension _LanguageQuickMigration on AppDatabase {
  Future<void> _createLanguageQuickSearch() async {
    await customStatement(
      "CREATE INDEX language_quick_time ON language_quick_lookups(created_at)",
    );
    await customStatement(
      "CREATE INDEX language_quick_action_time ON language_quick_lookups(action_id, created_at)",
    );
    await customStatement(
      "CREATE INDEX language_quick_cache ON language_quick_lookups(cache_key, created_at)",
    );
    await customStatement(
      "CREATE VIRTUAL TABLE language_quick_search USING fts5(input, summary, content, content='language_quick_lookups', content_rowid='rowid', tokenize='trigram')",
    );
    await customStatement(
      "CREATE TRIGGER language_quick_insert AFTER INSERT ON language_quick_lookups BEGIN "
      "INSERT INTO language_quick_search(rowid, input, summary, content) "
      "VALUES(new.rowid, new.input, new.summary, new.content); END",
    );
    await customStatement(
      "CREATE TRIGGER language_quick_delete AFTER DELETE ON language_quick_lookups BEGIN "
      "INSERT INTO language_quick_search(language_quick_search, rowid, input, summary, content) "
      "VALUES('delete', old.rowid, old.input, old.summary, old.content); END",
    );
  }
}
