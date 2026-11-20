part of 'controller.dart';

extension _ChatSessions on AppController {
  Future<void> _reloadImpl() async {
    allSessions = await db.sessions();
    final rows = search.isEmpty ? allSessions : await db.sessions(search);
    sessions = _visibleSessions(rows);
    changed();
  }

  Future<void> _searchSessionsImpl(String value) async {
    search = value;
    final subject = subjectFilter;
    final result = await db.sessions(value, subject);
    if (search == value && subjectFilter == subject) {
      sessions = _visibleSessions(result);
      changed();
    }
  }

  Future<void> _selectSessionImpl(ChatSession session) async {
    await stop();
    await _loadSession(session);
  }

  Future<void> _prepareSubjectChatImpl() async {
    final pending = _subjectChatPreparation;
    if (pending != null) return pending;
    final preparation = _prepareSubjectChat();
    _subjectChatPreparation = preparation;
    try {
      await preparation;
    } finally {
      if (identical(_subjectChatPreparation, preparation)) {
        _subjectChatPreparation = null;
      }
    }
  }

  Future<void> _prepareSubjectChat() async {
    while (!_disposed) {
      final subject = subjectFilter;
      if (subject.isEmpty || selected?.subject == subject) return;
      // Search text only filters the history list, never the candidate session.
      final candidates = await db.sessions('', subject);
      if (_disposed) return;
      if (subject != subjectFilter) continue;
      if (candidates.isEmpty) {
        await newSession();
      } else {
        await selectSession(candidates.first);
      }
    }
  }

  Future<void> _loadSession(ChatSession session) async {
    final current = ++_epoch;
    final loaded = await Future.wait<Object>([
      db.messages(session.id),
      db.images(session.id),
      db.preference('ai_reasoning:${session.id}').then((v) => v ?? ''),
      db
          .preference(studyToolCategoriesKey(session.id))
          .then((v) => readStudyToolCategories(v)),
      db.preference('ai_drawing:${session.id}').then((v) => v ?? ''),
      db.preference(chatA2uiPreference(session.id)).then((v) => v ?? ''),
    ]);
    if (_epoch != current) return;
    final row = await (db.select(
      db.chatSessions,
    )..where((s) => s.id.equals(session.id))).getSingleOrNull();
    // Re-check after the second await: another select may have completed
    // meanwhile, and the session may have been deleted in between.
    if (_epoch != current || row == null) return;
    selected = row;
    messages = loaded[0] as List<ChatMessage>;
    attachments = loaded[1] as List<Attachment>;
    final override = loaded[2] as String;
    studyToolCategories = loaded[3] as Set<StudyToolCategory>;
    sessionDrawingOverride = switch (loaded[4]) {
      'true' => true,
      'false' => false,
      _ => null,
    };
    sessionA2uiOverride = readA2uiOverride(loaded[5] as String);
    sessionReasoning = AiOptions(config).supportsOverride(override)
        ? override
        : '';
    error = null;
    await db.setPreference('selected_session', session.id);
    changed();
  }

  Future<void> _newSessionImpl() async {
    await stop();
    final profile = await LearningProfile.load(db);
    await selectSession(
      await db.createSession(
        mode: profile.teaching,
        title: l10n.newStudyConversation,
        subject: subjectFilter.isEmpty ? null : subjectFilter,
      ),
    );
    search = '';
    await reload();
  }

  Future<void> _renameSessionImpl(ChatSession s, String title) async {
    await db.rename(s.id, title);
    await reload();
    if (selected?.id == s.id) {
      selected = selected!.copyWith(title: title.trim());
      changed();
    }
  }

