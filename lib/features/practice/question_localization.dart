import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';
import 'question_spec.dart';

/// Localizes built-in question kinds without translating user content.
String questionKindLabel(BuildContext context, String kind) => switch (kind) {
  'single_choice' => context.l10n.singleChoice,
  'multiple_choice' => context.l10n.multipleChoice,
  'true_false' => context.l10n.trueFalse,
  'fill_blank' => context.l10n.fillInTheBlanks,
  'numeric' => context.l10n.numericalAnswer,
  'short_answer' => context.l10n.selfAssessed,
  _ => questionKinds[kind] ?? kind,
};
