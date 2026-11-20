import "package:material_ui/material_ui.dart";

import "language_layout.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/ui/actions.dart";
import "course_content.dart";
import "course_progress.dart";
import "language_store.dart";

class LanguageCourse extends StatefulWidget {
  const LanguageCourse({
    super.key,
    this.store,
    this.initialLanguage = "en",
    this.openProfile,
  });

  final LanguageLearningStore? store;
  final String initialLanguage;
  final ValueChanged<String>? openProfile;

  @override
  State<LanguageCourse> createState() => _LanguageCourseState();
}

class _LanguageCourseState extends State<LanguageCourse> {
  late String _language = widget.initialLanguage;
  late var _progress = widget.store?.courseProgress(_language);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zh = l10n.localeName == "zh";
    final lessons = languageLessons(_language);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageFoundations)),
      body: StreamBuilder(
        key: ValueKey(_language),
        stream: _progress,
        builder: (context, snapshot) => languagePage(
          children: [
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: "en", label: Text(l10n.languageEnglish)),
                ButtonSegment(value: "ja", label: Text(l10n.languageJapanese)),
              ],
              selected: {_language},
              onSelectionChanged: (values) => setState(() {
                _language = values.single;
                _progress = widget.store?.courseProgress(_language);
              }),
            ),
            if (widget.openProfile case final open?)
              TextButton(
                onPressed: () => open(_language),
                child: Text(l10n.languageProfile),
              ),
            if (snapshot.hasError) Text(l10n.couldNotCompleteTheAction),
            for (final (index, lesson) in lessons.indexed)
              Builder(
                builder: (context) {
                  final all = snapshot.data ?? const <String, CourseProgress>{};
                  final progress =
                      all[courseLessonId(index)] ?? const CourseProgress([]);
                  final prepared =
                      index == 0 ||
                      (all[courseLessonId(index - 1)]?.passed ?? false);
                  return ListTile(
                    title: Text(zh ? lesson.titleZh : lesson.titleEn),
                    selected:
                        widget.store != null &&
                        (progress.due(DateTime.now()) ||
                            prepared && !progress.passed),
                    subtitle: widget.store == null
                        ? null
                        : Text(
                            progress.due(DateTime.now())
                                ? l10n.languageCourseReviewDue
                                : progress.passed
                                ? l10n.languageCourseCheckpointComplete
                                : !prepared
                                ? l10n.languageCoursePriorLesson
                                : l10n.languageCourseCheckpointProgress(
                                    progress.passedRotations.length,
                                  ),
                          ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _LessonPage(
                          lesson,
                          store: widget.store,
                          language: _language,
                          index: index,
                          rotation: progress.nextRotation,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage(
    this.lesson, {
    required this.store,
    required this.language,
    required this.index,
    required this.rotation,
  });
  final LanguageLesson lesson;
  final LanguageLearningStore? store;
  final String language;
  final int index, rotation;

  @override
  Widget build(BuildContext context) {
    final zh = context.l10n.localeName == "zh";
    return Scaffold(
      appBar: AppBar(title: Text(zh ? lesson.titleZh : lesson.titleEn)),
      body: languagePage(
        children: [
          for (final example in lesson.examples)
            ListTile(
              title: Text(example.text),
              subtitle: Text(zh ? example.zh : example.en),
            ),
          if (store case final storage?)
            FilledButton(
              onPressed: () async {
                final finished = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => _CourseCheck(
                      lesson,
                      storage,
                      language,
                      index,
                      rotation,
                    ),
                  ),
                );
                if (context.mounted && finished == true) Navigator.pop(context);
              },
              child: Text(context.l10n.languageCourseCheckpoint),
            ),
        ],
      ),
    );
  }
}

class _CourseCheck extends StatefulWidget {
  const _CourseCheck(
    this.lesson,
    this.store,
    this.language,
    this.index,
    this.rotation,
  );
  final LanguageLesson lesson;
  final LanguageLearningStore store;
  final String language;
  final int index, rotation;

  @override
  State<_CourseCheck> createState() => _CourseCheckState();
}

class _CourseCheckState extends State<_CourseCheck> {
  final _choices = List<String?>.filled(2, null);
  String _written = "";
  (int, int)? _score;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving ||
        _score != null ||
        _choices.contains(null) ||
        _written.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final examples = widget.lesson.examples;
    final recognized = [
      for (var i = 0; i < 2; i++)
        if (_choices[i] ==
            examples[(widget.rotation + i) % examples.length].text)
          i,
    ].length;
    final produced =
        sameCourseExpression(
          _written,
          examples[(widget.rotation + 2) % examples.length].text,
        )
        ? 1
        : 0;
    await act(context, () async {
      await widget.store.recordCourseCheck(
        language: widget.language,
        lesson: widget.index,
        rotation: widget.rotation,
        recognized: recognized,
        produced: produced,
      );
      if (mounted) setState(() => _score = (recognized, produced));
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zh = l10n.localeName == "zh";
    final examples = widget.lesson.examples;
    final prompt = examples[(widget.rotation + 2) % examples.length];
    final options = examples.map((example) => example.text).toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageCourseCheckpoint)),
      body: languagePage(
        children: [
          for (var i = 0; i < 2; i++) ...[
            Text(
              zh
                  ? examples[(widget.rotation + i) % examples.length].zh
                  : examples[(widget.rotation + i) % examples.length].en,
            ),
            AppSelectField<String>(
              initialValue: _choices[i],
              decoration: InputDecoration(
                labelText: l10n.languageWordRecognition,
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem(
                    value: option,
                    child: Text(option, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _saving || _score != null
                  ? null
                  : (value) => setState(() => _choices[i] = value),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            (zh ? prompt.zh : prompt.en).replaceAll(
              RegExp(RegExp.escape(prompt.text), caseSensitive: false),
              "…",
            ),
          ),
          TextField(
            maxLength: 500,
            enabled: !_saving && _score == null,
            decoration: InputDecoration(labelText: l10n.languageAnswer),
            onChanged: (value) => setState(() => _written = value),
          ),
          if (_score case (final recognized, final produced)) ...[
            Text(l10n.languageCourseCheckpointResult(recognized, produced)),
            Text(l10n.languageExpected(prompt.text)),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.close),
            ),
          ] else
            FilledButton(
              onPressed:
                  _saving || _choices.contains(null) || _written.trim().isEmpty
                  ? null
                  : _submit,
              child: Text(l10n.languageCheck),
            ),
        ],
      ),
    );
  }
}
