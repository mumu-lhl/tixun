import '../../core/database/database.dart';
import '../../core/l10n/app_error.dart';

/// The selected learning subject is a hard boundary; an empty filter is unscoped.
Future<String?> readStudySubjectScope(AppDatabase db) async {
  final value = (await db.preference('subject_filter'))?.trim() ?? '';
  return value.isEmpty ? null : value;
}

void requireStudySubject(String subject, String? scope) {
  if (scope != null && subject.trim() != scope) {
    throw AppFormatException(
      AppErrorCode.errorInvalidSubject,
      '当前学习科目为“$scope”，不能操作“$subject”资料。',
    );
  }
}
