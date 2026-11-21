import "dart:convert";

import "web_activity.dart";

List<Map<String, String>> deepSeekWebTools(
  WebAccess access, {
  required bool thinking,
}) => [
  // Thinking + search suppresses the distinct signed read-link operation.
  if (access != WebAccess.readLink || !thinking)
    {"type": "deepseek_web_search"},
  {"type": "deepseek_read_url"},
];

WebAction? deepSeekWebAction(Object? value) => switch (value) {
  "search" => WebAction.search,
  "open_page" || "read_link" || "find_in_page" => WebAction.read,
  _ => null,
};

Iterable<Map> _maps(Object? value) =>
    value is List ? value.whereType<Map>() : const [];

Iterable<Map> _calls(Object? steps) =>
    _maps(steps).expand((step) => _maps(step["calls"]));

WebActivity? deepSeekWebActivity(Map delta) {
  final sources = <Object?>[
    for (final annotation in _maps(delta["annotations"]))
      if (annotation["type"] == "url_citation") annotation["url_citation"],
  ];
  final operations = <WebOperation>[];
  for (final call in _calls(delta["server_tool_calls"])) {
    final action = call["action"];
    if (action is! Map) continue;
    final kind = deepSeekWebAction(action["type"]);
    if (kind == null) continue;
    final page = call["page"] is Map ? call["page"] : action;
    operations.add(
      WebOperation(
        kind,
        queries: action["queries"],
        page: page,
        failed: call["status"] == "failed",
      ),
    );
    if (call["status"] == "completed") {
      sources.addAll(_maps(call["sources"]));
      sources.add(page);
    }
  }
  final report = WebActivity(operations: operations, sources: sources);
  return report.isEmpty ? null : report;
}

const _maxReplayLength = 512 * 1024;

bool _signedRead(Object? steps) => _calls(steps).any(
  (call) =>
      call["kind"] == "read_link" &&
      call["status"] == "completed" &&
      call["signature"] is String &&
      (call["signature"] as String).isNotEmpty,
);

String? deepSeekWebReplay(Object? steps) {
  // Only linked pages contribute web context to later turns. Preserve the
  // original steps (including signatures) instead of rebuilding tool calls
  // from display-only metadata.
  if (!_signedRead(steps)) return null;
  final encoded = jsonEncode(steps);
  return encoded.length <= _maxReplayLength ? encoded : null;
}

List<dynamic>? decodeDeepSeekWebReplay(String? encoded) {
  if (encoded == null || encoded.length > _maxReplayLength) return null;
  try {
    final steps = jsonDecode(encoded);
    return steps is List && _signedRead(steps) ? steps : null;
  } on FormatException {
    return null;
  }
}
