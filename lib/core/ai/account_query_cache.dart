/// One account's last successful read. No timers, credentials, or persistence.
class AccountQueryCache<T extends Object> {
  AccountQueryCache(this.checkedAt);

  static const lifetime = Duration(minutes: 5);
  final DateTime Function(T) checkedAt;
  Object? _identity;
  T? _value;
  Future<T>? _pending;

  /// Expired values remain available for display, never for freshness checks.
  T? peek(Object identity) {
    if (_identity != identity) {
      _identity = identity;
      _value = null;
      _pending = null;
    }
    return _value;
  }

  Future<T> load(
    Object identity,
    Future<T> Function() fetch, {
    bool refresh = false,
  }) async {
    final value = peek(identity);
    final pending = _pending;
    if (pending != null) return pending;
    if (!refresh && value != null) {
      final age = DateTime.now().difference(checkedAt(value));
      if (!age.isNegative && age < lifetime) return value;
    }
    final request = fetch();
    _pending = request;
    try {
      final result = await request;
      // An old account's late response must not repopulate the current cache.
      if (_identity == identity && identical(_pending, request)) {
        _value = result;
      }
      return result;
    } finally {
      if (identical(_pending, request)) _pending = null;
    }
  }
}
