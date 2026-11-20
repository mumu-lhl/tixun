import "package:material_ui/material_ui.dart";
import "package:uuid/uuid.dart";

import "language_layout.dart";
import "../../core/database/database.dart" show LearningLexicalForm;
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "lexical_form.dart";
import "lexical_form_store.dart";

String inflectionLabel(AppLocalizations l10n, Inflection inflection) =>
    switch (inflection) {
      Inflection.past => l10n.languageFormPast,
      Inflection.pastParticiple => l10n.languageFormPastParticiple,
      Inflection.presentParticiple => l10n.languageFormPresentParticiple,
      Inflection.thirdPerson => l10n.languageFormThirdPerson,
      Inflection.plural => l10n.languageFormPlural,
      Inflection.comparative => l10n.languageFormComparative,
      Inflection.superlative => l10n.languageFormSuperlative,
    };

Future<List<LexicalFormDraft>> confirmLookupForms(
  BuildContext context,
  String lemma,
  List<LexicalFormDraft> forms,
) async {
  if (forms.isEmpty) return const [];
  final selected = <LexicalFormDraft>{};
  return await showDialog<List<LexicalFormDraft>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            scrollable: true,
            title: Text(context.l10n.languageConfirmForms(lemma)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                for (final form in forms)
                  CheckboxListTile(
                    title: Text(form.surface),
                    subtitle: Text(
                      inflectionLabel(context.l10n, form.inflection),
                    ),
                    value: selected.contains(form),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        selected.add(form);
                      } else {
                        selected.remove(form);
                      }
                    }),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, <LexicalFormDraft>[]),
                child: Text(context.l10n.languageSkip),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected.toList()),
                child: Text(context.l10n.confirmChoice),
              ),
            ],
          ),
        ),
      ) ??
      const [];
}

class LexicalFormsScreen extends StatefulWidget {
  const LexicalFormsScreen(
    this.store, {
    required this.language,
    this.card,
    this.initialProduction = false,
    super.key,
  });
  final LanguageLearningStore store;
  final String language;
  final LanguageCard? card;
  final bool initialProduction;

  @override
  State<LexicalFormsScreen> createState() => _LexicalFormsScreenState();
}

class _LexicalFormsScreenState extends State<LexicalFormsScreen> {
  late Future<List<LearningLexicalForm>> _forms = widget.store.lexicalForms(
    widget.card!.sense.id,
  );
  late final Future<List<FormPractice>> _practice = widget.store.formPractice(
    widget.language,
  );
  final _answer = TextEditingController();
  var _index = 0;
  late var _production = widget.initialProduction;
  var _busy = false;
  bool? _correct;
  String _attempt = const Uuid().v4();

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _add(LanguageCard card) async {
    final item = card.item;
    var surface = "";
    Inflection? feature;
    final formKey = GlobalKey<FormState>();
    final candidate = await showDialog<LexicalFormDraft>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.languageConfirmForms(item.form)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              TextFormField(
                maxLength: 80,
                decoration: InputDecoration(
                  labelText: context.l10n.languageFormSurface,
                ),
                onChanged: (value) => surface = value,
                validator: (value) {
                  try {
                    LexicalFormDraft(
                      value ?? "",
                      Inflection.past,
                    ).validate(item.form);
                    return null;
                  } on FormatException {
                    return context.l10n.languageInvalidForm;
                  }
                },
              ),
              AppSelectFormField<Inflection>(
                decoration: InputDecoration(
                  labelText: context.l10n.languageInflection,
                ),
                items: [
                  for (final value in Inflection.values)
                    DropdownMenuItem(
                      value: value,
                      child: Text(inflectionLabel(context.l10n, value)),
                    ),
                ],
                onChanged: (value) => feature = value,
                validator: (value) =>
                    value == null ? context.l10n.languageRequired : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, LexicalFormDraft(surface, feature!));
              }
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    if (!mounted || candidate == null) return;
    await act(context, () async {
      await widget.store.saveLexicalForm(card, candidate);
      if (mounted) {
        setState(() => _forms = widget.store.lexicalForms(card.sense.id));
      }
    });
  }

  void _reset() {
    _answer.clear();
    _correct = null;
    _attempt = const Uuid().v4();
  }

  Future<void> _submit(FormPractice row) async {
    if (_answer.text.trim().isEmpty || _busy || _correct != null) return;
    setState(() => _busy = true);
    await act(context, () async {
      final result = await widget.store.recordFormPractice(
        attemptId: _attempt,
        exercise: row,
        answer: _answer.text,
        production: _production,
      );
      if (mounted) setState(() => _correct = result);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final card = widget.card;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageForms)),
      body: languagePage(
        children: [
          if (card != null)
            FutureBuilder(
              future: _forms,
              builder: (context, snapshot) => Column(
                children: [
                  if (snapshot.hasError) Text(l10n.couldNotCompleteTheAction),
                  for (final form in snapshot.data ?? <LearningLexicalForm>[])
                    ListTile(
                      title: Text(form.surface),
                      subtitle: Text(
                        inflectionLabel(
                          l10n,
                          Inflection.values.byName(form.inflection),
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: () => _add(card),
                    child: Text(l10n.languageAddForm),
                  ),
                ],
              ),
            )
          else
            FutureBuilder(
              future: _practice,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(l10n.couldNotCompleteTheAction);
                }
                final rows = snapshot.data;
                if (rows == null) return const LinearProgressIndicator();
                if (rows.isEmpty) {
                  return Text(l10n.languageNoForms);
                }
                final row = rows[_index % rows.length];
                final inflection = inflectionLabel(
                  l10n,
                  Inflection.values.byName(row.form.inflection),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.languageFormProduction),
                      value: _production,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _production = value;
                              _reset();
                            }),
                    ),
                    Text(
                      _production
                          ? l10n.languageFormAskProduction(
                              row.item.form,
                              inflection,
                              row.sense.meaning,
                            )
                          : l10n.languageFormAskRecognition(
                              row.form.surface,
                              row.sense.meaning,
                            ),
                    ),
                    TextField(
                      controller: _answer,
                      maxLength: 80,
                      enabled: _correct == null && !_busy,
                      decoration: InputDecoration(
                        labelText: l10n.languageAnswer,
                      ),
                      onSubmitted: (_) => _submit(row),
                    ),
                    if (_correct case final correct?) ...[
                      Text(
                        correct
                            ? l10n.languageCorrect
                            : l10n.languageFormExample(
                                _production ? row.form.surface : row.item.form,
                              ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _index++;
                          _reset();
                        }),
                        child: Text(l10n.languageNext),
                      ),
                    ] else
                      FilledButton(
                        onPressed: _busy ? null : () => _submit(row),
                        child: Text(l10n.languageCheck),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
