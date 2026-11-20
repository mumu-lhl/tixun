import 'package:tixun/core/l10n/app_error.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import '../../core/python/python_tool.dart';
import '../../core/python/python_runtime.dart';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/ai/chat_provider.dart';
import '../../core/ai/ai_usage_store.dart';
import '../../core/ai/context_compactor.dart';
import '../../core/ai/tool_limits.dart';
import '../../core/ai/token_estimator.dart';
import 'chat_context_store.dart';
import '../../core/ai/study_tools.dart';
import '../../core/ai/quiz_tool.dart';
import '../../core/ai/region_tool.dart';
import '../../core/ai/visual_tool.dart';
import '../../core/ai/visual_toolset.dart';
import '../../core/database/database.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/platform/attachment_store.dart';
import '../library/study_store.dart';
import '../a2ui/a2ui_store.dart';
import '../a2ui/a2ui_tools.dart';
import '../library/subject_scope.dart';
import '../practice/practice_store.dart';
import '../review/review_store.dart';
import '../visual/visual_store.dart';
import '../progress/learning_profile.dart';
import '../../core/ai/prompt_settings.dart';
import '../../core/ai/study_write_task.dart';

part 'learning_run_context.dart';
part 'learning_run_tools.dart';

class LearningRunResult {
  const LearningRunResult({
    required this.text,
    this.tokens,
    required this.quizCreated,
    this.title,
    this.visualCreated = false,
    this.surfaceInserted = false,
    this.reasoning,
    this.reasoningTrace,
  });
  final String text;
  final int? tokens;
  final bool quizCreated;
  final String? title;

  /// A scene was created this run; its card renders under the message.
  /// Creation is an intermediate result: explanation/quiz rounds may follow.
  final bool visualCreated;
  final bool surfaceInserted;

  /// Reasoning streamed in the final round, if the provider returned any.
  /// Persisted with the assistant message so later tool requests can pass
  /// it back; null when the round had no reasoning content.
  final String? reasoning;

  /// Display-only trace across rounds; never replay this as protocol reasoning.
  final String? reasoningTrace;
}

/// Complete learning inference, including context, protocol turns and tool policy.
/// Message persistence and UI state stay with the caller; DB tool writes retain
/// the existing transactional stores and explicit confirmation interface.
class LearningRun {
  LearningRun(
    this.db,
    this.files,
    this.study,
    this.practice,
    this.review,
    this.provider, {
    PythonTool? pythonTool,
    this.visual,
    this.a2ui,
  }) : python = pythonTool ?? PythonTool(db, files.root);
  final AppDatabase db;
  final AttachmentStore files;
  final StudyStore study;
  final PracticeStore practice;
  final ReviewStore review;
  final ChatProvider provider;
  final PythonTool python;

  /// Null in tests that do not wire a visual store; `create_visual` is
  /// then never offered, so the dispatch branch stays unreachable.
  final VisualStore? visual;
  final ChatA2uiStore? a2ui;

