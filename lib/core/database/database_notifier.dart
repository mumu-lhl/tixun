import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notify UI consumers in the store's owning zone. Drift scopes transactions
/// to zones; deferred Riverpod refreshes must never inherit a nested transaction
/// that has already closed when the refresh runs.
class DatabaseNotifier extends ChangeNotifier {
  final Zone _ownerZone = Zone.current;
  bool isDisposed = false;
  int _activeOperations = 0;
  Completer<void>? _idle;
  Future<void> get whenIdle => _activeOperations == 0
      ? Future.value()
      : (_idle ??= Completer<void>()).future;
  Future<T> runOperation<T>(Future<T> Function() action) async {
    if (isDisposed) throw StateError('学习数据已关闭，无法继续修改。');
    _activeOperations++;
    try {
      return await action();
    } finally {
      if (--_activeOperations == 0) {
        final done = _idle;
        _idle = null;
        done?.complete();
      }
    }
  }

  void changed() {
    if (!isDisposed) _ownerZone.run(notifyListeners);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    isDisposed = true;
    super.dispose();
  }
}
