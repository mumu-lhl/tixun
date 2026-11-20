import "package:material_ui/material_ui.dart";

// Short, bounded snapshots make route re-entry immediate. Streams remain the
// source of truth and are subscribed again on each visit.
final _snapshots = Expando<Map<Object, Object?>>();

class CachedStreamBuilder<T> extends StatelessWidget {
  const CachedStreamBuilder({
    super.key,
    required this.owner,
    required this.cacheKey,
    required this.stream,
    required this.builder,
  });

  final Object owner;
  final Object cacheKey;
  final Stream<T> stream;
  final AsyncWidgetBuilder<T> builder;

  @override
  Widget build(BuildContext context) {
    final cache = _snapshots[owner] ??= {};
    final previous = cache.remove(cacheKey);
    if (previous != null) cache[cacheKey] = previous;
    return StreamBuilder<T>(
      stream: stream,
      initialData: previous as T?,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active &&
            !snapshot.hasError) {
          final data = snapshot.data;
          cache.remove(cacheKey);
          // Avoid retaining large collections. A null result invalidates a
          // deleted record rather than reviving its previous snapshot.
          if (data != null && (data is! List || data.length <= 200)) {
            cache[cacheKey] = data;
          }
          while (cache.length > 24) {
            cache.remove(cache.keys.first);
          }
        }
        return builder(context, snapshot);
      },
    );
  }
}
