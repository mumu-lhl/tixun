import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/ai/chat_provider.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_error_localization.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'language_store.dart';
import 'vocabulary_ai.dart';
import 'vocabulary_editor.dart';

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
  final _form = GlobalKey<FormState>();
  late final _topic = TextEditingController(text: widget.group?.title);
  VocabularyGroupType _kind = VocabularyGroupType.topic;
  late VocabularyLevel _level = widget.initialLevel;
  VocabularyProposal? _proposal;
  Map<VocabularyEntry, List<String>> _matches = {};
  final _chosen = <VocabularyEntry>{};
  CancelToken? _running;
  bool _saving = false;
  String? _error;

  String get _title => widget.group?.title ?? _topic.text.trim();
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
    if (_running != null || !_form.currentState!.validate()) return;
    final token = CancelToken();
    final gloss =
        widget.feedbackLanguage ??
        (Localizations.localeOf(context).languageCode == 'zh' ? 'zh' : 'en');
    setState(() {
      _running = token;
      _error = null;
    });
    try {
      final group = widget.group;
      final current = group == null
          ? const <LanguageCard>[]
          : await widget.store.cards(language: 'en', groupId: group.id);
      token.checkCancelled();
      final proposal = await widget.ai.propose(
        config: widget.config,
        topic: _title,
        groupType: _groupType,
        level: _level,
        glossLanguage: gloss,
        existingExpressions: current
            .map((card) => card.item.form)
            .toSet()
            .toList(),
        cancel: token,
      );
      token.checkCancelled();
      final matches = await widget.store.existingGroupsForEntries(
        'en',
        proposal.entries,
      );
      if (!mounted || token.isCancelled) return;
      setState(() {
        _proposal = proposal;
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

  Future<void> _save() async {
    final proposal = _proposal;
    if (_saving || proposal == null || _chosen.isEmpty) return;
    setState(() => _saving = true);
    await act(context, () async {
      await widget.store.saveEntries(
        language: 'en',
        groupTitle: _title,
        groupType: _groupType,
        entries: proposal.entries.where(_chosen.contains).toList(),
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
          proposal == null ? l10n.languageAiGenerate : l10n.languageAiPreview,
        ),
        scrollable: true,
        content: SizedBox(
          width: 480,
          child: proposal == null
              ? Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? l10n.languageRequired
                              : null,
                          decoration: InputDecoration(
                            labelText: l10n.languageGroupTitle,
                          ),
                        ),
                        DropdownButtonFormField<VocabularyGroupType>(
                          initialValue: _kind,
                          isExpanded: true,
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
                      DropdownButtonFormField<VocabularyLevel>(
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
                      if (running != null) const LinearProgressIndicator(),
                      if (_error case final error?) Text(error),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(l10n.languageAiReviewNotice),
                    Text(proposal.provenance.model),
                    for (final entry in proposal.entries) _candidate(entry),
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
              onPressed: running == null ? _generate : null,
              child: Text(l10n.languageAiGenerate),
            )
          else
            FilledButton(
              onPressed: _saving || _chosen.isEmpty ? null : _save,
              child: Text(l10n.languageAiSaveSelected),
            ),
        ],
      ),
    );
  }

  Widget _candidate(VocabularyEntry entry) {
    final l10n = context.l10n;
    final groups = _matches[entry]!;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
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
      title: Text('${entry.form} — ${entry.meaning}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lexicalTypeLabel(l10n, entry.type)),
          Text(entry.example!),
          Text(entry.translation!),
          if (groups.isNotEmpty)
            Text(l10n.languageAiExistingGroups(groups.join(', '))),
        ],
      ),
    );
  }
}
