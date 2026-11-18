import 'package:material_ui/material_ui.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/ui/actions.dart';
import 'language_store.dart';

String vocabularyGroupLabel(AppLocalizations l10n, VocabularyGroupType type) =>
    switch (type) {
      VocabularyGroupType.topic => l10n.languageTopic,
      VocabularyGroupType.concept => l10n.languageConcept,
      VocabularyGroupType.function => l10n.languageFunction,
      VocabularyGroupType.contrast => l10n.languageContrast,
    };

String lexicalTypeLabel(AppLocalizations l10n, LexicalType type) =>
    switch (type) {
      LexicalType.word => l10n.languageWord,
      LexicalType.phrase => l10n.languagePhrase,
      LexicalType.phrasalVerb => l10n.languagePhrasalVerb,
      LexicalType.collocation => l10n.languageCollocation,
      LexicalType.idiom => l10n.languageIdiom,
    };

Future<void> addVocabularyEntry(
  BuildContext context,
  LanguageLearningStore store,
  String language, {
  LearningVocabularyGroup? group,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _VocabularyEditor(store, language, group),
);

class _VocabularyEditor extends StatefulWidget {
  const _VocabularyEditor(this.store, this.language, this.group);

  final LanguageLearningStore store;
  final String language;
  final LearningVocabularyGroup? group;

  @override
  State<_VocabularyEditor> createState() => _VocabularyEditorState();
}

class _VocabularyEditorState extends State<_VocabularyEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _expression = TextEditingController();
  final _meaning = TextEditingController();
  final _example = TextEditingController();
  final _translation = TextEditingController();
  final _application = TextEditingController();
  final _answer = TextEditingController();
  var _groupType = VocabularyGroupType.topic;
  var _lexicalType = LexicalType.word;
  var _saving = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _expression,
      _meaning,
      _example,
      _translation,
      _application,
      _answer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await act(context, () async {
      await widget.store.saveEntries(
        language: widget.language,
        groupTitle: widget.group?.title ?? _title.text,
        groupType: _groupType,
        entries: [
          VocabularyEntry(
            form: _expression.text,
            meaning: _meaning.text,
            type: _lexicalType,
            example: _example.text,
            translation: _translation.text,
            application: _application.text,
            applicationAnswer: _answer.text,
          ),
        ],
      );
      if (mounted) Navigator.of(context).pop();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? requiredText(String? text) =>
        (text ?? '').trim().isEmpty ? l10n.languageRequired : null;
    Widget field(
      TextEditingController controller,
      String label, [
      FormFieldValidator<String>? validate,
    ]) => TextFormField(
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(labelText: label),
      validator: validate,
    );
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.languageAddEntry),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.group == null) ...[
                  field(_title, l10n.languageGroupTitle, requiredText),
                  DropdownButtonFormField<VocabularyGroupType>(
                    initialValue: _groupType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.languageGroupType,
                    ),
                    items: [
                      for (final type in VocabularyGroupType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(vocabularyGroupLabel(l10n, type)),
                        ),
                    ],
                    onChanged: _saving ? null : (type) => _groupType = type!,
                  ),
                ] else
                  Text(widget.group!.title),
                field(_expression, l10n.languageExpression, requiredText),
                field(_meaning, l10n.languageMeaning, requiredText),
                DropdownButtonFormField<LexicalType>(
                  initialValue: _lexicalType,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.languageLexicalType,
                  ),
                  items: [
                    for (final type in LexicalType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(lexicalTypeLabel(l10n, type)),
                      ),
                  ],
                  onChanged: _saving ? null : (type) => _lexicalType = type!,
                ),
                field(_example, l10n.languageExample),
                field(_translation, l10n.languageTranslation),
                field(_application, l10n.languageApplication, (value) {
                  final sentence = value?.trim() ?? '';
                  final answer = _answer.text.trim();
                  if (sentence.isEmpty && answer.isEmpty) return null;
                  return answer.isNotEmpty &&
                          '___'.allMatches(sentence).length == 1
                      ? null
                      : l10n.languageBlankRequired;
                }),
                field(_answer, l10n.languageApplicationAnswer),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.confirmChoice),
          ),
        ],
      ),
    );
  }
}
