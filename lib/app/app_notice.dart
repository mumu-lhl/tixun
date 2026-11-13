import '../core/l10n/generated/app_localizations.dart';

/// Transient controller failures have stable, language-independent identities.
enum AppTransientError {
  draftSaveFailed,
  messageSaveFailed,
  responseSaveFailed;

  String text(AppLocalizations l10n) => switch (this) {
    AppTransientError.draftSaveFailed => l10n.couldNotSaveTheDraft,
    AppTransientError.messageSaveFailed => l10n.couldNotSaveTheMessage,
    AppTransientError.responseSaveFailed => l10n.couldNotSaveTheResponse,
  };
}

/// Stable application notice categories; never contains translated user content.
enum AppNoticeKind {
  promptSettingsUnreadable,
  subjectSettingsUnreadable,
  sessionReasoningFallback,
  imageEditsCleanupFailed,
  draftImageCleanupFailed,
  interruptedImageRestored,
  imageSelectionIncomplete,
  imageRecoveryFailed,
  examSubjectDeleted,
  examPhotosRecovered,
  studyOwnerDeleted,
  studyPhotosRecovered,
  backupExported,
  backupRestored,
  backupRestoreIncomplete,
}

class AppNotice {
  const AppNotice(this.kind, {this.photoCount = 0, this.mistake = false});
  final AppNoticeKind kind;
  final int photoCount;
  final bool mistake;

  String text(AppLocalizations l10n) => switch (kind) {
    AppNoticeKind.promptSettingsUnreadable => l10n.couldNotReadPromptSettings,
    AppNoticeKind.subjectSettingsUnreadable => l10n.couldNotReadYourSubject,
    AppNoticeKind.sessionReasoningFallback => l10n.thisSessionNowUsesThe,
    AppNoticeKind.imageEditsCleanupFailed => l10n.imageEditsSavedButThe,
    AppNoticeKind.draftImageCleanupFailed => l10n.imageRemovedFromTheDraft,
    AppNoticeKind.interruptedImageRestored =>
      l10n.theInterruptedImageSelectionWas,
    AppNoticeKind.imageSelectionIncomplete => l10n.theLastImageSelectionDid,
    AppNoticeKind.imageRecoveryFailed => l10n.couldNotRestoreThePreviously,
    AppNoticeKind.examSubjectDeleted => l10n.theExamSubjectWasDeleted,
    AppNoticeKind.examPhotosRecovered => l10n.examPhotosRecoveredNothingWas,
    AppNoticeKind.studyOwnerDeleted => l10n.theOriginalMaterialWasDeleted,
    AppNoticeKind.studyPhotosRecovered => l10n.restoredStudyPhotos(
      photoCount,
      mistake ? l10n.mistakeBook : l10n.knowledgeLibrary,
    ),
    AppNoticeKind.backupExported => l10n.fullBackupExportedAPIKeys,
    AppNoticeKind.backupRestored => l10n.learningDataRestoredYouCan,
    AppNoticeKind.backupRestoreIncomplete => l10n.restoreDidNotFinishYour,
  };
}
