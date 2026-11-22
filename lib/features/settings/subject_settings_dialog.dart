import "package:material_ui/material_ui.dart";

import "../../app/preferences.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";

enum _Override {
  inherit(null),
  on(true),
  off(false);

  const _Override(this.value);
  final bool? value;
}

class SubjectSettingsDialog extends StatefulWidget {
  const SubjectSettingsDialog({
    required this.subject,
    required this.settings,
    required this.languageEnabled,
    super.key,
  });

  final String subject;
  final SubjectSettings settings;
  final bool languageEnabled;

  @override
  State<SubjectSettingsDialog> createState() => _SubjectSettingsDialogState();
}

class _SubjectSettingsDialogState extends State<SubjectSettingsDialog> {
  late SubjectSettings settings = widget.settings;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(context.subjectName(widget.subject)),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(l.languageSubject),
              value: settings.language ?? widget.languageEnabled,
              onChanged: (value) => setState(() {
                settings = (
                  language: value,
                  drawing: settings.drawing,
                  a2ui: settings.a2ui,
                );
              }),
            ),
            const SizedBox(height: 12),
            _toolField(l.aiDrawing, settings.drawing, (value) {
              settings = (
                language: settings.language,
                drawing: value,
                a2ui: settings.a2ui,
              );
            }),
            const SizedBox(height: 12),
            _toolField(l.aiA2ui, settings.a2ui, (value) {
              settings = (
                language: settings.language,
                drawing: settings.drawing,
                a2ui: value,
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(settings),
          child: Text(l.save),
        ),
      ],
    );
  }

  Widget _toolField(String label, bool? value, ValueChanged<bool?> update) {
    final l = context.l10n;
    return AppSelectField<_Override>(
      decoration: InputDecoration(labelText: label),
      initialValue: _Override.values.firstWhere(
        (option) => option.value == value,
      ),
      items: [
        DropdownMenuItem(
          value: _Override.inherit,
          child: Text(l.useGlobalDefault),
        ),
        DropdownMenuItem(value: _Override.on, child: Text(l.subjectToolOn)),
        DropdownMenuItem(value: _Override.off, child: Text(l.subjectToolOff)),
      ],
      onChanged: (option) {
        if (option != null) setState(() => update(option.value));
      },
    );
  }
}
