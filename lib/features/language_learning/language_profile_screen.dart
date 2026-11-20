import "package:material_ui/material_ui.dart";

import "language_layout.dart";
import "../../core/l10n/app_strings.dart";
import "../../core/ui/app_menu.dart";
import "../../core/l10n/generated/app_localizations.dart";
import "language_profile_store.dart";
import "language_skills.dart";
import "language_store.dart";
import "sentence_content.dart";
import "sentence_practice.dart" show sentenceSkillLabel;

SentenceSkill? sentenceSkillForAbility(LanguageSkill skill) => SentenceSkill
    .values
    .where((value) => sentenceAbility(value) == skill)
    .firstOrNull;

String languageSkillLabel(AppLocalizations l10n, LanguageSkill skill) {
  final sentence = sentenceSkillForAbility(skill);
  if (sentence != null) return sentenceSkillLabel(l10n, sentence);
  return switch (skill) {
    LanguageSkill.wordRecognition => l10n.languageWordRecognition,
    LanguageSkill.wordRecall => l10n.languageReview,
    LanguageSkill.formRecognition => l10n.languageFormRecognition,
    LanguageSkill.formProduction => l10n.languageFormProduction,
    LanguageSkill.wordApplication => l10n.languageNewContexts,
    LanguageSkill.reading => l10n.languageReading,
    LanguageSkill.insertion => l10n.languageSentenceInsertion,
    LanguageSkill.cloze => l10n.languageCloze,
    LanguageSkill.grammar => l10n.languageGrammarGap,
    LanguageSkill.writingTask => l10n.languageWriting,
    LanguageSkill.writingOrganization => l10n.languageWritingOrganizationSkill,
    LanguageSkill.writingAccuracy => l10n.languageWritingAccuracySkill,
    _ => skill.name,
  };
}

String _evidenceLabel(AppLocalizations l10n, EvidenceKind kind) =>
    switch (kind) {
      EvidenceKind.independent => l10n.languageEvidenceIndependent,
      EvidenceKind.assisted => l10n.languageEvidenceAssisted,
      EvidenceKind.repeat => l10n.languageEvidenceRepeat,
      EvidenceKind.selfReport => l10n.languageEvidenceSelf,
      EvidenceKind.unverified => l10n.languageEvidenceUnverified,
      EvidenceKind.disputed => l10n.languageEvidenceDisputed,
    };

class LanguageProfileScreen extends StatefulWidget {
  const LanguageProfileScreen({
    super.key,
    required this.store,
    required this.language,
    required this.onPractice,
    required this.onReview,
    this.goal = LanguageGoal.communication,
  });

  final LanguageLearningStore store;
  final String language;
  final void Function(LanguageProfile, LanguageRecommendation, LanguageGoal)
  onPractice;
  final VoidCallback onReview;
  final LanguageGoal goal;

  @override
  State<LanguageProfileScreen> createState() => _LanguageProfileScreenState();
}

