import "app_error.dart";
import "generated/app_localizations.dart";

part "app_data_error_text.dart";

String studyFieldText(
  AppLocalizations l10n,
  String name, {
  required bool builtin,
}) {
  if (!builtin) return name;
  final field = StudyErrorField.values
      .where((item) => item.name == name)
      .firstOrNull;
  return switch (field) {
    StudyErrorField.tag => l10n.errorFieldTag,
    StudyErrorField.title => l10n.titleLabel,
    StudyErrorField.body => l10n.errorFieldBody,
    StudyErrorField.subject => l10n.subject,
    StudyErrorField.chapter => l10n.chapter,
    StudyErrorField.content => l10n.content,
    StudyErrorField.reason => l10n.errorFieldReason,
    StudyErrorField.suggestedReason => l10n.errorFieldSuggestedReason,
    StudyErrorField.searchTerm => l10n.errorFieldSearchTerm,
    null => name,
  };
}

String appErrorText(
  AppLocalizations l10n,
  AppErrorCode code, [
  List<String> arguments = const [],
]) =>
    _generalErrorText(l10n, code, arguments) ??
    _dataErrorText(l10n, code, arguments) ??
    (throw StateError("Missing localization for ${code.name}"));

String? _generalErrorText(
  AppLocalizations l10n,
  AppErrorCode code,
  List<String> arguments,
) => switch (code) {
  AppErrorCode.cannotForkMessage => l10n.cannotForkMessage,
  AppErrorCode.chooseAModelThatSupports => l10n.chooseAModelThatSupports,
  AppErrorCode.selectAnAIReplyWith => l10n.selectAnAIReplyWith,
  AppErrorCode.restoreTheDeletedSourceConversation =>
    l10n.restoreTheDeletedSourceConversation,
  AppErrorCode.describeWhatYouWantTo => l10n.describeWhatYouWantTo,
  AppErrorCode.chooseAVisionCapableModel => l10n.chooseAVisionCapableModel,

  AppErrorCode.secureStorageUnavailableLinux =>
    l10n.secureStorageUnavailableLinux,
  AppErrorCode.materialToolsRequireModelWithoutThinking =>
    l10n.materialToolsRequireModelWithoutThinking,
  AppErrorCode.materialToolsRequireToolCapableModel =>
    l10n.materialToolsRequireToolCapableModel,
  AppErrorCode.conversationDataToolsRequireModelWithoutThinking =>
    l10n.conversationDataToolsRequireModelWithoutThinking,
  AppErrorCode.conversationDataToolsRequireToolCapableModel =>
    l10n.conversationDataToolsRequireToolCapableModel,
  AppErrorCode.connectionTestCancelled => l10n.connectionTestCancelled,
  AppErrorCode.theResponseReachedItsLength => l10n.theResponseReachedItsLength,
  AppErrorCode.theAPIKeyIsInvalid => l10n.theAPIKeyIsInvalid,
  AppErrorCode.saveAnAPIKeyBeforeQueryingTheBalance =>
    l10n.saveAnAPIKeyBeforeQueryingTheBalance,
  AppErrorCode.thisProviderHasNoBalanceEndpoint =>
    l10n.thisProviderHasNoBalanceEndpoint,
  AppErrorCode.insufficientAPIBalanceCheckYour =>
    l10n.insufficientAPIBalanceCheckYour,
  AppErrorCode.tooManyRequestsTryAgain => l10n.tooManyRequestsTryAgain,
  AppErrorCode.theServiceDoesNotSupport => l10n.theServiceDoesNotSupport,
  AppErrorCode.theConnectionFailedOrThe => l10n.theConnectionFailedOrThe,
  AppErrorCode.yourChatGPTSignInHas => l10n.yourChatGPTSignInHas,
  AppErrorCode.chatGptQuotaAccessDenied => l10n.chatGptQuotaAccessDenied,
  AppErrorCode.chatGPTPlanAllowanceOrPermissions =>
    l10n.chatGPTPlanAllowanceOrPermissions,
  AppErrorCode.chatGptUnsupportedModelOrParameter =>
    l10n.chatGptUnsupportedModelOrParameter,
  AppErrorCode.theChatGPTRequestFailedCheck =>
    l10n.theChatGPTRequestFailedCheck,
  AppErrorCode.chatGPTReturnedAnErrorRefresh =>
    l10n.chatGPTReturnedAnErrorRefresh,

  AppErrorCode.generationTimedOutPartialContent =>
    l10n.generationTimedOutPartialContent,
  AppErrorCode.generationStopped => l10n.generationStopped,
  AppErrorCode.theNetworkRequestFailedTry => l10n.theNetworkRequestFailedTry,
  AppErrorCode.generationFailedCheckSecureStorage =>
    l10n.generationFailedCheckSecureStorage,
  AppErrorCode.previousGenerationInterrupted =>
    l10n.previousGenerationInterrupted,
  AppErrorCode.aChatGPTSignInIs => l10n.aChatGPTSignInIs,
  AppErrorCode.aDirectoryWithThisName => l10n.aDirectoryWithThisName,
  AppErrorCode.anUnavailableToolCallWas => l10n.anUnavailableToolCallWas,
  AppErrorCode.cannotReadTheSelectedPhoto => l10n.cannotReadTheSelectedPhoto,
  AppErrorCode.chatGPTAuthorizationWasNotCompleted =>
    l10n.chatGPTAuthorizationWasNotCompleted,
  AppErrorCode.chatGPTDidNotCompleteThe => l10n.chatGPTDidNotCompleteThe,
  AppErrorCode.chatGPTIdentityVerificationFailedSign =>
    l10n.chatGPTIdentityVerificationFailedSign,
  AppErrorCode.chatGPTReturnedAWebPage => l10n.chatGPTReturnedAWebPage,
  AppErrorCode.chatGPTReturnedAnUnrecognizedFormat =>
    l10n.chatGPTReturnedAnUnrecognizedFormat,
  AppErrorCode.chatGPTReturnedIncompatibleResponseFields =>
    l10n.chatGPTReturnedIncompatibleResponseFields,
  AppErrorCode.chatGPTSignInCancelled => l10n.chatGPTSignInCancelled,
  AppErrorCode.chatGPTSignInChangedSend => l10n.chatGPTSignInChangedSend,
  AppErrorCode.chatGPTSignInFailedCheck => l10n.chatGPTSignInFailedCheck,
  AppErrorCode.chatGPTSignInTimedOut => l10n.chatGPTSignInTimedOut,
  AppErrorCode.chatGPTToolContextIsToo => l10n.chatGPTToolContextIsToo,
  AppErrorCode.chatGPTUsesBrowserSignIn => l10n.chatGPTUsesBrowserSignIn,
  AppErrorCode.chatGPTUsesOnlyTheOfficial => l10n.chatGPTUsesOnlyTheOfficial,
  AppErrorCode.connectedButNoResponseText => l10n.connectedButNoResponseText,
  AppErrorCode.couldNotLoadChatGPTModels => l10n.couldNotLoadChatGPTModels,
  AppErrorCode.couldNotOpenSystemBrowser => l10n.couldNotOpenSystemBrowser,
  AppErrorCode.couldNotOpenSystemCamera => l10n.couldNotOpenSystemCamera,
  AppErrorCode.couldNotParseAChatGPT => l10n.couldNotParseAChatGPT,
  AppErrorCode.couldNotReadChatGPTSign => l10n.couldNotReadChatGPTSign,
  AppErrorCode.couldNotRenewChatGPTSign => l10n.couldNotRenewChatGPTSign,
  AppErrorCode.deepSeekProDoesNotSupport => l10n.deepSeekProDoesNotSupport,
  AppErrorCode.editingAnUnselectedItemWas => l10n.editingAnUnselectedItemWas,
  AppErrorCode.enterAModelID => l10n.enterAModelID,
  AppErrorCode.examNameMustBe1 => l10n.examNameMustBe1,
  AppErrorCode.interactiveQuestionsNeedATool =>
    l10n.interactiveQuestionsNeedATool,
  AppErrorCode.invalidChatGPTAuthorizationServiceIdentity =>
    l10n.invalidChatGPTAuthorizationServiceIdentity,
  AppErrorCode.invalidChatGPTAuthorizationServiceURL =>
    l10n.invalidChatGPTAuthorizationServiceURL,
  AppErrorCode.invalidChatGPTModelCatalog => l10n.invalidChatGPTModelCatalog,
  AppErrorCode.invalidChatGPTResponseFormatTry =>
    l10n.invalidChatGPTResponseFormatTry,
  AppErrorCode.invalidChatGPTSignInCallback =>
    l10n.invalidChatGPTSignInCallback,
  AppErrorCode.invalidDeclaredReasoningLevels =>
    l10n.invalidDeclaredReasoningLevels,
  AppErrorCode.invalidReasoningEffort => l10n.invalidReasoningEffort,
  AppErrorCode.invalidToolCallFormat => l10n.invalidToolCallFormat,
  AppErrorCode.maxContextTokensMustBe => l10n.maxContextTokensMustBe,
  AppErrorCode.invalidToolCallLimit => l10n.invalidToolCallLimit,
  AppErrorCode.toolCallLimitReached => l10n.toolCallLimitReached(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.modelDoesNotSupportImages => l10n.modelDoesNotSupportImages,
  AppErrorCode.modelDoesNotSupportReasoningParameter =>
    l10n.modelDoesNotSupportReasoningParameter,
  AppErrorCode.noPreviousAPISettingsWere => l10n.noPreviousAPISettingsWere,
  AppErrorCode.onlyConversationsInTheTrash => l10n.onlyConversationsInTheTrash,
  AppErrorCode.previousAPISettingsAreInvalid =>
    l10n.previousAPISettingsAreInvalid,
  AppErrorCode.reviewSchedulingFailedButYour =>
    l10n.reviewSchedulingFailedButYour,
  AppErrorCode.saveAnAPIKeyIn => l10n.saveAnAPIKeyIn,
  AppErrorCode.select120SubjectsWith => l10n.select120SubjectsWith,
  AppErrorCode.select15KnowledgeEntries => l10n.select15KnowledgeEntries,
  AppErrorCode.selectASavedChatGPTAccount => l10n.selectASavedChatGPTAccount,
  AppErrorCode.selectASupportedDeepSeekModel =>
    l10n.selectASupportedDeepSeekModel,
  AppErrorCode.signInUsingContinueWith => l10n.signInUsingContinueWith,
  AppErrorCode.signingOutOfChatGPTTry => l10n.signingOutOfChatGPTTry,
  AppErrorCode.stopGeneratingBeforeChangingReasoning =>
    l10n.stopGeneratingBeforeChangingReasoning,
  AppErrorCode.stopGenerationBeforeEditingDraft =>
    l10n.stopGenerationBeforeEditingDraft,
  AppErrorCode.stopGenerationBeforeOrganizingMaterial =>
    l10n.stopGenerationBeforeOrganizingMaterial,
  AppErrorCode.stopTheReplyBeforeAdding => l10n.stopTheReplyBeforeAdding,
  AppErrorCode.theChatGPTAccountChangedSend =>
    l10n.theChatGPTAccountChangedSend,
  AppErrorCode.theChatGPTCompletionEventWas =>
    l10n.theChatGPTCompletionEventWas,
  AppErrorCode.theConnectionEndedEarlyReceived =>
    l10n.theConnectionEndedEarlyReceived,
  AppErrorCode.theCurrentModelHasNot => l10n.theCurrentModelHasNot,
  AppErrorCode.theEditedImageExceeds8 => l10n.theEditedImageExceeds8,
  AppErrorCode.theImageWasSentOr => l10n.theImageWasSentOr,
  AppErrorCode.theLimitOf4Tool => l10n.theLimitOf4Tool,
  AppErrorCode.theModelRequestedATool => l10n.theModelRequestedATool,
  AppErrorCode.theModelReturnedNoDisplayable =>
    l10n.theModelReturnedNoDisplayable,
  AppErrorCode.theModelReturnedUnreadableStream =>
    l10n.theModelReturnedUnreadableStream,
  AppErrorCode.theNonStreamingChatGPTResponse =>
    l10n.theNonStreamingChatGPTResponse,
  AppErrorCode.thePhotoChangedOrWas => l10n.thePhotoChangedOrWas,
  AppErrorCode.theResponseTimedOutReceived => l10n.theResponseTimedOutReceived,
  AppErrorCode.theSelectedKnowledgeMustBe => l10n.theSelectedKnowledgeMustBe,
  AppErrorCode.theServiceDidNotReturn => l10n.theServiceDidNotReturn,
  AppErrorCode.theServiceReturnedAnError => l10n.theServiceReturnedAnError,
  AppErrorCode.theSignedInIdentityDiffers => l10n.theSignedInIdentityDiffers,
  AppErrorCode.theToolResponseDidNot => l10n.theToolResponseDidNot,
  AppErrorCode.thisAccountHasNotGranted => l10n.thisAccountHasNotGranted,
  AppErrorCode.thisConversationContainsImagesBut =>
    l10n.thisConversationContainsImagesBut,
  AppErrorCode.thisRequestReachedTheLimit => l10n.thisRequestReachedTheLimit,
  AppErrorCode.thisTaskRequiresNonThinking => l10n.thisTaskRequiresNonThinking,
  AppErrorCode.thisWritingTaskIsInvalid => l10n.thisWritingTaskIsInvalid,
  AppErrorCode.useAnHTTPSAPIURL => l10n.useAnHTTPSAPIURL,
  AppErrorCode.errorSaveTryAgain || _ => null,
};

/// Only known, typed application errors are localized. External errors and
/// unrecognized FormatExceptions are returned exactly as supplied.
String failureText(AppLocalizations l10n, Object error) {
  if (error is LocalizedAppFailure) {
    final code = error.code;
    return code == null
        ? error.message
        : appErrorText(l10n, code, error.arguments);
  }
  if (error is FormatException) return error.message;
  return error.toString();
}
