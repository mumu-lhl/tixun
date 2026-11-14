/// Plain-Markdown export: the lossless fallback that survives copy/paste and
/// can be opened by any editor, and the format users can hand to a printer
/// queue that understands Markdown.
library;

import 'study_export.dart';

String buildStudyMarkdown(StudyExportBundle bundle, StudyExportChrome chrome) {
  final out = StringBuffer()
    ..writeln('# ${chrome.title}')
    ..writeln()
    ..writeln(chrome.dateLine);
  if (chrome.imagesExcluded.isNotEmpty && bundle.imageCount > 0) {
    out
      ..writeln()
      ..writeln('> ${chrome.imagesExcluded}');
  }
  out.writeln();
  for (final entry in bundle.bySubject.entries) {
    if (bundle.bySubject.length > 1) {
      out
        ..writeln('## ${entry.key}')
        ..writeln();
    }
    for (final note in entry.value) {
      out
        ..writeln('### ${note.title}')
        ..writeln()
        ..writeln(chrome.noteMeta(note))
        ..writeln()
        ..writeln(note.content.trim())
        ..writeln();
    }
  }
  return out.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}
