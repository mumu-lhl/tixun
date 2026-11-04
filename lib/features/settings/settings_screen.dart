import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/database/database.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _base, _model;
  final _key = TextEditingController();
  late String _kind, _effort;
  late bool _vision, _thinking, _supportsThinking, _supportsTools;
  bool _working = false;
  String? _status;
  bool _failure = false;
  @override
  void initState() {
    super.initState();
    final c = ref.read(appControllerProvider).config;
    _base = TextEditingController(text: c.baseUrl);
    _model = TextEditingController(text: c.model);
    _kind = c.kind;
    _effort = c.effort;
    _vision = c.vision;
    _thinking = c.thinking;
    _supportsThinking = c.supportsThinking;
    _supportsTools = c.supportsTools;
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _key.dispose();
    super.dispose();
  }

  ProviderConfig _candidate() => ProviderConfig(
    id: 1,
    kind: _kind,
    baseUrl: _base.text.trim().replaceAll(RegExp(r'/+$'), ''),
    model: _model.text.trim(),
    vision: _vision,
    thinking: _supportsThinking && _thinking,
    supportsThinking: _supportsThinking,
    supportsTools: _supportsTools,
    effort: _effort,
  );
  Future<void> _perform({bool test = false, bool remove = false}) async {
    setState(() {
      _working = true;
      _status = null;
    });
    try {
      final c = ref.read(appControllerProvider);
      if (test) {
        await c.testConnection(
          _candidate(),
          _key.text.trim().isEmpty ? null : _key.text,
        );
      } else {
        await c.saveSettings(
          _candidate(),
          remove
              ? ''
              : _key.text.trim().isEmpty
              ? null
              : _key.text,
        );
      }
      if (!mounted) return;
      setState(() {
        _failure = false;
        _status = test
            ? '连接成功，已收到模型回复。'
            : remove
            ? '已删除此地址对应的密钥。'
            : '配置已保存。密钥仅存于系统安全存储。';
        if (!test) _key.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = true;
        _status = e is FormatException
            ? e.message
            : e is AiFailure
            ? e.message
            : '无法访问系统安全存储。Linux 请启用并解锁 Secret Service 密钥环；应用不会改为明文保存密钥。';
      });
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 20 : 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('设置', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  '让学习助手适合你的使用习惯',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                _heading(context, 'AI 服务', Icons.hub_outlined),
                const SizedBox(height: 8),
                Text(
                  c.demo
                      ? '当前为独立 Mock 构建，不访问真实 API，不保存真实密钥。'
                      : '仅发送当前请求需要的对话和图片。API Key 不写入数据库与日志。',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: '服务商'),
                  items: const [
                    DropdownMenuItem(
                      value: 'deepseek',
                      child: Text('DeepSeek'),
                    ),
                    DropdownMenuItem(
                      value: 'compatible',
                      child: Text('OpenAI-compatible'),
                    ),
                  ],
                  onChanged: _working
                      ? null
                      : (kind) => setState(() {
                          _kind = kind!;
                          _base.text = kind == 'deepseek'
                              ? 'https://api.deepseek.com'
                              : 'https://api.openai.com/v1';
                          _model.text = kind == 'deepseek'
                              ? 'deepseek-flash'
                              : '';
                          _vision = kind == 'deepseek';
                          _supportsThinking = kind == 'deepseek';
                          _supportsTools = kind == 'deepseek';
                          _thinking = false;
                        }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _base,
                  enabled: !_working,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'API Base URL',
                    helperText: '填写接口前缀；应用会追加 /chat/completions',
                  ),
                ),
                const SizedBox(height: 16),
                if (_kind == 'deepseek')
                  DropdownButtonFormField<String>(
                    key: ValueKey('model-${_model.text}'),
                    initialValue: _model.text,
                    decoration: const InputDecoration(labelText: '模型'),
                    items: const [
                      DropdownMenuItem(
                        value: 'deepseek-flash',
                        child: Text('DeepSeek Flash · 支持图片'),
                      ),
                      DropdownMenuItem(
                        value: 'deepseek-v4-pro',
                        child: Text('DeepSeek V4 Pro · 仅文本'),
                      ),
                    ],
                    onChanged: _working
                        ? null
                        : (model) => setState(() {
                            _model.text = model!;
                            _vision = model == 'deepseek-flash';
                          }),
                  )
                else
                  TextField(
                    controller: _model,
                    enabled: !_working,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: '模型 ID',
                      hintText: '填写服务商提供的完整模型 ID',
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('api-key'),
                  controller: _key,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !_working && !c.demo,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: '留空则保留此地址已有的密钥',
                    helperText: c.demo
                        ? 'Mock 模式无需密钥'
                        : 'Android：系统加密存储；Linux：Secret Service 密钥环',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                if (_kind == 'compatible')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('支持工具调用'),
                    subtitle: const Text(
                      '根据服务商文档确认后开启',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _supportsTools,
                    onChanged: _working
                        ? null
                        : (v) => setState(() => _supportsTools = v),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('支持图片输入'),
                  subtitle: const Text(
                    '仅在服务商明确支持视觉时启用',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _vision,
                  onChanged: _working || (_kind == 'deepseek')
                      ? null
                      : (v) => setState(() => _vision = v),
                ),
                if (_kind == 'compatible')
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('支持 reasoning_effort 参数'),
                    subtitle: const Text(
                      '由服务商文档确认后开启',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _supportsThinking,
                    onChanged: _working
                        ? null
                        : (v) => setState(() {
                            _supportsThinking = v;
                            if (!v) _thinking = false;
                          }),
                  ),
                if (_supportsThinking) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_kind == 'deepseek' ? '深度思考' : '发送推理强度参数'),
                    subtitle: const Text(
                      '可能增加响应时间与 token 用量',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _thinking,
                    onChanged: _working
                        ? null
                        : (v) => setState(() => _thinking = v),
                  ),
                  if (_thinking)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _effort,
                        decoration: const InputDecoration(labelText: '推理强度'),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('低')),
                          DropdownMenuItem(value: 'high', child: Text('高')),
                          DropdownMenuItem(value: 'max', child: Text('最高')),
                        ],
                        onChanged: _working
                            ? null
                            : (v) => setState(() => _effort = v!),
                      ),
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '资料工具需在对话中单独开启，当前仅支持非深度思考模式。每次资料写入都需要确认。',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                if (_status != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _status!,
                      style: TextStyle(
                        color: _failure ? colors.error : colors.primary,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _working || c.busy ? null : () => _perform(),
                      child: Text(_working ? '处理中…' : '保存配置'),
                    ),
                    OutlinedButton(
                      onPressed: _working ? null : () => _perform(test: true),
                      child: const Text('测试连接'),
                    ),
                    TextButton(
                      onPressed: _working || c.demo
                          ? null
                          : () => _perform(remove: true),
                      child: const Text('删除已存密钥'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '测试连接会发送一条简短消息，可能产生少量 API 费用。',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                _heading(context, '外观', Icons.contrast_outlined),
                const SizedBox(height: 16),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
                    ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
                  ],
                  selected: {c.themeMode},
                  onSelectionChanged: (v) => c.theme(v.first),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                _heading(context, '关于题训', Icons.school_outlined),
                const SizedBox(height: 12),
                const Text(
                  'TiXun 0.3 · 开源 · 本地优先\n已支持 AI Chat、知识库、错题本、图片裁剪分题及受控资料工具。\n已加入结构化交互题、确定性评分、历史作答和错题重做。间隔复习和完整备份正在继续开发。',
                  style: TextStyle(height: 1.9),
                ),
                const SizedBox(height: 12),
                Text(
                  '已有对话可离线查看，草稿和图片保存在此设备。当前尚无完整备份功能，卸载前请保留应用数据目录。',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _heading(BuildContext context, String label, IconData icon) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 10),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
