import 'package:tixun/core/l10n/app_error.dart';

import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/context_compactor.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/reasoning_labels.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});
  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

enum _AiSettingsStatus {
  mockTest,
  connected,
  keyRemoved,
  demoSaved,
  saved,
  secureStorageError,
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late TextEditingController _base, _model, _maxContext;
  final _key = TextEditingController();
  late String _kind, _effort;
  late bool _vision, _thinking, _supportsThinking, _supportsTools;
  bool _working = false;
  bool _keyVisible = false;
  Object? _status;

  String _statusText(Object status) => switch (status) {
    _AiSettingsStatus.mockTest => context.l10n.mockTestCompletedNoReal,
    _AiSettingsStatus.connected => context.l10n.connectedAndReceivedAModel,
    _AiSettingsStatus.keyRemoved => context.l10n.theKeyForThisAddress,
    _AiSettingsStatus.demoSaved => context.l10n.demoSettingsLastOnlyFor,
    _AiSettingsStatus.saved => context.l10n.settingsSavedKeysAreStored,
    _AiSettingsStatus.secureStorageError =>
      context.l10n.secureStorageAccessFailedLinux,
    _ => failureText(context.l10n, status),
  };
  bool _failure = false;

  static const _kinds = ['deepseek', 'compatible', 'chatgpt'];
  static const _deepseekModels = ['deepseek-flash', 'deepseek-v4-pro'];
  String? _reasoningLevels;
  List<String> get _efforts => AiOptions(_candidate()).reasoningEfforts;

  /// Loads a stored config into the form, replacing values outside the
  /// dropdowns' item lists with valid defaults. Without this, a legacy or
  /// backup-restored value makes DropdownButtonFormField throw at build
  /// time ("There should be exactly one item with [DropdownButton]'s
  /// value") and blanks the whole settings page.
  void _applyConfig(ProviderConfig c) {
    _kind = _kinds.contains(c.kind) ? c.kind : 'deepseek';
    _base.text = c.baseUrl;
    _model.text = _kind == 'deepseek' && !_deepseekModels.contains(c.model)
        ? 'deepseek-flash'
        : c.model;
    _vision = c.vision;
    _thinking = c.thinking;
    _supportsThinking = c.supportsThinking;
    _supportsTools = c.supportsTools;
    _reasoningLevels = c.reasoningLevels;
    _effort = c.effort;
    _effort = AiOptions(_candidate()).preferredEffort;
  }

