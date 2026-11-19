import 'package:material_ui/material_ui.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';

String quickName(BuildContext context, LanguageQuickAction action) =>
    action.name.isNotEmpty
    ? action.name
    : switch (action.id) {
        'language_express' => context.l10n.quickExpress,
        'language_meaning' => context.l10n.quickMeaning,
        'language_usage' => context.l10n.quickUsage,
        _ => action.name,
      };

String quickDescription(BuildContext context, LanguageQuickAction action) =>
    action.description.isNotEmpty
    ? action.description
    : switch (action.id) {
        'language_express' => context.l10n.quickExpressDescription,
        'language_meaning' => context.l10n.quickMeaningDescription,
        'language_usage' => context.l10n.quickUsageDescription,
        _ => '',
      };

String quickHint(BuildContext context, LanguageQuickAction action) =>
    action.inputHint.isNotEmpty
    ? action.inputHint
    : switch (action.id) {
        'language_express' => context.l10n.quickExpressInput,
        'language_meaning' => context.l10n.quickMeaningInput,
        'language_usage' => context.l10n.quickUsageInput,
        _ => context.l10n.quickDefaultInput,
      };

IconData quickIcon(String value) => switch (value) {
  'express' => Icons.record_voice_over_outlined,
  'meaning' => Icons.menu_book_outlined,
  'usage' => Icons.tips_and_updates_outlined,
  'translate' => Icons.translate,
  _ => Icons.star_outline,
};

String quickLanguageName(BuildContext context, String code) => switch (code) {
  'auto' => context.l10n.quickAutoLanguage,
  'app' => context.l10n.quickAppLanguage,
  'en' => context.l10n.languageEnglish,
  'zh' => context.l10n.chinese,
  'ja' => context.l10n.languageJapanese,
  'fr' => 'Français',
  'de' => 'Deutsch',
  'es' => 'Español',
  'ko' => '한국어',
  _ => code,
};

Future<bool> confirmQuickDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    ) ??
    false;
