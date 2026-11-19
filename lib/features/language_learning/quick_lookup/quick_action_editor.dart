import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/ui/actions.dart';
import '../language_store.dart';
import 'quick_labels.dart';
import 'quick_models.dart';
import 'quick_store.dart';

Future<void> editQuickAction(
  BuildContext context,
  LanguageLearningStore store, [
  LanguageQuickAction? action,
]) async {
  final value = await showDialog<LanguageQuickAction>(
    context: context,
    builder: (context) => _QuickActionEditor(action),
  );
  if (context.mounted && value != null) {
    await act(context, () async {
      await store.saveQuickAction(value);
    });
  }
}

class QuickActionManager extends StatefulWidget {
  const QuickActionManager(this.store, {super.key});

  final LanguageLearningStore store;

  @override
  State<QuickActionManager> createState() => _QuickActionManagerState();
}

class _QuickActionManagerState extends State<QuickActionManager> {
  late var _actions = widget.store.quickActions();
  var _busy = false;

  Future<void> _change(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    await act(context, operation);
    if (mounted) {
      setState(() {
        _busy = false;
        _actions = widget.store.quickActions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quickActions)),
      body: FutureBuilder(
        future: _actions,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.couldNotCompleteTheAction));
          }
          final actions = snapshot.data;
          if (actions == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: actions.length + 1,
            itemBuilder: (context, index) {
              if (index == actions.length) {
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _change(
                            () => editQuickAction(context, widget.store),
                          ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.quickAddAction),
                  ),
                );
              }
              final action = actions[index];
              return Card(
                key: ValueKey(action.id),
                child: ListTile(
                  leading: Icon(quickIcon(action.icon)),
                  title: Text(quickName(context, action)),
                  subtitle: Text(quickDescription(context, action)),
                  enabled: !_busy,
                  onTap: () => _change(
                    () => editQuickAction(context, widget.store, action),
                  ),
                  trailing: PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) => _change(() async {
                      switch (value) {
                        case 'up':
                          await widget.store.moveQuickAction(action.id, -1);
                        case 'down':
                          await widget.store.moveQuickAction(action.id, 1);
                        case 'enabled':
                          await widget.store.setQuickActionEnabled(
                            action.id,
                            !action.enabled,
                          );
                        case 'reset':
                          await widget.store.saveQuickAction(
                            quickActionDefaults(
                              action.id,
                              action.position,
                              DateTime.now(),
                            ),
                          );
                        case 'delete':
                          if (await confirmQuickDelete(
                            context,
                            l10n.quickRemoveAction,
                          )) {
                            await widget.store.deleteQuickAction(action.id);
                          }
                      }
                    }),
                    itemBuilder: (context) => [
                      CheckedPopupMenuItem(
                        value: 'enabled',
                        checked: action.enabled,
                        child: Text(l10n.quickEnabled),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        enabled: index > 0,
                        child: Text(l10n.quickMoveUp),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: index + 1 < actions.length,
                        child: Text(l10n.quickMoveDown),
                      ),
                      if (action.builtIn)
                        PopupMenuItem(
                          value: 'reset',
                          child: Text(l10n.quickResetAction),
                        )
                      else
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QuickActionEditor extends StatefulWidget {
  const _QuickActionEditor(this.original);

  final LanguageQuickAction? original;

  @override
  State<_QuickActionEditor> createState() => _QuickActionEditorState();
}

class _QuickActionEditorState extends State<_QuickActionEditor> {
  final _form = GlobalKey<FormState>();
  late final _original =
      widget.original ??
      quickActionDefaults(const Uuid().v4(), 0, DateTime.now());
  late var _name = _original.name;
  late var _description = _original.description;
  late var _hint = _original.inputHint;
  late var _prompt = _original.prompt;
  late var _icon = _original.icon;
  late var _source = _original.sourceLanguage;
  late var _target = _original.targetLanguage;
  late var _gloss = _original.glossLanguage;
  late var _detailed = _original.detailed;
  late var _enabled = _original.enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget field(
      String label,
      String initial,
      int limit,
      ValueChanged<String> update, {
      String? hint,
      String? help,
      int lines = 1,
      FormFieldValidator<String>? validator,
    }) => TextFormField(
      initialValue: initial,
      maxLength: limit,
      minLines: lines,
      maxLines: lines == 1 ? 1 : lines + 4,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: help,
        helperMaxLines: 4,
        counterText: '',
      ),
      onChanged: update,
      validator: validator,
    );

    Widget language(
      String label,
      String initial,
      List<String> values,
      ValueChanged<String> update,
    ) => DropdownButtonFormField<String>(
      initialValue: initial,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final code in values)
          DropdownMenuItem(
            value: code,
            child: Text(quickLanguageName(context, code)),
          ),
      ],
      onChanged: (value) => update(value!),
    );

    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.original == null ? l10n.quickAddAction : l10n.quickEditAction,
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(
                l10n.quickActionName,
                _name,
                50,
                (value) => _name = value,
                hint: quickName(context, _original.copyWith(name: '')),
                validator: (value) =>
                    !_original.builtIn && (value ?? '').trim().isEmpty
                    ? l10n.languageRequired
                    : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _icon,
                decoration: InputDecoration(labelText: l10n.quickActionIcon),
                items: [
                  for (final icon in quickIcons)
                    DropdownMenuItem(
                      value: icon,
                      child: Icon(
                        quickIcon(icon),
                        semanticLabel: switch (icon) {
                          'express' => l10n.quickExpress,
                          'meaning' => l10n.quickMeaning,
                          'usage' => l10n.quickUsage,
                          'translate' => l10n.quickActionTarget,
                          _ => l10n.quickActionIcon,
                        },
                      ),
                    ),
                ],
                onChanged: (value) => _icon = value!,
              ),
              field(
                l10n.quickActionDescription,
                _description,
                180,
                (value) => _description = value,
                hint: quickDescription(
                  context,
                  _original.copyWith(description: ''),
                ),
              ),
              field(
                l10n.quickActionInputHint,
                _hint,
                180,
                (value) => _hint = value,
                hint: quickHint(context, _original.copyWith(inputHint: '')),
              ),
              field(
                l10n.quickActionPrompt,
                _prompt,
                quickPromptLimit,
                (value) => _prompt = value,
                help: l10n.quickTemplateHelp,
                lines: 4,
                validator: (value) {
                  try {
                    compileQuickPrompt(value ?? '');
                  } on FormatException {
                    return l10n.quickInvalidTemplate;
                  }
                  return null;
                },
              ),
              language(l10n.quickActionSource, _source, [
                'auto',
                ...quickLanguages,
              ], (value) => _source = value),
              language(
                l10n.quickActionTarget,
                _target,
                quickLanguages,
                (value) => _target = value,
              ),
              language(l10n.quickActionGloss, _gloss, [
                'app',
                ...quickLanguages,
              ], (value) => _gloss = value),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.quickDetailed),
                value: _detailed,
                onChanged: (value) => setState(() => _detailed = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.quickEnabled),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop(
              context,
              _original.copyWith(
                name: _name,
                description: _description,
                inputHint: _hint,
                prompt: _prompt,
                icon: _icon,
                sourceLanguage: _source,
                targetLanguage: _target,
                glossLanguage: _gloss,
                detailed: _detailed,
                enabled: _enabled,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
