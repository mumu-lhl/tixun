import "package:material_ui/material_ui.dart";

import "../../core/l10n/app_strings.dart";
import "../../core/ui/actions.dart";
import "language_data.dart";
import "language_layout.dart";
import "language_store.dart";

class VocabularyTrashScreen extends StatefulWidget {
  const VocabularyTrashScreen({
    super.key,
    required this.store,
    required this.language,
  });

  final LanguageLearningStore store;
  final String language;

  @override
  State<VocabularyTrashScreen> createState() => _VocabularyTrashScreenState();
}

class _VocabularyTrashScreenState extends State<VocabularyTrashScreen> {
  final _selected = <String>{};
  bool _saving = false;

  Stream<List<LanguageCard>> _load() =>
      widget.store.trashedCards(widget.language);

  Future<void> _apply(Set<String> ids, {required bool permanently}) async {
    if (_saving || ids.isEmpty) return;
    setState(() => _saving = true);
    await act(context, () async {
      if (permanently) {
        final l10n = context.l10n;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deletePermanently),
            content: Text(l10n.languageDeleteWordsForeverConfirm(ids.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.deletePermanently),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
        await widget.store.deleteTrashedVocabulary(ids);
      } else {
        await widget.store.restoreVocabulary(ids);
      }
      if (mounted) setState(() => _selected.removeAll(ids));
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageVocabularyTrash)),
      body: LanguageDataBuilder<List<LanguageCard>>(
        load: _load,
        builder: (context, cards) {
          final ids = {
            for (final card in cards)
              if (_selected.contains(card.sense.id)) card.sense.id,
          };
          if (cards.isEmpty) {
            return languagePage(children: [Text(l10n.trashIsEmpty)]);
          }
          return Column(
            children: [
              Expanded(
                child: languagePage(
                  children: [
                    for (final card in cards)
                      Card(
                        key: ValueKey(card.sense.id),
                        child: CheckboxListTile(
                          value: ids.contains(card.sense.id),
                          onChanged: _saving
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    _selected.add(card.sense.id);
                                  } else {
                                    _selected.remove(card.sense.id);
                                  }
                                }),
                          title: Text(card.item.form),
                          subtitle: Text(card.sense.meaning),
                        ),
                      ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text(l10n.languageSelectedWords(ids.length)),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: _saving || ids.isEmpty
                                ? null
                                : () => _apply(ids, permanently: false),
                            child: Text(l10n.restore),
                          ),
                          OutlinedButton(
                            onPressed: _saving || ids.isEmpty
                                ? null
                                : () => _apply(ids, permanently: true),
                            child: Text(l10n.deletePermanently),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
