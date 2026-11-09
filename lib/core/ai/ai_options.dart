import 'dart:convert';

import '../database/database.dart';

/// One place for model capabilities and task compatibility. Encoders own only
/// wire syntax; UI and learning workflows use the same resolved decisions.
class AiOptions {
  const AiOptions(this.config);
  final ProviderConfig config;
  bool get reasoningWithTools =>
      config.kind == 'chatgpt' || config.kind == 'deepseek';
  bool get toolsAvailable =>
      config.supportsTools && (!reasoningEnabled || reasoningWithTools);
  bool get vision =>
      config.vision &&
      !(config.kind == 'deepseek' && config.model == 'deepseek-v4-pro');
  String get offLabel => config.kind == 'deepseek' ? '关闭' : '模型默认';
  String get offChoiceLabel => config.kind == 'deepseek' ? '关闭思考' : '模型默认';
  bool get reasoningEnabled =>
      config.supportsThinking && config.thinking && config.effort != 'none';
  List<String> get reasoningEfforts {
    if (!config.supportsThinking) return [];
    if (config.kind == 'deepseek') return deepSeekReasoningLevels;
    final declared = config.reasoningLevels;
    if (declared != null) {
      try {
        return decodeReasoningLevels(declared);
      } on FormatException {
        /* use documented fallback */
      }
    }
    final known = documentedGptLevels(config.model);
    return config.kind == 'chatgpt'
        ? known
        : known.isNotEmpty
        ? known
        : apiReasoningLevels;
  }

  String label(String effort) => config.kind == 'deepseek' && effort == 'max'
      ? '最高'
      : reasoningLevelLabels[effort] ?? effort;
  String get preferredEffort => reasoningEfforts.contains(config.effort)
      ? config.effort
      : reasoningEfforts.contains('high')
      ? 'high'
      : reasoningEfforts.firstOrNull ?? 'high';
  bool supportsOverride(String value) =>
      value.isEmpty || value == 'off' || reasoningEfforts.contains(value);
  String get effortParameter => config.effort;
  static ProviderConfig forSession(ProviderConfig config, String override) {
    final options = AiOptions(config);
    if (override.isEmpty || !options.supportsOverride(override)) return config;
    return config.copyWith(
      thinking: config.supportsThinking && override != 'off',
      effort: override == 'off' ? config.effort : override,
    );
  }
}

void validateConfig(ProviderConfig c) {
  if (c.kind == 'chatgpt' && c.baseUrl != 'https://api.openai.com/v1') {
    throw const FormatException('ChatGPT 仅使用官方接口地址。');
  }
  final uri = Uri.tryParse(c.baseUrl);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.scheme != 'https' &&
          !(uri.scheme == 'http' &&
              ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
    throw const FormatException('API 地址需为 HTTPS（本机测试可用 HTTP），不可包含密钥、查询参数或片段。');
  }
  if (c.reasoningLevels != null) decodeReasoningLevels(c.reasoningLevels!);
  if (c.thinking &&
      (!c.supportsThinking ||
          !AiOptions(c).reasoningEfforts.contains(c.effort))) {
    throw const FormatException('当前模型不支持所选思考参数。');
  }
  if (c.model.trim().isEmpty) throw const FormatException('请填写模型 ID。');
  if (c.kind == 'deepseek' &&
      !['deepseek-flash', 'deepseek-v4-pro'].contains(c.model)) {
    throw const FormatException('请选择支持的 DeepSeek 模型。');
  }
  if (c.kind == 'deepseek' && c.model == 'deepseek-v4-pro' && c.vision) {
    throw const FormatException('DeepSeek Pro 不支持图片，请关闭图片能力。');
  }
}

const apiReasoningLevels = [
  'none',
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
  'max',
];
const deepSeekReasoningLevels = ['low', 'high', 'max'];
const reasoningLevelLabels = {
  'none': '不推理（none）',
  'minimal': '极低（minimal）',
  'low': '低',
  'medium': '中',
  'high': '高',
  'xhigh': '极高（xhigh）',
  'max': '最大（max）',
  'ultra': '超高（ultra）',
};

List<String> decodeReasoningLevels(String value) {
  final dynamic data = jsonDecode(value);
  if (data is! List ||
      data.length > 12 ||
      data.any(
        (e) => e is! String || !RegExp(r'^[a-z][a-z0-9_-]{0,31}$').hasMatch(e),
      )) {
    throw const FormatException('模型思考档位声明无效。');
  }
  return List<String>.unmodifiable(data.cast<String>().toSet());
}

/// Public /models may advertise additional levels. Honor those values verbatim;
/// client-only levels such as ultra are never offered without a declaration.
List<String>? advertisedReasoningLevels(Map model) {
  final dynamic raw =
      model['supported_reasoning_levels'] ??
      model['supported_reasoning_efforts'];
  if (raw == null) return null;
  if (raw is! List) return null;
  final values = <String>[];
  for (final dynamic entry in raw) {
    final dynamic level = entry is String
        ? entry
        : entry is Map
        ? entry['effort']
        : null;
    if (level is! String) return null;
    values.add(level);
  }
  try {
    return decodeReasoningLevels(jsonEncode(values));
  } on FormatException {
    return null;
  }
}

/// Conservative fallbacks from official model pages, not a claim that every GPT
/// supports the complete API enum. Unknown subscription models use defaults.
List<String> documentedGptLevels(String model) {
  final id = model.toLowerCase();
  if (id.startsWith('gpt-5-pro')) return ['high'];
  if (id.startsWith('gpt-5.2-pro') ||
      id.startsWith('gpt-5.4-pro') ||
      id.startsWith('gpt-5.5-pro')) {
    return ['medium', 'high', 'xhigh'];
  }
  if (id.startsWith('gpt-5.6')) {
    return ['none', 'low', 'medium', 'high', 'xhigh', 'max'];
  }
  // Check -pro before the gpt-6 prefix: gpt-6-pro was matched by the prefix
  // below and wrongly given reasoning levels.
  if (id.contains('-pro')) return [];
  if (id.startsWith('gpt-6')) {
    return ['low', 'medium', 'high', 'xhigh', 'max'];
  }
  if (id.contains('codex')) {
    if (id.startsWith('gpt-5.1-codex-max') ||
        id.startsWith('gpt-5.2') ||
        id.startsWith('gpt-5.3') ||
        id.startsWith('gpt-5.4') ||
        id.startsWith('gpt-5.5')) {
      return ['low', 'medium', 'high', 'xhigh'];
    }
    return ['low', 'medium', 'high'];
  }
  if (id.startsWith('gpt-5.2') ||
      id.startsWith('gpt-5.3') ||
      id.startsWith('gpt-5.4') ||
      id.startsWith('gpt-5.5')) {
    return ['none', 'low', 'medium', 'high', 'xhigh'];
  }
  if (id.startsWith('gpt-5.1')) return ['none', 'low', 'medium', 'high'];
  if (id == 'gpt-5' || id.startsWith('gpt-5-')) {
    return ['minimal', 'low', 'medium', 'high'];
  }
  if (RegExp(r'^o[134]($|-)').hasMatch(id)) return ['low', 'medium', 'high'];
  return [];
}
