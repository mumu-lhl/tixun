import 'dart:convert';

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
