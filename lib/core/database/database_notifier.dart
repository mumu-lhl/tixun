import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notify UI consumers in the store's owning zone. Drift scopes transactions
/// to zones; deferred Riverpod refreshes must never inherit a nested transaction
/// that has already closed when the refresh runs.
class DatabaseNotifier extends ChangeNotifier {
  final Zone _ownerZone = Zone.current;
  bool isDisposed = false;
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
