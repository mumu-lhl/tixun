import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "../../core/ai/chat_provider.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_error_localization.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "sentence_batch_ai.dart";
import "sentence_batch_store.dart";
import "sentence_content.dart";

String sentenceSource(AppLocalizations l10n, String model) =>
    model == "Mock" ? l10n.languageAiMockSource : l10n.languageAiSource(model);

String sentenceTopicLabel(AppLocalizations l10n, SentenceTopic topic) =>
    topic == SentenceTopic.dailyLife
    ? l10n.languageSentenceDaily
    : l10n.languageSentenceTravel;

String sentenceStyleLabel(AppLocalizations l10n, SentenceStyle style) =>
    style == SentenceStyle.written
    ? l10n.languageSentenceWritten
    : l10n.languageSentenceDialogue;

class SentenceBatchDialog extends StatefulWidget {
  const SentenceBatchDialog({
    super.key,
    required this.store,
    required this.ai,
    required this.topic,
    required this.style,
    required this.level,
    required this.glossLanguage,
    this.focus,
    this.suggestedCount,
    this.exclusions = const [],
    this.reused = const [],
    this.kind = SentencePracticeKind.sentence,
    this.contextVocabulary = const [],
  });

  final LanguageLearningStore store;
  final SentenceBatchAi ai;
  final SentenceTopic topic;
  final SentenceStyle style;
  final SentenceLevel? level;
  final String glossLanguage;
  final SentenceSkill? focus;
  final int? suggestedCount;
  final List<String> exclusions;
  final List<SentenceCard> reused;
  final SentencePracticeKind kind;
  final List<LanguageCard> contextVocabulary;

  @override
  State<SentenceBatchDialog> createState() => _SentenceBatchDialogState();
}

