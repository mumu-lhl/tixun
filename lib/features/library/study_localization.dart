import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';

/// Only translates built-in knowledgeKinds; unknown stored or user values remain unchanged.
String knowledgeKindLabel(BuildContext context, String value) =>
    switch (value) {
      '通用文章' => context.l10n.article,
      '概念' => context.l10n.concept,
      '定义' => context.l10n.definition,
      '公式' => context.l10n.formula,
      '定理' => context.l10n.theorem,
      '原理' => context.l10n.principle,
      '解题方法' => context.l10n.problemSolvingMethod,
      '解题技巧' => context.l10n.problemSolvingTip,
      '易错点' => context.l10n.commonPitfall,
      '例题' => context.l10n.workedExample,
      '个人笔记' => context.l10n.personalNote,
      _ => value,
    };

/// Only translates built-in mistakeReasons; unknown stored or user values remain unchanged.
String mistakeReasonLabel(BuildContext context, String value) =>
    switch (value) {
      '知识不理解' => context.l10n.conceptNotUnderstood,
      '公式记忆错误' => context.l10n.formulaRecallError,
      '方法选择错误' => context.l10n.wrongMethod,
      '推理或计算错误' => context.l10n.reasoningOrCalculationError,
      '审题错误' => context.l10n.misreadTheQuestion,
      '遗漏条件' => context.l10n.missedACondition,
      '粗心失误' => context.l10n.carelessMistake,
      '时间不足' => context.l10n.ranOutOfTime,
      '暂未确定' => context.l10n.notYetIdentified,
      _ => value,
    };
