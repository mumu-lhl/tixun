/// Hosted web actions are informational. They must never enter the app's
/// executable function-call pipeline.
enum WebAction { search, read }

enum WebAccess { off, automatic, readLink }

class WebSource {
  const WebSource(this.url, this.title);

  final Uri url;
  final String title;

  static WebSource? parse(Object? value) {
    if (value is! Map || value["url"] is! String) return null;
    final raw = value["url"] as String;
    if (raw.length > 4096) return null;
    final url = Uri.tryParse(raw);
    if (url == null ||
        !["http", "https"].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      return null;
    }
    final rawTitle = value["title"];
    final title = rawTitle is String ? rawTitle.trim() : "";
    return WebSource(
      url,
      title.length > 240 ? "${title.substring(0, 240)}…" : title,
    );
  }

  Map<String, String> toJson() => {"url": url.toString(), "title": title};
}

class WebOperation {
  WebOperation(
    this.action, {
    Object? queries,
    Object? page,
    this.failed = false,
  }) : queries = List.unmodifiable(_queries(queries)),
       page = WebSource.parse(page);

  final WebAction action;
  final List<String> queries;
  final WebSource? page;
  final bool failed;

  static Iterable<String> _queries(Object? value) sync* {
    final raw = value is List ? value : [value];
    for (final entry in raw.whereType<String>().take(10)) {
      final query = entry.trim();
      if (query.isNotEmpty) {
        yield query.length > 400 ? "${query.substring(0, 400)}…" : query;
      }
    }
  }

  Map<String, Object> toJson() => {
    "action": action.name,
    if (queries.isNotEmpty) "queries": queries,
    "page": ?page?.toJson(),
    if (failed) "failed": true,
  };

  static WebOperation? fromJson(Object? value) {
    if (value is! Map) return null;
    final action = WebAction.values
        .where((action) => action.name == value["action"])
        .firstOrNull;
    if (action == null) return null;
    return WebOperation(
      action,
      queries: value["queries"],
      page: value["page"],
      failed: value["failed"] == true,
    );
  }
}

/// Only display metadata; no page bodies or opaque protocol state.
class WebActivity {
  WebActivity({
    Iterable<WebOperation> operations = const [],
    Iterable<Object?> sources = const [],
  }) : operations = List.unmodifiable(operations.take(60)),
       sources = List.unmodifiable(_sources(sources));

  final List<WebOperation> operations;
  final List<WebSource> sources;
  bool get isEmpty => operations.isEmpty && sources.isEmpty;

  static Iterable<WebSource> _sources(Iterable<Object?> values) sync* {
    final seen = <Uri>{};
    for (final value in values) {
      final source = WebSource.parse(value);
      if (source == null || !seen.add(source.url)) continue;
      yield source;
      if (seen.length >= 20) break;
    }
  }

  Map<String, Object> toJson() => {
    "operations": [for (final operation in operations) operation.toJson()],
    "sources": [for (final source in sources) source.toJson()],
  };

  static WebActivity? fromJson(Object? value) {
    if (value is! Map) return null;
    final operations = value["operations"];
    final report = WebActivity(
      operations: [
        if (operations is List)
          for (final operation in operations.take(60))
            ?WebOperation.fromJson(operation),
      ],
      sources: value["sources"] is List ? value["sources"] as List : const [],
    );
    return report.isEmpty ? null : report;
  }
}
