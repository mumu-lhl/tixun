/// Whitespace separates keywords; quoted queries and mathematical expressions
/// remain literal so searches for formulas continue to work.
List<String> searchTerms(String query) {
  final term = query.trim();
  if (term.isEmpty) return const [];
  if (term.startsWith('"') && term.endsWith('"') && term.length > 1) {
    return [term.substring(1, term.length - 1)];
  }
  if (RegExp(r'[=+*/^<>]').hasMatch(term)) return [term];
  return term.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
}
