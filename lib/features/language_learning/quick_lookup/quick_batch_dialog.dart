import "package:material_ui/material_ui.dart";

import "../../../core/database/database.dart";
import "../../../core/l10n/app_strings.dart";
import "../../../core/ui/app_menu.dart";
import "quick_ai.dart";
import "quick_models.dart";

typedef QuickStudyItem = ({
  LanguageQuickLookup row,
  QuickCandidates? candidates,
});
typedef QuickStudyPlan = ({
  QuickLearningTarget target,
  List<QuickStudyItem> items,
});

Future<QuickStudyPlan?> chooseQuickStudyItems(
  BuildContext context,
  List<LanguageQuickLookup> rows, {
  required bool automatic,
  required int unavailable,
}) => showDialog<QuickStudyPlan>(
  context: context,
  builder: (_) => _QuickBatchDialog(rows, automatic, unavailable),
);

class _QuickBatchDialog extends StatefulWidget {
  const _QuickBatchDialog(this.rows, this.automatic, this.unavailable);

  final List<LanguageQuickLookup> rows;
  final bool automatic;
  final int unavailable;

  @override
  State<_QuickBatchDialog> createState() => _QuickBatchDialogState();
}

class _QuickBatchDialogState extends State<_QuickBatchDialog> {
  late bool _automatic = widget.automatic;
  var _target = QuickLearningTarget.vocabulary;
  late final _sources = {
    for (final row in widget.rows) row: QuickCandidates.fromLookup(row),
  };
  final _excluded = <(String, QuickLearningTarget, int)>{};

  bool _selected(LanguageQuickLookup row, int index) =>
      !_excluded.contains((row.id, _target, index));

  void _select(LanguageQuickLookup row, int index, bool? selected) {
    setState(() {
      final key = (row.id, _target, index);
      if (selected == true) {
        _excluded.remove(key);
      } else {
        _excluded.add(key);
      }
    });
  }

  int _count(QuickCandidates candidates) => switch (_target) {
    QuickLearningTarget.vocabulary => candidates.vocabulary.length,
    QuickLearningTarget.sentence => candidates.sentence == null ? 0 : 1,
  };

  List<QuickStudyItem> _items() {
    final items = <QuickStudyItem>[];
    for (final MapEntry(:key, :value) in _sources.entries) {
      if (_count(value) == 0) {
        if (_automatic && _selected(key, 0)) {
          items.add((row: key, candidates: null));
        }
      } else if (_target == QuickLearningTarget.vocabulary) {
        final entries = [
          for (final (index, entry) in value.vocabulary.indexed)
            if (_selected(key, index)) entry,
        ];
        if (entries.isNotEmpty) {
          items.add((row: key, candidates: QuickCandidates(entries, null)));
        }
      } else if (_selected(key, 0)) {
        items.add((row: key, candidates: QuickCandidates([], value.sentence)));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _items();
    return AlertDialog(
      title: Text(l10n.quickBatchAdd),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            AppSelectField<QuickLearningTarget>(
              initialValue: _target,
              items: [
                DropdownMenuItem(
                  value: QuickLearningTarget.vocabulary,
                  child: Text(
                    l10n.quickAddVocabulary,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: QuickLearningTarget.sentence,
                  child: Text(
                    l10n.quickAddSentence,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _target = value!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.quickAutoAdd),
              value: _automatic,
              onChanged: (value) => setState(() => _automatic = value),
            ),
            if (items.any((item) => item.candidates == null))
              Text(l10n.quickAutoAddNotice),
            if (widget.unavailable > 0)
              Text(l10n.quickBatchUnavailable(widget.unavailable)),
            for (final MapEntry(key: row, value: candidates)
                in _sources.entries) ...[
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 8),
                child: Text(
                  row.input,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_count(candidates) == 0)
                if (_automatic)
                  _option(row, 0, l10n.quickExtractCandidate)
                else
                  Text(l10n.quickNoCandidate)
              else if (_target == QuickLearningTarget.vocabulary)
                for (final (index, entry) in candidates.vocabulary.indexed)
                  _option(row, index, entry.form, entry.meaning)
              else
                _option(
                  row,
                  0,
                  candidates.sentence!.text,
                  candidates.sentence!.gloss,
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: items.isEmpty
              ? null
              : () => Navigator.pop(context, (target: _target, items: items)),
          child: Text(
            _target == QuickLearningTarget.vocabulary
                ? l10n.languageNext
                : l10n.save,
          ),
        ),
      ],
    );
  }

  Widget _option(
    LanguageQuickLookup row,
    int index,
    String title, [
    String? subtitle,
  ]) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis),
    subtitle: subtitle == null || subtitle.isEmpty
        ? null
        : Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
    controlAffinity: ListTileControlAffinity.leading,
    value: _selected(row, index),
    onChanged: (value) => _select(row, index, value),
  );
}
