import 'package:flutter/widgets.dart';

import '../ai/ai_options.dart';
import '../l10n/app_strings.dart';

/// Localizes known reasoning levels; provider-defined levels stay unchanged.
String reasoningEffortLabel(
  BuildContext context,
  AiOptions options,
  String effort,
) {
  if (options.config.kind == 'deepseek' && effort == 'max') {
    return context.l10n.maximum;
  }
  return switch (effort) {
    'none' => context.l10n.noReasoningNone,
    'minimal' => context.l10n.minimalMinimal,
    'low' => context.l10n.low,
    'medium' => context.l10n.medium,
    'high' => context.l10n.high,
    'xhigh' => context.l10n.extraHighXhigh,
    'max' => context.l10n.maximumMax,
    'ultra' => context.l10n.ultraUltra,
    _ => effort,
  };
}

String reasoningOffLabel(
  BuildContext context,
  AiOptions options, {
  bool choice = false,
}) => options.config.kind == 'deepseek'
    ? (choice ? context.l10n.thinkingOff : context.l10n.close)
    : context.l10n.modelDefault;
