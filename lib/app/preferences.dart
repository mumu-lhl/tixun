import "package:tixun/core/l10n/app_error.dart";

import "app_notice.dart";
import "../features/a2ui/a2ui_tools.dart";
import "../features/language_learning/language_subject.dart";

import "dart:convert";
import "dart:ui" show PlatformDispatcher;

import "package:material_ui/material_ui.dart";

import "../core/ai/chat_provider.dart";
import "../core/ai/context_compactor.dart";
import "../core/ai/prompt_settings.dart";
import "../core/ai/tool_limits.dart";
import "../core/ai/study_tools.dart" show studyToolCategoriesKey;
import "../core/ai/visual_toolset.dart" show aiDrawingEnabledKey;
import "../core/database/database.dart";
import "../core/database/database_notifier.dart";
import "../core/l10n/app_strings.dart";
import "../core/l10n/generated/app_localizations.dart";
import "../core/platform/key_store.dart";
import "../core/python/python_tool.dart" show pythonPolicyKey;

enum EnglishStudyLevel { mixed, beginner, intermediate }

enum LanguageFeedbackLanguage { app, zh, en }

typedef LanguageStudySettings = ({
  EnglishStudyLevel level,
  LanguageFeedbackLanguage feedbackLanguage,
});

typedef SubjectSettings = ({bool? language, bool? drawing, bool? a2ui});

/// Owns preference persistence and its shutdown barrier independently of study data.
class AppPreferences extends DatabaseNotifier {
  AppPreferences(this.db, this.keys, {required this.demo});
  final AppDatabase db;
  final KeyStore keys;
  final bool demo;
  AppNotice? loadNotice;
  List<String> learningSubjects = const ["语文", "数学", "英语"];
  static const subjectsPreference = "learning_subjects_v1";
  static const _subjectSettingsKey = "learning_subject_settings";
  Map<String, SubjectSettings> _subjectSettings = {};

  SubjectSettings subjectSettings(String? subject) =>
      _subjectSettings[subject] ?? (language: null, drawing: null, a2ui: null);

  bool isLanguageSubject(String subject) =>
      subjectSettings(subject).language ?? isLanguageLearningSubject(subject);
  late ProviderConfig config;
  int maxContextTokens = kDefaultMaxContextTokens;
  int maxToolCalls = defaultMaxToolCalls;
  PromptSettings _prompts = PromptSettings();
  PromptSettings get prompts {
    if (_prompts.language != promptLanguage) {
      _prompts = _prompts.withLanguage(promptLanguage);
    }
    return _prompts;
  }

  set prompts(PromptSettings value) => _prompts = value;
  static const _studyLevelKey = "language_en_level";
  static const _feedbackLanguageKey = "language_feedback_language";
  LanguageStudySettings _languageStudy = (
    level: EnglishStudyLevel.mixed,
    feedbackLanguage: LanguageFeedbackLanguage.app,
  );
  LanguageStudySettings get languageStudy => _languageStudy;

