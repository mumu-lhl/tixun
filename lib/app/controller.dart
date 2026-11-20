import "../features/timeline/timeline_store.dart";

import "package:tixun/core/l10n/app_error.dart";

import "app_notice.dart";
import "../features/scratchpad/scratch_store.dart";
import "../features/exams/exam_store.dart";
import "../features/library/module_store.dart";

import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:drift/drift.dart" hide Column;
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/legacy.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:uuid/uuid.dart";

import "preferences.dart";

import "../core/ai/chat_provider.dart";
import "../core/ai/chatgpt/usage.dart";
import "../core/ai/provider_balance.dart";
import "../core/ai/ai_usage_store.dart";
import "../core/ai/chatgpt/auth.dart";
import "../core/ai/chatgpt/responses.dart";
import "../core/ai/prompt_settings.dart";
import "../core/ai/study_write_task.dart";
import "../core/ai/study_tools.dart";
import "../core/database/attachment_cleanup.dart";
import "../core/database/database.dart";
import "../core/l10n/app_strings.dart";
import "../core/l10n/generated/app_localizations.dart";
import "../core/platform/attachment_store.dart";
import "../core/platform/attachment_selection.dart";
import "../core/platform/key_store.dart";
import "../features/language_learning/language_store.dart";
import "../features/library/study_store.dart";
import "../features/practice/practice_store.dart";
import "../features/chat/learning_run.dart";
import "../features/a2ui/a2ui_store.dart";
import "../features/a2ui/a2ui_tools.dart";
import "../features/chat/chat_branch_store.dart";
import "../features/chat/chat_failure.dart";
import "../features/progress/learning_profile.dart";
import "../features/review/review_store.dart";
import "../features/visual/visual_store.dart";

part "controller_chat_sessions.dart";
part "controller_chat_generation.dart";
part "controller_demo.dart";
part "controller_practice_setup.dart";

typedef _PreparedGeneration = ({
  String sessionId,
  bool enableConversationTitle,
});

final appControllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => throw StateError("AppController must be initialized"),
);

class AppController extends ChangeNotifier {
  AppController(
    this.db,
    this.files,
    this.keys,
    this.provider, {
    this.demo = false,
  });
  final AppDatabase db;
  final AttachmentStore files;
  final KeyStore keys;
  final ChatProvider provider;
  late final ChatGptAuth chatGpt = provider is RoutedChatProvider
      ? (provider as RoutedChatProvider).chatGpt
      : ChatGptAuth(keys);
  final bool demo;
  late final LanguageLearningStore language = LanguageLearningStore(db);
  late final StudyStore study = StudyStore(db, files);
  late final ExamStore exams = ExamStore(db, files);
  late final TimelineStore timeline = TimelineStore(db);
  late final ScratchStore scratch = ScratchStore(db);
  late final ReviewStore review = ReviewStore(db);
  late final VisualStore visual = VisualStore(db);
  late final ChatA2uiStore a2ui = ChatA2uiStore(db);
  late final PracticeStore practice = PracticeStore(
    db,
    files: files,
    visual: visual,
  )..onGraded = review.record;
  late final LearningRun learningRun = LearningRun(
    db,
    files,
    study,
    practice,
    review,
    provider,
    visual: visual,
    a2ui: a2ui,
  );
  ToolApproval? pendingTool;
  Completer<bool>? _toolDecision;
  late final AppPreferences preferences = AppPreferences(db, keys, demo: demo)
    ..addListener(changed);
  ProviderConfig get config => preferences.config;
  set config(ProviderConfig value) => preferences.config = value;
  PromptSettings get prompts => preferences.prompts;
  set prompts(PromptSettings value) => preferences.prompts = value;
  String sessionReasoning = "";
  Set<StudyToolCategory> studyToolCategories = allStudyToolCategories;
  String get languageChoice => preferences.languageChoice;
  bool get dynamicColors => preferences.dynamicColors;
  bool get aiDrawingEnabled => preferences.aiDrawingEnabled;
  Future<void> setAiDrawingEnabled(bool value) =>
      preferences.setAiDrawingEnabled(value);