  @override
  void initState() {
    super.initState();
    final c = ref.read(appControllerProvider).config;
    _base = TextEditingController();
    _model = TextEditingController();
    _maxContext = TextEditingController(
      text: ref.read(appControllerProvider).maxContextTokens.toString(),
    );
    _applyConfig(c);
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _maxContext.dispose();
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
    reasoningLevels: _reasoningLevels,
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
        final parsed = int.tryParse(_maxContext.text.trim());
        if (parsed == null || !isValidMaxContextTokens(parsed)) {
          throw const AppFormatException(
            AppErrorCode.maxContextTokensMustBe,
            '最大上下文 Token 数应为 4096–1048576 的整数。',
          );
        }
        await c.setMaxContextTokens(parsed);
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
            ? (c.demo
                  ? _AiSettingsStatus.mockTest
                  : _AiSettingsStatus.connected)
            : remove
            ? _AiSettingsStatus.keyRemoved
            : (c.demo ? _AiSettingsStatus.demoSaved : _AiSettingsStatus.saved);
        if (!test) _key.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _failure = true;
        _status = e is FormatException || e is AiFailure
            ? e
            : _AiSettingsStatus.secureStorageError;
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
        _applyConfig(next);
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
                Row(
                  children: [
                    BackButton(onPressed: () => context.go('/settings')),
                    Expanded(
                      child: Text(
                        context.l10n.aiService,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  c.demo
                      ? context.l10n.isolatedMockBuildNoReal
                      : context.l10n.onlyTheConversationAndImages,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  title: Text(context.l10n.chatGPTPlan),
                  subtitle: Text(context.l10n.signInThroughYourBrowser),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/settings/chatgpt'),
                ),
                const SizedBox(height: 12),
                // ChatGPT is managed from the subscription tile above; the
                // dropdown only switches between API providers in place.
                // It is hidden while a ChatGPT subscription is active, so
                // its value is always one of the items below.
                if (_kind != 'chatgpt')
                  AppSelectField<String>(
                    key: const Key('provider-selector'),

                    initialValue: _kind == 'compatible'
                        ? 'compatible'
                        : 'deepseek',
                    decoration: InputDecoration(
                      labelText: context.l10n.provider,
                    ),
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
                            _reasoningLevels = null;
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
                            _effort = AiOptions(_candidate()).preferredEffort;
                          }),
                  ),
                if (_kind == 'chatgpt')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.usingChatGPTPlanManageYour),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _working
                            ? null
                            : () => act(context, () async {
                                await c.restoreApiProvider();
                                if (!mounted) return;
                                setState(() => _applyConfig(c.config));
                              }),
                        child: Text(context.l10n.restorePreviousAPISettings),
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
                      helperText: context.l10n.enterTheAPIPrefixChat,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == 'deepseek')
                    AppSelectField<String>(
                      key: const Key('model-selector'),
                      initialValue: _deepseekModels.contains(_model.text)
                          ? _model.text
                          : 'deepseek-flash',
                      decoration: InputDecoration(
                        labelText: context.l10n.model,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'deepseek-flash',
                          child: Text(
                            context.l10n.deepSeekFlashSupportsImages,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'deepseek-v4-pro',
                          child: Text(
                            context.l10n.deepSeekV4ProTextOnly,
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
                      onChanged: (_) => setState(() {
                        _reasoningLevels = null;
                        _effort = AiOptions(_candidate()).preferredEffort;
                      }),
                      enabled: !_working,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.l10n.modelID,
                        hintText: context.l10n.enterTheFullModelID,
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('api-key'),
                    controller: _key,
                    obscureText: !_keyVisible,
                    enableSuggestions: false,
                    autocorrect: false,
                    enabled: !_working && !c.demo,
                    decoration: InputDecoration(
                      labelText: 'API Key',
                      hintText: context.l10n.leaveBlankToKeepThe,
                      helperText: c.demo
                          ? context.l10n.noKeyNeededInMock
                          : context.l10n.androidSystemEncryptedStorageLinux,
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        tooltip: (_keyVisible
                            ? context.l10n.hideKey
                            : context.l10n.showKey),
                        onPressed: () =>
                            setState(() => _keyVisible = !_keyVisible),
                        icon: Icon(
                          _keyVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_kind == 'compatible')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.supportsToolCalls),
                      subtitle: Text(
                        context.l10n.enableAfterCheckingTheProvider,
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _supportsTools,
                      onChanged: _working
                          ? null
                          : (v) => setState(() => _supportsTools = v),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.supportsImageInput),
                    subtitle: Text(
                      // DeepSeek derives vision from the model (Flash yes,
                      // V4 Pro no), so the switch is fixed here.
                      _kind == 'deepseek'
                          ? context.l10n.decidedByTheModelFlash
                          : context.l10n.enableOnlyIfTheProvider,
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
                      title: Text(context.l10n.supportsReasoningEffort),
                      subtitle: Text(
                        context.l10n.enableAfterConsultingYourProvider,
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
                            ? context.l10n.deepThinking
                            : context.l10n.sendReasoningEffortParameter,
                      ),
                      subtitle: Text(
                        context.l10n.defaultForConversationsWithoutAn,
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
                        child: AppSelectField<String>(
                          key: const Key('api-effort-selector'),
                          initialValue: _efforts.contains(_effort)
                              ? _effort
                              : _efforts.firstOrNull,
                          decoration: InputDecoration(
                            labelText: context.l10n.defaultReasoningEffort,
                          ),
                          items: [
                            for (final level in _efforts)
                              DropdownMenuItem(
                                value: level,
                                child: Text(
                                  reasoningEffortLabel(
                                    context,
                                    AiOptions(_candidate()),
                                    level,
                                  ),
                                ),
                              ),
                          ],
                          onChanged: _working
                              ? null
                              : (v) => setState(() => _effort = v!),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _maxContext,
                    enabled: !_working,
                    autocorrect: false,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.l10n.maxContextTokens,
                      helperText: context.l10n.whenTheLimitIsExceeded,
                      helperMaxLines: 3,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      context.l10n.enableMaterialToolsPerConversation,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  if (_status != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _statusText(_status!),
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
                          _working
                              ? context.l10n.working
                              : context.l10n.saveConfiguration,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _working ? null : () => _perform(test: true),
                        child: Text(context.l10n.testConnection),
                      ),
                      TextButton(
                        onPressed: _working || c.demo
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text(context.l10n.deleteTheSavedKey),
                                    content: Text(
                                      context.l10n.thisDeletesTheKeySaved,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: Text(context.l10n.cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: Text(context.l10n.deleteKey),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) await _perform(remove: true);
                              },
                        child: Text(context.l10n.deleteSavedKey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.l10n.testingSendsAShortMessage,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  context.l10n.keysAreKeptInSystem,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
