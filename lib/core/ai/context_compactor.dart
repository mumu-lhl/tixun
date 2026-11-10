import 'dart:async';

import 'package:dio/dio.dart';

import '../database/database.dart';
import 'ai_types.dart';
import 'chat_provider.dart';
import 'token_estimator.dart';

/// Context budgeting and compression for long chat sessions.
///
/// The old design capped context at the newest 30 messages / 32000 chars,
/// which silently dropped old turns. The new design budgets by estimated
/// tokens (the unit providers bill and limit by) and, when the budget is
/// exceeded, summarizes the oldest turns with the model itself — the same
/// "summary buffer" shape pi, Claude Code, Codex and OpenCode use:
/// a stored summary for the distant past plus the recent turns verbatim.
///
/// Token counting is deliberately an ESTIMATE (see `token_estimator.dart`):
/// there is no tokenizer in the app, and exact counts are unnecessary —
/// the estimate only decides when to summarize. The provider's real
/// context window is the final backstop, and a failed summarization
/// degrades to dropping the oldest turns instead of bricking the send.

/// Default maximum context tokens (user setting `max_context_tokens`).
const int kDefaultMaxContextTokens = 128000;

/// Bounds for the user setting.
const int kMinMaxContextTokens = 4096;
const int kMaxMaxContextTokens = 1048576;

/// Tokens held back from the budget for the model's reply: input and
/// output share the model window, so the context must leave room to answer.
const int kResponseReserveTokens = 4096;

/// Tokens held back for the system instructions (teaching prompt + state).
const int kInstructionReserveTokens = 1200;

/// Tokens of recent turns that stay verbatim after a compaction.
const int kKeepRecentTokens = 20000;

/// How many tokens of older turns one summarization call may swallow, so
/// a single summary request never carries an unbounded input.
const int kSummaryInputTokens = 16000;

/// Output cap for a summarization call, keeping the stored summary short.
const int kSummaryOutputTokens = 2000;

/// Rough token cost of one attached image in the estimate.
const int kTokensPerImageEstimate = 1000;

/// At most this many summarization rounds per send; anything still over
/// budget after that falls back to dropping the oldest turns.
const int kMaxCompactionRounds = 3;

/// Context window per model id, per the providers' docs (2026-11).
/// DeepSeek V4 family (deepseek-flash, deepseek-v4-pro): 1M tokens.
/// Legacy deepseek-chat / deepseek-reasoner (V3.2): 128K.
/// GPT-5 family: 400K. GPT-4o / GPT-4-turbo: 128K. o1/o3/o4: 200K.
/// Unknown model ids return null: no window cap, the user setting governs.
int? modelContextWindow(ProviderConfig config) {
  final model = config.model;
  if (model == 'deepseek-flash' ||
      model == 'deepseek-v4-pro' ||
      model == 'deepseek-v4-flash') {
    return 1000000;
  }
  if (model == 'deepseek-chat' || model == 'deepseek-reasoner') {
    return 131072;
  }
  if (model.startsWith('gpt-5')) return 400000;
  if (model.startsWith('gpt-4o') || model.startsWith('gpt-4-turbo')) {
    return 131072;
  }
  if (model.startsWith('o1') ||
      model.startsWith('o3') ||
      model.startsWith('o4')) {
    return 200000;
  }
  return null;
}

/// The token budget this request may spend on context, after reserving
/// room for the reply. Never below half the cap, so a small user setting
/// still leaves a usable window instead of collapsing to zero.
int effectiveContextBudget({
  required ProviderConfig config,
  required int maxContextTokens,
}) {
  final window = modelContextWindow(config);
  final cap = window == null || maxContextTokens < window
      ? maxContextTokens
      : window;
  final budget = cap - kResponseReserveTokens;
  return budget >= 1024 ? budget : cap ~/ 2;
}

/// Read the user's maximum-context-tokens setting; the default applies
/// when nothing is stored or the stored value does not parse.
Future<int> loadMaxContextTokens(AppDatabase db) async {
  final raw = await db.preference('max_context_tokens');
  final parsed = raw == null ? null : int.tryParse(raw.trim());
  if (parsed == null) return kDefaultMaxContextTokens;
  return parsed.clamp(kMinMaxContextTokens, kMaxMaxContextTokens);
}

