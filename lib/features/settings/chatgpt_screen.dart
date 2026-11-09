import '../../core/ui/app_menu.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/chatgpt/auth.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';

class ChatGptScreen extends ConsumerStatefulWidget {
  const ChatGptScreen({super.key});
  @override
  ConsumerState<ChatGptScreen> createState() => _ChatGptScreenState();
}

class _ChatGptScreenState extends ConsumerState<ChatGptScreen> {
  List<ChatGptAccount> accounts = [];
  List<ChatGptModel> models = [];
  String? active, model, message;
  bool working = true, vision = false;
  String effort = 'default';
  late final ChatGptAuth auth;
  CancelToken? connectionCancel;
  @override
  void initState() {
    super.initState();
    final c = ref.read(appControllerProvider);
    auth = c.chatGpt;
    if (c.config.kind == 'chatgpt') {
      model = c.config.model;
      vision = c.config.vision;
      effort = c.config.thinking ? c.config.effort : 'default';
    }
    load();
  }

  @override
  void dispose() {
    auth.cancelLogin();
    connectionCancel?.cancel('user');
    super.dispose();
  }

  Future<void> load() async {
    final auth = ref.read(appControllerProvider).chatGpt;
    try {
      final snapshot = await auth.snapshot();
      final saved = snapshot.accounts;
      final selected = snapshot.activeId;
      if (mounted) {
        setState(() {
          accounts = saved;
          active = selected;
        });
      }
      if (saved.any((a) => a.id == selected && a.connected)) {
        final choices = await auth.models();
        if (mounted) {
          setState(() {
            models = choices;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is AiFailure
              ? e.message
              : 'ChatGPT 登录记录无法读取，请检查系统安全存储。',
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> perform(Future<void> Function() task) async {
    if (working) return;
    setState(() {
      working = true;
      message = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is AiFailure
              ? e.message
              : e is FormatException
              ? e.message
              : '操作失败，请检查存储空间或系统密钥环后重试。',
        );
      }
    } finally {
      if (mounted) {
        await load();
      }
    }
  }

  ProviderConfig modelConfiguration() {
    final declared = models
        .where((m) => m.id == model)
        .firstOrNull
        ?.reasoningEfforts;
    return ProviderConfig(
      id: 1,
      kind: 'chatgpt',
      baseUrl: chatGptResource,
      model: model ?? '',
      vision: vision,
      supportsTools: true,
      supportsThinking: true,
      thinking: effort != 'default',
      effort: effort == 'default' ? 'high' : effort,
      reasoningLevels: declared == null ? null : jsonEncode(declared),
    );
  }

  List<String> get availableEfforts =>
      AiOptions(modelConfiguration()).reasoningEfforts;
  String get selectedEffort =>
      availableEfforts.contains(effort) ? effort : 'default';
  ProviderConfig candidate() => modelConfiguration().copyWith(
    supportsThinking: availableEfforts.isNotEmpty,
    thinking: selectedEffort != 'default',
  );

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider), auth = c.chatGpt;
    final account = accounts.where((a) => a.id == active).firstOrNull;
    final connected = account?.connected == true;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: context.tr('返回设置'),
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('ChatGPT 订阅'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    '使用 ChatGPT 账号授权的订阅额度，无需填写 API Key。模型及可用额度取决于账号与工作区，额度不足时不会转用 API 计费。',
                  ),
                ),
                const SizedBox(height: 12),
                Text(context.tr('登录通过系统浏览器完成。登录令牌仅保存在系统安全存储中，不进入学习数据备份。')),
                if (c.demo)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(context.tr('Mock 模式不进行真实 ChatGPT 登录。')),
                  ),
                const SizedBox(height: 20),
                if (accounts.isNotEmpty)
                  AppSelectField<String>(
                    key: const Key('chatgpt-account-selector'),

                    initialValue: active,
                    decoration: InputDecoration(
                      labelText: context.tr('ChatGPT 账号 / 工作区'),
                    ),
                    items: [
                      for (final a in accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: a.clientId,
                                child: Text(
                                  a.clientId.length > 8
                                      ? a.clientId.substring(
                                          a.clientId.length - 8,
                                        )
                                      : a.clientId,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: working
                        ? null
                        : (id) => perform(() async {
                            await c.stop();
                            await auth.select(id!);
                            if (mounted) {
                              setState(() {
                                models = [];
                                model = null;
                                vision = false;
                              });
                            }
                          }),
                  ),
                if (account != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      context.tr(connected ? '账号已登录' : '已退出，可重新登录此账号'),
                    ),
                  ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const Key('chatgpt-sign-in'),
                      onPressed: working || c.demo
                          ? null
                          : () => perform(() async {
                              await c.stop();
                              if (!mounted) return;
                              final login = auth.signIn();
                              setState(() {});
                              await login;
                              if (mounted) {
                                setState(() {
                                  model = null;
                                  models = [];
                                  vision = false;
                                });
                              }
                            }),
                      child: const Text('Continue with ChatGPT'),
                    ),
                    if (account != null)
                      OutlinedButton(
                        onPressed: working || c.demo
                            ? null
                            : () => perform(() async {
                                await c.stop();
                                if (!mounted) return;
                                final login = auth.signIn(
                                  accountId: account.id,
                                );
                                setState(() {});
                                await login;
                              }),
                        child: Text(context.tr('重新授权此账号')),
                      ),
                    if (connected)
                      TextButton(
                        onPressed: working
                            ? null
                            : () => perform(() async {
                                await c.stop();
                                final revoked = await auth.signOut(account!.id);
                                if (mounted) {
                                  setState(() {
                                    models = [];
                                    message = revoked
                                        ? '已退出 ChatGPT 登录。'
                                        : '本机登录已清除，但远程撤销未确认。请到 ChatGPT 设置检查授权。';
                                  });
                                }
                              }),
                        child: Text(context.tr('退出登录')),
                      ),
                    if (connectionCancel != null)
                      TextButton(
                        onPressed: () => connectionCancel?.cancel('user'),
                        child: Text(context.tr('取消连接测试')),
                      ),
                    if (auth.signingIn)
                      TextButton(
                        onPressed: auth.cancelLogin,
                        child: Text(context.tr('取消登录')),
                      ),
                  ],
                ),
                if (working)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: LinearProgressIndicator(),
                  ),
                if (connected) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('可用模型'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: working ? null : () => perform(() async {}),
                        child: Text(context.tr('刷新列表')),
                      ),
                    ],
                  ),
                  if (models.isEmpty)
                    Text(context.tr('暂时没有可用模型，请刷新列表或检查账号授权。')),
                  if (models.isNotEmpty)
                    AppSelectField<String>(
                      key: const Key('chatgpt-model-selector'),

                      initialValue: models.any((m) => m.id == model)
                          ? model
                          : null,
                      decoration: InputDecoration(labelText: context.tr('模型')),
                      items: [
                        for (final m in models)
                          DropdownMenuItem(
                            value: m.id,
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: working
                          ? null
                          : (value) => setState(() {
                              model = value;
                              vision = models
                                  .firstWhere((m) => m.id == value)
                                  .vision;
                            }),
                    ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('支持图片输入')),
                    subtitle: Text(context.tr('仅在模型文档明确支持图片时开启；模型列表未声明时默认关闭。')),
                    value: vision,
                    onChanged: working
                        ? null
                        : (v) => setState(() => vision = v),
                  ),
                  const SizedBox(height: 12),
                  AppSelectField<String>(
                    key: const Key('chatgpt-effort-selector'),
                    initialValue: selectedEffort,

                    decoration: InputDecoration(
                      labelText: context.tr('默认思考强度'),
                    ),
                    items: [
                      for (final e in {
                        'default': '模型默认',
                        for (final level in availableEfforts)
                          level: AiOptions(modelConfiguration()).label(level),
                      }.entries)
                        DropdownMenuItem(
                          value: e.key,
                          child: Text(context.tr(e.value)),
                        ),
                    ],
                    onChanged: working
                        ? null
                        : (v) => setState(() => effort = v!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      '档位按模型能力显示；xhigh 与 max 独立。模型默认不发送强度参数，none 明确请求不推理，两者不同。所有资料写入仍需确认。',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        key: const Key('use-chatgpt'),
                        onPressed: working || !models.any((m) => m.id == model)
                            ? null
                            : () => perform(() async {
                                await c.stop();
                                await c.saveSettings(candidate(), null);
                                if (mounted) {
                                  setState(() => message = '已启用 ChatGPT 订阅。');
                                }
                              }),
                        child: Text(context.tr('使用此账号和模型')),
                      ),
                      OutlinedButton(
                        onPressed: working || !models.any((m) => m.id == model)
                            ? null
                            : () => perform(() async {
                                final cancel = CancelToken();
                                setState(() => connectionCancel = cancel);
                                try {
                                  await c.testConnection(
                                    candidate(),
                                    null,
                                    cancellation: cancel,
                                  );
                                } finally {
                                  connectionCancel = null;
                                }
                                if (mounted) {
                                  setState(() => message = '连接成功，已收到模型回复。');
                                }
                              }),
                        child: Text(context.tr('测试连接')),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (message != null) SelectableText(context.tr(message!)),
                TextButton(
                  onPressed: () async {
                    if (!await launchUrl(
                          Uri.parse('https://chatgpt.com/settings/usage'),
                          mode: LaunchMode.externalApplication,
                        ) &&
                        mounted) {
                      setState(() => message = '无法打开系统浏览器，请检查浏览器设置。');
                    }
                  },
                  child: Text(context.tr('在 ChatGPT 中管理用量和授权')),
                ),
                Text(
                  context.tr('测试连接和学习请求会使用订阅额度。切换账号会停止当前回复，已有本地聊天记录保留。'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
