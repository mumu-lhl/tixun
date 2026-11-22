import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_ui/material_ui.dart";

import "../../app/controller.dart";
import "../../core/ai/token_breakdown.dart";
import "../../core/ai/token_estimator.dart";

/// Local visible-text count; excludes request framing and provider billing.
class PromptTokenCount extends ConsumerStatefulWidget {
  const PromptTokenCount(this.text, {super.key});
  final String text;

  @override
  ConsumerState<PromptTokenCount> createState() => _PromptTokenCountState();
}

class _PromptTokenCountState extends ConsumerState<PromptTokenCount> {
  (String, String, String, String)? _request;
  Future<int?>? _count;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appControllerProvider.select((c) => c.config));
    final request = (config.kind, config.model, config.baseUrl, widget.text);
    if (_request != request) {
      _request = request;
      // Coalesce typing before loading vocabularies in a worker.
      _count = Future<void>.delayed(const Duration(milliseconds: 250))
          .then((_) {
            if (!mounted || _request != request) return null;
            return countPromptTokens(
              provider: request.$1,
              model: request.$2,
              endpoint: request.$3,
              text: request.$4,
            );
          });
    }
    return FutureBuilder<int?>(
      key: ValueKey(request),
      future: _count,
      builder: (context, snapshot) => Text(
        "${config.model} · ≈${snapshot.data ?? estimateTokens(widget.text)} tokens",
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
