import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tixun/core/ui/cached_stream_builder.dart';

void main() {
  testWidgets('reentry shows cached data then reflects updates and deletion', (
    tester,
  ) async {
    final owner = Object();
    final first = StreamController<String?>();
    final second = StreamController<String?>();
    final third = StreamController<String?>();
    addTearDown(() async {
      await first.close();
      await second.close();
      await third.close();
    });
    Widget screen(Stream<String?> stream) => MaterialApp(
      home: CachedStreamBuilder<String?>(
        owner: owner,
        cacheKey: 'record',
        stream: stream,
        builder: (_, snapshot) => Text(snapshot.data ?? 'empty'),
      ),
    );
    await tester.pumpWidget(screen(first.stream));
    first.add('old');
    await tester.pump();
    expect(find.text('old'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen(second.stream));
    expect(find.text('old'), findsOneWidget);
    second.add('new');
    await tester.pump();
    expect(find.text('new'), findsOneWidget);
    second.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('empty'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen(third.stream));
    expect(find.text('empty'), findsOneWidget);
  });
}
