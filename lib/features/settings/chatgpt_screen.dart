import '../../core/ui/app_menu.dart';

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/chatgpt/auth.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/ui/reasoning_labels.dart';

class ChatGptScreen extends ConsumerStatefulWidget {
  const ChatGptScreen({super.key});
  @override
  ConsumerState<ChatGptScreen> createState() => _ChatGptScreenState();
}

enum _ChatGptStatus {
  loadFailed,
  operationFailed,
  signedOut,
  revocationUnconfirmed,
  enabled,
  connected,
  browserFailed,
}

class _ChatGptScreenState extends ConsumerState<ChatGptScreen> {
  List<ChatGptAccount> accounts = [];
  List<ChatGptModel> models = [];
  String? active, model;
  Object? message;

  String _messageText(Object value) => switch (value) {
    _ChatGptStatus.loadFailed => context.l10n.couldNotReadChatGPTSign,
    _ChatGptStatus.operationFailed => context.l10n.couldNotCompleteTheAction,
    _ChatGptStatus.signedOut => context.l10n.signedOutOfChatGPT,
    _ChatGptStatus.revocationUnconfirmed =>
      context.l10n.localTokensWereClearedBut,
    _ChatGptStatus.enabled => context.l10n.chatGPTPlanEnabled,
    _ChatGptStatus.connected => context.l10n.connectedAndReceivedAModel,
    _ChatGptStatus.browserFailed => context.l10n.couldNotOpenSystemBrowser,
    _ => failureText(context.l10n, value),
  };
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
          () => message = e is AiFailure ? e : _ChatGptStatus.loadFailed,
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
          () => message = e is AiFailure || e is FormatException
              ? e
              : _ChatGptStatus.operationFailed,
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
                      tooltip: context.l10n.backToSettings,
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.chatGPTPlan,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(context.l10n.useTheChatGPTPlanAllowance),
                const SizedBox(height: 12),
                Text(context.l10n.signInUsesYourSystem),
                if (c.demo)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(context.l10n.mockModeDoesNotSign),
                  ),
                const SizedBox(height: 20),
                if (accounts.isNotEmpty)
                  AppSelectField<String>(
                    key: const Key('chatgpt-account-selector'),

                    initialValue: active,
                    decoration: InputDecoration(
                      labelText: context.l10n.chatGPTAccountWorkspace,
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
                      (connected
                          ? context.l10n.accountConnected
                          : context.l10n.signedOutSignInAgain),
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
                        child: Text(context.l10n.authorizeThisAccountAgain),
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
                                        ? _ChatGptStatus.signedOut
                                        : _ChatGptStatus.revocationUnconfirmed;
                                  });
                                }
                              }),
                        child: Text(context.l10n.signOut),
                      ),
                    if (connectionCancel != null)
                      TextButton(
                        onPressed: () => connectionCancel?.cancel('user'),
                        child: Text(context.l10n.cancelConnectionTest),
                      ),
                    if (auth.signingIn)
                      TextButton(
                        onPressed: auth.cancelLogin,
                        child: Text(context.l10n.cancelSignIn),
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
                          context.l10n.availableModels,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: working ? null : () => perform(() async {}),
                        child: Text(context.l10n.refreshList),
                      ),
                    ],
                  ),
                  if (models.isEmpty)
                    Text(context.l10n.noAvailableModelsRefreshThe),
                  if (models.isNotEmpty)
                    AppSelectField<String>(
                      key: const Key('chatgpt-model-selector'),

                      initialValue: models.any((m) => m.id == model)
                          ? model
                          : null,
                      decoration: InputDecoration(
                        labelText: context.l10n.model,
                      ),
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
                    title: Text(context.l10n.supportsImageInput),
                    subtitle: Text(context.l10n.enableOnlyIfTheModel),
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
                      labelText: context.l10n.defaultReasoningEffort,
                    ),
                    items: [
                      for (final e in {
                        'default': context.l10n.modelDefault,
                        for (final level in availableEfforts)
                          level: reasoningEffortLabel(
                            context,
                            AiOptions(modelConfiguration()),
                            level,
                          ),
                      }.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: working
                        ? null
                        : (v) => setState(() => effort = v!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.levelsFollowTheModelS,
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
                                  setState(
                                    () => message = _ChatGptStatus.enabled,
                                  );
                                }
                              }),
                        child: Text(context.l10n.useThisAccountAndModel),
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
                                  setState(
                                    () => message = _ChatGptStatus.connected,
                                  );
                                }
                              }),
                        child: Text(context.l10n.testConnection),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (message != null) SelectableText(_messageText(message!)),
                TextButton(
                  onPressed: () async {
                    if (!await launchUrl(
                          Uri.parse('https://chatgpt.com/settings/usage'),
                          mode: LaunchMode.externalApplication,
                        ) &&
                        mounted) {
                      setState(() => message = _ChatGptStatus.browserFailed);
                    }
                  },
                  child: Text(context.l10n.manageUsageAndPermissionsIn),
                ),
                Text(
                  context.l10n.connectionTestsAndLearningRequests,
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
