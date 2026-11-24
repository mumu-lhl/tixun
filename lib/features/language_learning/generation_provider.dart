import "dart:convert";

import "../../core/ai/chat_provider.dart";
import "generation_profile.dart";
import "language_skills.dart";
import "language_profile_store.dart";
import "language_store.dart";
import "../../core/ai/prompt_settings.dart";
import "generation_store.dart";
import "../../core/database/database.dart";

const vocabularyRevisionContract =
    "Revise learning material for the supplied exact lexical sense. Preserve form, type, and meaning exactly. This is revision, not candidate selection: return exactly one entry, without groupTitle. Supply a fresh natural example and translation in glossLanguage; do not invent a different sense. Omit forms unless correcting inflections for this same sense.";

/// Supplies live settings at request start, while each captured run retains
/// the immutable configuration actually used for that request.
class LanguageGenerationProvider implements ChatProvider {
  const LanguageGenerationProvider({
    required this.provider,
    required this.configuration,
    required this.promptSettings,
    required this.history,
    required this.compare,
  });
  final ChatProvider Function() provider;
  final ProviderConfig Function() configuration;
  final PromptSettings Function() promptSettings;
  final LanguageGenerationStore history;
  final GenerationComparison compare;

  @override
  AiConversation start(ProviderConfig config, {String? apiKeyOverride}) =>
      provider().start(config, apiKeyOverride: apiKeyOverride);

  Future<AiRequest> prepare(
    String feature,
    AiRequest request, {
    Set<LanguageSkill> focus = const {},
  }) async {
    final definition = feature == "language_vocabulary_revision"
        ? LanguagePrompt.vocabulary
        : LanguagePrompt.values.where((p) => p.id == feature).firstOrNull;
    request = request.copyWith(
      instructions: definition == null
          ? null
          : "${definition.instructions(promptSettings())}${feature == 'language_vocabulary_revision' ? '\n$vocabularyRevisionContract' : ''}",
    );
    // These generators currently produce English only. Explanations, revisions,
    // scoring and lookup must not receive unrelated learner history.
    if (!const {
      "language_vocabulary",
      "language_sentence_batch",
      "language_context_understanding",
      "language_exam_generation",
      "language_writing_task",
    }.contains(feature)) {
      return request;
    }
    final profile = await LanguageLearningStore(history.db)
        .readLanguageProfile("en");
    return request.copyWith(
      instructions: "${request.instructions}\n$generationProfileInstructions",
      messages: [
        ...request.messages,
        AiMessage.user(
          jsonEncode({
            "learnerProfile": generationProfile(profile, feature, focus: focus),
          }),
        ),
      ],
    );
  }
}

ProviderConfig languageConfiguration(
  ChatProvider provider,
  ProviderConfig fallback,
) => provider is LanguageGenerationProvider
    ? provider.configuration()
    : fallback;