  String languageChoice = "zh";
  bool dynamicColors = true;
  bool aiDrawingEnabled = false;
  bool aiWebEnabled = false;
  bool aiA2uiEnabled = true;
  Locale? get appLocale =>
      languageChoice == "system" ? null : Locale(languageChoice);
  String get promptLanguage => languageChoice == "system"
      ? resolveAppLocale(PlatformDispatcher.instance.locales).languageCode
      : languageChoice;
  AppLocalizations get l10n => lookupAppLocalizations(Locale(promptLanguage));
  ThemeMode themeMode = ThemeMode.system;
  Future<void> load() async {
    config = await db.config();
    maxContextTokens = await loadMaxContextTokens(db);
    maxToolCalls = await loadMaxToolCalls(db);
    aiDrawingEnabled = await db.preference(aiDrawingEnabledKey) == "true";
    aiWebEnabled = await db.preference("ai_web_enabled") == "true";
    aiA2uiEnabled =
        readA2uiOverride(await db.preference(aiA2uiEnabledKey)) ?? true;
    await loadSubjects();
    _subjectSettings = await _readSubjectSettings();
    final studyLevel = await db.preference(_studyLevelKey);
    final feedbackLanguage = await db.preference(_feedbackLanguageKey);
    _languageStudy = (
      level: EnglishStudyLevel.values.firstWhere(
        (value) => value.name == studyLevel,
        orElse: () => EnglishStudyLevel.mixed,
      ),
      feedbackLanguage: LanguageFeedbackLanguage.values.firstWhere(
        (value) => value.name == feedbackLanguage,
        orElse: () => LanguageFeedbackLanguage.app,
      ),
    );
    final language = await db.preference("app_language") ?? "zh";
    languageChoice = ["zh", "en", "system"].contains(language)
        ? language
        : "zh";
    dynamicColors =
        (await db.preference("dynamic_colors") ?? (demo ? "false" : "true")) ==
        "true";
    try {
      prompts = PromptSettings.decode(
        await db.preference(PromptSettings.preference),
      ).withLanguage(promptLanguage);
    } catch (_) {
      prompts = PromptSettings().withLanguage(promptLanguage);
      loadNotice = const AppNotice(AppNoticeKind.promptSettingsUnreadable);
    }
    themeMode = switch (await db.preference("theme")) {
      "dark" => ThemeMode.dark,
      "light" => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static List<String> checkedSubjects(Iterable<String> subjects) {
    final values = subjects.map((s) => s.trim()).toSet().toList();
    if (values.isEmpty ||
        values.length > 20 ||
        values.any((s) => s.isEmpty || s.length > 40 || s.contains("\n"))) {
      throw const AppFormatException(
        AppErrorCode.select120SubjectsWith,
        "请选择 1–20 个科目，每个名称最多 40 字。",
      );
    }
    return List.unmodifiable(values);
  }

  Future<void> loadSubjects() async {
    final raw = await db.preference(subjectsPreference);
    if (raw != null && raw.isNotEmpty) {
      try {
        final dynamic value = jsonDecode(raw);
        if (value is! List || value.any((v) => v is! String)) {
          throw const FormatException();
        }
        learningSubjects = checkedSubjects(value.cast<String>());
        return;
      } catch (_) {
        loadNotice = const AppNotice(AppNoticeKind.subjectSettingsUnreadable);
      }
    }
    // Existing users keep access to recorded subjects; fresh installs start
    // with the three main subjects and choose electives in Settings.
    final recorded = await db
        .customSelect(
          "SELECT DISTINCT subject FROM (SELECT subject FROM chat_sessions WHERE deleted=0 UNION SELECT subject FROM knowledge_items WHERE deleted=0 UNION SELECT subject FROM mistakes WHERE deleted=0 UNION SELECT subject FROM exam_subjects) WHERE subject IS NOT NULL AND trim(subject)<>'' ORDER BY subject",
        )
        .get();
    learningSubjects = checkedSubjects(
      {
        "语文",
        "数学",
        "英语",
        ...recorded
            .map((r) => r.read<String>("subject"))
            .where((s) => s.length <= 40 && !s.contains("\n")),
      }.take(20),
    );
  }

  Future<void> saveSubjects(
    List<String> subjects, {
    String currentFilter = "",
  }) => runOperation(() async {
    final values = checkedSubjects(subjects);
    await db.transaction(() async {
      await db.setPreference(subjectsPreference, jsonEncode(values));
      if (currentFilter.isNotEmpty && !values.contains(currentFilter)) {
        await db.setPreference("subject_filter", "");
      }
    });
    learningSubjects = values;
    changed();
  });

  Future<Map<String, SubjectSettings>> _readSubjectSettings() async {
    final raw = await db.preference(_subjectSettingsKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      bool? flag(Object? value) => value is bool ? value : null;
      return {
        for (final MapEntry(:key, :value) in decoded.entries)
          if (value is Map<String, dynamic>)
            key: (
              language: flag(value["language"]),
              drawing: flag(value["drawing"]),
              a2ui: flag(value["a2ui"]),
            ),
      };
    } on FormatException {
      return {};
    }
  }

  Future<void> saveSubjectSettings(String subject, SubjectSettings settings) =>
      runOperation(() async {
        final name = checkedSubjects([subject]).single;
        _subjectSettings = await db.transaction(() async {
          final updated = await _readSubjectSettings();
          if (settings == (language: null, drawing: null, a2ui: null)) {
            updated.remove(name);
          } else {
            updated[name] = settings;
          }
          await db.setPreference(
            _subjectSettingsKey,
            jsonEncode({
              for (final MapEntry(key: subject, value: value)
                  in updated.entries)
                subject: {
                  "language": value.language,
                  "drawing": value.drawing,
                  "a2ui": value.a2ui,
                },
            }),
          );
          return updated;
        });
        changed();
      });

  Future<void> saveLanguageStudy(LanguageStudySettings settings) =>
      runOperation(() async {
        await db.transaction(() async {
          await db.setPreference(_studyLevelKey, settings.level.name);
          await db.setPreference(
            _feedbackLanguageKey,
            settings.feedbackLanguage.name,
          );
        });
        _languageStudy = settings;
        changed();
      });

  Future<void> setLanguage(String value) => runOperation(() async {
    if (!["zh", "en", "system"].contains(value)) {
      throw const FormatException("Unsupported language");
    }
    await db.setPreference("app_language", value);
    languageChoice = value;
    prompts = prompts.withLanguage(promptLanguage);
    changed();
  });

  Future<void> setDynamicColors(bool value) => runOperation(() async {
    await db.setPreference("dynamic_colors", value.toString());
    dynamicColors = value;
    changed();
  });

  Future<void> copyChatSettings(String source, String target) =>
      runOperation(() async {
        for (final (oldKey, newKey) in [
          ("ai_reasoning:$source", "ai_reasoning:$target"),
          ("ai_drawing:$source", "ai_drawing:$target"),
          (chatWebPreference(source), chatWebPreference(target)),
          (chatA2uiPreference(source), chatA2uiPreference(target)),
          (studyToolCategoriesKey(source), studyToolCategoriesKey(target)),
        ]) {
          final value = await db.preference(oldKey);
          if (value != null) await db.setPreference(newKey, value);
        }
      });

  Future<void> setAiDrawingEnabled(bool value) => runOperation(() async {
    await db.setPreference(aiDrawingEnabledKey, value.toString());
    aiDrawingEnabled = value;
    changed();
  });

  static String chatWebPreference(String id) => "ai_web:$id";

  Future<void> setAiWebEnabled(bool value) => runOperation(() async {
    await db.setPreference("ai_web_enabled", value.toString());
    aiWebEnabled = value;
    changed();
  });

  Future<bool?> chatWebOverride(String id) async =>
      switch (await db.preference(chatWebPreference(id))) {
        "true" => true,
        "false" => false,
        _ => null,
      };

  Future<void> saveChatWebOverride(String id, bool? value) => runOperation(
    () => db.setPreference(chatWebPreference(id), value?.toString() ?? ""),
  );

  Future<String> pythonExecutionPolicy() async {
    final value = await db.preference(pythonPolicyKey);
    return ["ask", "auto", "off"].contains(value) ? value! : "ask";
  }

  Future<void> setPythonExecutionPolicy(String value) =>
      runOperation(() => db.setPreference(pythonPolicyKey, value));

  Future<void> setAiA2uiEnabled(bool value) => runOperation(() async {
    await db.setPreference(aiA2uiEnabledKey, value.toString());
    aiA2uiEnabled = value;
    changed();
  });

  Future<void> saveChatA2uiOverride(String id, bool? value) => runOperation(
    () => db.setPreference(chatA2uiPreference(id), value?.toString() ?? ""),
  );

  Future<void> setMaxToolCalls(int value) => runOperation(() async {
    if (value < 0) {
      throw const AppFormatException(
        AppErrorCode.invalidToolCallLimit,
        "工具调用上限应为非负整数，0 表示不限制。",
      );
    }
    await db.setPreference(maxToolCallsKey, value.toString());
    maxToolCalls = value;
    changed();
  });

  Future<void> setMaxContextTokens(int value) => runOperation(() async {
    if (!isValidMaxContextTokens(value)) {
      throw const AppFormatException(
        AppErrorCode.maxContextTokensMustBe,
        "最大上下文 Token 数应为 4096–1048576 的整数。",
      );
    }
    await db.setPreference("max_context_tokens", value.toString());
    maxContextTokens = value;
    changed();
  });

  Future<void> savePrompt(String id, String value) => runOperation(() async {
    final saved = await db.transaction(() async {
      PromptSettings current;
      try {
        current = PromptSettings.decode(
          await db.preference(PromptSettings.preference),
        ).withLanguage(promptLanguage);
      } catch (_) {
        current = prompts;
      }
      final next = current.update(id, value);
      await db.setPreference(PromptSettings.preference, next.encode());
      return next;
    });
    prompts = saved;
    changed();
  });

  Future<bool> hasApiKey(ProviderConfig provider) async {
    final key = await keys.read(providerKeyId(provider));
    return key?.isNotEmpty == true;
  }

  Future<void> saveSettings(ProviderConfig next, String? key) =>
      runOperation(() async {
        validateConfig(next);
        if (next.kind == "chatgpt" && key != null) {
          throw const AppFormatException(
            AppErrorCode.chatGPTUsesBrowserSignIn,
            "ChatGPT 使用浏览器登录，无需 API Key。",
          );
        }
        // Read the current key first so a failed write can be undone.
        final previousKey = key == null
            ? null
            : await keys.read(providerKeyId(next));
        final previousConfig = config;
        // Persist the config BEFORE writing the key: if the config
        // write fails, the key is never rotated out from under the
        // config still in effect (same provider, model-only change).
        await db.transaction(() async {
          if (next.kind == "chatgpt" && config.kind != "chatgpt") {
            await db.setPreference(
              "previous_api_provider",
              jsonEncode(config.toJson()),
            );
          }
          if (config.kind == "chatgpt" && next.kind != "chatgpt") {
            await db.setPreference(
              "previous_chatgpt_provider",
              jsonEncode(config.toJson()),
            );
          }
          await db.saveConfig(next);
        });
        if (key != null) {
          try {
            await keys.write(providerKeyId(next), key.trim());
          } catch (_) {
            // The config is already saved; leave no mismatched state
            // behind: restore the previous key (or clear the entry when
            // there was none) and roll the saved config back, then
            // report the failure so the user can retry.
            try {
              if (previousKey == null || previousKey.isEmpty) {
                await keys.write(providerKeyId(next), "");
              } else {
                await keys.write(providerKeyId(next), previousKey);
              }
            } catch (_) {}
            try {
              await db.saveConfig(previousConfig);
            } catch (_) {}
            rethrow;
          }
        }
        config = next;
        changed();
      });

  Future<ProviderConfig?> previousChatGptProvider() async {
    final previous = await _previousProvider("previous_chatgpt_provider");
    return previous?.kind == "chatgpt" ? previous : null;
  }

  Future<ProviderConfig?> previousApiProvider() async {
    final previous = await _previousProvider("previous_api_provider");
    return previous?.kind == "chatgpt" ? null : previous;
  }

  Future<ProviderConfig?> _previousProvider(String key) async {
    final raw = await db.preference(key);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return ProviderConfig.fromJson(decoded);
  }

  Future<void> restoreApiProvider() => runOperation(() async {
    final raw = await db.preference("previous_api_provider");
    if (raw == null || raw.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.noPreviousAPISettingsWere,
        "没有已保存的 API 配置，请在设置中选择服务商。",
      );
    }
    final previous = ProviderConfig.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (previous.kind == "chatgpt") {
      throw const AppFormatException(
        AppErrorCode.previousAPISettingsAreInvalid,
        "原 API 配置无效。",
      );
    }
    await saveSettings(previous, null);
    // A successful restore consumes the saved provider; leaving the
    // stale value would let a second restore silently re-apply it.
    await db.setPreference("previous_api_provider", "");
  });

  Future<void> theme(ThemeMode value) => runOperation(() async {
    await db.setPreference("theme", value.name);
    themeMode = value;
    changed();
  });
}
