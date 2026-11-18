part of 'controller.dart';

extension _ChatGeneration on AppController {
  Future<void> _setSessionReasoningImpl(String value) =>
      preferences.runOperation(() async {
        if (busy || selected == null) {
          throw const AiFailure.localized(
            AppErrorCode.stopGeneratingBeforeChangingReasoning,
            '请先停止生成，再调整本会话思考强度。',
          );
        }
        if (value.isNotEmpty && value != 'off' && !config.supportsThinking) {
          throw const AiFailure.localized(
            AppErrorCode.theCurrentModelHasNot,
            '当前模型未声明支持思考参数。',
          );
        }
        if (!AiOptions(config).supportsOverride(value)) {
          throw const AppFormatException(
            AppErrorCode.invalidReasoningEffort,
            '思考强度无效。',
          );
        }
        final thinking = AiOptions(AiOptions.forSession(config, value))
            .reasoningEnabled;
        if (thinking &&
            !AiOptions(config).reasoningWithTools &&
            (selected!.toolsEnabled || selected!.mode == 'exam')) {
          throw const AiFailure.localized(
            AppErrorCode.thisTaskRequiresNonThinking,
            '当前任务需要非思考工具调用，请保持关闭；普通讲解可在其他会话开启。',
          );
        }
        await db.setPreference('ai_reasoning:${selected!.id}', value);
        sessionReasoning = value;
        changed();
      });

  Future<void> _useToolReasoningImpl() async {
    if (AiOptions(config).reasoningWithTools) return;
    await setSessionReasoning('off');
    if (config.thinking) {
      notice = const AppNotice(AppNoticeKind.sessionReasoningFallback);
      changed();
    }
  }

  Future<void> _useQuizReasoningImpl() async {
    if (!config.supportsThinking ||
        AiOptions(config).reasoningEfforts.isEmpty) {
      return;
    }
    if (AiOptions(config).reasoningWithTools) {
      await setSessionReasoning(AiOptions(config).preferredEffort);
    } else {
      await useToolReasoning();
    }
  }

  Future<void> _setToolsImpl(bool enabled) =>
      setStudyToolCategories(enabled ? allStudyToolCategories : {});

  Future<void> _setStudyToolCategoriesImpl(
    Set<StudyToolCategory> categories,
  ) async {
    if (busy || selected == null) return;
    final enabled = categories.isNotEmpty;
    if (enabled && !AiOptions(sessionConfig).toolsAvailable) {
      throw sessionConfig.supportsTools
          ? const AiFailure.localized(
              AppErrorCode.materialToolsRequireModelWithoutThinking,
              '资料工具需要支持工具调用的模型，并关闭深度思考。',
            )
          : const AiFailure.localized(
              AppErrorCode.materialToolsRequireToolCapableModel,
              '资料工具需要支持工具调用的模型。',
            );
    }
    final sessionId = selected!.id;
    final saved = Set<StudyToolCategory>.unmodifiable(categories);
    await db.transaction(() async {
      await db.setPreference(
        studyToolCategoriesKey(sessionId),
        saved.map((c) => c.name).join(','),
      );
      await (db.update(db.chatSessions)..where((s) => s.id.equals(sessionId)))
          .write(ChatSessionsCompanion(toolsEnabled: Value(enabled)));
    });
    if (selected?.id == sessionId) {
      selected = selected!.copyWith(toolsEnabled: enabled);
      studyToolCategories = saved;
      changed();
    }
  }

  void _decideToolImpl(bool approve) {
    if (_toolDecision?.isCompleted == false) _toolDecision!.complete(approve);
  }

  Future<bool> _confirmTool(
    String name,
    Map<String, dynamic> args,
    CancelToken cancel, {
    int imageCount = 0,
  }) async {
    cancel.checkCancelled();
    // Every id the model must supply is validated here with its own name:
    // an unguarded `as String` throws TypeError, which the tool runner
    // would report as a generic '操作未完成' instead of telling the model
    // which parameter is missing.
    String argString(String key) {
      final value = args[key];
      if (value == null) {
        throw AppFormatException(
          AppErrorCode.errorMissingParameter,
          '缺少参数：$key。',
          [key],
        );
      }
      if (value is! String) {
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          '参数 $key 类型无效。',
          [key],
        );
      }
      return value;
    }