  bool? sessionDrawingOverride;
  bool get sessionDrawingEnabled => sessionDrawingOverride ?? aiDrawingEnabled;
  Future<void> setSessionDrawingEnabled(bool? value) {
    final id = selected?.id;
    if (_disposed || busy || id == null) return Future.value();
    sessionDrawingOverride = value;
    changed();
    return preferences.runOperation(
      () => db.setPreference("ai_drawing:$id", value?.toString() ?? ""),
    );
  }

  bool get aiA2uiEnabled => preferences.aiA2uiEnabled;
  Future<void> setAiA2uiEnabled(bool value) =>
      preferences.setAiA2uiEnabled(value);
  bool? sessionA2uiOverride;
  bool get sessionA2uiEnabled => sessionA2uiOverride ?? aiA2uiEnabled;
  Future<void> setSessionA2uiEnabled(bool? value) async {
    final id = selected?.id;
    if (_disposed || busy || id == null) return;
    await preferences.saveChatA2uiOverride(id, value);
    if (_disposed || selected?.id != id) return;
    sessionA2uiOverride = value;
    changed();
  }

  int get maxToolCalls => preferences.maxToolCalls;
  Future<void> setMaxToolCalls(int value) => preferences.setMaxToolCalls(value);

  int get maxContextTokens => preferences.maxContextTokens;
  Future<void> setMaxContextTokens(int value) =>
      preferences.setMaxContextTokens(value);
  Locale? get appLocale => preferences.appLocale;
  String get promptLanguage => preferences.promptLanguage;
  AppLocalizations get l10n => preferences.l10n;
  ProviderConfig get sessionConfig =>
      AiOptions.forSession(config, sessionReasoning);

  List<ChatSession> sessions = [];
  List<ChatSession> allSessions = [];
  List<ChatMessage> messages = [];
  List<Attachment> attachments = [];
  ChatSession? selected;
  ThemeMode get themeMode => preferences.themeMode;
  bool busy = false;
  AppTransientError? error;
  CancelToken? _cancel;
  Future<void>? _generation;
  Completer<void>? _preparation;
  int _epoch = 0;
  bool _disposed = false;
  String search = "";
  String? searchTargetMessageId;
  int searchTargetRevision = 0;

  void showSearchMessage(String sessionId, String messageId) {
    if (selected?.id != sessionId || !messages.any((m) => m.id == messageId)) {
      return;
    }
    searchTargetMessageId = messageId;
    searchTargetRevision++;
    changed();
  }

  AppNotice? notice;
  List<String> get learningSubjects => preferences.learningSubjects;
  Future<void> setLearningSubjects(List<String> values) async {
    await preferences.saveSubjects(values, currentFilter: subjectFilter);
    if (subjectFilter.isNotEmpty && !learningSubjects.contains(subjectFilter)) {
      subjectFilter = "";
    }
    await reload();
  }

  // Global subject filter: empty means all records; configured custom subjects
  // are supported alongside the built-in school subjects.
  // Persisted under 'subject_filter'; sessions, library, mistakes,
  // practice and review all follow it.
  String subjectFilter = "";

  List<ChatSession> _visibleSessions(List<ChatSession> rows) =>
      subjectFilter.isEmpty
      ? rows
      : rows.where((s) => s.subject == subjectFilter).toList();

  Future<void> setSubjectFilter(String value) async {
    if (value != "" &&
        !schoolSubjects.contains(value) &&
        !learningSubjects.contains(value)) {
      throw const AppFormatException(AppErrorCode.errorInvalidSubject, "科目无效。");
    }
    if (value == subjectFilter) return;
    subjectFilter = value;
    await db.setPreference("subject_filter", value);
    await reload();
  }

  // Session subjects are free text like knowledge subjects (custom
  // subjects are allowed); configured custom subjects are also filterable.
  Future<void> setSessionSubject(ChatSession s, String subject) async {
    await db.setSessionSubject(s.id, subject);
    await reload();
    if (selected?.id == s.id) {
      selected = selected!.copyWith(subject: Value(subject));
      changed();
    }
  }