  Future<void> _applyDeepSeekTitle(
    String sessionId,
    String? expectedTitle,
    String generatedTitle,
  ) async {
    if (expectedTitle == null) return;
    final title = generatedTitle
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .characters
        .take(30)
        .toString();
    if (title.isEmpty || title == expectedTitle) return;
    final updated =
        await (db.update(db.chatSessions)..where(
              (session) =>
                  session.id.equals(sessionId) &
                  session.title.equals(expectedTitle),
            ))
            .write(ChatSessionsCompanion(title: Value(title)));
    if (updated == 0) return;
    if (selected?.id == sessionId) selected = selected!.copyWith(title: title);
    sessions = [
      for (final session in sessions)
        if (session.id == sessionId)
          session.copyWith(title: title)
        else
          session,
    ];
    allSessions = [
      for (final session in allSessions)
        if (session.id == sessionId)
          session.copyWith(title: title)
        else
          session,
    ];
    changed();
  }

  Future<void> _deleteSessionImpl(ChatSession s) async {
    if (selected?.id == s.id) {
      await stop();
      selected = null;
      messages = [];
      attachments = [];
    }
    await db.setDeleted(s.id, true);
    await reload();
  }

  Future<void> _restoreSessionImpl(ChatSession s) async {
    await db.setDeleted(s.id, false);
    await reload();
  }

  Future<int> _purgeSessionImpl(String id) => study.runOperation(() async {
    final paths = <String>[];
    await db.transaction(() async {
      final session = await (db.select(
        db.chatSessions,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (session == null || !session.deleted) {
        throw const AppFormatException(
          AppErrorCode.onlyConversationsInTheTrash,
          '只能永久删除回收区中的会话。',
        );
      }
      for (final image in await db.images(id)) {
        paths.add(image.relativePath);
        if (image.originalPath != null) paths.add(image.originalPath!);
      }
      await (db.delete(
        db.aiToolOperations,
      )..where((o) => o.sessionId.equals(id))).go();
      await (db.delete(db.chatSessions)..where((s) => s.id.equals(id))).go();
      await db.setPreference('practice_parent:$id', '');
    });

    final failed = await cleanupPurgedAttachments(db, files, paths);
    practice.changed();
    study.changed();
    await reload();
    return failed;
  });

  Future<void> _draftImpl(String value) async {
    final s = selected;
    if (s == null) return;
    if (demo && s.draft.isEmpty && value.isNotEmpty) {
      debugPrint('TIXUN_DRAFT_READY');
    }
    selected = s.copyWith(draft: value);
    try {
      await db.saveDraft(s.id, value);
    } catch (_) {
      error = AppTransientError.draftSaveFailed;
      changed();
    }
  }

  Future<void> _modeImpl(String value) async {
    if (selected == null || busy) return;
    final s = selected!.copyWith(mode: value, stage: 'diagnosing');
    await db.update(db.chatSessions).replace(s);
    selected = s;
    changed();
  }

  Future<Attachment> _addImageImpl(String path) => study.runOperation(() async {
    if (busy) {
      throw const AppFormatException(
        AppErrorCode.stopTheReplyBeforeAdding,
        '请先停止生成，再添加图片。',
      );
    }
    if (selected == null) await newSession();
    final s = selected!;
    final image = await files.importFile(path);
    final id = const Uuid().v4();
    try {
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: id,
              sessionId: s.id,
              relativePath: image.path,
              mime: image.mime,
              byteLength: image.bytes,
            ),
          );
    } catch (_) {
      await files.resolve(image.path).delete();
      rethrow;
    }
    if (selected?.id == s.id) {
      attachments = await db.images(s.id);
      changed();
    }
    return (await (db.select(
      db.attachments,
    )..where((t) => t.id.equals(id))).getSingle());
  });

