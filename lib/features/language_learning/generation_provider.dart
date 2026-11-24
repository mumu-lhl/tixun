import "../../core/ai/chat_provider.dart";
import "../../core/ai/prompt_settings.dart";
import "generation_store.dart";
import "../../core/database/database.dart";

const vocabularyRevisionContract =
    "Revise learning material for the supplied exact lexical sense. Preserve form, type, and meaning exactly. Supply a fresh natural example and translation; do not invent a different sense.";

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

  AiRequest prepare(String feature, AiRequest request) {
    final definition = feature == "language_vocabulary_revision"
        ? LanguagePrompt.vocabulary
        : LanguagePrompt.values.where((p) => p.id == feature).firstOrNull;
    return request.copyWith(
      instructions: definition == null
          ? null
          : "${definition.instructions(promptSettings())}${feature == 'language_vocabulary_revision' ? '\n$vocabularyRevisionContract' : ''}",
    );
  }
}

ProviderConfig languageConfiguration(
  ChatProvider provider,
  ProviderConfig fallback,
) => provider is LanguageGenerationProvider
    ? provider.configuration()
    : fallback;
