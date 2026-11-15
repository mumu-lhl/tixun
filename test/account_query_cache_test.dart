import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/account_query_cache.dart';

void main() {
  test(
    'fresh reads reuse, expired reads refetch, and refresh bypasses TTL',
    () async {
      final cache = AccountQueryCache<DateTime>((value) => value);
      var calls = 0;
      var time = DateTime.now().subtract(const Duration(minutes: 6));
      Future<DateTime> fetch() async {
        calls++;
        return time;
      }

      await cache.load('account', fetch);
      expect(cache.peek('account'), time); // Expired data is still displayable.
      time = DateTime.now();
      await cache.load('account', fetch);
      await cache.load('account', fetch);
      expect(calls, 2);
      await cache.load('account', fetch, refresh: true);
      expect(calls, 3);
    },
  );

  test(
    'concurrent reads coalesce; failures retain the previous successful read',
    () async {
      final cache = AccountQueryCache<DateTime>((value) => value);
      final result = Completer<DateTime>();
      var calls = 0;
      Future<DateTime> fetch() {
        calls++;
        return result.future;
      }

      final first = cache.load('account', fetch);
      final second = cache.load('account', fetch);
      final time = DateTime.now();
      result.complete(time);
      await Future.wait([first, second]);
      expect(calls, 1);
      await expectLater(
        cache.load(
          'account',
          () async => throw StateError('offline'),
          refresh: true,
        ),
        throwsStateError,
      );
      expect(cache.peek('account'), time);
      await cache.load('account', () async {
        calls++;
        return time;
      }, refresh: true);
      expect(
        calls,
        2,
      ); // A failed request does not leave a stuck pending future.
    },
  );

  test(
    'identity changes clear data and ignore old in-flight completions',
    () async {
      final cache = AccountQueryCache<DateTime>((value) => value);
      final old = Completer<DateTime>();
      final pending = cache.load('old', () => old.future);
      expect(cache.peek('new'), isNull);
      final fresh = DateTime.now();
      await cache.load('new', () async => fresh);
      old.complete(fresh.subtract(const Duration(minutes: 1)));
      await pending;
      expect(cache.peek('new'), fresh);
      expect(cache.peek('old'), isNull);
    },
  );
}
