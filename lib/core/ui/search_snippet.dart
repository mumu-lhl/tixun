import 'package:material_ui/material_ui.dart';

import '../database/search_terms.dart';

RegExpMatch? _firstMatch(String text, String query) {
  for (final term in searchTerms(query)) {
    if (term.isEmpty) continue;
    final match = RegExp(
      RegExp.escape(term),
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (match != null) return match;
  }
  return null;
}

bool _splitsSurrogate(String text, int index) =>
    index > 0 &&
    index < text.length &&
    text.codeUnitAt(index - 1) >= 0xD800 &&
    text.codeUnitAt(index - 1) <= 0xDBFF &&
    text.codeUnitAt(index) >= 0xDC00 &&
    text.codeUnitAt(index) <= 0xDFFF;

/// Returns a short excerpt around the first literal occurrence of [query].
String? searchExcerpt(String text, String query, {int context = 45}) {
  final match = _firstMatch(text, query);
  if (match == null) return null;
  var start = (match.start - context).clamp(0, text.length);
  var end = (match.end + context).clamp(0, text.length);
  if (_splitsSurrogate(text, start)) start--;
  if (_splitsSurrogate(text, end)) end++;
  return '${start > 0 ? '…' : ''}${text.substring(start, end).replaceAll('\n', ' ')}${end < text.length ? '…' : ''}';
}

class SearchSnippet extends StatelessWidget {
  const SearchSnippet(this.text, this.query, {super.key});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final match = _firstMatch(text, query);
    return Text.rich(
      TextSpan(
        children: [
          if (match == null)
            TextSpan(text: text)
          else ...[
            TextSpan(text: text.substring(0, match.start)),
            TextSpan(
              text: text.substring(match.start, match.end),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .tertiaryContainer,
              ),
            ),
            TextSpan(text: text.substring(match.end)),
          ],
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    );
  }
}
