import "package:material_ui/material_ui.dart";

import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "lexical_form.dart";
import "lexical_form_screen.dart" show inflectionLabel;

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
  builder: (_) => _VocabularyEditor.add(store, language, group),
);

Future<VocabularyEntry?> editVocabularyCandidate(
  BuildContext context,
  VocabularyEntry entry,
) => showDialog<VocabularyEntry>(
  context: context,
  builder: (_) => _VocabularyEditor.preview(entry),
);

class _VocabularyEditor extends StatefulWidget {
  const _VocabularyEditor.add(this.store, this.language, this.group)
    : initial = null;
  const _VocabularyEditor.preview(this.initial)
    : store = null,
      language = "en",
      group = null;

  final LanguageLearningStore? store;
  final String language;
  final LearningVocabularyGroup? group;
  final VocabularyEntry? initial;

  @override
  State<_VocabularyEditor> createState() => _VocabularyEditorState();
}

class _VocabularyEditorState extends State<_VocabularyEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late final _expression = TextEditingController(text: widget.initial?.form);
  late final _meaning = TextEditingController(text: widget.initial?.meaning);
  late final _partOfSpeech = TextEditingController(
    text: widget.initial?.partOfSpeech,
  );
  late final _example = TextEditingController(text: widget.initial?.example);
  late final _translation = TextEditingController(
    text: widget.initial?.translation,
  );
  late final _application = TextEditingController(
    text: widget.initial?.application,
  );
  late final _answer = TextEditingController(
    text: widget.initial?.applicationAnswer,
  );
  var _groupType = VocabularyGroupType.topic;
  late var _lexicalType = widget.initial?.type ?? LexicalType.word;
  late final _formSurfaces = [
    for (final form in widget.initial?.forms ?? <LexicalFormDraft>[])
      TextEditingController(text: form.surface),
  ];
  late final _selectedForms = [for (final _ in _formSurfaces) true];
  var _saving = false;
  var _dirty = false;
  var _confirmingClose = false;

  Future<void> _close() async {
    if (_saving || _confirmingClose) return;
    if (!_dirty) {
      Navigator.pop(context);
      return;
    }
    _confirmingClose = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(context.l10n.discardUnsavedChanges),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.discard),
          ),
        ],
      ),
    );
    _confirmingClose = false;
    if (mounted && discard == true) Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _expression,
      _meaning,
      _partOfSpeech,
      _example,
      _translation,
      _application,
      _answer,
      ..._formSurfaces,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final entry = VocabularyEntry(
      form: _expression.text,
      meaning: _meaning.text,
      type: _lexicalType,
      partOfSpeech: _partOfSpeech.text.trim().isEmpty
          ? null
          : _partOfSpeech.text.trim(),
      example: _example.text,
      translation: _translation.text,
      application: _application.text,
      applicationAnswer: _answer.text,
      forms: [
        for (var i = 0; i < _formSurfaces.length; i++)
          if (_selectedForms[i] && _lexicalType == LexicalType.word)
            LexicalFormDraft(
              _formSurfaces[i].text.trim(),
              widget.initial!.forms[i].inflection,
            ),
      ],
    );
    final store = widget.store;
    if (store == null) {
      Navigator.of(context).pop(entry);
      return;
    }
    setState(() => _saving = true);
    await act(context, () async {
      await store.saveEntries(
        language: widget.language,
        groupTitle: widget.group?.title ?? _title.text,
        groupType: _groupType,
        entries: [entry],
      );
      if (mounted) Navigator.of(context).pop();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String? requiredText(String? text) =>
        (text ?? "").trim().isEmpty ? l10n.languageRequired : null;
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
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _close();
      },
      child: AlertDialog(
        title: Text(widget.initial == null ? l10n.languageAddEntry : l10n.edit),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                if (widget.initial == null && widget.group == null) ...[
                  field(_title, l10n.languageGroupTitle, requiredText),
                  AppSelectField<VocabularyGroupType>(
                    initialValue: _groupType,
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
                    onChanged: _saving
                        ? null
                        : (type) => setState(() {
                            _groupType = type!;
                            _dirty = true;
                          }),
                  ),
                ] else if (widget.group case final group?)
                  Text(group.title),
                field(_expression, l10n.languageExpression, requiredText),
                field(_meaning, l10n.languageMeaning, requiredText),
                field(_partOfSpeech, l10n.languagePartOfSpeech),
                AppSelectField<LexicalType>(
                  initialValue: _lexicalType,
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
                  onChanged: _saving
                      ? null
                      : (type) => setState(() {
                          _lexicalType = type!;
                          _dirty = true;
                        }),
                ),
                field(_example, l10n.languageExample),
                field(_translation, l10n.languageTranslation),
                if (_formSurfaces.isNotEmpty &&
                    _lexicalType == LexicalType.word) ...[
                  Text(l10n.languageForms),
                  for (var i = 0; i < _formSurfaces.length; i++)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _selectedForms[i],
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  _selectedForms[i] = value!;
                                  _dirty = true;
                                }),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _formSurfaces[i],
                            enabled: !_saving && _selectedForms[i],
                            maxLength: 80,
                            decoration: InputDecoration(
                              labelText: inflectionLabel(
                                l10n,
                                widget.initial!.forms[i].inflection,
                              ),
                            ),
                            validator: (value) {
                              if (!_selectedForms[i]) return null;
                              try {
                                LexicalFormDraft(
                                  value ?? "",
                                  widget.initial!.forms[i].inflection,
                                ).validate(_expression.text);
                                return null;
                              } on FormatException {
                                return l10n.languageInvalidForm;
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _close,
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
