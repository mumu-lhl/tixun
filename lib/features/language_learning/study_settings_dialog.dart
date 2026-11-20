import "package:material_ui/material_ui.dart";

import "../../app/preferences.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/ui/actions.dart";

Future<void> editLanguageStudy(
  BuildContext context,
  AppPreferences preferences,
) async {
  final l10n = context.l10n;
  var settings = preferences.languageStudy;
  final updated = await showDialog<LanguageStudySettings>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.languageStudySettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.languageStudySettingsIntro),
          const SizedBox(height: 16),
          AppSelectField<EnglishStudyLevel>(
            initialValue: settings.level,
            decoration: InputDecoration(
              labelText: l10n.languageDifficulty,
              hintText: l10n.languageSentenceMixed,
            ),
            items: [
              for (final value in EnglishStudyLevel.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(switch (value) {
                    EnglishStudyLevel.mixed => l10n.languageStudyMixed,
                    EnglishStudyLevel.beginner => l10n.languageBeginner,
                    EnglishStudyLevel.intermediate => l10n.languageIntermediate,
                  }),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                settings = (
                  level: value,
                  feedbackLanguage: settings.feedbackLanguage,
                );
              }
            },
          ),
          const SizedBox(height: 16),
          AppSelectField<LanguageFeedbackLanguage>(
            initialValue: settings.feedbackLanguage,
            decoration: InputDecoration(
              labelText: l10n.languageFeedbackLanguage,
            ),
            items: [
              for (final value in LanguageFeedbackLanguage.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(switch (value) {
                    LanguageFeedbackLanguage.app =>
                      l10n.languageFeedbackAppLanguage,
                    LanguageFeedbackLanguage.zh => l10n.chinese,
                    LanguageFeedbackLanguage.en => l10n.languageEnglish,
                  }),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                settings = (level: settings.level, feedbackLanguage: value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, settings),
          child: Text(l10n.save),
        ),
      ],
    ),
  );
  if (context.mounted &&
      updated != null &&
      updated != preferences.languageStudy) {
    await act(context, () => preferences.saveLanguageStudy(updated));
  }
}
