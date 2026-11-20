part of "exam_subject_screen.dart";

class ExamAiScreen extends ConsumerStatefulWidget {
  const ExamAiScreen({required this.subject, required this.images, super.key});
  final ExamSubject subject;
  final List<ExamAttachment> images;
  @override
  ConsumerState<ExamAiScreen> createState() => _ExamAiState();
}

class _ExamAiState extends ConsumerState<ExamAiScreen> {
  final selected = <String>{};
  final cancel = CancelToken();
  bool busy = false;
  String reasoning = "", effort = "";
  String? error;
  List<ScoreDraft>? proposal;
  @override
  void initState() {
    super.initState();
    selected.addAll(
      widget.images.where((i) => i.role != "paper").map((i) => i.id),
    );
  }

  @override
  void dispose() {
    cancel.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final config = AiOptions.forSession(c.config, effort);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.extractQuestionMarksWithAI)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(context.l10n.onlyTheSelectedPhotosWill),
          if (c.demo) Text(context.l10n.mockModeDoesNotGrade),
          if (!AiOptions(config).vision)
            Text(context.l10n.modelDoesNotSupportImages),
          AppSelectField<String>(
            initialValue: effort,
            decoration: InputDecoration(
              labelText: context.l10n.reasoningEffort,
            ),
            items: [
              for (final e in {
                "": context.l10n.useGlobalDefault,
                "off": reasoningOffLabel(
                  context,
                  AiOptions(c.config),
                  choice: true,
                ),
                for (final level in AiOptions(c.config).reasoningEfforts)
                  level: reasoningEffortLabel(
                    context,
                    AiOptions(c.config),
                    level,
                  ),
              }.entries)
                DropdownMenuItem(
                  value: e.key,
                  enabled:
                      e.key.isEmpty ||
                      e.key == "off" ||
                      c.config.supportsThinking,
                  child: Text(e.value),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => effort = v ?? ""),
          ),
          for (final image in widget.images)
            CheckboxListTile(
              value: selected.contains(image.id),
              title: Text(examImageRoleLabel(context, image.role)),
              secondary: Image.file(
                c.files.resolve(image.relativePath),
                width: 55,
                height: 55,
                fit: BoxFit.cover,
                cacheWidth: 150,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        selected.add(image.id);
                      } else {
                        selected.remove(image.id);
                      }
                    }),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                busy || c.demo || !AiOptions(config).vision || selected.isEmpty
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                      proposal = null;
                      reasoning = "";
                    });
                    try {
                      final rows = await generateExamScores(
                        provider: c.provider,
                        config: config,
                        files: c.files,
                        images: widget.images
                            .where((i) => selected.contains(i.id))
                            .toList(),
                        subject: widget.subject.subject,
                        prompt: c.prompts.text("exam_scores"),
                        cancel: cancel,
                        usageStore: AiUsageStore(c.db),
                        onReasoning: (value) {
                          if (mounted && value != reasoning) {
                            setState(() => reasoning = value);
                          }
                        },
                      );
                      if (mounted) {
                        await (c.db.update(
                          c.db.examSubjects,
                        )..where((t) => t.id.equals(widget.subject.id))).write(
                          ExamSubjectsCompanion(
                            aiReasoning: Value(reasoning),
                            aiModel: Value(config.model),
                          ),
                        );
                        if (mounted) {
                          setState(() {
                            proposal = rows;
                            busy = false;
                          });
                        }
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(() {
                          busy = false;
                          error =
                              context.l10n.aiExtractionFailedWithoutChanging;
                        });
                      }
                    }
                  },
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(context.l10n.uploadSelectedPhotosAndExtract),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
          if (busy)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.stopAndReturn),
            ),
          if (reasoning.isNotEmpty)
            ReasoningPanel(text: reasoning, generating: busy),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (proposal != null) ...[
            const SizedBox(height: 16),
            Text(context.l10n.extractionFinishedYourSavedMarks),
            for (final row in proposal!)
              ListTile(
                contentPadding: EdgeInsets.only(
                  left: row.parentId == null ? 0 : 20,
                ),
                title: Text(row.label),
                subtitle: row.note.isEmpty ? null : Text(row.note),
                trailing: Text(
                  "${points(row.earned)} / ${points(row.maximum)}",
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ScoreEditor(subject: widget.subject, proposal: proposal),
                ),
              ),
              child: Text(context.l10n.reviewAndEditMarks),
            ),
          ],
        ],
      ),
    );
  }
}
