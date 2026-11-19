import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'exam_ai.dart';
import 'exam_labels.dart';
import 'exam_material.dart';
import 'exam_paper_screen.dart';
import 'exam_store.dart';
import 'sentence_content.dart';
import 'sentence_practice.dart';

class ExamLab extends StatefulWidget {
  const ExamLab({
    super.key,
    required this.ai,
    required this.kind,
    this.glossLanguage,
  });

  final ExamAi ai;
  final ExamKind kind;
  final String? glossLanguage;

  @override
  State<ExamLab> createState() => _ExamLabState();
}

class _ExamLabState extends State<ExamLab> {
  late final _library = widget.ai.store.examLibrary(widget.kind);
  CancelToken? _request;
  bool _opening = false;

  @override
  void dispose() {
    _request?.cancel();
    super.dispose();
  }

  Future<void> _open(ExamMaterial material) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ExamPaperScreen(
        ai: widget.ai,
        material: material,
        glossLanguage: widget.glossLanguage,
      ),
    ),
  );

  Future<void> _generate() async {
    if (_request != null || _opening) return;
    setState(() => _opening = true);
    SentenceSkill? focus;
    await act(context, () async {
      focus = await widget.ai.store.recommendedExamSkill(widget.kind);
    });
    if (!mounted) return;
    final options = await showDialog<({ExamTarget target, bool reuse})>(
      context: context,
      builder: (_) => _ExamSettings(kind: widget.kind, focus: focus),
    );
    if (!mounted) return;
    setState(() => _opening = false);
    if (options == null) return;
    final request = CancelToken();
    final gloss =
        widget.glossLanguage ?? Localizations.localeOf(context).languageCode;
    setState(() => _request = request);
    try {
      final material = await widget.ai.acquire(
        options.target,
        glossLanguage: gloss,
        cancel: request,
        reuse: options.reuse,
      );
      if (mounted && !request.isCancelled) await _open(material);
    } catch (error) {
      if (mounted && !request.isCancelled) {
        await act(context, () => Future<void>.error(error));
      }
    } finally {
      if (mounted) setState(() => _request = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _request != null || _opening;
    return Scaffold(
      appBar: AppBar(title: Text(examKindLabel(l10n, widget.kind))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(l10n.languageExamPracticeIntro),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : _generate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(l10n.languageExamPrepare),
          ),
          if (_request != null) ...[
            const LinearProgressIndicator(),
            TextButton(
              onPressed: () => _request?.cancel(),
              child: Text(l10n.cancel),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            l10n.languageExamLibrary,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          StreamBuilder<List<LearningExamMaterialRow>>(
            stream: _library,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(l10n.couldNotCompleteTheAction);
              }
              final rows = snapshot.data;
              if (rows == null) return const LinearProgressIndicator();
              if (rows.isEmpty) return Text(l10n.languageExamLibraryEmpty);
              return Column(
                children: [
                  for (final row in rows)
                    Builder(
                      builder: (context) {
                        final material = ExamMaterial(row);
                        return ListTile(
                          title: Text(row.title),
                          subtitle: Text(examSourceLabel(l10n, material)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: busy ? null : () => _open(material),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExamSettings extends StatefulWidget {
  const _ExamSettings({required this.kind, this.focus});
  final ExamKind kind;
  final SentenceSkill? focus;

  @override
  State<_ExamSettings> createState() => _ExamSettingsState();
}

class _ExamSettingsState extends State<_ExamSettings> {
  final _topic = TextEditingController();
  SentenceLevel _level = SentenceLevel.intermediate;
  late SentenceSkill? _skill = widget.focus;
  late final _counts = ExamTarget(
    kind: widget.kind,
    level: _level,
    count: 5,
  ).counts;
  late int _count = _counts.contains(5) ? 5 : _counts.first;
  bool _reuse = true;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.languageExamPrepare),
      content: SizedBox(
        width: 450,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.languageExamProfile),
            Text(examKindLabel(l10n, widget.kind)),
            DropdownButtonFormField<SentenceLevel>(
              initialValue: _level,
              decoration: InputDecoration(labelText: l10n.languageExamLevel),
              items: [
                DropdownMenuItem(
                  value: SentenceLevel.beginner,
                  child: Text(l10n.languageBeginner),
                ),
                DropdownMenuItem(
                  value: SentenceLevel.intermediate,
                  child: Text(l10n.languageIntermediate),
                ),
              ],
              onChanged: (level) => setState(() => _level = level!),
            ),
            DropdownButtonFormField<int>(
              initialValue: _count,
              decoration: InputDecoration(labelText: l10n.languageExamCount),
              items: [
                for (final count in _counts)
                  DropdownMenuItem(value: count, child: Text('$count')),
              ],
              onChanged: (value) => setState(() => _count = value!),
            ),
            DropdownButtonFormField<SentenceSkill?>(
              initialValue: _skill,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.languageExamFocus),
              items: [
                DropdownMenuItem<SentenceSkill?>(
                  child: Text(l10n.languageExamAnySkill),
                ),
                for (final skill in SentenceSkill.values)
                  DropdownMenuItem(
                    value: skill,
                    child: Text(sentenceSkillLabel(l10n, skill)),
                  ),
              ],
              onChanged: (skill) => setState(() => _skill = skill),
            ),
            TextField(
              controller: _topic,
              maxLength: 100,
              decoration: InputDecoration(labelText: l10n.languageExamTopic),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _reuse,
              onChanged: (value) => setState(() => _reuse = value),
              title: Text(l10n.languageExamReuse),
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
          onPressed: () => Navigator.of(context).pop((
            target: ExamTarget(
              kind: widget.kind,
              level: _level,
              count: _count,
              topic: _topic.text.trim(),
              skill: _skill,
            ),
            reuse: _reuse,
          )),
          child: Text(l10n.languageExamPrepare),
        ),
      ],
    );
  }
}
