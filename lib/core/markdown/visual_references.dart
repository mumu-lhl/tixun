import 'package:markdown/markdown.dart' as md;

final _visualId = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Local scene references only; never a path, network image or executable DSL.
String? visualReferenceId(String source) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      uri.scheme != 'visual' ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment ||
      !_visualId.hasMatch(uri.path)) {
    return null;
  }
  return uri.path;
}

/// Parse Markdown so examples inside code blocks do not hide fallback cards.
Set<String> visualReferences(String markdown) {
  if (!markdown.contains('visual:')) return const {};
  final ids = <String>{};
  void visit(md.Node node) {
    if (node is! md.Element) return;
    if (node.tag == 'img') {
      final id = visualReferenceId(node.attributes['src'] ?? '');
      if (id != null) ids.add(id);
    }
    for (final child in node.children ?? <md.Node>[]) {
      visit(child);
    }
  }

  for (final node in md.Document().parse(markdown)) {
    visit(node);
  }
  return ids;
}