bool isValidMaxContextTokens(int value) =>
    value >= kMinMaxContextTokens && value <= kMaxMaxContextTokens;

/// Newest-first selection within a token budget. The newest user message
/// and anything after it is the current request, not history: it is
/// always kept whole, even if it alone exceeds the budget. The selection
/// is a contiguous suffix of the history starting with a user message;
/// incomplete assistant messages are never sent.
List<ChatMessage> selectRecentWithinBudget(
  List<ChatMessage> history, {
  required int tokenBudget,
}) {
  final newestUser = history.lastIndexWhere((m) => m.role == 'user');
  final selected = <ChatMessage>[];
  var tokens = 0;
  for (var i = history.length - 1; i >= 0; i--) {
    final m = history[i];
    if (m.role == 'assistant' && m.status != 'complete') continue;
    final cost =
        estimateTokens(m.content) +
        (m.role == 'assistant' ? estimateTokens(m.reasoningContent ?? '') : 0);
    if (newestUser >= 0 && i >= newestUser) {
      selected.insert(0, m);
      tokens += cost;
      continue;
    }
    if (tokens + cost > tokenBudget && selected.isNotEmpty) break;
    selected.insert(0, m);
    tokens += cost;
  }
  while (selected.isNotEmpty && selected.first.role != 'user') {
    selected.removeAt(0);
  }
  return selected;
}

/// The section appended to the system instructions carrying the stored
/// summary. It is instructions, not a message, so the message list stays
/// positionally aligned with the persisted history (the quiz-state
/// annotations in `LearningRun` index into it).
String contextSummarySection(String summary, {required bool english}) => english
    ? '[Context summary: the summary below covers earlier turns; the recent turns that follow are verbatim.]\n$summary'
    : '[上下文摘要：以下为较早对话的摘要，供参考；最近的对话以原文为准。]\n$summary';

class CompactedContext {
  const CompactedContext({
    required this.selected,
    this.summary,
    this.droppedUncovered = 0,
  });

  /// History to send verbatim, newest-complete-turns-first within budget.
  final List<ChatMessage> selected;

  /// Stored summary of everything older than [selected], if any.
  final String? summary;

  /// Turns dropped by the token budget that no summary covers. These are
  /// the only ones the request note may report as skipped.
  final int droppedUncovered;
}

