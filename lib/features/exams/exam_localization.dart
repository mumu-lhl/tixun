import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';
import 'exam_store.dart';

/// Localizes known image roles while preserving unknown stored values.
String examImageRoleLabel(BuildContext context, String role) => switch (role) {
  'paper' => context.l10n.examPaper,
  'sheet' => context.l10n.answerSheet,
  'answers' => context.l10n.referenceAnswers,
  _ => examImageRoles[role] ?? role,
};
