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
