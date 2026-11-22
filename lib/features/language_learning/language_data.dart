import "package:material_ui/material_ui.dart";

import "../../core/l10n/app_strings.dart";

/// Retries only the failed read; surrounding form and navigation state survive.
class LanguageDataBuilder<T> extends StatefulWidget {
  const LanguageDataBuilder({
    super.key,
    required this.load,
    required this.builder,
  });

  final Stream<T> Function() load;
  final Widget Function(BuildContext, T) builder;

  @override
  State<LanguageDataBuilder<T>> createState() => _LanguageDataBuilderState<T>();
}

class _LanguageDataBuilderState<T> extends State<LanguageDataBuilder<T>> {
  late Stream<T> _source = _load();

  Stream<T> _load() {
    try {
      return widget.load();
    } catch (error, stack) {
      return Stream<T>.error(error, stack);
    }
  }

  @override
  void didUpdateWidget(covariant LanguageDataBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.load != widget.load) _source = _load();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _source,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.couldNotCompleteTheAction),
            TextButton.icon(
              onPressed: () => setState(() => _source = _load()),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        );
      }
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return widget.builder(context, snapshot.data as T);
    },
  );
}
