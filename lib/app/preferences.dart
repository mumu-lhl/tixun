import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../core/ai/chat_provider.dart';
import '../core/ai/prompt_settings.dart';
import '../core/database/database.dart';
import '../core/database/database_notifier.dart';
import '../core/l10n/app_strings.dart';
import '../core/platform/key_store.dart';

/// Owns preference persistence and its shutdown barrier independently of study data.
class AppPreferences extends DatabaseNotifier {
  AppPreferences(this.db, this.keys, {required this.demo});
  final AppDatabase db;
  final KeyStore keys;
  final bool demo;
  String? loadNotice;
  List<String> learningSubjects = const ['语文', '数学', '英语'];
  static const subjectsPreference = 'learning_subjects_v1';
  late ProviderConfig config;
  PromptSettings _prompts = PromptSettings();
  PromptSettings get prompts {
    if (_prompts.language != promptLanguage) {
      _prompts = _prompts.withLanguage(promptLanguage);
    }
    return _prompts;
  }

  set prompts(PromptSettings value) => _prompts = value;
  String languageChoice = 'zh';
  bool dynamicColors = true;
  Locale? get appLocale =>
      languageChoice == 'system' ? null : Locale(languageChoice);
  String get promptLanguage => languageChoice == 'system'
      ? resolveAppLocale(PlatformDispatcher.instance.locales).languageCode
      : languageChoice;
  String uiText(String key, [List<Object?> arguments = const []]) =>
      AppStrings(Locale(promptLanguage)).text(key, arguments);
  ThemeMode themeMode = ThemeMode.system;
  Future<void> load() async {
    config = await db.config();
    await loadSubjects();
    final language = await db.preference('app_language') ?? 'zh';
    languageChoice = ['zh', 'en', 'system'].contains(language)
        ? language
        : 'zh';
    dynamicColors =
        (await db.preference('dynamic_colors') ?? (demo ? 'false' : 'true')) ==
        'true';
    try {
      prompts = PromptSettings.decode(
        await db.preference(PromptSettings.preference),
      ).withLanguage(promptLanguage);
    } catch (_) {
      prompts = PromptSettings().withLanguage(promptLanguage);
      loadNotice = '提示词配置无法读取，暂用默认值；可在提示词管理中重新保存。';
    }
    themeMode = switch (await db.preference('theme')) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  static List<String> checkedSubjects(Iterable<String> subjects) {
    final values = subjects.map((s) => s.trim()).toSet().toList();
    if (values.isEmpty ||
        values.length > 20 ||
        values.any((s) => s.isEmpty || s.length > 40 || s.contains('\n'))) {
      throw const FormatException('请选择 1–20 个科目，每个名称最多 40 字。');
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
        loadNotice = '学习科目配置无法读取，暂按已有资料显示；可在设置中重新选择。';
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
        '语文',
        '数学',
        '英语',
        ...recorded
            .map((r) => r.read<String>('subject'))
            .where((s) => s.length <= 40 && !s.contains('\n')),
      }.take(20),
    );
  }

  Future<void> saveSubjects(
    List<String> subjects, {
    String currentFilter = '',
  }) => runOperation(() async {
    final values = checkedSubjects(subjects);
    await db.transaction(() async {
      await db.setPreference(subjectsPreference, jsonEncode(values));
      if (currentFilter.isNotEmpty && !values.contains(currentFilter)) {
        await db.setPreference('subject_filter', '');
      }
    });
    learningSubjects = values;
    changed();
  });

  Future<void> setLanguage(String value) => runOperation(() async {
    if (!['zh', 'en', 'system'].contains(value)) {
      throw const FormatException('Unsupported language');
    }
    await db.setPreference('app_language', value);
    languageChoice = value;
    prompts = prompts.withLanguage(promptLanguage);
    changed();
  });

  Future<void> setDynamicColors(bool value) => runOperation(() async {
    await db.setPreference('dynamic_colors', value.toString());
    dynamicColors = value;
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

  Future<void> saveSettings(ProviderConfig next, String? key) =>
      runOperation(() async {
        validateConfig(next);
        if (next.kind == 'chatgpt' && key != null) {
          throw const FormatException('ChatGPT 使用浏览器登录，无需 API Key。');
        }
        if (key != null) await keys.write(providerKeyId(next), key.trim());
        await db.transaction(() async {
          if (next.kind == 'chatgpt' && config.kind != 'chatgpt') {
            await db.setPreference(
              'previous_api_provider',
              jsonEncode(config.toJson()),
            );
          }
          await db.saveConfig(next);
        });
        config = next;
        changed();
      });

  Future<void> restoreApiProvider() => runOperation(() async {
    final raw = await db.preference('previous_api_provider');
    if (raw == null) throw const FormatException('没有已保存的 API 配置，请在设置中选择服务商。');
    final previous = ProviderConfig.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    if (previous.kind == 'chatgpt') throw const FormatException('原 API 配置无效。');
    await saveSettings(previous, null);
  });

  Future<void> theme(ThemeMode value) => runOperation(() async {
    await db.setPreference('theme', value.name);
    themeMode = value;
    changed();
  });
}
