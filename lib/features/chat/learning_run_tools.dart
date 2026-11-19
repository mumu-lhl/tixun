part of 'learning_run.dart';

extension _LearningRunTools on LearningRun {
  Future<Map<String, dynamic>> _executeTool(
    ToolCall call, {
    required String sessionId,
    required String runId,
    required List<Attachment> sourceImages,
    required CancelToken cancel,
    required bool exam,
    required bool drawingEnabled,
    required StudyToolRunner runner,
    required Future<bool> Function(String, Map<String, dynamic>, int) approve,
  }) async {
    final result = call.name == 'run_python'
        ? await python.run(
            call,
            sessionId: sessionId,
            runId: runId,
            cancel: cancel,
            confirm: (name, args) => approve(name, args, 0),
          )
        : call.name == 'suggest_question_regions' && !exam
        ? (sourceImages.isNotEmpty
              ? await executeRegionTool(
                  db,
                  call,
                  sessionId: sessionId,
                  runId: runId,
                  sourceImages: sourceImages,
                  cancel: cancel,
                )
              : <String, dynamic>{'ok': false, 'error': '当前对话中没有可供分题的图片。'})
        : call.name == 'create_quiz'
        ? await executeQuizTool(
            practice,
            call,
            sessionId: sessionId,
            runId: runId,
            cancel: cancel,
            sourceImages: sourceImages,
            visual: drawingEnabled ? visual : null,
            exam: exam,
          )
        : call.name == 'create_visual'
        ? visual == null
              // Unreachable: the unknown-tool guard above rejects
              // calls for tools not in the request, and the schema
              // is only offered when a visual store is wired.
              ? <String, dynamic>{'ok': false, 'error': '当前会话未启用图形工具。'}
              : await executeVisualTool(
                  visual!,
                  call,
                  sessionId: sessionId,
                  runId: runId,
                  cancel: cancel,
                )
        : call.name == 'update_visual'
        ? visual == null
              ? <String, dynamic>{'ok': false, 'error': '当前会话未启用图形工具。'}
              : await executeUpdateVisualTool(
                  visual!,
                  call,
                  sessionId: sessionId,
                  runId: runId,
                  cancel: cancel,
                )
        : call.name == 'get_visual'
        ? visual == null
              ? <String, dynamic>{'ok': false, 'error': '当前会话未启用图形工具。'}
              : await executeGetVisualTool(
                  visual!,
                  call,
                  sessionId: sessionId,
                  runId: runId,
                  cancel: cancel,
                )
        : await runner.execute(call, cancel);
    if (call.name == 'get_visual') {
      // The visual reader remains read-only. Store only a small display
      // record here, never the scene, so chat can show the actual call.
      final title = result['title'];
      try {
        await db
            .into(db.aiToolOperations)
            .insert(
              AiToolOperationsCompanion.insert(
                id: '$runId:${call.id}',
                runId: runId,
                sessionId: sessionId,
                name: call.name,
                arguments: '{}',
                status: result['ok'] == true ? 'succeeded' : 'failed',
                result: Value(
                  jsonEncode({
                    'ok': result['ok'] == true,
                    if (title is String) 'title': title,
                  }),
                ),
                createdAt: DateTime.now(),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      } on Exception {
        // A display-only history failure must not turn a read into a
        // failed tool response or change the figure.
      }
    }
    return result;
  }

  Future<void> _recordUsage({
    required String actionId,
    required String sessionId,
    required String messageId,
    required ProviderConfig config,
    required String feature,
    required String status,
    required DateTime startedAt,
    required int imageCount,
    required int toolCallCount,
    required AiTokenUsage? usage,
    required AiRequest request,
    required String response,
    required String reasoning,
    required List<ToolCall> calls,
  }) async {
    if (provider is MockChatProvider) return;
    try {
      await AiUsageStore(db).record(
        AiUsageCapture(
          actionId: actionId,
          sessionId: sessionId,
          messageId: messageId,
          providerKind: config.kind,
          endpoint: config.baseUrl,
          model: config.model,
          feature: feature,
          status: status,
          occurredAt: startedAt,
          durationMs: DateTime.now().difference(startedAt).inMilliseconds,
          imageCount: imageCount,
          toolCallCount: toolCallCount,
          usage: usage,
        ),
        request: request,
        response: response,
        reasoning: reasoning,
        calls: calls,
      );
    } catch (_) {
      // Usage-accounting failures must never fail a learning request.
    }
  }
}

// Recognize explicit reference-only/opt-out requests, not general teaching
// intent. Read only the latest user's own turn, never old context or summaries.
bool _requestsStudyMaterial(String text) {
  final lower = text.toLowerCase();
  final noQuiz = RegExp(
    r'(?:不要|不用|无需|不需要|别|不准)\s*(?:再)?(?:给我)?\s*(?:出题|测验|练习|考我)(?:\s*(?:、|和|或|及|与|/)\s*(?:出题|测验|练习|考我))*|\b(?:no|without)\s+(?:quizzes|quiz|questions?|tests?)\b|\b(?:do not|don.t)\s+(?:quiz|test|ask)\b',
  );
  final remaining = lower.replaceAll(noQuiz, '');
  if (RegExp(
    r'出.{0,3}题|练习题|测验|考我|\b(?:quiz|practice questions?|test me|assess me)\b',
  ).hasMatch(remaining)) {
    return false;
  }
  if (noQuiz.hasMatch(lower)) return true;
  const actions = [
    '梳理',
    '整理',
    '汇总',
    '总结',
    '列出',
    '罗列',
    '清单',
    '速查',
    '提纲',
    '一览',
    '有哪些',
    'summarize',
    'summarise',
    'summary',
    'list',
    'overview',
    'cheat sheet',
    'study guide',
    'reference sheet',
    'revision sheet',
  ];
  const material = [
    '公式',
    '知识',
    '考点',
    '复习',
    '定理',
    '概念',
    '笔记',
    '资料',
    'formula',
    'concept',
    'revision',
    'review',
    'theorem',
    'notes',
    'study guide',
    'checklist',
    'cheat sheet',
  ];
  return actions.any(lower.contains) && material.any(lower.contains);
}
