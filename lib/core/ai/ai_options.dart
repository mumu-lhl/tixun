import '../database/database.dart';

/// One place for model capabilities and task compatibility. Encoders own only
/// wire syntax; UI and learning workflows use the same resolved decisions.
class AiOptions {
  const AiOptions(this.config);
  final ProviderConfig config;
  bool get reasoningWithTools =>
      config.kind == 'chatgpt' || config.kind == 'deepseek';
  bool get toolsAvailable =>
      config.supportsTools && (!config.thinking || reasoningWithTools);
  bool get vision =>
      config.vision &&
      !(config.kind == 'deepseek' && config.model == 'deepseek-v4-pro');
  String get offLabel => config.kind == 'deepseek' ? '关闭' : '模型默认';
  String get offChoiceLabel => config.kind == 'deepseek' ? '关闭思考' : '模型默认';
  String get effortParameter =>
      config.kind == 'chatgpt' && config.effort == 'max'
      ? 'xhigh'
      : config.effort;
  static ProviderConfig forSession(ProviderConfig config, String override) =>
      override.isEmpty
      ? config
      : config.copyWith(
          thinking: config.supportsThinking && override != 'off',
          effort: override == 'off' ? config.effort : override,
        );
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
  if (c.thinking &&
      (!c.supportsThinking || !['low', 'high', 'max'].contains(c.effort))) {
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
