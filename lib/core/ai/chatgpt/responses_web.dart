import "../web_activity.dart";

WebAction? responsesWebAction(Map item) {
  if (item["type"] != "web_search_call") return null;
  final action = item["action"];
  return switch (action is Map ? action["type"] : null) {
    "open_page" || "find_in_page" => WebAction.read,
    "search" || null => WebAction.search,
    _ => null,
  };
}

Iterable<Map> _maps(Object? value) =>
    value is List ? value.whereType<Map>() : const [];

WebActivity? responsesWebActivity(List output) {
  final citations = <Map>[], sources = <Map>[];
  final operations = <WebOperation>[];
  for (final item in output.whereType<Map>()) {
    if (item["type"] == "message") {
      for (final part in _maps(item["content"])) {
        citations.addAll(
          _maps(part["annotations"]).where((a) => a["type"] == "url_citation"),
        );
      }
    }
    final kind = responsesWebAction(item);
    if (kind == null) continue;
    final action = item["action"] is Map ? item["action"] as Map : const {};
    final failed = item["status"] == "failed";
    operations.add(
      WebOperation(
        kind,
        queries: action["queries"] ?? action["query"],
        page: action,
        failed: failed,
      ),
    );
    if (!failed) {
      sources.addAll(_maps(action["sources"]));
      sources.add(action);
    }
  }
  final report = WebActivity(
    operations: operations,
    sources: [...citations, ...sources],
  );
  return report.isEmpty ? null : report;
}
