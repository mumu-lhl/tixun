import 'package:material_ui/material_ui.dart';

import '../../core/export/study_export.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/generated/app_localizations.dart';

class StudyExportChoice {
  const StudyExportChoice({required this.format, required this.includeImages});
  final StudyExportFormat format;
  final bool includeImages;
}

/// Asks which printable format to produce. Markdown cannot carry the
/// attachments, so the image switch is disabled for it instead of pretending to
/// include them.
Future<StudyExportChoice?> showStudyExportDialog(BuildContext context) =>
    showDialog<StudyExportChoice>(
      context: context,
      builder: (_) => const StudyExportDialog(),
    );

class StudyExportDialog extends StatefulWidget {
  const StudyExportDialog({super.key});
  @override
  State<StudyExportDialog> createState() => _StudyExportDialogState();
}

class _StudyExportDialogState extends State<StudyExportDialog> {
  StudyExportFormat _format = StudyExportFormat.pdf;
  bool _includeImages = true;

  String _label(AppLocalizations l10n, StudyExportFormat format) =>
      switch (format) {
        StudyExportFormat.pdf => l10n.exportFormatPdf,
        StudyExportFormat.docx => l10n.exportFormatDocx,
        StudyExportFormat.markdown => l10n.exportFormatMarkdown,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final canIncludeImages = _format != StudyExportFormat.markdown;
    return AlertDialog(
      title: Text(l10n.exportDialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.exportFormatLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final format in StudyExportFormat.values)
                  ChoiceChip(
                    key: Key('export-format-${format.name}'),
                    label: Text(_label(l10n, format)),
                    selected: _format == format,
                    onSelected: (_) => setState(() => _format = format),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('export-include-images'),
              value: canIncludeImages && _includeImages,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.exportIncludeImages),
              subtitle: canIncludeImages
                  ? null
                  : Text(
                      l10n.exportMarkdownWithoutImages,
                      style: theme.textTheme.bodySmall,
                    ),
              onChanged: canIncludeImages
                  ? (value) => setState(() => _includeImages = value)
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('export-confirm'),
          onPressed: () => Navigator.of(context).pop(
            StudyExportChoice(
              format: _format,
              includeImages: canIncludeImages && _includeImages,
            ),
          ),
          child: Text(l10n.exportGenerate),
        ),
      ],
    );
  }
}
