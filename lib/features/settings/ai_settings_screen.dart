import 'dart:async';

import 'package:tixun/core/l10n/app_error.dart';

import '../../core/ui/app_menu.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/chat_provider.dart';
import '../../core/ai/context_compactor.dart';
import '../../core/ai/provider_balance.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/ui/actions.dart';
import '../../core/ui/reasoning_labels.dart';
import 'provider_balance_panel.dart';

import 'chatgpt_screen.dart';

part 'api_settings_fields.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key, this.showSubscription = false});
  final bool showSubscription;
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
  late String _kind, _effort, _provider;
  late bool _vision, _thinking, _supportsThinking, _supportsTools;
  bool _working = false;
  Timer? _saveTimer;
  bool _keyVisible = false;
  bool? _hasSavedKey;
  Object? _status;
  ProviderBalance? _balance;
  Object? _balanceFailure;
  bool _balanceLoading = false;
  int _balanceRequest = 0;

  void _resetBalance() {
    _balanceRequest++;
    _balance = null;
    _balanceFailure = null;
    _balanceLoading = false;
  }

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
    _provider = widget.showSubscription ? 'chatgpt' : _kind;
    _refreshKeyStatus();
  }

  Future<void> _refreshKeyStatus() async {
    if (_kind == 'chatgpt') return;
    try {
      final controller = ref.read(appControllerProvider);
      final candidate = _candidate();
      final hasKey = await controller.hasApiKey(candidate);
      if (!mounted || providerKeyId(candidate) != providerKeyId(_candidate())) {
        return;
      }
      setState(() => _hasSavedKey = hasKey);
      if (hasKey &&
          !controller.demo &&
          _kind == 'deepseek' &&
          _key.text.isEmpty) {
        await _loadBalance(refresh: false);
      }
    } catch (_) {
      if (mounted) setState(() => _hasSavedKey = null);
    }
  }

  /// Asks the provider for its own account balance. A key being typed wins over
  /// the stored one so a fresh key can be checked before it is saved.
  Future<void> _loadBalance({bool refresh = true}) async {
    if (_balanceLoading) return;
    final request = ++_balanceRequest;
    final controller = ref.read(appControllerProvider);
    final candidate = _candidate();
    final key = _key.text;
    bool current() => mounted && request == _balanceRequest;
    setState(() {
      _balanceLoading = true;
      _balanceFailure = null;
    });
    try {
      if (key.isEmpty) {
        final cached = await controller.cachedProviderBalance(candidate);
        if (current()) setState(() => _balance = cached);
      }
      if (!current()) return;
      final balance = await controller.providerBalance(
        candidate,
        key: key,
        refresh: refresh,
      );
      if (current()) setState(() => _balance = balance);
    } catch (e) {
      if (current()) setState(() => _balanceFailure = e);
    } finally {
      if (current()) setState(() => _balanceLoading = false);
    }
  }

  @override
  void dispose() {
    _base.dispose();
    _model.dispose();
    _maxContext.dispose();
    _saveTimer?.cancel();
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
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _perform();
    });
  }

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
        if (!test) {
          _resetBalance();
          _key.clear();
          _refreshKeyStatus();
        }
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

  void _mutate(VoidCallback callback) => setState(callback);

  Future<void> _selectProvider(String kind) async {
    if (kind == _provider || _working) return;
    if (_saveTimer?.isActive == true) {
      _saveTimer!.cancel();
      await _perform();
      if (!mounted) return;
    }
    if (kind == 'chatgpt') {
      setState(() => _provider = kind);
      return;
    }
    final c = ref.read(appControllerProvider);
    ProviderConfig? previous;
    if (c.config.kind == 'chatgpt' && _kind != kind) {
      setState(() => _working = true);
      try {
        previous = await c.preferences.previousApiProvider();
      } on FormatException {
        // A stale backup setting can be replaced by the selected API defaults.
      } finally {
        if (mounted) setState(() => _working = false);
      }
      if (!mounted) return;
    }
    setState(() {
      _provider = kind;
      if (_kind == kind) return;
      _key.clear();
      _hasSavedKey = null;
      _status = null;
      _resetBalance();
      if (previous?.kind == kind) {
        _applyConfig(previous!);
      } else {
        _kind = kind;
        _reasoningLevels = null;
        _base.text = kind == 'deepseek'
            ? 'https://api.deepseek.com'
            : 'https://api.openai.com/v1';
        _model.text = kind == 'deepseek' ? 'deepseek-flash' : '';
        _vision = kind == 'deepseek';
        _supportsThinking = kind == 'deepseek';
        _supportsTools = kind == 'deepseek';
        _thinking = false;
        _effort = AiOptions(_candidate()).preferredEffort;
      }
    });
    if (c.config != _candidate() && _model.text.isNotEmpty) {
      await _perform();
    } else {
      await _refreshKeyStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    ref.listen(appControllerProvider.select((value) => value.config), (
      previous,
      next,
    ) {
      if (previous == next || next.kind == 'chatgpt' || _kind != next.kind) {
        return;
      }
      setState(() {
        _applyConfig(next);
        _key.clear();
        _hasSavedKey = null;
        _resetBalance();
      });
      _refreshKeyStatus();
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
                    BackButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/settings'),
                    ),
                    Expanded(
                      child: Text(
                        context.l10n.modelsAndConnections,
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
                AppSelectField<String>(
                  key: const Key('provider-selector'),
                  initialValue: _provider,
                  decoration: InputDecoration(labelText: context.l10n.provider),
                  items: [
                    const DropdownMenuItem(
                      value: 'deepseek',
                      child: Text('DeepSeek'),
                    ),
                    const DropdownMenuItem(
                      value: 'compatible',
                      child: Text('OpenAI-compatible'),
                    ),
                    DropdownMenuItem(
                      value: 'chatgpt',
                      child: Text(context.l10n.chatGPTPlan),
                    ),
                  ],
                  onChanged: _working
                      ? null
                      : (value) {
                          if (value != null) {
                            act(context, () => _selectProvider(value));
                          }
                        },
                ),
                if (_provider == 'chatgpt') ...[
                  const SizedBox(height: 24),
                  const ChatGptSettings(),
                ] else
                  ..._apiFields(c, colors),
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