  void changed() {
    if (!_disposed) notifyListeners();
  }

  static Future<Directory> rootDirectory({required bool demo}) async {
    if (demo) return Directory.systemTemp.createTemp("tixun-demo-");
    return Directory(
      p.join((await getApplicationSupportDirectory()).path, "tixun"),
    );
  }

  static Future<AppController> open({required bool demo}) async {
    return openRoot(await rootDirectory(demo: demo), demo: demo, seed: true);
  }

  static Future<AppController> openRoot(
    Directory root, {
    required bool demo,
    bool seed = false,
    KeyStore? keyStore,
    ChatProvider? chatProvider,
  }) async {
    await root.create(recursive: true);
    final db = demo && seed
        ? AppDatabase.memory()
        : AppDatabase.file(File(p.join(root.path, "tixun.sqlite")));
    final actualKeys =
        keyStore ?? (demo ? MemoryKeyStore() : const SecureKeyStore());
    final c = AppController(
      db,
      AttachmentStore(root),
      actualKeys,
      chatProvider ??
          (demo
              ? MockChatProvider()
              : RoutedChatProvider(ChatGptAuth(actualKeys), keys: actualKeys)),
      demo: demo,
    );
    try {
      await c.initialize(seed: seed);
    } catch (_) {
      c.dispose();
      await db.close();
      rethrow;
    }
    return c;
  }

  Future<void> initialize({bool seed = true}) async {
    await preferences.load();
    await AiUsageStore(db).ensureBuiltinPrices();
    notice = preferences.loadNotice;
    final savedSubject = await db.preference("subject_filter");
    if (savedSubject != null &&
        (savedSubject.isEmpty ||
            schoolSubjects.contains(savedSubject) ||
            learningSubjects.contains(savedSubject))) {
      subjectFilter = savedSubject;
    }
    if (demo && seed) {
      await seedDemo();
      await preferences.loadSubjects();
    }
    await reload();
    final lastId = await db.preference("selected_session");
    // A list filter must not prevent restoring a conversation that still exists.
    final last = allSessions.where((s) => s.id == lastId).firstOrNull;
    if (last != null) await selectSession(last);
  }

  Future<void> seedDemo() => _seedDemo(db, study, files);

  Future<void>? _subjectChatPreparation;

  Future<void> reload() => _ChatSessions(this)._reloadImpl();

  Future<void> searchSessions(String value) =>
      _ChatSessions(this)._searchSessionsImpl(value);

  Future<void> selectSession(ChatSession session) =>
      _ChatSessions(this)._selectSessionImpl(session);

  /// Main chat entry follows the subject selected on the study page. Filtering
  /// alone does not interrupt a conversation, and explicit history/source links
  /// continue to open the exact session the user selected.
  Future<void> prepareSubjectChat() =>
      _ChatSessions(this)._prepareSubjectChatImpl();

  Future<void> newSession() => _ChatSessions(this)._newSessionImpl();

  Future<void> renameSession(ChatSession s, String title) =>
      _ChatSessions(this)._renameSessionImpl(s, title);

  Future<void> deleteSession(ChatSession s) =>
      _ChatSessions(this)._deleteSessionImpl(s);

  Future<void> restoreSession(ChatSession s) =>
      _ChatSessions(this)._restoreSessionImpl(s);

  Future<int> purgeSession(String id) =>
      _ChatSessions(this)._purgeSessionImpl(id);

  Future<void> draft(String value) => _ChatSessions(this)._draftImpl(value);

  Future<void> setLanguage(String value) => preferences.setLanguage(value);
  Future<void> setDynamicColors(bool value) =>
      preferences.setDynamicColors(value);
  Future<void> savePrompt(String id, String value) =>
      preferences.savePrompt(id, value);

  Future<void> setSessionReasoning(String value) =>
      _ChatGeneration(this)._setSessionReasoningImpl(value);

  Future<void> useToolReasoning() =>
      _ChatGeneration(this)._useToolReasoningImpl();

