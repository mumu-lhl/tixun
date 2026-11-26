import "package:dio/dio.dart";
import "package:material_ui/material_ui.dart";

import "../../core/ai/chat_provider.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_error_localization.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/ui/actions.dart";
import "language_store.dart";
import "lexical_form_screen.dart" show inflectionLabel;
import "sentence_content.dart";
import "sentence_practice.dart" show sentenceSkillLabel;
import "vocabulary_ai.dart";
import "vocabulary_editor.dart";

Future<void> showVocabularyProposal(
  BuildContext context, {
  required LanguageLearningStore store,
  required VocabularyAi ai,
  required ProviderConfig config,
  LearningVocabularyGroup? group,
  VocabularyLevel initialLevel = VocabularyLevel.beginner,
  String? feedbackLanguage,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _ProposalDialog(store, ai, config, group, initialLevel, feedbackLanguage),
);

class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog(
    this.store,
    this.ai,
    this.config,
    this.group,
    this.initialLevel,
    this.feedbackLanguage,
  );

  final LanguageLearningStore store;
  final VocabularyAi ai;
  final ProviderConfig config;
  final LearningVocabularyGroup? group;
  final VocabularyLevel initialLevel;
  final String? feedbackLanguage;

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  late final _topic = TextEditingController(text: widget.group?.title);
  VocabularyGroupType _kind = VocabularyGroupType.topic;
  late VocabularyLevel _level = widget.initialLevel;
  int _count = 5;
  SentenceSkill? _focus;
  VocabularyProposal? _proposal;
  Map<VocabularyEntry, List<String>> _matches = {};
  final _chosen = <VocabularyEntry>{};
  final _entries = <VocabularyEntry>[];
  CancelToken? _running;
  bool _saving = false;
  bool _withAi = false;
  String? _error;
  String? _customTitle;

  String get _title =>
      widget.group?.title ??
      _customTitle ??
      _proposal?.groupTitle ??
      _topic.text.trim();
  VocabularyGroupType get _groupType => widget.group == null
      ? _kind
      : VocabularyGroupType.values.byName(widget.group!.groupType);

  @override
  void dispose() {
    _running?.cancel();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_running != null) return;
    final token = CancelToken();
    final gloss =
        widget.feedbackLanguage ??
        (Localizations.localeOf(context).languageCode == "zh" ? "zh" : "en");
    setState(() {
      _running = token;
      _error = null;
    });
    try {
      final group = widget.group;
      final current = group == null
          ? const <String>[]
          : await widget.store.groupExpressions(group.id);
      final trashed = await widget.store.trashedExpressions("en");
      token.checkCancelled();
      final proposal = await widget.ai.propose(
        config: widget.config,
        topic: group?.title ?? _topic.text.trim(),
        generateGroupTitle: group == null && _topic.text.trim().isEmpty,
        groupType: _groupType,
        level: _level,
        glossLanguage: gloss,
        existingExpressions: current,
        localExclusions: trashed,
        cancel: token,
        count: _count,
        focus: _focus,
      );
      token.checkCancelled();
      final matches = await widget.store.existingGroupsForEntries(
        "en",
        proposal.entries,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _proposal = proposal;
        _entries
          ..clear()
          ..addAll(proposal.entries);
        _chosen.clear();
        _matches = matches;
        _chosen.addAll(
          proposal.entries.where((entry) => !matches[entry]!.contains(_title)),
        );
      });
    } catch (error) {
      if (!mounted || token.isCancelled) return;
      final l10n = context.l10n;
      setState(
        () => _error = error is AiFailure
            ? failureText(l10n, error)
            : l10n.languageVocabularyGenerationFailed,
      );
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<bool> _resolveGroup() async {
    if (widget.group != null) return true;
    final existing = await widget.store.groupNamed("en", _title);
    if (existing == null) return true;
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.l10n.languageGroupExists),
            content: Text(existing.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.l10n.languageRenameGroup),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.l10n.languageUseExistingGroup),
              ),
            ],
          ),
        ) ==
        true;
  }

  Future<void> _saveEmpty() async {
    if (_saving) return;
    if (_title.isEmpty) {
      setState(() => _error = context.l10n.languageGroupNameRequired);
      return;
    }
    setState(() => _saving = true);
    await act(context, () async {
      final existing = await widget.store.groupNamed("en", _title);
      if (!mounted) return;
      if (existing != null) {
        setState(() => _error = context.l10n.languageGroupExists);
      } else {
        await widget.store.createGroup("en", _title, _groupType);
        if (mounted) Navigator.pop(context);
      }
    });
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _save() async {
    final proposal = _proposal;
    if (_saving || proposal == null || _chosen.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    await act(context, () async {
      if (!await _resolveGroup()) return;
      await widget.store.saveEntries(
        language: "en",
        groupTitle: _title,
        groupType: _groupType,
        entries: _entries.where(_chosen.contains).toList(),
        provenance: proposal.provenance,
      );
      if (mounted) Navigator.of(context).pop();
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final running = _running;
    final proposal = _proposal;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          proposal == null
              ? (widget.group == null
                    ? l10n.languageCreateGroup
                    : l10n.languageAiExpand)
              : l10n.languageAiPreview,
        ),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: proposal == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.group != null || _withAi)
                      Text(
                        widget.ai.provider is MockChatProvider
                            ? l10n.languageAiMockNotice
                            : l10n.languageAiPrivacyNotice,
                      ),
                    const SizedBox(height: 12),
                    if (widget.group == null) ...[
                      TextFormField(
                        controller: _topic,
                        enabled: running == null,
                        maxLength: 100,
                        decoration: InputDecoration(
                          labelText: _withAi
                              ? l10n.languageAiGroupTitle
                              : l10n.languageGroupTitle,
                          helperText: _withAi
                              ? l10n.languageAiGroupTitleHint
                              : null,
                        ),
                      ),
                      AppSelectField<VocabularyGroupType>(
                        initialValue: _kind,
                        decoration: InputDecoration(
                          labelText: l10n.languageGroupType,
                        ),
                        items: [
                          for (final kind in VocabularyGroupType.values)
                            DropdownMenuItem(
                              value: kind,
                              child: Text(vocabularyGroupLabel(l10n, kind)),
                            ),
                        ],
                        onChanged: running != null
                            ? null
                            : (kind) => _kind = kind!,
                      ),
                    ] else
                      Text(_title),
                    if (widget.group == null)
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.languageFillWithAi),
                        value: _withAi,
                        onChanged: running == null
                            ? (value) => setState(() => _withAi = value)
                            : null,
                      ),
                    if (widget.group != null || _withAi) ...[
                      AppSelectField<VocabularyLevel>(
                        initialValue: _level,
                        decoration: InputDecoration(
                          labelText: l10n.languageDifficulty,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: VocabularyLevel.beginner,
                            child: Text(l10n.languageBeginner),
                          ),
                          DropdownMenuItem(
                            value: VocabularyLevel.intermediate,
                            child: Text(l10n.languageIntermediate),
                          ),
                          DropdownMenuItem(
                            value: VocabularyLevel.advanced,
                            child: Text(l10n.languageAdvanced),
                          ),
                        ],
                        onChanged: running != null
                            ? null
                            : (level) => _level = level!,
                      ),
                      AppSelectField<int>(
                        initialValue: _count,
                        decoration: InputDecoration(
                          labelText: l10n.languageVocabularyCount,
                        ),
                        items: [
                          for (final count in [5, 10, 20])
                            DropdownMenuItem(
                              value: count,
                              child: Text("$count"),
                            ),
                        ],
                        onChanged: running == null
                            ? (count) => _count = count!
                            : null,
                      ),
                      AppSelectField<SentenceSkill>(
                        decoration: InputDecoration(
                          labelText: l10n.languageExamFocus,
                        ),
                        items: [
                          DropdownMenuItem(
                            child: Text(l10n.languageExamAnySkill),
                          ),
                          for (final skill in const [
                            SentenceSkill.collocation,
                            SentenceSkill.intention,
                            SentenceSkill.reference,
                          ])
                            DropdownMenuItem(
                              value: skill,
                              child: Text(sentenceSkillLabel(l10n, skill)),
                            ),
                        ],
                        onChanged: running == null
                            ? (focus) => _focus = focus
                            : null,
                      ),
                    ],
                    if (running != null) const LinearProgressIndicator(),
                    if (_error case final error?) Text(error),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(l10n.languageAiReviewNotice),
                    Text(proposal.provenance.model),
                    if (_error case final error?) Text(error),
                    if (proposal.entries.length < (proposal.requested ?? 0))
                      Text(
                        l10n.languageSentencePartialBatch(
                          proposal.entries.length,
                          proposal.requested!,
                        ),
                      ),
                    for (final entry in _entries) _candidate(entry),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          if (proposal == null)
            FilledButton(
              onPressed: running != null || _saving
                  ? null
                  : (widget.group == null && !_withAi ? _saveEmpty : _generate),
              child: Text(
                widget.group == null && !_withAi
                    ? l10n.create
                    : l10n.languageFillWithAi,
              ),
            )
          else ...[
            TextButton(
              onPressed: _saving || running != null ? null : _generate,
              child: Text(l10n.regenerate),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      final title = await editText(
                        context,
                        title: l10n.languageRenameGroup,
                        initial: _title,
                      );
                      if (mounted && title != null && title.trim().isNotEmpty) {
                        setState(() => _customTitle = title.trim());
                      }
                    },
              child: Text(l10n.languageRenameGroup),
            ),
            FilledButton(
              onPressed: _saving || _chosen.isEmpty ? null : _save,
              child: Text(l10n.languageAiSaveSelected),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _edit(VocabularyEntry entry) async {
    final edited = await editVocabularyCandidate(context, entry);
    if (!mounted || edited == null) return;
    setState(() => _saving = true);
    await act(context, () async {
      final same = _entries.any(
        (other) =>
            !identical(other, entry) &&
            other.type == edited.type &&
            normalizeLanguageText(other.form) ==
                normalizeLanguageText(edited.form) &&
            normalizeLanguageText(other.meaning) ==
                normalizeLanguageText(edited.meaning),
      );
      if (same) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.languageVocabularyDuplicateCandidate),
          ),
        );
        return;
      }
      final trashed = await widget.store.trashedExpressions("en");
      if (!mounted) return;
      if (trashed.contains(normalizeLanguageText(edited.form))) {
        setState(() => _error = context.l10n.languageWordInTrash);
        return;
      }
      final matches = await widget.store.existingGroupsForEntries("en", [
        edited,
      ]);
      if (!mounted) return;
      setState(() {
        _error = null;
        _entries[_entries.indexOf(entry)] = edited;
        _matches.remove(entry);
        _matches.addAll(matches);
        if (_chosen.remove(entry) && !matches[edited]!.contains(_title)) {
          _chosen.add(edited);
        }
      });
    });
    if (mounted) setState(() => _saving = false);
  }

  Widget _candidate(VocabularyEntry entry) {
    final l10n = context.l10n;
    final groups = _matches[entry]!;
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            value: _chosen.contains(entry),
            onChanged: _saving || groups.contains(_title)
                ? null
                : (chosen) => setState(() {
                    if (chosen == true) {
                      _chosen.add(entry);
                    } else {
                      _chosen.remove(entry);
                    }
                  }),
            title: Text("${entry.form} — ${entry.meaning}"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lexicalTypeLabel(l10n, entry.type)),
                if (entry.partOfSpeech case final partOfSpeech?)
                  Text(partOfSpeech),
                if (entry.example case final example?) Text(example),
                if (entry.translation case final translation?)
                  Text(translation),
                if (entry.application case final application?)
                  Text("$application → ${entry.applicationAnswer}"),
                for (final form in entry.forms)
                  Text(
                    "${inflectionLabel(l10n, form.inflection)}: ${form.surface}",
                  ),
                if (groups.isNotEmpty)
                  Text(l10n.languageAiExistingGroups(groups.join(", "))),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: _saving ? null : () => _edit(entry),
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.edit,
        ),
      ],
    );
  }
}
