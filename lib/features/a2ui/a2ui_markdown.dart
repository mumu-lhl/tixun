import "package:markdown/markdown.dart" as md;

import "../../core/database/database.dart";

final _surfaceId = RegExp(
  r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
);
final _image = RegExp(r"!\[(?:\\.|[^\]\\\n])*\]\(a2ui:([0-9a-f-]+)\)");

String? chatA2uiReference(Uri uri, {required String scheme}) =>
    uri.scheme == scheme &&
        !uri.hasAuthority &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        _surfaceId.hasMatch(uri.path)
    ? uri.path
    : null;

typedef A2uiMarkdownPart = ({String? markdown, String? surfaceId});

/// Mark candidate links with unique query fragments, then use the Markdown
/// parser to identify real images. Code fences, inline code and escaped
/// literals stay intact. Automatic locations take precedence over aliases.
List<A2uiMarkdownPart> chatA2uiMarkdown(
  String body,
  List<ChatA2uiSurface> surfaces, {
  required bool interrupted,
  String? renderScheme,
}) {
  final automatic = surfaces.where((row) => row.autoOffset != null).toList()
    ..sort((a, b) {
      final offset = a.autoOffset!.compareTo(b.autoOffset!);
      return offset == 0 ? a.ordinal.compareTo(b.ordinal) : offset;
    });
  final seen = {for (final row in automatic) row.id};
  final legacy = {
    for (final surface in surfaces)
      if (!surface.toolCallId.startsWith("inline:")) surface.id,
  };
  final matches = legacy.isEmpty
      ? <RegExpMatch>[]
      : _image
            .allMatches(body)
            .where((m) => _surfaceId.hasMatch(m[1]!))
            .toList();
  final real = <int>{};
  if (matches.isNotEmpty) {
    var occurrence = 0;
    var marker = "tixun-occurrence";
    while (body.contains(marker)) {
      marker += "x";
    }
    final marked = body.replaceAllMapped(_image, (match) {
      if (!_surfaceId.hasMatch(match[1]!)) return match[0]!;
      final text = match[0]!;
      return "${text.substring(0, text.length - 1)}?$marker=${occurrence++})";
    });
    void visit(md.Node node) {
      if (node is! md.Element) return;
      if (node.tag == "img") {
        final uri = Uri.tryParse(node.attributes["src"] ?? "");
        final index = int.tryParse(uri?.queryParameters[marker] ?? "");
        if (uri?.scheme == "a2ui" &&
            index != null &&
            index >= 0 &&
            index < matches.length &&
            uri!.path == matches[index][1]) {
          real.add(index);
        }
      }
      for (final child in node.children ?? <md.Node>[]) {
        visit(child);
      }
    }

    for (final node in md.Document().parse(marked)) {
      visit(node);
    }
  }

  final changes = <({int start, int end, String? id, String? replacement})>[
    for (final (i, match) in matches.indexed)
      if (real.contains(i) && legacy.contains(match[1]!))
        (
          start: match.start,
          end: match.end,
          id: null,
          replacement: !seen.add(match[1]!)
              ? ""
              : renderScheme == null
              ? match[0]
              : _replaceDestination(match[0]!, renderScheme),
        ),
    for (final row in automatic)
      (
        start: row.autoOffset!.clamp(0, body.length),
        end: row.autoOffset!.clamp(0, body.length),
        id: row.id,
        replacement: null,
      ),
    if (interrupted)
      for (final row in surfaces)
        if (seen.add(row.id))
          (start: body.length, end: body.length, id: row.id, replacement: null),
  ];
  // Dart's sort is unstable. Retain the original sequence for equal offsets.
  final ordered = changes.indexed.toList()
    ..sort((a, b) {
      final order = a.$2.start.compareTo(b.$2.start);
      if (order != 0) return order;
      final length = (a.$2.end - a.$2.start).compareTo(b.$2.end - b.$2.start);
      return length == 0 ? a.$1.compareTo(b.$1) : length;
    });
  final result = <A2uiMarkdownPart>[];
  var cursor = 0;
  var text = StringBuffer();
  for (final (_, change) in ordered) {
    if (change.start >= cursor) {
      text.write(body.substring(cursor, change.start));
      cursor = change.end;
      if (change.replacement case final String replacement) {
        text.write(replacement);
      }
    }
    if (change.id != null) {
      if (text.isNotEmpty) {
        result.add((markdown: text.toString(), surfaceId: null));
      }
      text = StringBuffer();
      result.add((markdown: null, surfaceId: change.id));
    }
  }
  text.write(body.substring(cursor));
  if (text.isNotEmpty) result.add((markdown: text.toString(), surfaceId: null));
  return result;
}

String _replaceDestination(String image, String scheme) {
  final end = image.lastIndexOf("(a2ui:") + 1;
  return image.replaceRange(end, end + "a2ui".length, scheme);
}
