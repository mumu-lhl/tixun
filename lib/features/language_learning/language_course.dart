import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import '../practice/practice_store.dart';
import '../practice/question_spec.dart';
import 'course_content.dart';

String _lessonOperation(String language, LanguageLesson lesson) =>
    'language-course:$language:${lesson.id}:v1';

extension on PracticeStore {
  Future<Set<String>> _completedLessons(
    String language,
    List<LanguageLesson> lessons,
  ) async {
    final questions = db.practiceQuestions;
    final attempts = db.practiceAttempts;
    final operations = {
      for (final lesson in lessons)
        _lessonOperation(language, lesson): lesson.id,
    };
    final query = db.selectOnly(questions, distinct: true)
      ..addColumns([questions.sourceOperation])
      ..join([innerJoin(attempts, attempts.questionId.equalsExp(questions.id))])
      ..where(
        questions.sourceOperation.isIn(operations.keys) &
            attempts.status.equals('graded') &
            attempts.correct.equals(true),
      );
    return {
      for (final row in await query.get())
        operations[row.read(questions.sourceOperation)]!,
    };
  }

  Future<String> _beginLesson(String language, LanguageLesson lesson) async {
    final id = await create(
      QuestionSpec(
        kind: 'single_choice',
        subject: language == 'ja' ? '日语' : '英语',
        stem: '${lesson.titleEn}\n\n${lesson.promptEn}',
        options: {
          for (final (i, option) in lesson.options.indexed) '$i': option,
        },
        answers: [
          ['${lesson.answer}'],
        ],
        explanation: lesson.examples
            .map((e) => '${e.text} — ${e.en}')
            .join('\n\n'),
      ),
      origin: 'template',
      verification: 'template_checked',
      operation: _lessonOperation(language, lesson),
    );
    final attempt = await begin(id, retry: true);
    return attempt.id;
  }
}

class LanguageCourse extends StatefulWidget {
  const LanguageCourse({super.key, required this.practice});

  final PracticeStore practice;

  @override
  State<LanguageCourse> createState() => _LanguageCourseState();
}

class _LanguageCourseState extends State<LanguageCourse> {
  String _language = 'en';
  List<LanguageLesson> get _lessons =>
      _language == 'ja' ? japaneseLessons : englishLessons;
  late var _completed = widget.practice._completedLessons(_language, _lessons);
  bool _unlocked = false;

  void _chooseLanguage(String language) {
    setState(() {
      _language = language;
      _unlocked = false;
      _completed = widget.practice._completedLessons(_language, _lessons);
    });
  }

  Future<void> _open(LanguageLesson lesson) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LessonPage(
          practice: widget.practice,
          lesson: lesson,
          language: _language,
        ),
      ),
    );
    if (mounted) {
      final completed = widget.practice._completedLessons(_language, _lessons);
      setState(() {
        _completed = completed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zh = l10n.localeName == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageFoundations)),
      body: FutureBuilder<Set<String>>(
        key: ValueKey(_language),
        future: _completed,
        builder: (context, snapshot) {
          final completed = snapshot.data;
          if (completed == null) {
            return Center(
              child: snapshot.hasError
                  ? Text(l10n.couldNotCompleteTheAction)
                  : const CircularProgressIndicator(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                  ButtonSegment(
                    value: 'ja',
                    label: Text(l10n.languageJapanese),
                  ),
                ],
                selected: {_language},
                onSelectionChanged: (values) => _chooseLanguage(values.single),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.languageCourseProgress(completed.length, _lessons.length),
              ),
              if (!_unlocked && completed.length < _lessons.length)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _unlocked = true),
                    child: Text(l10n.languageSkipPrerequisites),
                  ),
                ),
              for (final (index, lesson) in _lessons.indexed)
                _lessonTile(lesson, index, completed, zh),
              if (completed.length == _lessons.length)
                Text(l10n.languageCourseComplete),
            ],
          );
        },
      ),
    );
  }

  Widget _lessonTile(
    LanguageLesson lesson,
    int index,
    Set<String> completed,
    bool zh,
  ) {
    final done = completed.contains(lesson.id);
    final available =
        done ||
        _unlocked ||
        _lessons
            .take(index)
            .every((previous) => completed.contains(previous.id));
    return ListTile(
      title: Text(zh ? lesson.titleZh : lesson.titleEn),
      leading: Icon(
        done
            ? Icons.check_circle_outline
            : available
            ? Icons.play_circle_outline
            : Icons.lock_outline,
      ),
      enabled: available,
      onTap: available ? () => _open(lesson) : null,
    );
  }
}

class _LessonPage extends StatefulWidget {
  const _LessonPage({
    required this.practice,
    required this.lesson,
    required this.language,
  });

  final PracticeStore practice;
  final LanguageLesson lesson;
  final String language;

  @override
  State<_LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<_LessonPage> {
  bool _checking = false;
  int? _choice;
  String? _attempt;
  bool? _correct;
  bool _saving = false;

  Future<void> _submit() async {
    final choice = _choice;
    if (choice == null || _saving || _correct != null) return;
    setState(() => _saving = true);
    await act(context, () async {
      final id = _attempt ??= await widget.practice._beginLesson(
        widget.language,
        widget.lesson,
      );
      final result = await widget.practice.submit(id, ['$choice']);
      final correct = result.correct == true;
      if (mounted) setState(() => _correct = correct);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zh = l10n.localeName == 'zh';
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(zh ? lesson.titleZh : lesson.titleEn)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_checking) ...[
            for (final example in lesson.examples)
              ListTile(
                title: Text(example.text),
                subtitle: Text(zh ? example.zh : example.en),
              ),
            FilledButton(
              onPressed: () => setState(() => _checking = true),
              child: Text(l10n.languageCourseCheck),
            ),
          ] else ...[
            Text(zh ? lesson.promptZh : lesson.promptEn),
            for (final (i, option) in lesson.options.indexed)
              ChoiceChip(
                label: Text(option),
                selected: _choice == i,
                onSelected: _saving || _correct != null
                    ? null
                    : (_) => setState(() => _choice = i),
              ),
            if (_correct == null)
              FilledButton(
                onPressed: _saving || _choice == null ? null : _submit,
                child: Text(l10n.submitAnswer),
              )
            else ...[
              Text(_correct! ? l10n.correct : l10n.needsCorrection),
              Text(l10n.languageSentenceAnswer(lesson.options[lesson.answer])),
              if (_correct!)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.languageBackToCourse),
                )
              else
                FilledButton(
                  onPressed: () => setState(() {
                    _correct = null;
                    _choice = null;
                    _attempt = null;
                    _checking = false;
                  }),
                  child: Text(l10n.languageTryAgain),
                ),
            ],
          ],
        ],
      ),
    );
  }
}
