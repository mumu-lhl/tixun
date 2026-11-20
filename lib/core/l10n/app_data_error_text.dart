part of "app_error_localization.dart";

String? _dataErrorText(
  AppLocalizations l10n,
  AppErrorCode code,
  List<String> arguments,
) => switch (code) {
  AppErrorCode.errorSaveTryAgain => l10n.errorSaveTryAgain,
  AppErrorCode.errorModelDidNotFinish => l10n.errorModelDidNotFinish(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorStudyFieldRequired => l10n.errorStudyFieldRequired(
    studyFieldText(
      l10n,
      arguments.firstOrNull ?? "",
      builtin: arguments.elementAtOrNull(2) == "builtin",
    ),
  ),
  AppErrorCode.errorStudyFieldTooLong => l10n.errorStudyFieldTooLong(
    studyFieldText(
      l10n,
      arguments.firstOrNull ?? "",
      builtin: arguments.elementAtOrNull(2) == "builtin",
    ),
    arguments.elementAtOrNull(1) ?? "",
  ),

  AppErrorCode.errorImageCouldNotBeDecoded => l10n.errorImageCouldNotBeDecoded,
  AppErrorCode.errorImageCouldNotBeSaved => l10n.errorImageCouldNotBeSaved,
  AppErrorCode.errorSaveCheckStorage => l10n.errorSaveCheckStorage,

  AppErrorCode.errorMissingParameter => l10n.errorMissingParameter(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorInvalidParameterType => l10n.errorInvalidParameterType(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorUnknownParameter => l10n.errorUnknownParameter(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorParameterMustBeText => l10n.errorParameterMustBeText(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorParameterMustBeNumber => l10n.errorParameterMustBeNumber(
    arguments.firstOrNull ?? "",
  ),
  AppErrorCode.errorServiceReturnedDetails => l10n.errorServiceReturnedDetails(
    arguments.firstOrNull ?? "",
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
  AppErrorCode.errorAssessmentFigureMustBeStatic =>
    l10n.errorAssessmentFigureMustBeStatic,
  AppErrorCode.errorVisualQuestionNotAnswerable =>
    l10n.errorVisualQuestionNotAnswerable,
  _ => null,
};
