import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../progress/profile_editor.dart';
import '../review/review_providers.dart';
import 'backup_panel.dart';
import 'language_color_settings.dart';

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
            ? (c.demo ? 'Mock 测试已完成，没有请求真实服务。' : '连接成功，已收到模型回复。')
            : remove
            ? '已删除此地址对应的密钥。'
            : (c.demo ? '演示配置仅在本次运行中保留。' : '配置已保存。密钥仅存于系统安全存储。');
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
    ref.listen(appControllerProvider.select((value) => value.config), (
      previous,
      next,
    ) {
      if (previous == next) return;
      setState(() {
        _kind = next.kind;
        _base.text = next.baseUrl;
        _model.text = next.model;
        _vision = next.vision;
        _supportsThinking = next.supportsThinking;
        _supportsTools = next.supportsTools;
        _thinking = next.thinking;
        _effort = next.effort;
        _key.clear();
      });
    });
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
                Text(
                  context.tr("设置"),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr("让学习助手适合你的使用习惯"),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                _heading(context, context.tr("外观"), Icons.contrast_outlined),
                const SizedBox(height: 16),
                const LanguageColorSettings(),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(context.tr("跟随系统")),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(context.tr("浅色")),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(context.tr("深色")),
                    ),
                  ],
                  selected: {c.themeMode},
                  onSelectionChanged: (v) => c.theme(v.first),
                ),
                const SizedBox(height: 28),
                _heading(context, context.tr("学习目标"), Icons.school_outlined),
                ref
                    .watch(learningProfileProvider)
                    .when(
                      data: (p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          context.tr("{0} · 每日 {1} 分钟", [
                            p.stage,
                            p.dailyMinutes,
                          ]),
                        ),
                        subtitle: Text(
                          p.exam.isEmpty ? context.tr("自由学习") : p.exam,
                        ),
                        trailing: TextButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ProfileEditor(p),
                          ),
                          child: Text(context.tr("修改")),
                        ),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(context.tr("学习设置读取失败")),
                    ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note_outlined),
                  title: Text(context.tr("提示词管理")),
                  subtitle: Text(context.tr("自定义教学风格、讲解、出题与分题提示词")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/prompts'),
                ),
                const SizedBox(height: 24),
                _heading(context, context.tr("AI 服务"), Icons.hub_outlined),
                const SizedBox(height: 8),
                Text(
                  c.demo
                      ? context.tr("当前为独立 Mock 构建，不访问真实 API，不保存真实密钥。")
                      : context.tr("仅发送当前请求需要的对话和图片。API Key 不写入数据库与日志。"),
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.tr('ChatGPT 订阅')),
                  subtitle: Text(context.tr('使用 Plus/Pro 等账号获准共享的额度，通过浏览器登录')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/chatgpt'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('provider-$_kind'),
                  isExpanded: true,
                  initialValue: _kind,
                  decoration: InputDecoration(labelText: context.tr("服务商")),
                  items: const [
                    DropdownMenuItem(value: 'chatgpt', child: Text('ChatGPT')),
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
                          if (kind == 'chatgpt') {
                            context.go('/settings/chatgpt');
                            return;
                          }
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
                if (_kind == 'chatgpt')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('已使用 ChatGPT 订阅，请在订阅管理页更换账号或模型。')),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _working
                            ? null
                            : () => act(context, () async {
                                await c.restoreApiProvider();
                                if (!mounted) return;
                                setState(() {
                                  _kind = c.config.kind;
                                  _base.text = c.config.baseUrl;
                                  _model.text = c.config.model;
                                  _vision = c.config.vision;
                                  _supportsThinking = c.config.supportsThinking;
                                  _supportsTools = c.config.supportsTools;
                                  _thinking = c.config.thinking;
                                  _effort = c.config.effort;
                                });
                              }),
                        child: Text(context.tr('恢复上次 API 配置')),
                      ),
                    ],
                  )
                else ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _base,
                    enabled: !_working,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'API Base URL',
                      helperText: context.tr("填写接口前缀；应用会追加 /chat/completions"),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == 'deepseek')
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      key: ValueKey('model-${_model.text}'),
                      initialValue: _model.text,
                      decoration: InputDecoration(labelText: context.tr("模型")),
                      items: [
                        DropdownMenuItem(
                          value: 'deepseek-flash',
                          child: Text(
                            context.tr("DeepSeek Flash · 支持图片"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'deepseek-v4-pro',
                          child: Text(
                            context.tr("DeepSeek V4 Pro · 仅文本"),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                      decoration: InputDecoration(
                        labelText: context.tr("模型 ID"),
                        hintText: context.tr("填写服务商提供的完整模型 ID"),
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
                      hintText: context.tr("留空则保留此地址已有的密钥"),
                      helperText: c.demo
                          ? context.tr("Mock 模式无需密钥")
                          : context.tr(
                              "Android：系统加密存储；Linux：Secret Service 密钥环",
                            ),
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == 'compatible')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.tr("支持工具调用")),
                      subtitle: Text(
                        context.tr("根据服务商文档确认后开启"),
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _supportsTools,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _supportsTools = v),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr("支持图片输入")),
                    subtitle: Text(
                      context.tr("仅在服务商明确支持视觉时启用"),
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
                      title: Text(context.tr("支持 reasoning_effort 参数")),
                      subtitle: Text(
                        context.tr("由服务商文档确认后开启"),
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
                      title: Text(
                        _kind == 'deepseek'
                            ? context.tr("深度思考")
                            : context.tr("发送推理强度参数"),
                      ),
                      subtitle: Text(
                        context.tr("用于未单独设置的会话；聊天标题栏可覆盖。可能增加响应时间与用量。"),
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
                          isExpanded: true,
                          initialValue: _effort,
                          decoration: InputDecoration(
                            labelText: context.tr("默认思考强度"),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text(context.tr("低")),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text(context.tr("高")),
                            ),
                            DropdownMenuItem(
                              value: 'max',
                              child: Text(context.tr("最高")),
                            ),
                          ],
                          onChanged: _working
                              ? null
                              : (v) => setState(() => _effort = v!),
                        ),
                      ),
                  ],
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      context.tr("资料工具需在对话中单独开启，当前仅支持非深度思考模式。每次资料写入都需要确认。"),
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        context.tr(_status!),
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
                        child: Text(
                          _working ? context.tr("处理中…") : context.tr("保存配置"),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _working ? null : () => _perform(test: true),
                        child: Text(context.tr("测试连接")),
                      ),
                      TextButton(
                        onPressed: _working || c.demo
                            ? null
                            : () => _perform(remove: true),
                        child: Text(context.tr("删除已存密钥")),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr("测试连接会发送一条简短消息，可能产生少量 API 费用。"),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                const BackupPanel(),
                const SizedBox(height: 28),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                _heading(context, context.tr("关于题训"), Icons.school_outlined),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    "TiXun 0.5 · 开源 · 本地优先\n已支持 AI Chat、知识库、错题本、图片裁剪分题及受控资料工具。\n已加入结构化交互题、确定性评分、历史作答和错题重做。已支持间隔复习、学习诊断与自由学习目标。完整备份、恢复撤销与 AI 分题建议现已提供。",
                  ),
                  style: TextStyle(height: 1.9),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr("已有资料与练习可离线使用。卸载前请导出完整备份；API Key 仅由系统安全存储保管。"),
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
      Text(context.tr(label), style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