/// Build the context for one send: summarize the oldest turns when the
/// projected size exceeds the budget, otherwise keep everything verbatim.
/// The stored summary and its watermark advance one chunk at a time and
/// are persisted on the session, so later sends reuse them instead of
/// re-summarizing. A failed summarization never fails the send: it falls
/// through to dropping the oldest turns.
Future<CompactedContext> compactContext({
  required AppDatabase db,
  required String sessionId,
  required List<ChatMessage> history,
  required List<Attachment> images,
  required ProviderConfig config,
  required ChatProvider provider,
  required int maxContextTokens,
  required CancelToken cancel,
  String language = 'zh',
}) async {
  final session = await (db.select(
    db.chatSessions,
  )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
  if (session == null) throw const AiFailure('会话不存在，请重新选择会话。');
  final budget = effectiveContextBudget(
    config: config,
    maxContextTokens: maxContextTokens,
  );
  final messageBudget = budget - kInstructionReserveTokens;
  var summary = session.contextSummary;
  var upToId = session.contextSummaryUpToId;

  int watermarkIndex() =>
      upToId == null ? -1 : history.indexWhere((m) => m.id == upToId);

  int projectedTokens() {
    // Real usage from the last turn (pi-style trigger) refined by the
    // estimate of the message just sent; the full-history estimate is
    // the fallback for early turns with no usage yet.
    var projected =
        estimateTokens(summary ?? '') + images.length * kTokensPerImageEstimate;
    for (final m in history) {
      projected += estimateTokens(m.content);
      if (m.role == 'assistant') {
        projected += estimateTokens(m.reasoningContent ?? '');
      }
    }
    int? lastUsage;
    for (var i = history.length - 1; i >= 0; i--) {
      final m = history[i];
      if (m.role == 'assistant' && m.totalTokens != null) {
        lastUsage = m.totalTokens;
        break;
      }
    }
    final newestUser = history.lastIndexWhere((m) => m.role == 'user');
    if (lastUsage != null && newestUser >= 0) {
      final viaUsage = lastUsage + estimateTokens(history[newestUser].content);
      if (viaUsage > projected) projected = viaUsage;
    }
    return projected;
  }

  var rounds = 0;
  while (projectedTokens() > messageBudget && rounds < kMaxCompactionRounds) {
    rounds++;
    final keepRecent = (messageBudget ~/ 4).clamp(
      kMinMaxContextTokens,
      kKeepRecentTokens,
    );
    final recent = selectRecentWithinBudget(history, tokenBudget: keepRecent);
    final recentIds = recent.map((m) => m.id).toSet();
    // Oldest unsummarized turns first, bounded so one summary call never
    // swallows an unbounded input; the rest waits for the next round.
    final toSummarize = <ChatMessage>[];
    var chunkTokens = 0;
    for (var i = watermarkIndex() + 1; i < history.length; i++) {
      final m = history[i];
      if (recentIds.contains(m.id)) break;
      if (m.role == 'assistant' && m.status != 'complete') continue;
      final cost = estimateTokens(m.content);
      if (toSummarize.isNotEmpty && chunkTokens + cost > kSummaryInputTokens) {
        break;
      }
      toSummarize.add(m);
      chunkTokens += cost;
    }
    if (toSummarize.isEmpty) break;
    String chunkSummary;
    try {
      chunkSummary = await _summarize(
        provider,
        config,
        toSummarize,
        language: language,
        cancel: cancel,
      );
    } catch (_) {
      // Summarization failed: keep the old summary and fall through to
      // the drop-oldest fallback below instead of failing the send.
      break;
    }
    summary = summary == null || summary.isEmpty
        ? chunkSummary
        : '$summary\n$chunkSummary';
    upToId = toSummarize.last.id;
    await db.setContextSummary(sessionId, summary, upToId);
  }

  final summaryTokens = estimateTokens(summary ?? '');
  // Only the turns the summary does NOT cover may go out verbatim:
  // sending the summarized turns again would make the summary pure
  // overhead instead of a saving.
  final unsummarized = history.sublist(watermarkIndex() + 1);
  final selected = selectRecentWithinBudget(
    unsummarized,
    tokenBudget: messageBudget - summaryTokens,
  );
  final selectedIds = selected.map((m) => m.id).toSet();
  var droppedUncovered = 0;
  for (final m in unsummarized) {
    if (m.role == 'assistant' && m.status != 'complete') continue;
    if (!selectedIds.contains(m.id)) droppedUncovered++;
  }
  return CompactedContext(
    selected: selected,
    summary: summary,
    droppedUncovered: droppedUncovered,
  );
}

String _summaryPrompt(bool english) => english
    ? 'You are summarizing an earlier study conversation for the teacher who will continue with the same student. Keep the topics and chapters covered, the key formulas and conclusions, the student\'s weak points and causes of errors, decisions already made, and any unresolved questions. Do not invent content, do not repeat the full text, stay under 1500 words. Output only the summary.'
    : '你是一名学习对话的摘要员。请把下面较早的对话轮次压缩成一份简要摘要，供继续辅导同一名学生的老师参考：保留已覆盖的知识点与章节、关键公式与结论、学生已暴露的薄弱点与错因、已达成的约定或决定、以及未解决的问题。不要编造内容，不要重复逐字原文，控制在 1500 字以内。只输出摘要本身。';

Future<String> _summarize(
  ChatProvider provider,
  ProviderConfig config,
  List<ChatMessage> turns, {
  required String language,
  required CancelToken cancel,
}) async {
  final request = AiRequest(
    instructions: _summaryPrompt(language == 'en'),
    messages: [
      for (final m in turns)
        m.role == 'user'
            ? AiMessage.user(m.content)
            : AiMessage.assistant(m.content),
    ],
    maxOutputTokens: kSummaryOutputTokens,
  );
  // No tools and no thinking: the summary is a plain completion, the same
  // way pi summarizes through its core client.
  final conversation = provider.start(config.copyWith(thinking: false));
  final buffer = StringBuffer();
  await for (final chunk in conversation.complete(request, cancel)) {
    buffer.write(chunk.text);
  }
  final summary = buffer.toString().trim();
  if (summary.isEmpty) throw const AiFailure('摘要为空，未压缩上下文。');
  return summary;
}
