import 'app_error.dart';
import 'generated/app_localizations.dart';

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
]) => switch (code) {
  AppErrorCode.chooseAModelThatSupports => l10n.chooseAModelThatSupports,
  AppErrorCode.selectAnAIReplyWith => l10n.selectAnAIReplyWith,
  AppErrorCode.restoreTheDeletedSourceConversation =>
    l10n.restoreTheDeletedSourceConversation,
  AppErrorCode.describeWhatYouWantTo => l10n.describeWhatYouWantTo,
  AppErrorCode.chooseAVisionCapableModel => l10n.chooseAVisionCapableModel,

  AppErrorCode.secureStorageUnavailableLinux =>
    l10n.secureStorageUnavailableLinux,
  AppErrorCode.errorSaveTryAgain => l10n.errorSaveTryAgain,
  AppErrorCode.errorModelDidNotFinish => l10n.errorModelDidNotFinish(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorStudyFieldRequired => l10n.errorStudyFieldRequired(
    studyFieldText(
      l10n,
      arguments.firstOrNull ?? '',
      builtin: arguments.elementAtOrNull(2) == 'builtin',
    ),
  ),
  AppErrorCode.errorStudyFieldTooLong => l10n.errorStudyFieldTooLong(
    studyFieldText(
      l10n,
      arguments.firstOrNull ?? '',
      builtin: arguments.elementAtOrNull(2) == 'builtin',
    ),
    arguments.elementAtOrNull(1) ?? '',
  ),

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
  AppErrorCode.insufficientAPIBalanceCheckYour =>
    l10n.insufficientAPIBalanceCheckYour,
  AppErrorCode.tooManyRequestsTryAgain => l10n.tooManyRequestsTryAgain,
  AppErrorCode.theServiceDoesNotSupport => l10n.theServiceDoesNotSupport,
  AppErrorCode.theConnectionFailedOrThe => l10n.theConnectionFailedOrThe,
  AppErrorCode.yourChatGPTSignInHas => l10n.yourChatGPTSignInHas,
  AppErrorCode.chatGPTPlanAllowanceOrPermissions =>
    l10n.chatGPTPlanAllowanceOrPermissions,
  AppErrorCode.chatGptUnsupportedModelOrParameter =>
    l10n.chatGptUnsupportedModelOrParameter,
  AppErrorCode.theChatGPTRequestFailedCheck =>
    l10n.theChatGPTRequestFailedCheck,
  AppErrorCode.chatGPTReturnedAnErrorRefresh =>
    l10n.chatGPTReturnedAnErrorRefresh,

  AppErrorCode.errorImageCouldNotBeDecoded => l10n.errorImageCouldNotBeDecoded,
  AppErrorCode.errorImageCouldNotBeSaved => l10n.errorImageCouldNotBeSaved,
  AppErrorCode.errorSaveCheckStorage => l10n.errorSaveCheckStorage,

  AppErrorCode.errorMissingParameter => l10n.errorMissingParameter(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorInvalidParameterType => l10n.errorInvalidParameterType(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorUnknownParameter => l10n.errorUnknownParameter(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorParameterMustBeText => l10n.errorParameterMustBeText(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorParameterMustBeNumber => l10n.errorParameterMustBeNumber(
    arguments.firstOrNull ?? '',
  ),
  AppErrorCode.errorServiceReturnedDetails => l10n.errorServiceReturnedDetails(
    arguments.firstOrNull ?? '',
  ),

  AppErrorCode.errorAnotherBackupOperationIsStillIn =>
    l10n.errorAnotherBackupOperationIsStillIn,
  AppErrorCode.errorTheRestoreDidNotFinishThe =>
    l10n.errorTheRestoreDidNotFinishThe,
  AppErrorCode.errorInvalidSubject => l10n.errorInvalidSubject,
  AppErrorCode.errorTheParentModuleDoesNotExist =>
    l10n.errorTheParentModuleDoesNotExist,
  AppErrorCode.errorInvalidMaterialType => l10n.errorInvalidMaterialType,
  AppErrorCode.errorTheFolderDoesNotExistOr =>
    l10n.errorTheFolderDoesNotExistOr,
  AppErrorCode.errorTheQuestionDoesNotExist =>
    l10n.errorTheQuestionDoesNotExist,
  AppErrorCode.errorThisFolderHasNoMaterialsAvailable =>
    l10n.errorThisFolderHasNoMaterialsAvailable,
  AppErrorCode.errorTheSelectedMistakesAreMostlyImages =>
    l10n.errorTheSelectedMistakesAreMostlyImages,
  AppErrorCode.errorAtMost8ToolCallsAre => l10n.errorAtMost8ToolCallsAre,
  AppErrorCode.errorToolCallsAreIncompleteOrHave =>
    l10n.errorToolCallsAreIncompleteOrHave,
  AppErrorCode.errorToolCallDataIsTooLong => l10n.errorToolCallDataIsTooLong,
  AppErrorCode.errorSimulatedNetworkFailureSelectRegenerateTo =>
    l10n.errorSimulatedNetworkFailureSelectRegenerateTo,
  AppErrorCode.errorTheChatGPTSignInRecordIs =>
    l10n.errorTheChatGPTSignInRecordIs,
  AppErrorCode.errorTheConversationNoLongerExistsSelect =>
    l10n.errorTheConversationNoLongerExistsSelect,
  AppErrorCode.errorTheSummaryIsEmptyTheContext =>
    l10n.errorTheSummaryIsEmptyTheContext,
  AppErrorCode.errorQuestionDataIsTooLong => l10n.errorQuestionDataIsTooLong,
  AppErrorCode.errorInvalidQuestionImageReference =>
    l10n.errorInvalidQuestionImageReference,
  AppErrorCode.errorThisModelCannotCurrentlyCreateSelf =>
    l10n.errorThisModelCannotCurrentlyCreateSelf,
  AppErrorCode.errorThisToolCallIDHasAlready =>
    l10n.errorThisToolCallIDHasAlready,
  AppErrorCode.errorTheSuggestedQuestionRegionsAreToo =>
    l10n.errorTheSuggestedQuestionRegionsAreToo,
  AppErrorCode.errorInvalidSuggestedQuestionRegions =>
    l10n.errorInvalidSuggestedQuestionRegions,
  AppErrorCode.errorTheSourceImageIsMissingOr =>
    l10n.errorTheSourceImageIsMissingOr,
  AppErrorCode.errorTheImageDoesNotBelongTo =>
    l10n.errorTheImageDoesNotBelongTo,
  AppErrorCode.errorTheArgumentIsTooLong => l10n.errorTheArgumentIsTooLong,
  AppErrorCode.errorUnknownTool => l10n.errorUnknownTool,
  AppErrorCode.errorNoFieldsToUpdateWereProvided =>
    l10n.errorNoFieldsToUpdateWereProvided,
  AppErrorCode.errorInvalidToolCallIndex => l10n.errorInvalidToolCallIndex,
  AppErrorCode.errorInvalidToolCallID => l10n.errorInvalidToolCallID,
  AppErrorCode.errorInvalidToolArgumentFragment =>
    l10n.errorInvalidToolArgumentFragment,
  AppErrorCode.errorTheAttachmentDirectoryContainsSymbolicLinks =>
    l10n.errorTheAttachmentDirectoryContainsSymbolicLinks,
  AppErrorCode.errorTheNumberOfAttachmentsExceedsThe =>
    l10n.errorTheNumberOfAttachmentsExceedsThe,
  AppErrorCode.errorTheUncompressedBackupExceedsThe8 =>
    l10n.errorTheUncompressedBackupExceedsThe8,
  AppErrorCode.errorSomeImageAttachmentsAreMissingRepair =>
    l10n.errorSomeImageAttachmentsAreMissingRepair,
  AppErrorCode.errorTheBackupManifestIsTooLarge =>
    l10n.errorTheBackupManifestIsTooLarge,
  AppErrorCode.errorTheBackupFileIsTooLarge =>
    l10n.errorTheBackupFileIsTooLarge,
  AppErrorCode.errorInvalidNumberOfFilesInThe =>
    l10n.errorInvalidNumberOfFilesInThe,
  AppErrorCode.errorTheBackupContainsDuplicateFilesLinks =>
    l10n.errorTheBackupContainsDuplicateFilesLinks,
  AppErrorCode.errorTheExpandedBackupIsTooLarge =>
    l10n.errorTheExpandedBackupIsTooLarge,
  AppErrorCode.errorTheBackupManifestIsMissing =>
    l10n.errorTheBackupManifestIsMissing,
  AppErrorCode.errorTheBackupFormatOrDatabaseVersion =>
    l10n.errorTheBackupFormatOrDatabaseVersion,
  AppErrorCode.errorTheBackupManifestIsIncomplete =>
    l10n.errorTheBackupManifestIsIncomplete,
  AppErrorCode.errorInvalidBackupChecksumInformation =>
    l10n.errorInvalidBackupChecksumInformation,
  AppErrorCode.errorTheBackupManifestContainsDuplicatePaths =>
    l10n.errorTheBackupManifestContainsDuplicatePaths,
  AppErrorCode.errorTheBackupManifestDoesNotMatch =>
    l10n.errorTheBackupManifestDoesNotMatch,
  AppErrorCode.errorTheBackupFileInformationDoesNot =>
    l10n.errorTheBackupFileInformationDoesNot,
  AppErrorCode.errorTheAttachmentPathIsOutsideThe =>
    l10n.errorTheAttachmentPathIsOutsideThe,
  AppErrorCode.errorBackupIntegrityVerificationFailedExistingData =>
    l10n.errorBackupIntegrityVerificationFailedExistingData,
  AppErrorCode.errorTheDatabaseVersionDoesNotMatch =>
    l10n.errorTheDatabaseVersionDoesNotMatch,
  AppErrorCode.errorTheBackupIsMissingAttachmentsReferenced =>
    l10n.errorTheBackupIsMissingAttachmentsReferenced,
  AppErrorCode.errorCannotReadTheBackupItMay =>
    l10n.errorCannotReadTheBackupItMay,
  AppErrorCode.errorDatabaseIntegrityCheckFailed =>
    l10n.errorDatabaseIntegrityCheckFailed,
  AppErrorCode.errorInvalidAttachmentPathInTheBackup =>
    l10n.errorInvalidAttachmentPathInTheBackup,
  AppErrorCode.errorAFileInTheBackupHas => l10n.errorAFileInTheBackupHas,
  AppErrorCode.errorTheBackupDatabaseIsInvalidOr =>
    l10n.errorTheBackupDatabaseIsInvalidOr,
  AppErrorCode.errorThisDatabaseDoesNotBelongTo =>
    l10n.errorThisDatabaseDoesNotBelongTo,
  AppErrorCode.errorTheRecoveryRecordIsInvalidAutomatic =>
    l10n.errorTheRecoveryRecordIsInvalidAutomatic,
  AppErrorCode.errorRecoveryIsIncompleteAndNoUsable =>
    l10n.errorRecoveryIsIncompleteAndNoUsable,
  AppErrorCode.errorTheSafetyCopyPathIsInvalid =>
    l10n.errorTheSafetyCopyPathIsInvalid,
  AppErrorCode.errorInvalidRestoreStagingDirectory =>
    l10n.errorInvalidRestoreStagingDirectory,
  AppErrorCode.errorThereIsNoRestoreToUndo => l10n.errorThereIsNoRestoreToUndo,
  AppErrorCode.errorTheSafetyCopyContainsSymbolicLinks =>
    l10n.errorTheSafetyCopyContainsSymbolicLinks,
  AppErrorCode.errorInvalidAttachmentDirectory =>
    l10n.errorInvalidAttachmentDirectory,
  AppErrorCode.errorInvalidTeachingMode => l10n.errorInvalidTeachingMode,
  AppErrorCode.errorTheConversationNameCannotBeEmpty =>
    l10n.errorTheConversationNameCannotBeEmpty,
  AppErrorCode.errorInvalidAttachmentPath => l10n.errorInvalidAttachmentPath,
  AppErrorCode.errorEachImageMustBeAtMost => l10n.errorEachImageMustBeAtMost,
  AppErrorCode.errorOnlyJPGPNGGIFAndWebP => l10n.errorOnlyJPGPNGGIFAndWebP,
  AppErrorCode.errorTheAIScoreBreakdownIsToo =>
    l10n.errorTheAIScoreBreakdownIsToo,
  AppErrorCode.errorTheAIDidNotReturnA => l10n.errorTheAIDidNotReturnA,
  AppErrorCode.errorTheQuestionNumbersOrNotesReturned =>
    l10n.errorTheQuestionNumbersOrNotesReturned,
  AppErrorCode.errorTheAIScoreFormatIsInvalid =>
    l10n.errorTheAIScoreFormatIsInvalid,
  AppErrorCode.errorTheAISubquestionFormatIsInvalid =>
    l10n.errorTheAISubquestionFormatIsInvalid,
  AppErrorCode.errorTheScoreBreakdownSupportsOnlyTwo =>
    l10n.errorTheScoreBreakdownSupportsOnlyTwo,
  AppErrorCode.errorAScoreBreakdownCanHaveAt =>
    l10n.errorAScoreBreakdownCanHaveAt,
  AppErrorCode.errorSelectImagesForTheAITo => l10n.errorSelectImagesForTheAITo,
  AppErrorCode.errorTheImagesExceed20MBIn => l10n.errorTheImagesExceed20MBIn,
  AppErrorCode.errorTheAIReturnedDataAfterCompletion =>
    l10n.errorTheAIReturnedDataAfterCompletion,
  AppErrorCode.errorTheAIResponseIsTooLong => l10n.errorTheAIResponseIsTooLong,
  AppErrorCode.errorToolCallsAreNotAllowedWhile =>
    l10n.errorToolCallsAreNotAllowedWhile,
  AppErrorCode.errorTheConnectionClosedEarlyTheScore =>
    l10n.errorTheConnectionClosedEarlyTheScore,
  AppErrorCode.errorInvalidScoreFormat => l10n.errorInvalidScoreFormat,
  AppErrorCode.errorInvalidPhotoRecoveryDestination =>
    l10n.errorInvalidPhotoRecoveryDestination,
  AppErrorCode.errorQuestionNumbersMustBeUniqueAnd =>
    l10n.errorQuestionNumbersMustBeUniqueAnd,
  AppErrorCode.errorEachSubquestionMustBelongToA =>
    l10n.errorEachSubquestionMustBelongToA,
  AppErrorCode.errorQuestionNumbersAtTheSameLevel =>
    l10n.errorQuestionNumbersAtTheSameLevel,
  AppErrorCode.errorScoresMustBeValidNumbersFrom =>
    l10n.errorScoresMustBeValidNumbersFrom,
  AppErrorCode.errorTheScoreCannotExceedTheMaximum =>
    l10n.errorTheScoreCannotExceedTheMaximum,
  AppErrorCode.errorCheckTheLengthsOfTheSubject =>
    l10n.errorCheckTheLengthsOfTheSubject,
  AppErrorCode.errorThisRecordHasChangedReopenThe =>
    l10n.errorThisRecordHasChangedReopenThe,
  AppErrorCode.errorInvalidImageCategory => l10n.errorInvalidImageCategory,
  AppErrorCode.errorReopenThisConversationBeforeSaving =>
    l10n.errorReopenThisConversationBeforeSaving,
  AppErrorCode.errorThisConversationHasNoLinkedMistake =>
    l10n.errorThisConversationHasNoLinkedMistake,
  AppErrorCode.errorTheSelectedAreaIsTooSmall =>
    l10n.errorTheSelectedAreaIsTooSmall,
  AppErrorCode.errorTheImageExceedsTheEditorS =>
    l10n.errorTheImageExceedsTheEditorS,
  AppErrorCode.errorTheImageResolutionIsTooLarge =>
    l10n.errorTheImageResolutionIsTooLarge,
  AppErrorCode.errorTheEditedCopyExceeds8MB =>
    l10n.errorTheEditedCopyExceeds8MB,
  AppErrorCode.errorFolderNamesMustContain180 =>
    l10n.errorFolderNamesMustContain180,
  AppErrorCode.errorASubmoduleMustBeUnderA => l10n.errorASubmoduleMustBeUnderA,
  AppErrorCode.errorEachSubjectCanHaveAtMost =>
    l10n.errorEachSubjectCanHaveAtMost,
  AppErrorCode.errorFolderNamesMustContain1802 =>
    l10n.errorFolderNamesMustContain1802,
  AppErrorCode.errorInvalidSortDirection => l10n.errorInvalidSortDirection,
  AppErrorCode.errorEachMaterialCanBeLinkedTo =>
    l10n.errorEachMaterialCanBeLinkedTo,
  AppErrorCode.errorTheMaterialDoesNotExistOr =>
    l10n.errorTheMaterialDoesNotExistOr,
  AppErrorCode.errorTheCategoryWasChangedElsewhereReopen =>
    l10n.errorTheCategoryWasChangedElsewhereReopen,
  AppErrorCode.errorOnlyModulesOrSubmodulesInThe =>
    l10n.errorOnlyModulesOrSubmodulesInThe,
  AppErrorCode.errorTheQuestionRegionContainsUnknownFields =>
    l10n.errorTheQuestionRegionContainsUnknownFields,
  AppErrorCode.errorInvalidQuestionRegionText =>
    l10n.errorInvalidQuestionRegionText,
  AppErrorCode.errorQuestionRegionCoordinatesMustBeWithin =>
    l10n.errorQuestionRegionCoordinatesMustBeWithin,
  AppErrorCode.errorTheQuestionRegionIsTooSmall =>
    l10n.errorTheQuestionRegionIsTooSmall,
  AppErrorCode.errorTheSourceConversationWasDeletedFind =>
    l10n.errorTheSourceConversationWasDeletedFind,
  AppErrorCode.errorTheMaterialIsTooLongEdit =>
    l10n.errorTheMaterialIsTooLongEdit,
  AppErrorCode.errorEachMaterialCanHaveAtMost =>
    l10n.errorEachMaterialCanHaveAtMost,
  AppErrorCode.errorInvalidUserCropArea => l10n.errorInvalidUserCropArea,
  AppErrorCode.errorInvalidQuestionRegionImageOrNumber =>
    l10n.errorInvalidQuestionRegionImageOrNumber,
  AppErrorCode.errorTheSuggestedQuestionRegionWasNot =>
    l10n.errorTheSuggestedQuestionRegionWasNot,
  AppErrorCode.errorTheKnowledgeRecordDoesNotExist =>
    l10n.errorTheKnowledgeRecordDoesNotExist,
  AppErrorCode.errorTheMistakeDoesNotExistOr =>
    l10n.errorTheMistakeDoesNotExistOr,
  AppErrorCode.errorTheSourceConversationAndMessageDo =>
    l10n.errorTheSourceConversationAndMessageDo,
  AppErrorCode.errorInvalidKnowledgeType => l10n.errorInvalidKnowledgeType,
  AppErrorCode.errorSelect1200MaterialsAtA => l10n.errorSelect1200MaterialsAtA,
  AppErrorCode.errorTheImageFileIsMissing => l10n.errorTheImageFileIsMissing,
  AppErrorCode.errorSelectADifferentKnowledgeRecord =>
    l10n.errorSelectADifferentKnowledgeRecord,
  AppErrorCode.errorTheQuizRecoveryStateIsInvalid =>
    l10n.errorTheQuizRecoveryStateIsInvalid,
  AppErrorCode.errorInvalidQuestionSource => l10n.errorInvalidQuestionSource,
  AppErrorCode.errorThisOperationAlreadyCreatedAQuestion =>
    l10n.errorThisOperationAlreadyCreatedAQuestion,
  AppErrorCode.errorTheAnswerIsTooLong => l10n.errorTheAnswerIsTooLong,
  AppErrorCode.errorCompleteYourAnswerFirst =>
    l10n.errorCompleteYourAnswerFirst,
  AppErrorCode.errorFillInAllBlanks => l10n.errorFillInAllBlanks,
  AppErrorCode.errorInvalidOption => l10n.errorInvalidOption,
  AppErrorCode.errorEnterAFiniteNumberDecimalOr =>
    l10n.errorEnterAFiniteNumberDecimalOr,
  AppErrorCode.errorAQuestionInThisQuizWas => l10n.errorAQuestionInThisQuizWas,
  AppErrorCode.errorTheQuizAnswerStateIsInconsistent =>
    l10n.errorTheQuizAnswerStateIsInconsistent,
  AppErrorCode.errorTheQuizProgressIsInconsistentEnd =>
    l10n.errorTheQuizProgressIsInconsistentEnd,
  AppErrorCode.errorTheQuizStateCouldNotBe => l10n.errorTheQuizStateCouldNotBe,
  AppErrorCode.errorThereAreNoQuestionsYetEnter =>
    l10n.errorThereAreNoQuestionsYetEnter,
  AppErrorCode.errorThisQuizRoundDoesNotExist =>
    l10n.errorThisQuizRoundDoesNotExist,
  AppErrorCode.errorSubmitAndGradeTheAnswerFirst =>
    l10n.errorSubmitAndGradeTheAnswerFirst,
  AppErrorCode.errorTheQuestionContainsUnknownFields =>
    l10n.errorTheQuestionContainsUnknownFields,
  AppErrorCode.errorInvalidQuestionOptionsAnswersOrArguments =>
    l10n.errorInvalidQuestionOptionsAnswersOrArguments,
  AppErrorCode.errorTheQuestionTextIsEmptyOr =>
    l10n.errorTheQuestionTextIsEmptyOr,
  AppErrorCode.errorUnsupportedQuestionType =>
    l10n.errorUnsupportedQuestionType,
  AppErrorCode.errorThereAreTooManyKnowledgePoints =>
    l10n.errorThereAreTooManyKnowledgePoints,
  AppErrorCode.errorInvalidToleranceOrTimeLimit =>
    l10n.errorInvalidToleranceOrTimeLimit,
  AppErrorCode.errorTheNumberOfAnswersIsInvalid =>
    l10n.errorTheNumberOfAnswersIsInvalid,
  AppErrorCode.errorTheOptionsAndCorrectAnswersDo =>
    l10n.errorTheOptionsAndCorrectAnswersDo,
  AppErrorCode.errorTrueFalseOptionsMustUseTrue =>
    l10n.errorTrueFalseOptionsMustUseTrue,
  AppErrorCode.errorInvalidFillInOrNumericAnswer =>
    l10n.errorInvalidFillInOrNumericAnswer,
  AppErrorCode.errorThisQuestionRequiresSelfGrading =>
    l10n.errorThisQuestionRequiresSelfGrading,
  AppErrorCode.errorInvalidLearningSettings =>
    l10n.errorInvalidLearningSettings,
  AppErrorCode.errorEnterTheDailyTimeAsA => l10n.errorEnterTheDailyTimeAsA,
  AppErrorCode.errorInvalidReviewStatus => l10n.errorInvalidReviewStatus,
  AppErrorCode.errorCompleteGradingBeforeSchedulingAReview =>
    l10n.errorCompleteGradingBeforeSchedulingAReview,
  AppErrorCode.errorTheDateMustBeBetweenToday =>
    l10n.errorTheDateMustBeBetweenToday,
  AppErrorCode.errorVisualSceneJsonEmpty => l10n.errorVisualSceneJsonEmpty,
  AppErrorCode.errorVisualSceneDoesNotExist =>
    l10n.errorVisualSceneDoesNotExist,
  AppErrorCode.errorVisualSceneRevisionDoesNotExist =>
    l10n.errorVisualSceneRevisionDoesNotExist,
  AppErrorCode.errorVisualStudyLinkNeedsOneOwner =>
    l10n.errorVisualStudyLinkNeedsOneOwner,

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