class _SentenceBatchDialogState extends State<SentenceBatchDialog> {
  final _selected = <String>{};
  late int _count = widget.suggestedCount ?? 2;
  bool _customCount = false;
  SentenceBatchProposal? _proposal;
  CancelToken? _pending;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_pending != null || _saving) return;
    final cancel = CancelToken();
    setState(() {
      _pending = cancel;
      _error = null;
    });
    try {
      final proposal = await widget.ai.propose(
        topic: widget.topic,
        kind: widget.kind,
        vocabulary: widget.contextVocabulary,
        style: widget.style,
        level: widget.level,
        glossLanguage: widget.glossLanguage,
        count: _count,
        focus: widget.focus,
        exclude: [
          ...widget.exclusions,
          ...widget.reused.map((card) => card.text),
        ],
        cancel: cancel,
      );
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _proposal = proposal;
        _selected.clear();
        _selected.addAll(proposal.cards.map((card) => card.id));
      });
    } catch (error) {
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _error = error is AiFailure
            ? failureText(context.l10n, error)
            : context.l10n.languageSentenceBatchError;
      });
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  Future<void> _save(SentenceBatchProposal proposal) async {
    if (_pending != null || _saving || _selected.isEmpty) return;
    setState(() => _saving = true);
    await act(context, () async {
      await widget.store.saveSentenceBatch(proposal, _selected);
      if (!mounted) return;
      Navigator.of(context).pop(
        SentenceBatch(
          [
            ...widget.reused,
            ...proposal.cards.where((card) => _selected.contains(card.id)),
          ],
          generatedBy: proposal.model,
          kind: proposal.kind,
        ),
      );
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final proposal = _proposal;
    final busy = _pending != null || _saving;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.languageSentenceGenerate),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proposal == null) ...[
                Text(l10n.languageSentenceGenerateNotice),
                if (widget.reused.isNotEmpty)
                  Text(l10n.languageSentenceReused(widget.reused.length)),
                AppSelectField<int>(
                  initialValue: _customCount ? 0 : _count,
                  decoration: InputDecoration(
                    labelText: l10n.languageSentenceCount,
                  ),
                  items: [
                    for (final count in ({
                      1,
                      2,
                      3,
                      4,
                      5,
                      10,
                      15,
                      20,
                      if (_count > 0 && _count <= 20) _count,
                    }.toList()..sort()))
                      DropdownMenuItem(value: count, child: Text("$count")),
                    DropdownMenuItem(
                      value: 0,
                      child: Text(l10n.languageSentenceCustomCount),
                    ),
                  ],
                  onChanged: _pending != null
                      ? null
                      : (value) => setState(() {
                          _customCount = value == 0;
                          if (!_customCount) _count = value!;
                        }),
                ),
                if (_customCount)
                  TextFormField(
                    initialValue: "$_count",
                    enabled: _pending == null,
                    keyboardType: TextInputType.number,
                    maxLength: 2,
                    decoration: InputDecoration(
                      labelText: l10n.languageSentenceCustomCount,
                    ),
                    onChanged: (value) =>
                        setState(() => _count = int.tryParse(value) ?? -1),
                  ),
              ] else ...[
                Text(sentenceSource(l10n, proposal.model)),
                Text(l10n.languageSentenceGeneratedNotice),
                if (proposal.cards.length < (proposal.requestedCount ?? 0))
                  Text(
                    l10n.languageSentencePartialBatch(
                      proposal.cards.length,
                      proposal.requestedCount!,
                    ),
                  ),
                for (final card in proposal.cards)
                  CheckboxListTile(
                    title: Text(card.text),
                    subtitle: widget.kind == SentencePracticeKind.newContext
                        ? Text(card.question)
                        : null,
                    value: _selected.contains(card.id),
                    onChanged: busy
                        ? null
                        : (selected) => setState(() {
                            if (selected == true) {
                              _selected.add(card.id);
                            } else {
                              _selected.remove(card.id);
                            }
                          }),
                  ),
              ],
              if (busy) const LinearProgressIndicator(),
              if (_error case final error?) Text(error),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (proposal == null && widget.reused.isNotEmpty)
            TextButton(
              onPressed: _pending == null
                  ? () =>
                        Navigator.of(context).pop(SentenceBatch(widget.reused))
                  : null,
              child: Text(l10n.languageSentenceSavedOnly),
            ),
          if (proposal == null)
            FilledButton(
              onPressed:
                  _pending != null ||
                      _count < 1 ||
                      _count > SentenceBatchAi.maximumCount
                  ? null
                  : _generate,
              child: Text(l10n.languageSentenceGenerateAction),
            )
          else ...[
            TextButton(
              onPressed: busy ? null : _generate,
              child: Text(l10n.regenerate),
            ),
            FilledButton(
              onPressed: busy || _selected.isEmpty
                  ? null
                  : () => _save(proposal),
              child: Text(l10n.languageSentenceSaveAndStart),
            ),
          ],
        ],
      ),
    );
  }
}

Future<SentenceBatch?> chooseSavedSentenceBatch(
  BuildContext context,
  LanguageLearningStore store, {
  required SentencePracticeKind kind,
}) {
  final batches = store.savedSentenceBatches(kind: kind);
  return showDialog<SentenceBatch>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        title: Text(l10n.languageSentenceSaved),
        content: SizedBox(
          width: 480,
          height: 300,
          child: FutureBuilder<List<LearningSentenceBatch>>(
            future: batches,
            builder: (context, snapshot) {
              final rows = snapshot.data;
              if (rows == null) {
                return snapshot.hasError
                    ? Center(child: Text(l10n.languageSentenceSavedError))
                    : const Center(child: CircularProgressIndicator());
              }
              if (rows.isEmpty) {
                return Center(child: Text(l10n.languageSentenceSavedEmpty));
              }
              return ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final topic = SentenceTopic.values.byName(row.topic);
                  final style = SentenceStyle.values.byName(row.style);
                  final batch = openSavedSentenceBatch(row);
                  return ListTile(
                    title: Text(
                      batch.cards.first.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      "${sentenceTopicLabel(l10n, topic)} · "
                      "${sentenceStyleLabel(l10n, style)}\n"
                      "${sentenceSource(l10n, batch.generatedBy!)}",
                    ),
                    onTap: () => Navigator.of(context).pop(batch),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      );
    },
  );
}
