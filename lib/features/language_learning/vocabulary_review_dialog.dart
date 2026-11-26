import "package:material_ui/material_ui.dart";

import "../../app/preferences.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "vocabulary_review_settings.dart";

Future<void> editVocabularyReview(
  BuildContext context,
  AppPreferences preferences,
) => showDialog<void>(
  context: context,
  builder: (_) => _ReviewSettingsDialog(preferences),
);

class _ReviewSettingsDialog extends StatefulWidget {
  const _ReviewSettingsDialog(this.preferences);

  final AppPreferences preferences;

  @override
  State<_ReviewSettingsDialog> createState() => _ReviewSettingsDialogState();
}

class _ReviewSettingsDialogState extends State<_ReviewSettingsDialog> {
  late bool _enabled = widget.preferences.vocabularyReview.enabled;
  late int _retention = widget.preferences.vocabularyReview.retentionPercent;
  late final _maximum = TextEditingController(
    text: widget.preferences.vocabularyReview.maximumInterval.toString(),
  );
  final _advanced = ExpansibleController();
  bool _saving = false;
  bool _invalidMaximum = false;

  @override
  void dispose() {
    _advanced.dispose();
    _maximum.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final days = int.tryParse(_maximum.text.trim(), radix: 10);
    if (days == null || !validVocabularyReviewDays(days)) {
      _advanced.expand();
      setState(() => _invalidMaximum = true);
      return;
    }
    setState(() => _saving = true);
    var saved = false;
    await act(context, () async {
      await widget.preferences.setVocabularyReview((
        enabled: _enabled,
        retentionPercent: _retention,
        maximumInterval: days,
      ));
      saved = true;
    });
    if (!mounted) return;
    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.languageVocabularyReviewSettings),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.languageEnableFsrs),
                value: _enabled,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _enabled = value),
              ),
              Text(l10n.languageReviewRetention(_retention)),
              Slider(
                value: _retention.toDouble(),
                min: minVocabularyRetention.toDouble(),
                max: maxVocabularyRetention.toDouble(),
                divisions: maxVocabularyRetention - minVocabularyRetention,
                label: l10n.languageReviewRetention(_retention),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _retention = value.round()),
              ),
              Text(l10n.languageReviewRetentionHint),
              ExpansionTile(
                controller: _advanced,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.symmetric(vertical: 12),
                title: Text(l10n.languageReviewAdvanced),
                children: [
                  TextField(
                    key: const Key("vocabulary-review-maximum"),
                    controller: _maximum,
                    readOnly: _saving,
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      if (_invalidMaximum) {
                        setState(() => _invalidMaximum = false);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.languageReviewMaximum,
                      errorText: _invalidMaximum
                          ? l10n.languageReviewMaximumInvalid
                          : null,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _retention =
                              defaultVocabularyReviewSettings.retentionPercent;
                          _maximum.text = defaultVocabularyReviewSettings
                              .maximumInterval
                              .toString();
                          _invalidMaximum = false;
                        }),
                  child: Text(l10n.languageReviewReset),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key("save-vocabulary-review-settings"),
            onPressed: _saving ? null : _save,
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
