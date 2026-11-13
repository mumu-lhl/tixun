import 'package:tixun/core/l10n/app_error.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import 'study_store.dart';

Future<void> startAiStudyWriting(
  BuildContext context,
  WidgetRef ref, {
  ChatMessage? source,
  KnowledgeItem? knowledge,
  bool mistake = false,
}) async {
  final c = ref.read(appControllerProvider);
  if (c.busy) {
    throw const AppFormatException(
      AppErrorCode.stopGenerationBeforeOrganizingMaterial,
      '请先停止生成，再整理资料。',
    );
  }
  final title = knowledge != null
      ? source == null
            ? context.l10n.editKnowledgeWithAI
            : context.l10n.mergeIntoExistingKnowledgeWith
      : mistake
      ? context.l10n.organizeAsAMistakeWith
      : context.l10n.createKnowledgeWithAI;
  final instruction = await showDialog<String>(
    context: context,
    builder: (_) => _WritingRequest(
      title: title,
      target: knowledge?.title,
      requiredInput: source == null,
      initial: knowledge != null && source == null
          ? context.l10n.improveTheStructurePreserveThe
          : '',
    ),
  );
  if (instruction == null || !context.mounted) return;
  final prompt = await c.prepareStudyWriting(
    sourceMessageId: source?.id,
    knowledgeId: knowledge?.id,
    mistake: mistake,
    instruction: instruction,
  );
  if (!context.mounted) return; // The prepared draft remains available.
  context.go('/chat');
  await c.send(prompt);
}

class _WritingRequest extends StatefulWidget {
  const _WritingRequest({
    required this.title,
    required this.requiredInput,
    required this.initial,
    this.target,
  });
  final String title, initial;
  final String? target;
  final bool requiredInput;
  @override
  State<_WritingRequest> createState() => _WritingRequestState();
}

class _WritingRequestState extends State<_WritingRequest> {
  late final input = TextEditingController(text: widget.initial);
  String? error;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.target != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(widget.target!),
            ),
          TextField(
            key: const Key('ai-study-instruction'),
            controller: input,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: (widget.requiredInput
                  ? context.l10n.whatWouldYouLikeToCreateOrChange
                  : context.l10n.instructionsOptional),
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.useTheCurrentModelIn,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('start-ai-study-writing'),
        onPressed: () {
          if (widget.requiredInput && input.text.trim().isEmpty) {
            setState(() => error = context.l10n.describeWhatYouWantTo);
            return;
          }
          Navigator.pop(context, input.text.trim());
        },
        child: Text(context.l10n.startOrganizing),
      ),
    ],
  );
}

Future<KnowledgeItem?> pickKnowledgeForAi(
  BuildContext context,
  StudyStore store,
) => showDialog<KnowledgeItem>(
  context: context,
  builder: (_) => _KnowledgePicker(store),
);

class _KnowledgePicker extends StatefulWidget {
  const _KnowledgePicker(this.store);
  final StudyStore store;
  @override
  State<_KnowledgePicker> createState() => _KnowledgePickerState();
}

class _KnowledgePickerState extends State<_KnowledgePicker> {
  late Future<List<KnowledgeItem>> items = widget.store.searchKnowledge(
    limit: 100,
  );
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 540,
      height: 560,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.selectKnowledgeToMergeInto,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const CloseButton(),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('ai-knowledge-target-search'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.searchKnowledgeOrSelectA,
              ),
              onChanged: (q) => setState(
                () => items = widget.store.searchKnowledge(
                  query: q.trim(),
                  limit: 100,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<KnowledgeItem>>(
                future: items,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(context.l10n.couldNotLoadKnowledgeReopen),
                    );
                  }
                  if (snap.data!.isEmpty) {
                    return Center(
                      child: Text(context.l10n.noMatchingKnowledge),
                    );
                  }
                  return ListView.builder(
                    itemCount: snap.data!.length,
                    itemBuilder: (_, i) {
                      final k = snap.data![i];
                      return ListTile(
                        key: ValueKey('ai-knowledge-target-${k.id}'),
                        title: Text(
                          k.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(context.subjectName(k.subject)),
                        onTap: () => Navigator.pop(context, k),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
