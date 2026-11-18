import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../practice/practice_store.dart';
import '../practice/question_spec.dart';

class ReadingPractice extends StatefulWidget {
  const ReadingPractice({super.key, required this.store});

  final PracticeStore store;

  @override
  State<ReadingPractice> createState() => _ReadingPracticeState();
}

class _ReadingPracticeState extends State<ReadingPractice> {
  _Passage? _passage;
  var _position = 0;
  String? _selected;
  PracticeAttempt? _result;
  bool _saving = false;

  Future<void> _check(_Passage passage, _Item item) async {
    final answer = _selected;
    if (answer == null || _saving || _result != null) return;
    setState(() => _saving = true);
    await act(context, () async {
      final question = await widget.store.create(
        QuestionSpec(
          kind: 'single_choice',
          subject: '英语',
          stem:
              '${passage.title}\n\n${passage.paragraphs.join('\n\n')}\n\n${item.question}',
          options: item.options,
          answers: [
            [item.answer],
          ],
          explanation:
              '${passage.paragraphs[item.evidence]}\n\n${item.explanation}',
        ),
        origin: 'template',
        verification: 'template_checked',
        operation: 'language-reading:${passage.id}:v1:$_position',
      );
      final attempt = await widget.store.begin(question, retry: true);
      final result = await widget.store.submit(attempt.id, [answer]);
      if (mounted) setState(() => _result = result);
    });
    if (mounted) setState(() => _saving = false);
  }

  void _advance(_Passage passage) {
    setState(() {
      _position++;
      if (_position == passage.items.length) {
        _position = 0;
        _passage = null;
      }
      _selected = null;
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
      appBar: AppBar(title: Text(l10n.languageReading)),
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
                    for (final option in _passages)
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
                          selected: _selected == option.key,
                          onSelected: result != null || _saving
                              ? null
                              : (_) => setState(() => _selected = option.key),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (result == null)
                      FilledButton(
                        onPressed: _selected == null || _saving
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
                      Text(
                        l10n.languageSentenceAnswer(item.options[item.answer]!),
                      ),
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

class _Passage {
  const _Passage(this.id, this.title, this.paragraphs, this.items);
  final String id, title;
  final List<String> paragraphs;
  final List<_Item> items;
}

class _Item {
  const _Item(
    this.question,
    this.options,
    this.answer,
    this.evidence,
    this.explanation,
  );
  final String question, answer, explanation;
  final Map<String, String> options;
  final int evidence;
}

const _passages = [
  _Passage(
    'seed-library',
    'A Library for Seeds',
    [
      'When the local library began lending seeds, the idea was simple: take a few seeds in spring, grow them, and return some of the seeds from your plants in autumn. Unlike ordinary books, there is no deadline or fine. If your plants fail, the library asks for nothing back.',
      'Last year, a dry summer reduced the number of seeds that people returned. Rather than buy packets to fill the shelves, the organizers asked experienced growers to show newcomers how to save seeds from the healthiest plants. By the following spring, more people were bringing seeds in than taking them out.',
      'For the organizers, that change mattered more than stocking every kind of vegetable. They wanted neighbors to share what they knew about growing food in this particular town, where the weather and soil can make advice from a book hard to follow.',
    ],
    [
      _Item(
        'What happens when a borrower cannot grow any plants?',
        {
          'A': 'They pay a fine.',
          'B': 'They return nothing.',
          'C': 'They buy replacement seeds.',
        },
        'B',
        0,
        'The last sentence sets out the exception. The library asks for seeds only when borrowers have some to return.',
      ),
      _Item(
        'Why did the organizers ask experienced growers to help?',
        {
          'A': 'To teach newcomers how to save seeds.',
          'B': 'To sell more packets.',
          'C': 'To find a new library building.',
        },
        'A',
        1,
        '“Rather than” contrasts buying replacement seeds with teaching borrowers how to save them.',
      ),
      _Item(
        'What did the organizers value most?',
        {
          'A': 'A complete collection of seeds.',
          'B': 'The number of books borrowed.',
          'C': 'Sharing useful local knowledge.',
        },
        'C',
        2,
        'The final paragraph contrasts the size of the collection with the value of sharing knowledge that fits local conditions.',
      ),
    ],
  ),
  _Passage(
    'repair-cafe',
    'A Place to Repair Things',
    [
      'At first, Mina thought the monthly repair café worked like a shop. She planned to leave her lamp on a table and collect it later. Instead, a volunteer invited her to sit down, watch how he checked the switch, and try the next step herself.',
      'Not every broken object can be fixed there. However, the volunteers always explain what they found. Sometimes a repair needs a part they do not have; other times an object is unsafe to open. Either way, visitors leave with a clearer idea of what to do next.',
    ],
    [
      _Item(
        'What surprised Mina about the café?',
        {
          'A': 'She was invited to take part in the repair.',
          'B': 'She could not collect her lamp.',
          'C': 'The café only opened on weekends.',
        },
        'A',
        0,
        '“Instead” marks the contrast between dropping off a lamp and working alongside the volunteer.',
      ),
      _Item(
        'What does the café offer even when it cannot finish a repair?',
        {
          'A': 'A replacement object.',
          'B': 'Money to buy spare parts.',
          'C': 'Information about the problem and what to do next.',
        },
        'C',
        1,
        'The second paragraph says the volunteers always explain what they found.',
      ),
    ],
  ),
];
