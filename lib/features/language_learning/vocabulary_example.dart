import "package:material_ui/material_ui.dart";

import "../../core/database/database.dart";
import "language_store.dart";
import "lexical_form_store.dart";

TextSpan vocabularyExampleSpan(
  String text,
  Iterable<String> forms,
  TextStyle emphasis,
) {
  final alternatives =
      forms.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList()
        ..sort((a, b) => b.length.compareTo(a.length));
  if (alternatives.isEmpty) return TextSpan(text: text);
  final pattern = alternatives
      .map((s) => s.split(RegExp(r"\s+")).map(RegExp.escape).join(r"\s+"))
      .join("|");
  final matches = RegExp(
    r"(?<![\p{L}\p{N}_])(?:" + pattern + r")(?![\p{L}\p{N}_])",
    caseSensitive: false,
    unicode: true,
  ).allMatches(text);
  var offset = 0;
  final spans = <InlineSpan>[];
  for (final match in matches) {
    if (match.start > offset) {
      spans.add(TextSpan(text: text.substring(offset, match.start)));
    }
    spans.add(TextSpan(text: match.group(0), style: emphasis));
    offset = match.end;
  }
  if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
  return TextSpan(children: spans);
}

class VocabularyExampleText extends StatefulWidget {
  const VocabularyExampleText({
    required this.card,
    this.store,
    this.textAlign = TextAlign.start,
    super.key,
  });
  final LanguageCard card;
  final LanguageLearningStore? store;
  final TextAlign textAlign;
  @override
  State<VocabularyExampleText> createState() => _ExampleTextState();
}

class _ExampleTextState extends State<VocabularyExampleText> {
  late Future<List<LearningLexicalForm>> _forms = _load();
  Future<List<LearningLexicalForm>> _load() =>
      widget.store?.lexicalForms(widget.card.sense.id) ??
      Future.value(const []);
  @override
  void didUpdateWidget(VocabularyExampleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.sense.id != widget.card.sense.id ||
        oldWidget.store != widget.store) {
      _forms = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return FutureBuilder<List<LearningLexicalForm>>(
      future: _forms,
      builder: (context, snapshot) => Text.rich(
        vocabularyExampleSpan(
          widget.card.sense.example ?? "",
          [widget.card.item.form, ...?snapshot.data?.map((r) => r.surface)],
          TextStyle(
            color: color,
            decoration: TextDecoration.underline,
            decorationColor: color.withValues(alpha: .65),
            decorationThickness: 1.2,
          ),
        ),
        textAlign: widget.textAlign,
      ),
    );
  }
}