  /// Quiz preparation turns thinking on for this session only, at the
  /// effort configured in Settings, when the model supports thinking with
  /// tools. Providers that don't (compatible) still force it off.
  Future<void> useQuizReasoning() =>
      _ChatGeneration(this)._useQuizReasoningImpl();

  Future<void> setTools(bool enabled) =>
      _ChatGeneration(this)._setToolsImpl(enabled);

  Future<void> setStudyToolCategories(Set<StudyToolCategory> categories) =>
      _ChatGeneration(this)._setStudyToolCategoriesImpl(categories);

  void decideTool(bool approve) =>
      _ChatGeneration(this)._decideToolImpl(approve);

  Future<void> mode(String value) => _ChatSessions(this)._modeImpl(value);

  Future<Attachment> addImage(String path) =>
      _ChatSessions(this)._addImageImpl(path);

  Future<String> replaceDraftImage(Attachment image, Uint8List bytes) =>
      _ChatSessions(this)._replaceDraftImageImpl(image, bytes);

  Future<void> removeImage(Attachment image) =>
      _ChatSessions(this)._removeImageImpl(image);

  Future<void> send(String input) => _ChatGeneration(this)._sendImpl(input);

  Future<void> prepareQuickQuiz() =>
      _PracticeSetup(this)._prepareQuickQuizImpl();

  Future<void> prepareModulePractice(
    String moduleId, {
    required bool mistake,
  }) =>
      _PracticeSetup(this)
          ._prepareModulePracticeImpl(moduleId, mistake: mistake);

  /// Called only after the UI's task dialog authorizes this focused session.
  /// Preparation persists a draft; callers open Chat before awaiting send.
  Future<String> prepareStudyWriting({
    String? sourceMessageId,
    String? knowledgeId,
    bool mistake = false,
    required String instruction,
  }) => _PracticeSetup(this)._prepareStudyWritingImpl(
    sourceMessageId: sourceMessageId,
    knowledgeId: knowledgeId,
    mistake: mistake,
    instruction: instruction,
  );

  Future<void> prepareKnowledgePractice(List<String> ids) =>
      _PracticeSetup(this)._prepareKnowledgePracticeImpl(ids);

  Future<void> prepareVariant(QuestionDetail detail) =>
      _PracticeSetup(this)._prepareVariantImpl(detail);

  Future<void> stop() => _ChatGeneration(this)._stopImpl();

  Future<void> regenerate() => _ChatGeneration(this)._regenerateImpl();

  /// Fork without inference; the chosen message is included in the prefix.
  Future<void> forkChat(ChatMessage message) =>
      _ChatSessions(this)._forkChatImpl(message);

  Future<void> editAndResend(ChatMessage message, String text) =>
      _ChatSessions(this)._editAndResendImpl(message, text);

  Future<void> saveSettings(ProviderConfig next, String? key) =>
      preferences.saveSettings(next, key);
  Future<bool> hasApiKey(ProviderConfig provider) =>
      preferences.hasApiKey(provider);

  late final _quotaClient = ChatGptUsageClient(auth: chatGpt);
  late final _balanceClient = ProviderBalanceClient();

  ChatGptQuota? get cachedChatGptQuota => _quotaClient.cached;

  Future<ChatGptQuota> chatGptQuota({
    ChatGptUsageClient? client,
    bool refresh = false,
  }) => (client ?? _quotaClient).fetch(refresh: refresh);

  Future<ProviderBalance?> cachedProviderBalance(
    ProviderConfig candidate,
  ) async => _balanceClient.cached(
    baseUrl: candidate.baseUrl,
    apiKey: await keys.read(providerKeyId(candidate)) ?? "",
  );