  Future<String> _replaceDraftImageImpl(Attachment image, Uint8List bytes) =>
      study.runOperation(() async {
        if (busy || selected == null) {
          throw const AppFormatException(
            AppErrorCode.stopGenerationBeforeEditingDraft,
            '请先停止生成，再编辑草稿图片。',
          );
        }
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
            final row =
                await (db.select(db.attachments)..where(
                      (a) =>
                          a.id.equals(image.id) &
                          a.sessionId.equals(selected!.id) &
                          a.messageId.isNull(),
                    ))
                    .getSingleOrNull();
            if (row == null) {
              throw const AppFormatException(
                AppErrorCode.theImageWasSentOr,
                '图片已发送或草稿已切换，请重新打开编辑。',
              );
            }
            final file = files.resolve(path);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes, flush: true);
            await (db.update(
              db.attachments,
            )..where((a) => a.id.equals(row.id))).write(
              AttachmentsCompanion(
                relativePath: Value(path),
                mime: Value(mime),
                byteLength: Value(bytes.length),
                originalPath: Value(row.originalPath ?? row.relativePath),
              ),
            );
            if (row.originalPath != null &&
                row.relativePath != row.originalPath) {
              discard = row.relativePath;
            }
          });
        } catch (_) {
          if (await files.resolve(path).exists()) {
            await files.resolve(path).delete();
          }
          rethrow;
        }
        if (discard != null) {
          try {
            if (await cleanupPurgedAttachments(db, files, [discard!]) > 0) {
              notice = const AppNotice(AppNoticeKind.imageEditsCleanupFailed);
            }
          } catch (_) {
            notice = const AppNotice(AppNoticeKind.imageEditsCleanupFailed);
          }
        }
        attachments = await db.images(selected!.id);
        changed();
        return image.id;
      });

  Future<void> _removeImageImpl(Attachment image) =>
      study.runOperation(() async {
        if (busy || image.messageId != null || selected == null) return;
        final session = selected!.id;
        final paths = <String>[];
        await db.transaction(() async {
          final row =
              await (db.select(db.attachments)..where(
                    (a) =>
                        a.id.equals(image.id) &
                        a.sessionId.equals(session) &
                        a.messageId.isNull(),
                  ))
                  .getSingleOrNull();
          if (row == null) return;
          paths.add(row.relativePath);
          if (row.originalPath != null) paths.add(row.originalPath!);
          await (db.delete(
            db.attachments,
          )..where((a) => a.id.equals(row.id))).go();
        });
        if (await cleanupPurgedAttachments(db, files, paths) > 0) {
          notice = const AppNotice(AppNoticeKind.draftImageCleanupFailed);
        }
        if (selected?.id == session) attachments = await db.images(session);
        changed();
      });

  Future<void> _forkChatImpl(ChatMessage message) async {
    if (busy) return;
    busy = true;
    final ready = Completer<void>();
    _preparation = ready;
    changed();
    try {
      await _forkSession(message);
    } finally {
      ready.complete();
      if (identical(_preparation, ready)) _preparation = null;
      busy = false;
      changed();
    }
  }

  Future<ChatSession> _forkSession(
    ChatMessage message, {
    String? editedText,
    bool inheritStudyLinks = true,
  }) async {
    final parent = await (db.select(
      db.chatSessions,
    )..where((s) => s.id.equals(message.sessionId))).getSingleOrNull();
    if (parent == null) {
      throw AppFormatException(
        AppErrorCode.cannotForkMessage,
        l10n.cannotForkMessage,
      );
    }
    final branch =
        await ChatBranchStore(
          db,
          practice,
          copySettings: preferences.copyChatSettings,
        ).fork(
          through: message,
          title: l10n.chatBranchTitle(l10nArgument(parent.title)),
          editedText: editedText,
          inheritStudyLinks: inheritStudyLinks,
        );
    await _loadSession(branch);
    search = '';
    await reload();
    return branch;
  }

  Future<void> _editAndResendImpl(ChatMessage message, String text) async {
    if (busy || text.trim().isEmpty || selected == null) return;
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index < 0 || message.role != 'user') return;
    await _startRequest(() async {
      final branch = await _forkSession(message, editedText: text);
      return (sessionId: branch.id, enableConversationTitle: false);
    });
  }
}