  Future<LearningRunResult> run({
    required String sessionId,
    required String runId,
    required ProviderConfig requestConfig,
    required PromptSettings requestPrompts,
    required List<ChatMessage> history,
    required List<Attachment> images,
    required String mode,
    required bool authorized,
    bool enableConversationTitle = false,
    bool? drawingOverride,
    bool? a2uiOverride,
    required CancelToken cancel,
    required Future<bool> Function(
      String name,
      Map<String, dynamic> args,
      int imageCount,
    )
    confirm,
    required Future<void> Function(LearningRunResult progress) onProgress,
  }) async {
    Timer deadline() =>
        Timer(const Duration(minutes: 3), () => cancel.cancel('timeout'));
    var timer = deadline();
    Future<bool> approve(
      String name,
      Map<String, dynamic> args,
      int count,
    ) async {
      // Human review time is not inference time. Stop remains available.
      timer.cancel();
      try {
        return await confirm(name, args, count);
      } finally {
        timer = deadline();
      }
    }

    var text = '';
    int? tokens;
    var quizCreated = false,
        visualCreated = false,
        regionsCreated = false,
        studyChanged = false,
        pythonExecuted = false;
    String? lastRoundReasoning;
    String? generatedTitle;
    var titleRequestPending =
        enableConversationTitle && requestConfig.kind == 'deepseek';
    var activeReasoning = '', trace = '';
    var exam = mode == 'exam';
    var surfaceCreated = false, surfaceInsertedEver = false;
    Future<void> publish({bool surfaceInserted = false}) => onProgress(
      LearningRunResult(
        text: exam ? (quizCreated ? '先独立尝试下面的题目。提交后查看参考答案与解析。' : '') : text,
        tokens: tokens,
        quizCreated: quizCreated,
        visualCreated: visualCreated,
        surfaceInserted: surfaceInserted,
        reasoning: activeReasoning.isEmpty ? null : activeReasoning,
        reasoningTrace: trace.isEmpty ? null : trace,
        title: generatedTitle,
      ),
    );
    try {
      final prepared = await _prepareRound(
        sessionId: sessionId,
        runId: runId,
        requestConfig: requestConfig,
        requestPrompts: requestPrompts,
        history: history,
        images: images,
        mode: mode,
        authorized: authorized,
        drawingOverride: drawingOverride,
        a2uiOverride: a2uiOverride,
        cancel: cancel,
        approve: approve,
      );
      var request = prepared.request;
      exam = prepared.exam;
      final (
        :quizEnabled,
        :drawingEnabled,
        :a2uiEnabled,
        :visualTools,
        :studyTask,
        :runner,
        :contextRun,
        :sourceImages,
        request: _,
        exam: _,
      ) = prepared;
      final conversation = provider.start(requestConfig);
      var selectedKnowledgeRead = false;
      var callsUsed = 0;
      final maxToolCalls = await loadMaxToolCalls(db);
      // Every invocation counts, including discovery and each call in a batch.
      // Zero disables only this count limit, never cancellation or the deadline.
      while (true) {
        cancel.checkCancelled();
        final calls = <ToolCall>[];
        // Rounds that called create_visual are accounted under
        // 'visual_create' and rounds that called update_visual under
        // 'visual_edit' instead of the default 'chat' category.
        // get_visual is read-only and stays under 'chat'. A round that
        // created a quiz with a visual attached is 'quiz_with_visual':
        // the args are machine-generated JSON, so parse them and check
        // for a non-empty 'visual_id' — a substring match would also
        // fire on '"visual_id": null'.
        String usageFeature() => calls.any((c) => c.name == createA2uiName)
            ? 'a2ui_create'
            : calls.any((c) => c.name == 'update_visual')
            ? 'visual_edit'
            : calls.any((c) => c.name == 'create_visual')
            ? 'visual_create'
            : calls.any((c) {
                if (c.name != 'create_quiz') return false;
                try {
                  final args = jsonDecode(c.arguments) as Map;
                  final visualId = args['visual_id'];
                  return (visualId is String && visualId.isNotEmpty) ||
                      args['question_scene'] is Map;
                } catch (_) {
                  return false;
                }
              })
            ? 'quiz_with_visual'
            : 'chat';
        var roundText = '';
        var roundReasoning = '';
        activeReasoning = '';
        var traceStarted = false;
        var roundTokens = 0;
        var completed = false;
        AiTokenUsage? roundUsage;
        final requestStartedAt = DateTime.now();
        final roundRequest = request.copyWith(
          enableConversationTitle: titleRequestPending,
        );
        titleRequestPending = false;
        await contextRun?.request(roundRequest);
        final requestImageCount = request.messages.fold<int>(
          0,
          (count, message) => count + message.images.length,
        );
        try {
          await for (final chunk in conversation.complete(
            roundRequest,
            cancel,
          )) {
            cancel.checkCancelled();
            final title = chunk.title?.trim();
            if (title != null && title.isNotEmpty) generatedTitle = title;
            if (chunk.usage != null) roundUsage = chunk.usage;
            text += chunk.text;
            roundText += chunk.text;
            if (chunk.reasoning.isNotEmpty) {
              if (!traceStarted && trace.isNotEmpty) trace += '\n\n---\n\n';
              traceStarted = true;
              trace += chunk.reasoning;
            }
            roundReasoning += chunk.reasoning;
            activeReasoning = roundReasoning;
            final reportedTokens = chunk.usage?.totalTokens ?? chunk.tokens;
            if (reportedTokens != null) {
              tokens = (tokens ?? 0) - roundTokens + reportedTokens;
              roundTokens = reportedTokens;
            }
            if (completed &&
                chunk.text.isEmpty &&
                chunk.reasoning.isEmpty &&
                chunk.calls.isEmpty) {
              // Duplicate completion frame (e.g. a final usage chunk restating
              // finish_reason): ignore it instead of failing the round.
              continue;
            }
            if (completed &&
                (chunk.completed ||
                    chunk.calls.isNotEmpty ||
                    chunk.text.isNotEmpty ||
                    chunk.reasoning.isNotEmpty)) {
              throw const AiFailure.localized(
                AppErrorCode.theServiceReturnedAnError,
                '服务返回错误，请检查模型配置后重试。',
              );
            }
            if (chunk.calls.isNotEmpty && !chunk.completed) {
              throw const AiFailure.localized(
                AppErrorCode.theToolResponseDidNot,
                '工具响应未正常结束，未执行本轮资料修改。',
              );
            }
            calls.addAll(chunk.calls);
            completed = completed || chunk.completed;
            await publish();
          }
        } catch (_) {
          await _recordUsage(
            actionId: runId,
            sessionId: sessionId,
            messageId: runId,
            config: requestConfig,
            feature: usageFeature(),
            status: 'error',
            startedAt: requestStartedAt,
            imageCount: requestImageCount,
            toolCallCount: calls.length,
            usage: roundUsage,
            request: roundRequest,
            response: roundText,
            reasoning: roundReasoning,
            calls: calls,
          );
          rethrow;
        }
        await _recordUsage(
          actionId: runId,
          sessionId: sessionId,
          messageId: runId,
          config: requestConfig,
          feature: usageFeature(),
          status: completed ? 'complete' : 'incomplete',
          startedAt: requestStartedAt,
          imageCount: requestImageCount,
          toolCallCount: calls.length,
          usage: roundUsage,
          request: roundRequest,
          response: roundText,
          reasoning: roundReasoning,
          calls: calls,
        );
        // Keep the reasoning of the round that just streamed, even if the
        // text is later replaced by the quiz placeholder below.
        lastRoundReasoning = roundReasoning.isEmpty ? null : roundReasoning;
        if (!completed) {
          throw const AiFailure.localized(
            AppErrorCode.theConnectionEndedEarlyReceived,
            '连接提前断开，已保留收到的内容。请重新生成。',
          );
        }
        validateToolCalls(calls);
        await contextRun?.output(
          roundText,
          roundReasoning,
          compactA2uiTranscript(calls),
        );
        if (calls.isEmpty) break;
        if (!quizEnabled ||
            calls.any(
              (call) => !request.tools.any((tool) => tool.name == call.name),
            )) {
          throw const AiFailure.localized(
            AppErrorCode.anUnavailableToolCallWas,
            '模型尝试调用未开放的工具，已阻止。',
          );
        }
        if (studyTask != null &&
            calls.any(
              (call) =>
                  call.name != 'run_python' &&
                  !(!exam &&
                      visualTools != null &&
                      {
                        enableVisualToolsName,
                        'create_visual',
                        'get_visual',
                        'update_visual',
                      }.contains(call.name)) &&
                  !studyTask.allows(call),
            )) {
          throw const AiFailure.localized(
            AppErrorCode.editingAnUnselectedItemWas,
            '已阻止修改未选中的资料，请重新发起整理。',
          );
        }
        callsUsed += calls.length;
        if (maxToolCalls > 0 && callsUsed > maxToolCalls) {
          throw AiFailure.localized(
            AppErrorCode.toolCallLimitReached,
            '已达到本次工具调用次数上限。',
            [maxToolCalls.toString()],
          );
        }
        request = request.copyWith(
          messages: [
            ...request.messages,
            AiMessage.assistant(
              roundText,
              calls: calls,
              reasoningContent: roundReasoning.isEmpty ? null : roundReasoning,
            ),
          ],
        );
        for (final call in calls) {
          cancel.checkCancelled();
          if (studyTask?.operation == 'update_knowledge' &&
              call.name == 'update_knowledge' &&
              !selectedKnowledgeRead) {
            throw const AiFailure.localized(
              AppErrorCode.theSelectedKnowledgeMustBe,
              '修改前必须完整读取所选知识；正文过长时请先手动拆分，避免覆盖未读取的内容。',
            );
          }
          // Loading is read-only protocol discovery, not a study-data write.
          // The advertised-tool guard above still applies in every mode.
          if (call.name == enableVisualToolsName && visualTools != null) {
            final wasEnabled = visualTools.enabled;
            final result = visualTools.enable(call);
            if (!wasEnabled && visualTools.enabled) {
              request = request.copyWith(
                tools: [
                  for (final tool in request.tools)
                    if (tool.name == enableVisualToolsName)
                      ...visualTools.tools
                    else if (tool.name != 'create_quiz')
                      tool,
                ],
                instructions:
                    '${request.instructions}\n${visualTools.instructions}',
              );
            }
            request = request.copyWith(
              messages: [
                ...request.messages,
                AiMessage.tool(call.id, jsonEncode(result)),
              ],
            );
            continue;
          }
          if (call.name == enableA2uiName && a2uiEnabled) {
            request = enableA2ui(request, call);
            continue;
          }
          final result = call.name == createA2uiName && a2uiEnabled
              ? await createA2ui(
                  a2ui!,
                  call,
                  sessionId: sessionId,
                  messageId: runId,
                  body: text,
                  cancel: cancel,
                )
              : await _executeTool(
                  call,
                  sessionId: sessionId,
                  runId: runId,
                  sourceImages: sourceImages,
                  cancel: cancel,
                  exam: exam,
                  drawingEnabled: drawingEnabled,
                  runner: runner,
                  approve: approve,
                );
          final createdSurface =
              call.name == createA2uiName && result['ok'] == true;
          if (createdSurface) surfaceCreated = true;
          final inserted = createdSurface && result['inserted'] == true;
          if (inserted) surfaceInsertedEver = true;
          if (studyTask?.operation == 'update_knowledge' &&
              call.name == 'get_knowledge') {
            selectedKnowledgeRead =
                result['ok'] == true &&
                result['id'] == studyTask!.knowledgeId &&
                result['truncated'] == false;
          }
          if (call.name == 'run_python' && result['ok'] == true) {
            pythonExecuted = true;
          }
          if (call.name == 'suggest_question_regions' && result['ok'] == true) {
            regionsCreated = true;
          }
          if (call.name == 'create_quiz' && result['ok'] == true) {
            quizCreated = true;
          }
          if (call.name == 'create_visual' && result['ok'] == true) {
            visualCreated = true;
          }
          // A successful study write already landed: remember it so an
          // empty final text does not report the round as failed (which
          // would invite a retry that re-executes the same write).
          if (result['ok'] == true &&
              call.name != 'suggest_question_regions' &&
              call.name != 'create_quiz' &&
              call.name != 'run_python' &&
              isWriteStudyTool(call.name)) {
            studyChanged = true;
          }
          if (inserted) await publish(surfaceInserted: true);
          cancel.checkCancelled();
          if (!inserted) await publish();
          request = request.copyWith(
            messages: [
              ...request.messages,
              AiMessage.tool(call.id, jsonEncode(result)),
            ],
          );
        }
        await contextRun?.results(
          request.messages.skip(request.messages.length - calls.length),
        );
        if (quizCreated || regionsCreated) {
          final notice = quizCreated
              ? '先独立尝试下面的题目。提交后查看参考答案与解析。'
              : '下面是图片分题建议。请检查每个范围，必要时调整后保存；原图会保留。';
          text = surfaceCreated && text.isNotEmpty
              ? '$text\n\n$notice'
              : notice;
          if (regionsCreated) study.changed();
          break;
        }
        if (text.isNotEmpty) text += '\n\n';
      }
      if (exam && !quizCreated) {
        text = '考试模式需要结构化题目，当前模型未成功创建。请重试，或切换教学模式查看文字讲解。';
      }
      if (text.trim().isEmpty && !surfaceInsertedEver) {
        if (visualCreated) {
          text = lookupAppLocalizations(
            requestPrompts.language == 'en'
                ? const Locale('en')
                : const Locale('zh'),
          ).visualCreatedMessage;
        } else if (studyChanged) {
          // The write already landed; report success with a placeholder
          // instead of an error that would invite a duplicate retry.
          text = '已保存，可在知识库查看。';
        } else if (pythonExecuted) {
          text = 'Python 执行完成，可展开查看代码和结果。';
        } else {
          throw const AiFailure.localized(
            AppErrorCode.theModelReturnedNoDisplayable,
            '模型没有返回可显示的正文，请重试。',
          );
        }
      }
      await publish();
      return LearningRunResult(
        text: text,
        tokens: tokens,
        quizCreated: quizCreated,
        visualCreated: visualCreated,
        reasoning: lastRoundReasoning,
        reasoningTrace: trace.isEmpty ? null : trace,
        title: generatedTitle,
      );
    } finally {
      timer.cancel();
    }
  }
}