    var target = '';
    if (name.endsWith('knowledge') && args['id'] is String) {
      target = (await study.knowledge(args['id'] as String)).title;
    }
    if (name.endsWith('mistake') && args['id'] is String) {
      target = (await study.mistake(args['id'] as String)).title;
    }
    if (name == 'link_mistake_to_knowledge') {
      target =
          '${(await study.mistake(argString('mistake_id'))).title} ↔ ${(await study.knowledge(argString('knowledge_id'))).title}';
    }
    if (name == 'create_subject_module' && args['parent_id'] is String) {
      final all = await study.modules.list(argString('subject'));
      final parent = all.where((m) => m.id == args['parent_id']).firstOrNull;
      if (parent == null) {
        throw const AppFormatException(
          AppErrorCode.errorTheParentModuleDoesNotExist,
          '上级模块不存在。',
        );
      }
      target = '${parent.name} / ${argString('name')}';
    }
    if (name == 'link_study_module') {
      if (!['knowledge', 'mistake'].contains(args['kind'])) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidMaterialType,
          '资料类型无效。',
        );
      }
      final isMistake = args['kind'] == 'mistake';
      final id = argString('id');
      final subject = isMistake
          ? (await study.mistake(id)).subject
          : (await study.knowledge(id)).subject;
      final title = isMistake
          ? (await study.mistake(id)).title
          : (await study.knowledge(id)).title;
      final all = await study.modules.list(subject);
      final moduleId = argString('module_id');
      final module = all.where((m) => m.id == moduleId).firstOrNull;
      if (module == null) {
        throw const AppFormatException(
          AppErrorCode.errorTheFolderDoesNotExistOr,
          '目录不存在或科目不匹配。',
        );
      }
      target = '$title → $subject / ${modulePath(module, all)}';
    }
    if (name == 'schedule_review') {
      try {
        target = (await practice.detail(argString('question_id'))).row.stem;
      } on StateError {
        throw const AppFormatException(
          AppErrorCode.errorTheQuestionDoesNotExist,
          '题目不存在。',
        );
      }
    }
    final decision = Completer<bool>();
    _toolDecision = decision;
    pendingTool = ToolApproval(
      name,
      Map.unmodifiable(args),
      target,
      imageCount,
    );
    changed();
    try {
      return await Future.any([
        decision.future,
        cancel.whenCancel.then((_) => false),
      ]);
    } finally {
      _toolDecision = null;
      pendingTool = null;
      changed();
    }
  }

  Future<void> _startRequest(
    Future<_PreparedGeneration> Function() prepare,
  ) async {
    busy = true;
    error = null;
    final ready = Completer<void>();
    _preparation = ready;
    changed();
    try {
      final prepared = await prepare();
      _generation = _generate(
        prepared.sessionId,
        enableConversationTitle: prepared.enableConversationTitle,
      );
      ready.complete();
      _preparation = null;
      await _generation;
    } catch (_) {
      error = AppTransientError.messageSaveFailed;
      busy = false;
      changed();
    } finally {
      if (!ready.isCompleted) ready.complete();
      if (identical(_preparation, ready)) _preparation = null;
    }
  }

  Future<void> _sendImpl(String input) async {
    if (busy ||
        (input.trim().isEmpty &&
            !attachments.any((a) => a.messageId == null))) {
      return;
    }
    await _startRequest(() async {
      if (selected == null) {
        selected = await db.createSession(
          subject: subjectFilter.isEmpty ? null : subjectFilter,
        );
        messages = [];
        attachments = [];
      }
      final s = selected!;
      final userId = const Uuid().v4();
      final now = DateTime.now();
      var requestConversationTitle = false;
      await db.transaction(() async {
        await db
            .into(db.chatMessages)
            .insert(
              ChatMessagesCompanion.insert(
                id: userId,
                sessionId: s.id,
                role: 'user',
                content: input.trim().isEmpty ? '请帮我理解图片中的题目。' : input.trim(),
                createdAt: now,
              ),
            );
        await (db.update(db.attachments)
              ..where((a) => a.sessionId.equals(s.id) & a.messageId.isNull()))
            .write(AttachmentsCompanion(messageId: Value(userId)));
        // The input stays editable while the send is being prepared, so the
        // user may already have typed past the sent text. Only clear the
        // stored draft when it still holds exactly the sent text; otherwise
        // keep it — wiping it would discard the newer typing.
        final stored = await (db.select(
          db.chatSessions,
        )..where((t) => t.id.equals(s.id))).getSingle();
        final untitledFirstSend =
            messages.isEmpty &&
            const ['新的学习对话', 'New study conversation'].contains(stored.title);
        requestConversationTitle =
            untitledFirstSend && sessionConfig.kind == 'deepseek';
        final clearDraft = stored.draft.isEmpty || stored.draft == input;
        await (db.update(
          db.chatSessions,
        )..where((t) => t.id.equals(s.id))).write(
          ChatSessionsCompanion(
            draft: clearDraft ? const Value('') : const Value.absent(),
            updatedAt: Value(now),
            title: untitledFirstSend
                ? Value(
                    input.trim().isEmpty
                        ? '图片题目'
                        : input.trim().characters.take(30).toString(),
                  )
                : const Value.absent(),
          ),
        );
      });
      selected = await (db.select(
        db.chatSessions,
      )..where((t) => t.id.equals(s.id))).getSingle();
      await db.setPreference('selected_session', s.id);
      await _refreshSelected();
      await reload();
      return (
        sessionId: s.id,
        enableConversationTitle: requestConversationTitle,
      );
    });
  }

  Future<void> _refreshSelected() async {
    final id = selected?.id;
    if (id == null) return;
    messages = await db.messages(id);
    attachments = await db.images(id);
    changed();
  }

  // Streaming progress used to reload the whole conversation from the
  // database on every tick (~12/s), which re-parsed every visible message's
  // Markdown. Progress ticks now persist the partial text (so a crash keeps
  // it) but update only the generating message in memory, at a slower
  // cadence. Unclosed fences/formulas can still re-layout mid-stream —
  // fixing that needs a streaming-aware Markdown renderer, not a throttle.
  static const _progressThrottleMs = 250;

  void _publishProgress(
    String id,
    String text,
    int? tokens,
    String? reasoning,
    String? trace,
  ) {
    final index = messages.indexWhere((m) => m.id == id);
    if (index < 0) {
      // The generating message is not in the local list (e.g. the session
      // was switched mid-generation): fall back to a full reload.
      unawaited(_refreshSelected());
      return;
    }
    messages = [
      ...messages.sublist(0, index),
      messages[index].copyWith(
        content: text,
        status: 'generating',
        reasoningContent: Value(reasoning),
        reasoningTrace: Value(trace),
        totalTokens: tokens == null ? const Value.absent() : Value(tokens),
      ),
      ...messages.sublist(index + 1),
    ];
    changed();
  }

  Future<void> _generate(
    String sessionId, {
    bool enableConversationTitle = false,
  }) async {
    busy = true;
    if (demo) debugPrint('TIXUN_GENERATION_STARTED');
    final cancel = CancelToken();
    _cancel = cancel;
    final id = const Uuid().v4();
    final titleBeforeGeneration = selected?.title;
    final requestConfig = sessionConfig;
    final requestPrompts = prompts;
    final requestDrawingEnabled = sessionDrawingEnabled;
    var text = '';
    var status = 'complete';
    String? failure;
    int? tokens;
    String? reasoning, trace;
    var lastWrite = DateTime.now();
    var progressStarted = false;
    final exam = selected!.mode == 'exam';
    var quizCreated = false;
    try {
      await db
          .into(db.chatMessages)
          .insert(
            ChatMessagesCompanion.insert(
              id: id,
              sessionId: sessionId,
              role: 'assistant',
              content: '',
              status: const Value('generating'),
              model: Value(demo ? 'Mock · 离线演示' : requestConfig.model),
              createdAt: DateTime.now(),
            ),
          );
      await _refreshSelected();
      final result = await learningRun.run(
        sessionId: sessionId,
        runId: id,
        requestConfig: requestConfig,
        requestPrompts: requestPrompts,
        history: messages.where((m) => m.id != id).toList(),
        images: attachments,
        mode: selected!.mode,
        authorized: selected!.toolsEnabled,
        enableConversationTitle: enableConversationTitle,
        drawingOverride: requestDrawingEnabled,
        cancel: cancel,
        confirm: (name, args, count) =>
            _confirmTool(name, args, cancel, imageCount: count),
        onProgress: (progress) async {
          text = progress.text;
          tokens = progress.tokens;
          quizCreated = progress.quizCreated;
          reasoning = progress.reasoning;
          trace = progress.reasoningTrace;
          if (DateTime.now().difference(lastWrite).inMilliseconds >=
                  _progressThrottleMs ||
              (!progressStarted &&
                  (text.isNotEmpty || (trace?.isNotEmpty ?? false)))) {
            await _writeMessage(
              id,
              text,
              'generating',
              null,
              tokens,
              reasoning,
              trace,
            );
            _publishProgress(id, text, tokens, reasoning, trace);
            progressStarted = true;
            lastWrite = DateTime.now();
          }
        },
      );
      if (enableConversationTitle && result.title != null) {
        await _applyDeepSeekTitle(
          sessionId,
          titleBeforeGeneration,
          result.title!,
        );
      }
      text = result.text;
      tokens = result.tokens;
      quizCreated = result.quizCreated;
      reasoning = result.reasoning;
      trace = result.reasoningTrace;
    } on AiFailure catch (e) {
      status = 'error';
      failure = e.code == null
          ? encodeRawChatFailure(e.message)
          : encodeChatFailure(e.code!, e.arguments);
    } on DioException catch (e) {
      status = CancelToken.isCancel(e) ? 'stopped' : 'error';
      failure = encodeChatFailure(
        cancel.cancelError?.error == 'timeout'
            ? AppErrorCode.generationTimedOutPartialContent
            : (status == 'stopped'
                  ? AppErrorCode.generationStopped
                  : AppErrorCode.theNetworkRequestFailedTry),
      );
    } catch (_) {
      status = 'error';
      failure = encodeChatFailure(
        AppErrorCode.generationFailedCheckSecureStorage,
      );
    } finally {
      cancel.cancel('finished');
      try {
        if (exam && !quizCreated && status != 'complete') text = '';
        await _writeMessage(
          id,
          text,
          status,
          failure,
          tokens,
          reasoning,
          trace,
        );
        await (db.update(
          db.chatSessions,
        )..where((s) => s.id.equals(sessionId))).write(
          ChatSessionsCompanion(
            stage: Value(
              (await practice.list(messageId: id)).isNotEmpty
                  ? 'practice'
                  : text.isNotEmpty
                  ? 'explaining'
                  : 'diagnosing',
            ),
          ),
        );
        await _refreshSelected();
        await reload();
      } catch (_) {
        error = AppTransientError.responseSaveFailed;
      }
      busy = false;
      _cancel = null;
      if (demo) debugPrint('TIXUN_GENERATION_FINISHED status=$status');
      changed();
    }
  }

  Future<void> _writeMessage(
    String id,
    String text,
    String status,
    String? error,
    int? tokens,
    String? reasoning,
    String? trace,
  ) async {
    await (db.update(db.chatMessages)..where((m) => m.id.equals(id))).write(
      ChatMessagesCompanion(
        content: Value(text),
        status: Value(status),
        error: Value(error),
        totalTokens: Value(tokens),
        reasoningContent: Value(reasoning),
        reasoningTrace: Value(trace),
      ),
    );
  }

  Future<void> _stopImpl() async {
    _cancel?.cancel('user');
    await _preparation?.future;
    _cancel?.cancel('user');
    await _generation;
  }

  Future<void> _regenerateImpl() async {
    if (busy || selected == null || messages.isEmpty) return;
    final user = messages.where((m) => m.role == 'user').lastOrNull;
    if (user != null) await editAndResend(user, user.content);
  }
}
