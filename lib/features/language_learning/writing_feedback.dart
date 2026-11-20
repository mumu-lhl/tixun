import "dart:convert";

enum WritingNoteKind { issue, suggestion }

class WritingNote {
  const WritingNote(this.start, this.end, this.kind, this.comment);

  final int start, end;
  final WritingNoteKind kind;
  final String comment;
}

class WritingFeedback {
  const WritingFeedback({
    required this.task,
    required this.organization,
    required this.language,
    required this.summary,
    required this.notes,
  });

  final int task, organization, language;
  final String summary;
  final List<WritingNote> notes;

  factory WritingFeedback.parse(String raw, String draft) {
    var text = raw.trim();
    if (text.startsWith("```")) {
      text = text.replaceFirst(RegExp(r"^```(?:json)?\s*"), "");
      if (text.endsWith("```")) text = text.substring(0, text.length - 3);
    }
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic>) {
      throw const FormatException("Invalid writing feedback");
    }
    int score(String key) {
      final value = data[key];
      if (value is! int || value < 0 || value > 4) {
        throw const FormatException("Invalid writing dimension");
      }
      return value;
    }

    final summary = data["summary"];
    final annotations = data["notes"];
    if (summary is! String ||
        summary.trim().isEmpty ||
        summary.length > 1200 ||
        annotations is! List ||
        annotations.length > 8) {
      throw const FormatException("Invalid writing feedback");
    }
    final anchors = <(int, int)>{};
    final notes = <WritingNote>[];
    for (final annotation in annotations) {
      if (annotation is! Map<String, dynamic>) continue;
      final quote = annotation["quote"];
      final comment = annotation["comment"];
      final kind = WritingNoteKind.values.asNameMap()[annotation["kind"]];
      if (quote is! String ||
          quote.trim().length < 2 ||
          quote.length > 240 ||
          comment is! String ||
          comment.trim().isEmpty ||
          comment.length > 500 ||
          kind == null) {
        continue;
      }
      final start = draft.indexOf(quote);
      if (start < 0 || draft.indexOf(quote, start + 1) >= 0) continue;
      final end = start + quote.length;
      if (anchors.add((start, end))) {
        notes.add(WritingNote(start, end, kind, comment.trim()));
      }
    }
    return WritingFeedback(
      task: score("task"),
      organization: score("organization"),
      language: score("language"),
      summary: summary.trim(),
      notes: notes,
    );
  }
}
