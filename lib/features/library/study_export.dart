/// Print export for knowledge notes.
///
/// The database and the attachment folder are read here, the fonts are loaded
/// from the asset bundle, and the result is staged in the cache directory for
/// the platform save dialog. The format writers themselves stay pure functions
/// in `core/export`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/export/docx_export.dart';
import '../../core/export/markdown_export.dart';
import '../../core/export/pdf_export.dart';
import '../../core/export/study_export.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/platform/export_file_picker.dart';
import 'study_store.dart';

class StudyExportService {
  StudyExportService(
    this.store, {
    Future<ByteData> Function(String key)? loadFont,
    this.picker = const ExportFilePicker(),
  }) : _loadFont = loadFont ?? rootBundle.load;

  final StudyStore store;
  final Future<ByteData> Function(String key) _loadFont;
  final ExportFilePicker picker;

  /// Reads the selected notes in the order the caller passes them.
  ///
  /// An unreadable or unsupported attachment is skipped instead of failing the
  /// whole export: losing one photo must not cost the user the printout.
  Future<StudyExportBundle> load({
    required List<String> ids,
    required String title,
    required DateTime generatedAt,
    required bool includeImages,
  }) async {
    final notes = <StudyExportNote>[];
    for (final id in ids) {
      final detail = await store.knowledgeDetail(id);
      final row = detail.item;
      if (row.deleted) continue;
      final images = <StudyExportImage>[];
      if (includeImages) {
        for (final attachment in detail.images) {
          if (attachment.deleted) continue;
          final mime = attachment.mime.toLowerCase();
          if (mime != 'image/png' &&
              mime != 'image/jpeg' &&
              mime != 'image/jpg') {
            continue;
          }
          try {
            final bytes = await store.files
                .resolve(attachment.relativePath)
                .readAsBytes();
            if (bytes.isEmpty) continue;
            images.add(StudyExportImage(bytes: bytes, mime: mime));
          } on Object {
            continue;
          }
        }
      }
      notes.add(
        StudyExportNote(
          title: row.title,
          subject: row.subject,
          chapter: row.chapter,
          kind: row.kind,
          tags: detail.tags,
          updatedAt: row.updatedAt,
          content: row.content,
          images: images,
        ),
      );
    }
    return StudyExportBundle(
      title: title,
      generatedAt: generatedAt,
      notes: notes,
    );
  }

  Future<Uint8List> render(
    StudyExportBundle bundle,
    StudyExportFormat format, {
    required StudyExportChrome chrome,
    required bool includeImages,
  }) async {
    switch (format) {
      case StudyExportFormat.markdown:
        return Uint8List.fromList(
          utf8.encode(buildStudyMarkdown(bundle, chrome)),
        );
      case StudyExportFormat.docx:
        return buildStudyDocx(
          bundle: bundle,
          chrome: chrome,
          includeImages: includeImages,
        );
      case StudyExportFormat.pdf:
        final font = await _loadFont('assets/fonts/NotoSansSC.ttf');
        final mono = await _loadFont('assets/fonts/RobotoMono.ttf');
        return buildStudyPdf(
          bundle: bundle,
          chrome: chrome,
          font: font,
          monoFont: mono,
          includeImages: includeImages,
        );
    }
  }

