import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ai/chat_provider.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/ui/actions.dart';
import 'language_store.dart';
import 'sentence_batch_ai.dart';
import 'sentence_batch_store.dart';
import 'sentence_content.dart';

String sentenceSource(AppLocalizations l10n, String model) =>
    model == 'Mock' ? l10n.languageAiMockSource : l10n.languageAiSource(model);

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
  });

  final LanguageLearningStore store;
  final SentenceBatchAi ai;
  final SentenceTopic topic;
  final SentenceStyle style;
  final SentenceLevel? level;
  final String glossLanguage;

  @override
  State<SentenceBatchDialog> createState() => _SentenceBatchDialogState();
}

class _SentenceBatchDialogState extends State<SentenceBatchDialog> {
  final _selected = <String>{};
  int _count = 2;
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
    final cancel = CancelToken();
    setState(() {
      _pending = cancel;
      _error = null;
    });
    try {
      final proposal = await widget.ai.propose(
        topic: widget.topic,
        style: widget.style,
        level: widget.level,
        glossLanguage: widget.glossLanguage,
        count: _count,
        cancel: cancel,
      );
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _proposal = proposal;
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
    setState(() => _saving = true);
    await act(context, () async {
      await widget.store.saveSentenceBatch(proposal, _selected);
      if (!mounted) return;
      Navigator.of(context).pop(
        SentenceBatch(
          proposal.cards.where((card) => _selected.contains(card.id)),
          generatedBy: proposal.model,
        ),
      );
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final proposal = _proposal;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.languageSentenceGenerate),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (proposal == null) ...[
                Text(l10n.languageSentenceGenerateNotice),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _count,
                  decoration: InputDecoration(
                    labelText: l10n.languageSentenceCount,
                  ),
                  items: [
                    for (final count in [1, 2, 3, 4])
                      DropdownMenuItem(value: count, child: Text('$count')),
                  ],
                  onChanged: _pending != null
                      ? null
                      : (value) => _count = value!,
                ),
              ] else ...[
                Text(sentenceSource(l10n, proposal.model)),
                Text(l10n.languageSentenceGeneratedNotice),
                for (final card in proposal.cards)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(card.text),
                    subtitle: Text('${card.hint}\n${card.translation}'),
                    value: _selected.contains(card.id),
                    onChanged: _saving
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
              if (_pending != null || _saving) const LinearProgressIndicator(),
              if (_error case final error?) Text(error),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (proposal == null)
            FilledButton(
              onPressed: _pending != null ? null : _generate,
              child: Text(l10n.languageSentenceGenerateAction),
            )
          else
            FilledButton(
              onPressed: _saving || _selected.isEmpty
                  ? null
                  : () => _save(proposal),
              child: Text(l10n.languageSentenceSaveAndStart),
            ),
        ],
      ),
    );
  }
}

Future<SentenceBatch?> chooseSavedSentenceBatch(
  BuildContext context,
  LanguageLearningStore store,
) {
  final batches = store.savedSentenceBatches();
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
                      '${sentenceTopicLabel(l10n, topic)} · '
                      '${sentenceStyleLabel(l10n, style)}\n'
                      '${sentenceSource(l10n, batch.generatedBy!)}',
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
