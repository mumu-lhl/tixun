part of "study_detail_screen.dart";

extension _StudyDetailSections on StudyDetailScreen {
  List<Widget> _materialSections(
    BuildContext context,
    KnowledgeDetail? k,
    MistakeDetail? m,
    bool deleted,
  ) {
    final colors = Theme.of(context).colorScheme;
    final images = k?.images ?? m!.images;
    return [
      if (k != null) ...[
        if (k.item.content.isEmpty)
          Text(
            context.l10n.noContentYetEditTo,
            style: TextStyle(color: colors.onSurfaceVariant),
          )
        else
          _panel(
            context,
            context.l10n.knowledgeContent,
            VisualMarkdown(k.item.content, knowledgeId: id),
          ),
        const SizedBox(height: 24),
        StudyImages(
          id: id,
          isMistake: false,
          images: images,
          editable: !deleted,
        ),
        const SizedBox(height: 24),
        StudyVisuals(
          knowledgeId: id,
          mistakeId: null,
          exclude: visualReferences(k.item.content),
          panelTitle: context.l10n.visualSection,
        ),
      ] else ...[
        _panel(
          context,
          context.l10n.originalQuestion,
          m!.item.question.isEmpty
              ? Text(
                  context.l10n.questionTextOptionalForImages,
                  style: TextStyle(color: colors.onSurfaceVariant),
                )
              : LearningMarkdown(m.item.question),
        ),
        const SizedBox(height: 8),
        StudyVisuals(knowledgeId: null, mistakeId: id, source: "original"),
        StudyImages(
          id: id,
          isMistake: true,
          images: images,
          editable: !deleted,
        ),
        const SizedBox(height: 24),
        if (m.item.originalAnswer.isNotEmpty)
          _section(
            context,
            context.l10n.myOriginalAnswer,
            m.item.originalAnswer,
          ),
        if (m.item.ownAnalysis.isNotEmpty)
          _section(
            context,
            context.l10n.myAnalysisAndThoughts,
            m.item.ownAnalysis,
          ),
        StudyVisuals(knowledgeId: null, mistakeId: id, source: "student"),
        _panel(
          context,
          context.l10n.errorCauses,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.item.errorReason),
              if (m.item.suggestedReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.aiSuggestionUnconfirmed(
                    l10nArgument((m.item.suggestedReason)),
                  ),
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(context.l10n.answerAndExplanation),
          subtitle: Text(
            context.l10n.tryIndependentlyBeforeOpeningThe,
            style: TextStyle(fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 20),
          children: [
            if (m.item.correctAnswer.isNotEmpty)
              _section(
                context,
                context.l10n.correctAnswer,
                m.item.correctAnswer,
              ),
            if (m.item.aiAnalysis.isNotEmpty)
              _section(
                context,
                context.l10n.aiExplanationCheckConclusion,
                m.item.aiAnalysis,
              ),
            StudyVisuals(knowledgeId: null, mistakeId: id, source: "ai"),
            if (m.item.correctAnswer.isEmpty && m.item.aiAnalysis.isEmpty)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(context.l10n.noAnswerOrExplanationYet),
              ),
          ],
        ),
      ],
    ];
  }

  List<Widget> _relatedMaterials(
    BuildContext context,
    WidgetRef ref,
    StudyStore store,
    KnowledgeDetail? k,
    MistakeDetail? m,
    bool deleted,
    int revision,
  ) {
    final colors = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 28),
      Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.linkedKnowledge,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (!deleted)
            TextButton.icon(
              onPressed: () => act(context, () => _link(context, ref)),
              icon: const Icon(Icons.add, size: 17),
              label: Text(context.l10n.link),
            ),
        ],
      ),
      for (final item in k?.related ?? m!.knowledge)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item.title),
          subtitle: Text(context.subjectName(item.subject)),
          trailing: IconButton(
            tooltip: context.l10n.unlink,
            onPressed: deleted
                ? null
                : () => act(
                    context,
                    () => store.link(
                      isMistake ? item.id : id,
                      mistakeId: isMistake ? id : null,
                      otherKnowledgeId: isMistake ? null : item.id,
                      remove: true,
                    ),
                  ),
            icon: const Icon(Icons.link_off),
          ),
          onTap: () => context.push("/knowledge/${item.id}"),
        ),
      if ((k?.related ?? m!.knowledge).isEmpty)
        Text(
          context.l10n.noLinkedKnowledgeYet,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      if (k != null) ...[
        const SizedBox(height: 24),
        Text(
          context.l10n.linkedMistakes,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final item in k.mistakes)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title),
            subtitle: Text(context.subjectName(item.subject)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push("/mistakes/${item.id}"),
          ),
        if (k.mistakes.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(context.l10n.linkThisKnowledgeFromA),
          ),
      ],
      const SizedBox(height: 28),
      Text(
        context.l10n.versionStoredOnThisDevice(l10nArgument((revision))),
        style: TextStyle(
          fontSize: 11,
          color: colors.onSurfaceVariant,
          height: 1.8,
        ),
      ),
    ];
  }
}
