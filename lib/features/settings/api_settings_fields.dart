part of "ai_settings_screen.dart";

extension _ApiSettingsFields on _AiSettingsScreenState {
  List<Widget> _apiFields(AppController c, ColorScheme colors) {
    return [
      const SizedBox(height: 16),
      TextField(
        controller: _base,
        onChanged: (_) {
          _mutate(() {
            _hasSavedKey = null;
            _resetBalance();
          });
          unawaited(_refreshKeyStatus());
          _scheduleSave();
        },
        enabled: !_working,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: "API Base URL",
          helperText: context.l10n.enterTheAPIPrefixChat,
        ),
      ),
      const SizedBox(height: 16),
      if (_kind == "deepseek")
        AppSelectField<String>(
          key: const Key("model-selector"),
          initialValue:
              _AiSettingsScreenState._deepseekModels.contains(_model.text)
              ? _model.text
              : "deepseek-flash",
          decoration: InputDecoration(labelText: context.l10n.model),
          items: [
            DropdownMenuItem(
              value: "deepseek-flash",
              child: Text(
                context.l10n.deepSeekFlashSupportsImages,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: "deepseek-v4-pro",
              child: Text(
                context.l10n.deepSeekV4ProTextOnly,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: _working
              ? null
              : (model) {
                  _mutate(() {
                    _model.text = model!;
                    _vision = model == "deepseek-flash";
                  });
                  _scheduleSave();
                },
        )
      else
        TextField(
          controller: _model,
          onChanged: (_) {
            _mutate(() {
              _reasoningLevels = null;
              _effort = AiOptions(_candidate()).preferredEffort;
            });
            _scheduleSave();
          },
          enabled: !_working,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: context.l10n.modelID,
            hintText: context.l10n.enterTheFullModelID,
          ),
        ),
      const SizedBox(height: 16),
      TextField(
        key: const Key("api-key"),
        controller: _key,
        onChanged: (_) {
          _mutate(_resetBalance);
          _scheduleSave();
        },
        obscureText: !_keyVisible,
        enableSuggestions: false,
        autocorrect: false,
        enabled: !_working && !c.demo,
        decoration: InputDecoration(
          labelText: "API Key",
          hintText: context.l10n.leaveBlankToKeepThe,
          helperText: c.demo
              ? context.l10n.noKeyNeededInMock
              : context.l10n.androidSystemEncryptedStorageLinux,
          helperMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: (_keyVisible
                ? context.l10n.hideKey
                : context.l10n.showKey),
            onPressed: () => _mutate(() => _keyVisible = !_keyVisible),
            icon: Icon(
              _keyVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
      if (!c.demo)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            _hasSavedKey == null
                ? context.l10n.apiKeyStatusUnknown
                : _hasSavedKey!
                ? context.l10n.apiKeyAlreadySaved
                : context.l10n.apiKeyNotSaved,
            style: TextStyle(
              fontSize: 12,
              color: _hasSavedKey == true
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
          ),
        ),
      if (!c.demo && _kind == "deepseek")
        ProviderBalancePanel(
          balance: _balance,
          loading: _balanceLoading,
          failure: _balanceFailure,
          onRefresh: _working || _balanceLoading ? null : _loadBalance,
        ),
      const SizedBox(height: 16),
      if (_kind == "compatible")
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
              : (v) {
                  _mutate(() => _supportsTools = v);
                  _scheduleSave();
                },
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(context.l10n.supportsImageInput),
        subtitle: Text(
          // DeepSeek derives vision from the model (Flash yes,
          // V4 Pro no), so the switch is fixed here.
          _kind == "deepseek"
              ? context.l10n.decidedByTheModelFlash
              : context.l10n.enableOnlyIfTheProvider,
          style: TextStyle(fontSize: 12),
        ),
        value: _vision,
        onChanged: _working || (_kind == "deepseek")
            ? null
            : (v) {
                _mutate(() => _vision = v);
                _scheduleSave();
              },
      ),
      if (_kind == "compatible")
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
              : (v) {
                  _mutate(() {
                    _supportsThinking = v;
                    if (!v) _thinking = false;
                  });
                  _scheduleSave();
                },
        ),
      if (_supportsThinking) ...[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _kind == "deepseek"
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
              : (v) {
                  _mutate(() => _thinking = v);
                  _scheduleSave();
                },
        ),
        if (_thinking)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppSelectField<String>(
              key: const Key("api-effort-selector"),
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
                  : (v) {
                      _mutate(() => _effort = v!);
                      _scheduleSave();
                    },
            ),
          ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _maxContext,
        onChanged: (_) => _scheduleSave(),
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
            style: TextStyle(color: _failure ? colors.error : colors.primary),
          ),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
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
                        content: Text(context.l10n.thisDeletesTheKeySaved),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(context.l10n.cancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
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
        style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
      ),
    ];
  }
}
