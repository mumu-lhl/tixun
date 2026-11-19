import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import 'course_content.dart';

class LanguageCourse extends StatefulWidget {
  const LanguageCourse({super.key});

  @override
  State<LanguageCourse> createState() => _LanguageCourseState();
}

class _LanguageCourseState extends State<LanguageCourse> {
  String _language = 'en';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final zh = l10n.localeName == 'zh';
    final lessons = _language == 'ja' ? japaneseLessons : englishLessons;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageFoundations)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
              ButtonSegment(value: 'ja', label: Text(l10n.languageJapanese)),
            ],
            selected: {_language},
            onSelectionChanged: (values) =>
                setState(() => _language = values.single),
          ),
          const SizedBox(height: 16),
          for (final lesson in lessons)
            ListTile(
              title: Text(zh ? lesson.titleZh : lesson.titleEn),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => _LessonPage(lesson)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LessonPage extends StatelessWidget {
  const _LessonPage(this.lesson);

  final LanguageLesson lesson;

  @override
  Widget build(BuildContext context) {
    final zh = context.l10n.localeName == 'zh';
    return Scaffold(
      appBar: AppBar(title: Text(zh ? lesson.titleZh : lesson.titleEn)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final example in lesson.examples)
            ListTile(
              title: Text(example.text),
              subtitle: Text(zh ? example.zh : example.en),
            ),
        ],
      ),
    );
  }
}
