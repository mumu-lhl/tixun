import "../../core/l10n/generated/app_localizations.dart";
import "exam_material.dart";
import "exam_store.dart";

String examKindLabel(AppLocalizations l10n, ExamKind kind) => switch (kind) {
  ExamKind.reading => l10n.languageReading,
  ExamKind.sentenceInsertion => l10n.languageSentenceInsertion,
  ExamKind.cloze => l10n.languageCloze,
  ExamKind.grammar => l10n.languageGrammarGap,
};

String examSourceLabel(AppLocalizations l10n, ExamMaterial material) {
  if (material.row.model == "Mock") return l10n.languageExamMock;
  return switch (material.source) {
    ExamSource.bundled => l10n.languageExamBundled,
    ExamSource.userCreated => l10n.languageExamUserCreated,
    ExamSource.aiGenerated => switch (material.verification) {
      ExamVerification.aiReviewed => l10n.languageExamAiReviewed,
      ExamVerification.reviewRejected => l10n.languageExamReviewRejected,
      _ => l10n.languageExamUnverified,
    },
  };
}
