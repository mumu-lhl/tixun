import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/ui/actions.dart';
import '../practice/practice_store.dart';
import '../practice/question_spec.dart';
import 'gap_exercises.dart';
import 'reading_content.dart';

enum EnglishReadingSkill {
  comprehension,
  sentenceInsertion,
  cloze,
  grammarGap;

  String label(AppLocalizations l10n) => switch (this) {
    comprehension => l10n.languageReading,
    sentenceInsertion => l10n.languageSentenceInsertion,
    cloze => l10n.languageCloze,
    grammarGap => l10n.languageGrammarGap,
  };

  List<ReadingPassage> get passages => switch (this) {
    comprehension => readingPassages,
    sentenceInsertion => sentenceInsertionPassages,
    cloze => clozePassages,
    grammarGap => grammarGapPassages,
  };
}

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({
    super.key,
    required this.store,
    this.skill = EnglishReadingSkill.comprehension,
  });

  final PracticeStore store;
  final EnglishReadingSkill skill;

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  ReadingPassage? _passage;
  var _position = 0;
  String _answer = '';
  String? _attemptId;
  PracticeAttempt? _result;
  bool _saving = false;

  Future<void> _check(ReadingPassage passage, ReadingItem item) async {
    final answer = _answer.trim();
    if (answer.isEmpty || _saving || _result != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    await act(context, () async {
      if (_attemptId == null) {
        final isChoice = item.options.isNotEmpty;
        final question = await widget.store.create(
          QuestionSpec(
            kind: isChoice ? 'single_choice' : 'fill_blank',
            subject: '英语',
            stem:
                '${passage.title}\n\n${passage.paragraphs.join('\n\n')}\n\n${item.question}',
            options: item.options,
            answers: [item.acceptedAnswers],
            caseSensitive: isChoice,
            explanation:
                '${passage.paragraphs[item.evidence]}\n\n${item.explanation}',
          ),
          origin: 'template',
          verification: 'template_checked',
          operation: 'language-reading:${passage.id}:v1:$_position',
        );
        final attempt = await widget.store.begin(question, retry: true);
        _attemptId = attempt.id;
      }
      final result = await widget.store.submit(_attemptId!, [answer]);
      if (mounted) setState(() => _result = result);
    });
    if (mounted) setState(() => _saving = false);
  }

  void _advance(ReadingPassage passage) {
    setState(() {
      _position++;
      if (_position == passage.items.length) {
        _position = 0;
        _passage = null;
      }
      _answer = '';
      _attemptId = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final passage = _passage;
    final result = _result;
    final item = passage?.items[_position];
    return Scaffold(
      appBar: AppBar(title: Text(widget.skill.label(l10n))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (passage == null || item == null) ...[
                    Text(l10n.languageReadingIntro),
                    const SizedBox(height: 12),
                    for (final option in widget.skill.passages)
                      Card(
                        child: ListTile(
                          title: Text(option.title),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => setState(() => _passage = option),
                        ),
                      ),
                  ] else ...[
                    Text(passage.title, style: theme.textTheme.headlineSmall),
                    for (final (i, paragraph) in passage.paragraphs.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SelectableText(
                          paragraph,
                          style: result != null && i == item.evidence
                              ? TextStyle(
                                  backgroundColor:
                                      theme.colorScheme.secondaryContainer,
                                  color: theme.colorScheme.onSecondaryContainer,
                                )
                              : null,
                        ),
                      ),
                    const Divider(height: 32),
                    Text(
                      l10n.languageReadingProgress(
                        _position + 1,
                        passage.items.length,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.question, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    for (final option in item.options.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: ChoiceChip(
                          label: Text(option.value),
                          selected: _answer == option.key,
                          onSelected: result != null || _saving
                              ? null
                              : (_) => setState(() => _answer = option.key),
                        ),
                      ),
                    if (item.options.isEmpty)
                      TextField(
                        key: ValueKey(item),
                        enabled: result == null && !_saving,
                        maxLength: 120,
                        decoration: InputDecoration(
                          labelText: l10n.languageGrammarAnswer,
                          counterText: '',
                        ),
                        onChanged: (value) => setState(() => _answer = value),
                        onSubmitted: (_) => _check(passage, item),
                      ),
                    const SizedBox(height: 8),
                    if (result == null)
                      FilledButton(
                        onPressed: _answer.trim().isEmpty || _saving
                            ? null
                            : () => _check(passage, item),
                        child: Text(l10n.submitAnswer),
                      )
                    else ...[
                      Text(
                        result.correct == true
                            ? l10n.correct
                            : l10n.needsCorrection,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(l10n.languageSentenceAnswer(item.answerText)),
                      const SizedBox(height: 8),
                      Text(
                        l10n.languageReadingEvidence,
                        style: theme.textTheme.titleSmall,
                      ),
                      SelectableText(passage.paragraphs[item.evidence]),
                      const SizedBox(height: 8),
                      Text(item.explanation),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push(
                          '/practice/${result.questionId}/history',
                        ),
                        child: Text(l10n.languageReadingAttempts),
                      ),
                      FilledButton(
                        onPressed: () => _advance(passage),
                        child: Text(
                          _position + 1 == passage.items.length
                              ? l10n.languageReadingChooseAnother
                              : l10n.languageReadingNext,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
