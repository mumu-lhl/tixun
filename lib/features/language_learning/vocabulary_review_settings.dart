import "dart:convert";

import "../../core/database/database.dart";

typedef VocabularyReviewSettings = ({
  bool enabled,
  int retentionPercent,
  int maximumInterval,
});

const defaultVocabularyReviewSettings = (
  enabled: false,
  retentionPercent: 90,
  maximumInterval: 180,
);
const vocabularyReviewSettingsKey = "vocabulary_review_settings";
const minVocabularyRetention = 70;
const maxVocabularyRetention = 97;
const minVocabularyReviewDays = 1;
const maxVocabularyReviewDays = 36500;

bool validVocabularyRetention(int? value) =>
    value != null &&
    value >= minVocabularyRetention &&
    value <= maxVocabularyRetention;

bool validVocabularyReviewDays(int? value) =>
    value != null &&
    value >= minVocabularyReviewDays &&
    value <= maxVocabularyReviewDays;

Future<VocabularyReviewSettings> loadVocabularyReviewSettings(
  AppDatabase db,
) async {
  final raw = await db.preference(vocabularyReviewSettingsKey);
  if (raw == null) return defaultVocabularyReviewSettings;
  try {
    if (jsonDecode(raw)
        case {
          "enabled": final bool enabled,
          "retention": final int retention,
          "maximum_interval": final int maximumInterval,
        }
        when validVocabularyRetention(retention) &&
            validVocabularyReviewDays(maximumInterval)) {
      return (
        enabled: enabled,
        retentionPercent: retention,
        maximumInterval: maximumInterval,
      );
    }
  } on FormatException {
    return defaultVocabularyReviewSettings;
  }
  return defaultVocabularyReviewSettings;
}

Future<void> saveVocabularyReviewSettings(
  AppDatabase db,
  VocabularyReviewSettings settings,
) async {
  if (!validVocabularyRetention(settings.retentionPercent) ||
      !validVocabularyReviewDays(settings.maximumInterval)) {
    throw ArgumentError.value(settings, "settings");
  }
  await db.setPreference(
    vocabularyReviewSettingsKey,
    jsonEncode({
      "enabled": settings.enabled,
      "retention": settings.retentionPercent,
      "maximum_interval": settings.maximumInterval,
    }),
  );
}
