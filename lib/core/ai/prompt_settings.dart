import 'dart:convert';

class PromptDefinition {
  const PromptDefinition(this.id, this.title, this.description, this.content);
  final String id, title, description, content;
}

const promptDefinitions = [
  PromptDefinition(
    'global',
    '通用教学风格',
    '用于所有学习请求，可调整语气、详略和讲解方式。',
    '你是题训 TiXun 的学习助手。解释应准确、清晰、尊重学习者，结合其学习阶段，优先理解真实困难。按需使用例子、反例和类比。',
  ),
  PromptDefinition(
    'guided',
    '引导教学',
    '普通对话的默认教学方式。',
    '先判断用户卡在哪里，必要时问一两个诊断问题，适量提示，让用户独立尝试，再根据回答反馈。按需给例子和检测题。不要机械套用固定流程；用户要求直接给答案时应遵从。',
  ),
  PromptDefinition(
    'direct',
    '直接解答',
    '用户选择直接解答时使用。',
    '根据问题解释原理，给出完整推导与答案。说明关键步骤和适用条件。',
  ),
  PromptDefinition(
    'exam',
    '考试训练',
    '训练对话的教学方式。提交前隐藏答案的规则仍由应用保留。',
    '出题并协助训练，先让用户独立作答，提交后再反馈，区分答案是否已核对。',
  ),
  PromptDefinition(
    'knowledge',
    '知识讲解',
    '从知识详情进入对话时使用。',
    '请帮我理解这条知识，并用例子检验我的理解。',
  ),
  PromptDefinition(
    'mistake',
    '错题讲解',
    '从错题详情发起引导讲解时使用。',
    '请引导我重新理解这道错题，先诊断我的困难，不要立即给出答案。',
  ),
  PromptDefinition(
    'quiz',
    '生成练习',
    '快速出题和知识专项、综合训练的请求。',
    '请给我出一道符合当前学习阶段的检测题，让我直接作答。题目条件需完整，不要提前透露答案。',
  ),
  PromptDefinition(
    'variant',
    '订正与变式',
    '从作答反馈发起同考点训练时使用。',
    '请针对以下题目引导我订正，再出一道可以直接作答的同考点变式题，不要提前给答案。新题条件需完整，不要引入未提供的图表。',
  ),
  PromptDefinition(
    'split',
    '图片分题',
    '从图片发起分题建议时使用。',
    '请判断这张图片包含几道题，给出分题范围建议。我会逐一检查、修改后再保存。题目文字不清楚时请保留原图，不要编造。',
  ),
];

class PromptSettings {
  PromptSettings([Map<String, String> values = const {}])
    : overrides = Map.unmodifiable(values) {
    for (final entry in overrides.entries) {
      if (!promptDefinitions.any((p) => p.id == entry.key) ||
          entry.value.trim().isEmpty ||
          entry.value.length > 6000) {
        throw const FormatException('每条提示词需为 1–6000 字符，且类型必须有效。');
      }
    }
    if (overrides.values.fold<int>(0, (n, text) => n + text.length) > 24000) {
      throw const FormatException('自定义提示词总长度不能超过 24000 字符。');
    }
  }
  static const preference = 'ai_prompts_v1';
  final Map<String, String> overrides;
  String text(String id) =>
      overrides[id] ?? promptDefinitions.firstWhere((p) => p.id == id).content;
  PromptSettings update(String id, String value) {
    final definition = promptDefinitions.firstWhere((p) => p.id == id);
    final next = Map<String, String>.of(overrides);
    if (value.trim() == definition.content) {
      next.remove(id);
    } else {
      next[id] = value.trim();
    }
    return PromptSettings(next);
  }

  String encode() => jsonEncode({'version': 1, 'overrides': overrides});
  factory PromptSettings.decode(String? value) {
    if (value == null || value.isEmpty) return PromptSettings();
    final data = jsonDecode(value);
    if (data is! Map || data['version'] != 1 || data['overrides'] is! Map) {
      throw const FormatException('提示词配置格式无效。');
    }
    final values = data['overrides'] as Map;
    if (values.entries.any((e) => e.key is! String || e.value is! String)) {
      throw const FormatException('提示词配置的名称和内容必须是文字。');
    }
    return PromptSettings(Map<String, String>.from(values));
  }
}
