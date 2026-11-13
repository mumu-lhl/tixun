import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';
import 'learning_markdown.dart';

/// Only provider-returned text or public summaries belong here.
class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({
    required this.text,
    this.generating = false,
    this.locked = false,
    super.key,
  });
  final String text;
  final bool generating, locked;
  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            widget.locked ? Icons.lock_outline : Icons.psychology_outlined,
          ),
          title: Text(context.tr(widget.generating ? '思考中' : '模型思考')),
          trailing: widget.locked
              ? null
              : Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: widget.locked
              ? null
              : () => setState(() => expanded = !expanded),
        ),
        // Locked reasoning is never mounted, selected or exposed to semantics.
        if (expanded && !widget.locked)
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              child: widget.text.isEmpty
                  ? Text(context.tr('等待模型返回思考内容…'))
                  : LearningMarkdown(widget.text),
            ),
          ),
      ],
    ),
  );
}
