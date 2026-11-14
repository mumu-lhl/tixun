/// Data handed to the print exporters.
///
/// The bundle is deliberately plain: text, timestamps and already-decoded
/// images. Reading the database, the attachment folder and the font assets
/// stays in the UI layer, so every writer here is a pure function that a test
/// can call without a widget tree.
library;

import 'dart:typed_data';

class StudyExportImage {
  const StudyExportImage({required this.bytes, required this.mime});
  final Uint8List bytes;
  final String mime;

  bool get isPng => mime == 'image/png';
  bool get isJpeg => mime == 'image/jpeg' || mime == 'image/jpg';
}

class StudyExportNote {
  const StudyExportNote({
    required this.title,
    required this.subject,
    required this.content,
    required this.updatedAt,
    this.chapter = '',
    this.kind = '',
    this.tags = const [],
    this.images = const [],
  });

  final String title;
  final String subject;
  final String chapter;
  final String kind;
  final List<String> tags;
  final DateTime updatedAt;
  final String content;
  final List<StudyExportImage> images;
}

class StudyExportBundle {
  const StudyExportBundle({
    required this.title,
    required this.generatedAt,
    required this.notes,
  });

  final String title;
  final DateTime generatedAt;
  final List<StudyExportNote> notes;

  bool get isEmpty => notes.isEmpty;

  int get imageCount => notes.fold(0, (sum, note) => sum + note.images.length);

  /// Subjects in the order they first appear, so the print keeps the order the
  /// caller selected instead of re-sorting a list the user already arranged.
  Map<String, List<StudyExportNote>> get bySubject {
    final grouped = <String, List<StudyExportNote>>{};
    for (final note in notes) {
      grouped.putIfAbsent(note.subject, () => []).add(note);
    }
    return grouped;
  }
}

enum StudyExportFormat {
  pdf('pdf', 'application/pdf'),
  docx(
    'docx',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ),
  markdown('md', 'text/markdown');

  const StudyExportFormat(this.extension, this.mimeType);
  final String extension;
  final String mimeType;
}

/// Text the document frame needs. Supplied by the UI so the writers stay free
/// of localisation.
class StudyExportChrome {
  const StudyExportChrome({
    required this.title,
    required this.dateLine,
    required this.pageLabel,
    required this.noteMeta,
    this.imagesExcluded = '',
  });

  final String title;
  final String dateLine;
  final String Function(int page, int total) pageLabel;
  final String Function(StudyExportNote note) noteMeta;

  /// Shown in formats that cannot carry the attachments.
  final String imagesExcluded;
}
