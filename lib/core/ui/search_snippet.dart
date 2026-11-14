import 'package:material_ui/material_ui.dart';

/// Returns a short excerpt around the first literal occurrence of [query].
String? searchExcerpt(String text, String query, {int context = 45}) {
  final term = query.trim().toLowerCase();
  if (term.isEmpty) return null;
  final index = text.toLowerCase().indexOf(term);
  if (index < 0) return null;
  final start = (index - context).clamp(0, text.length);
  final end = (index + term.length + context).clamp(0, text.length);
  return '${start > 0 ? '…' : ''}${text.substring(start, end).replaceAll('\n', ' ')}${end < text.length ? '…' : ''}';
}

class SearchSnippet extends StatelessWidget {
  const SearchSnippet(this.text, this.query, {super.key});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final index = text.toLowerCase().indexOf(query.trim().toLowerCase());
    final length = query.trim().length;
    return Text.rich(
      TextSpan(
        children: [
          if (index < 0 || length == 0)
            TextSpan(text: text)
          else ...[
            TextSpan(text: text.substring(0, index)),
            TextSpan(
              text: text.substring(index, index + length),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .tertiaryContainer,
              ),
            ),
            TextSpan(text: text.substring(index + length)),
          ],
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    );
  }
}