class _LanguageProfileScreenState extends State<LanguageProfileScreen> {
  late final _source = widget.store.languageProfile(widget.language);
  late LanguageGoal _goal = widget.goal;
  SentenceLevel? _level;
  final _skip = <LanguageSkill>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.languageProfile)),
      body: StreamBuilder<LanguageProfile>(
        stream: _source,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(l10n.couldNotCompleteTheAction));
          }
          final profile = snapshot.data;
          if (profile == null) return const LinearProgressIndicator();
          final plan = recommendLanguage(
            profile,
            _goal,
            difficulty: _level,
            skip: _skip,
          );
          final evidence = profile.skills[plan.skill]!;
          final fieldWidth = MediaQuery.sizeOf(context).width < 570
              ? double.infinity
              : 290.0;
          final LanguageRecommendation? transfer =
              _goal == LanguageGoal.communication &&
                  profile.hasApplications &&
                  plan.skill != LanguageSkill.wordApplication &&
                  evidence.observations.isNotEmpty
              ? (
                  skill: LanguageSkill.wordApplication,
                  level: plan.level,
                  count: plan.count,
                  diagnostic: false,
                )
              : null;
          final practiced = profile.skills.values
              .where((row) => row.independent > 0 || row.tentative > 0)
              .length;
          final challenge =
              _goal == LanguageGoal.communication &&
                  practiced >= 2 &&
                  !plan.diagnostic
              ? recommendLanguage(
                  profile,
                  LanguageGoal.communication,
                  difficulty: _level,
                  skip: {..._skip, plan.skill, LanguageSkill.wordApplication},
                )
              : null;

          return languagePage(
            children: [
              Wrap(
                runSpacing: 10,
                spacing: 16,
                children: [
                  if (profile.language == "en")
                    SizedBox(
                      width: fieldWidth,
                      child: AppSelectField<LanguageGoal>(
                        initialValue: _goal,
                        decoration: InputDecoration(
                          labelText: l10n.languageGoal,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: LanguageGoal.communication,
                            child: Text(l10n.languageGoalCommunication),
                          ),
                          DropdownMenuItem(
                            value: LanguageGoal.exam,
                            child: Text(l10n.languageExamSkills),
                          ),
                          DropdownMenuItem(
                            value: LanguageGoal.foundations,
                            child: Text(l10n.languageFoundations),
                          ),
                        ],
                        onChanged: (value) => setState(() {
                          _goal = value!;
                          _skip.clear();
                        }),
                      ),
                    ),
                  SizedBox(
                    width: fieldWidth,
                    child: AppSelectField<SentenceLevel>(
                      initialValue: _level,
                      decoration: InputDecoration(
                        labelText: l10n.languageExamLevel,
                      ),
                      items: [
                        DropdownMenuItem(
                          child: Text(l10n.languageProfileAdaptive),
                        ),
                        DropdownMenuItem(
                          value: SentenceLevel.beginner,
                          child: Text(l10n.languageBeginner),
                        ),
                        DropdownMenuItem(
                          value: SentenceLevel.intermediate,
                          child: Text(l10n.languageIntermediate),
                        ),
                      ],
                      onChanged: (value) => setState(() => _level = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_goal == LanguageGoal.exam) Text(l10n.languageExamProfile),
              if (profile.due > 0)
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.languageNextReview),
                  subtitle: Text(l10n.languageDue(profile.due)),
                  onTap: widget.onReview,
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates_outlined),
                  title: Text(
                    l10n.languageNextSkill(
                      languageSkillLabel(l10n, plan.skill),
                    ),
                  ),
                  subtitle: Text(
                    evidence.preliminaryWeak && evidence.uncertain
                        ? l10n.languageTentativeWeakness
                        : plan.diagnostic
                        ? l10n.languageSentenceDiagnostic
                        : l10n.languageNextSkillReason(
                            evidence.correct,
                            evidence.independent,
                          ),
                  ),
                  onTap: () => widget.onPractice(profile, plan, _goal),
                  trailing: IconButton(
                    tooltip: l10n.languageSkip,
                    onPressed: () => setState(() {
                      if (!_skip.add(plan.skill)) _skip.clear();
                    }),
                    icon: const Icon(Icons.skip_next),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (transfer != null)
                ListTile(
                  leading: const Icon(Icons.compare_arrows_outlined),
                  title: Text(l10n.languageTransferPractice),
                  subtitle: Text(l10n.languageNewContexts),
                  onTap: () => widget.onPractice(profile, transfer, _goal),
                ),
              if (challenge != null &&
                  challenge.skill != plan.skill &&
                  challenge.skill != transfer?.skill)
                ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: Text(l10n.languageNewChallenge),
                  subtitle: Text(languageSkillLabel(l10n, challenge.skill)),
                  onTap: () => widget.onPractice(profile, challenge, _goal),
                ),
              for (final row in profile.skills.values) _SkillEvidence(row: row),
            ],
          );
        },
      ),
    );
  }
}

class _SkillEvidence extends StatelessWidget {
  const _SkillEvidence({required this.row});
  final SkillPerformance row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpansionTile(
      key: ValueKey(row.skill),
      title: Text(languageSkillLabel(l10n, row.skill)),
      subtitle: Text(
        row.uncertain
            ? l10n.languageEvidenceInsufficient(row.observations.length)
            : l10n.languageEvidenceReliable(row.correct, row.independent),
      ),
      children: [
        if (row.observations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kind in EvidenceKind.values)
                  if (row.count(kind) > 0)
                    Text(
                      [_evidenceLabel(l10n, kind), row.count(kind)].join(" "),
                    ),
              ],
            ),
          ),
        for (final entry in row.observations.take(6))
          ListTile(
            title: Text(
              entry.basis,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                _evidenceLabel(l10n, entry.kind),
                if (!entry.verified && entry.kind != EvidenceKind.unverified)
                  l10n.languageEvidenceUnverified,
                if (entry.correct != null)
                  entry.correct!
                      ? l10n.languageCorrect
                      : l10n.languageIncorrect,
              ].join(" · "),
            ),
          ),
      ],
    );
  }
}
