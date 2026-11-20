import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";

import "../../../core/database/database.dart";
import "../../../core/l10n/app_strings.dart";
import "../../../core/ui/learning_markdown.dart";
import "../language_store.dart";
import "quick_models.dart";
import "quick_store.dart";

class QuickResult extends StatelessWidget {
  const QuickResult({
    required this.row,
    required this.onVocabulary,
    required this.onSentence,
    required this.onDiscuss,
    required this.onRegenerate,
    required this.onDelete,
    super.key,
  });

  final LanguageQuickLookup row;
  final ValueChanged<List<VocabularyEntry>> onVocabulary;
  final ValueChanged<QuickSentence?> onSentence;
  final VoidCallback? onDiscuss, onRegenerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidates = QuickCandidates.fromLookup(row);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [row.actionName, row.provider, row.model].join(" · "),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          LearningMarkdown(row.content),
          const SizedBox(height: 8),
          if (row.targetLanguage != "en") Text(l10n.quickEnglishStudyOnly),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (candidates.vocabulary.isNotEmpty &&
                  row.targetLanguage == "en")
                TextButton(
                  onPressed: () => onVocabulary(candidates.vocabulary),
                  child: Text(l10n.quickAddVocabulary),
                ),
              if (candidates.sentence != null && row.targetLanguage == "en")
                TextButton(
                  onPressed: () => onSentence(candidates.sentence),
                  child: Text(l10n.quickAddSentence),
                ),
              TextButton(onPressed: onDiscuss, child: Text(l10n.quickDiscuss)),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case "copy":
                      await Clipboard.setData(ClipboardData(text: row.content));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.quickCopied)),
                        );
                      }
                    case "vocabulary":
                      onVocabulary(candidates.vocabulary);
                    case "sentence":
                      onSentence(candidates.sentence);
                    case "retry":
                      onRegenerate?.call();
                    case "delete":
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: "copy", child: Text(l10n.quickCopy)),
                  if (candidates.vocabulary.isEmpty &&
                      row.targetLanguage == "en")
                    PopupMenuItem(
                      value: "vocabulary",
                      child: Text(l10n.quickAddVocabulary),
                    ),
                  if (candidates.sentence == null && row.targetLanguage == "en")
                    PopupMenuItem(
                      value: "sentence",
                      child: Text(l10n.quickAddSentence),
                    ),
                  PopupMenuItem(
                    value: "retry",
                    enabled: onRegenerate != null,
                    child: Text(l10n.quickRegenerate),
                  ),
                  PopupMenuItem(value: "delete", child: Text(l10n.delete)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickHistoryTile extends StatelessWidget {
  const QuickHistoryTile({
    required this.row,
    required this.detail,
    required this.answer,
    required this.onToggle,
    super.key,
  });

  final QuickHistoryRow row;
  final Future<LanguageQuickLookup?>? detail;
  final Widget Function(LanguageQuickLookup) answer;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(row.input, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            row.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Icon(
            detail == null ? Icons.expand_more : Icons.expand_less,
          ),
          onTap: onToggle,
        ),
        if (detail != null)
          FutureBuilder(
            future: detail,
            builder: (context, snapshot) {
              if (snapshot.data case final lookup?) return answer(lookup);
              if (snapshot.connectionState == ConnectionState.done) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(context.l10n.couldNotCompleteTheAction),
                );
              }
              return const LinearProgressIndicator();
            },
          ),
      ],
    ),
  );
}