  /// Stages [bytes] and asks the platform to save them under [fileName].
  Future<bool> save(
    Uint8List bytes, {
    required String fileName,
    required StudyExportFormat format,
    required String label,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    try {
      return await picker.save(
        file,
        name: fileName,
        extension: format.extension,
        mimeType: format.mimeType,
        label: label,
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

/// Builds the frame texts the writers need from the current locale.
StudyExportChrome studyExportChrome({
  required AppLocalizations l10n,
  required String Function(String subject) subjectName,
  required StudyExportBundle bundle,
}) {
  final generated = formatExportDate(bundle.generatedAt);
  return StudyExportChrome(
    title: l10n.exportDocumentTitle,
    dateLine: l10n.exportGeneratedLine(
      l10nArgument(generated),
      l10nArgument(bundle.notes.length),
    ),
    pageLabel: (page, total) =>
        l10n.exportPageLabel(l10nArgument(page), l10nArgument(total)),
    noteMeta: (note) {
      final parts = <String>[
        subjectName(note.subject),
        note.chapter,
        note.kind,
        if (note.tags.isNotEmpty) note.tags.map((tag) => '#$tag').join(' '),
      ].where((part) => part.trim().isNotEmpty);
      return l10n.exportNoteMeta(
        l10nArgument(parts.join(' · ')),
        l10nArgument(formatExportDate(note.updatedAt)),
      );
    },
    imagesExcluded: l10n.exportMarkdownWithoutImages,
  );
}

String formatExportDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}

String exportFileName(DateTime now, StudyExportFormat format) {
  final local = now.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  final stamp =
      '${local.year}${two(local.month)}${two(local.day)}-${two(local.hour)}${two(local.minute)}';
  return 'tixun-notes-$stamp.${format.extension}';
}

/// What the progress dialog reports back to the screen.
class StudyExportOutcome {
  const StudyExportOutcome({
    this.savedName,
    this.cancelled = false,
    this.failed = false,
  });
  final String? savedName;
  final bool cancelled;
  final bool failed;
}

/// Runs the whole export behind a blocking progress dialog and reports the
/// outcome through the snackbar. Returns true when a file was written.
///
/// The work happens inside [StudyExportProgressDialog] so the dialog owns its
/// own lifetime: a cancelled picker, a failure or a success all leave exactly
/// one dialog to close.
Future<bool> exportStudySelection(
  BuildContext context, {
  required StudyStore store,
  required List<String> ids,
  required StudyExportFormat format,
  required bool includeImages,
}) async {
  if (ids.isEmpty) return false;
  final l10n = context.l10n;
  final String Function(String subject) subjectName = context.subjectName;
  final messenger = ScaffoldMessenger.of(context);
  final now = DateTime.now();
  final outcome = await showDialog<StudyExportOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => StudyExportProgressDialog(
      message: l10n.exportGenerating,
      run: () async {
        final service = StudyExportService(store);
        final bundle = await service.load(
          ids: ids,
          title: l10n.exportDocumentTitle,
          generatedAt: now,
          includeImages: includeImages,
        );
        if (bundle.isEmpty) return const StudyExportOutcome(cancelled: true);
        final bytes = await service.render(
          bundle,
          format,
          chrome: studyExportChrome(
            l10n: l10n,
            subjectName: subjectName,
            bundle: bundle,
          ),
          includeImages: includeImages,
        );
        final name = exportFileName(now, format);
        final saved = await service.save(
          bytes,
          fileName: name,
          format: format,
          label: l10n.exportDocumentTitle,
        );
        return saved
            ? StudyExportOutcome(savedName: name)
            : const StudyExportOutcome(cancelled: true);
      },
    ),
  );
  if (outcome == null) return false;
  if (outcome.failed) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    return false;
  }
  final saved = outcome.savedName;
  if (saved == null) return false;
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.exportSaved(l10nArgument(saved)))),
  );
  return true;
}

/// A dialog that cannot be dismissed while the file is being written.
class StudyExportProgressDialog extends StatefulWidget {
  const StudyExportProgressDialog({
    required this.message,
    required this.run,
    super.key,
  });

  final String message;
  final Future<StudyExportOutcome> Function() run;

  @override
  State<StudyExportProgressDialog> createState() =>
      _StudyExportProgressDialogState();
}

class _StudyExportProgressDialogState extends State<StudyExportProgressDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    StudyExportOutcome outcome;
    try {
      outcome = await widget.run();
    } on Object {
      outcome = const StudyExportOutcome(failed: true);
    }
    if (mounted) Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      content: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(widget.message)),
        ],
      ),
    ),
  );
}