  /// Reads the provider's own account balance. Only DeepSeek documents such an
  /// endpoint; the key is used here so the UI never has to read it itself.
  Future<ProviderBalance> providerBalance(
    ProviderConfig candidate, {
    String? key,
    ProviderBalanceClient? client,
    bool refresh = false,
  }) async {
    if (candidate.kind != "deepseek") {
      throw const AiFailure.localized(
        AppErrorCode.thisProviderHasNoBalanceEndpoint,
        "该服务商没有提供查询余额的公开接口。",
      );
    }
    final typed = key?.trim() ?? "";
    final apiKey = typed.isNotEmpty
        ? typed
        : await keys.read(providerKeyId(candidate)) ?? "";
    return (client ?? _balanceClient).deepSeek(
      baseUrl: candidate.baseUrl,
      apiKey: apiKey,
      refresh: refresh,
    );
  }

  Future<void> restoreApiProvider() async {
    await stop();
    await preferences.restoreApiProvider();
  }

  Future<void> testConnection(
    ProviderConfig candidate,
    String? key, {
    CancelToken? cancellation,
  }) async {
    validateConfig(candidate);
    final cancel = cancellation ?? CancelToken();
    final timer = Timer(
      const Duration(seconds: 35),
      () => cancel.cancel("timeout"),
    );
    final actionId = const Uuid().v4();
    final startedAt = DateTime.now();
    AiTokenUsage? usage;
    var requestStatus = "error";
    final request = AiRequest(
      instructions: "",
      messages: [const AiMessage.user("只回复 OK")],
      maxOutputTokens: 16,
    );
    final text = StringBuffer();
    final reasoning = StringBuffer();
    try {
      await for (final chunk
          in provider
              .start(
                candidate,
                apiKeyOverride: key?.trim().isNotEmpty == true
                    ? key!.trim()
                    : null,
              )
              .complete(request, cancel)) {
        if (chunk.usage != null) usage = chunk.usage;
        text.write(chunk.text);
        reasoning.write(chunk.reasoning);
        if (text.isNotEmpty && chunk.completed && chunk.calls.isEmpty) {
          requestStatus = "complete";
        }
      }
      if (requestStatus == "complete") return;
      throw const AiFailure.localized(
        AppErrorCode.connectedButNoResponseText,
        "连接成功但没有收到正文。",
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        throw cancel.cancelError?.error == "timeout"
            ? const AiFailure.localized(
                AppErrorCode.theResponseTimedOutReceived,
                "等待回复超时，已保留收到的内容。",
              )
            : const AiFailure.localized(
                AppErrorCode.connectionTestCancelled,
                "连接测试已取消。",
              );
      }
      rethrow;
    } finally {
      timer.cancel();
      if (provider is! MockChatProvider) {
        try {
          await AiUsageStore(db).record(
            AiUsageCapture(
              actionId: actionId,
              providerKind: candidate.kind,
              endpoint: candidate.baseUrl,
              model: candidate.model,
              feature: "connection_test",
              status: requestStatus,
              occurredAt: startedAt,
              durationMs: DateTime.now().difference(startedAt).inMilliseconds,
              usage: usage,
            ),
            request: request,
            response: text.toString(),
            reasoning: reasoning.toString(),
          );
        } catch (_) {
          // A usage write must not override the connection-test result.
        }
      }
    }
  }

  Future<void> theme(ThemeMode value) => preferences.theme(value);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scratch.dispose();
    exams.dispose();
    timeline.dispose();
    preferences.dispose();
    language.dispose();
    study.modules.dispose();
    study.dispose();
    practice.dispose();
    visual.dispose();
    review.dispose();
    _cancel?.cancel();
    chatGpt.cancelLogin();
    super.dispose();
  }

  Future<void> shutdown() async {
    await stop();
    await practice.flushDrafts();
    await scratch.flush();
    await exams.whenIdle;
    await timeline.whenIdle;
    await preferences.whenIdle;
    await language.whenIdle;
    await study.modules.whenIdle;
    await study.whenIdle;
    await practice.whenIdle;
    await visual.whenIdle;
    await review.whenIdle;
    dispose();
    await db.close();
    if (demo && await files.root.exists()) {
      await files.root.delete(recursive: true);
    }
  }
}

class ToolApproval {
  const ToolApproval(
    this.name,
    this.arguments,
    this.target, [
    this.imageCount = 0,
  ]);
  final String name, target;
  final int imageCount;
  final Map<String, dynamic> arguments;
}
