import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/features/language_learning/language_stream.dart';

void main() {
  test('cancels a silent stream without waiting for the provider', () async {
    final source = StreamController<AiChunk>();
    final cancel = CancelToken();
    late CancelToken transport;
    final reply = boundedLanguageStream((token) {
      transport = token;
      return source.stream;
    }, cancel).toList();
    final observed = expectLater(reply, throwsA(isA<DioException>()));
    cancel.cancel();
    await observed;
    expect(transport.isCancelled, isTrue);
    await source.close();
  });

  test('heartbeats do not reset the total deadline', () async {
    final source = StreamController<AiChunk>();
    final pulse = Timer.periodic(
      const Duration(milliseconds: 2),
      (_) => source.add(const AiChunk()),
    );
    try {
      await expectLater(
        boundedLanguageStream(
          (_) => source.stream,
          CancelToken(),
          deadline: const Duration(milliseconds: 25),
        ).toList(),
        throwsA(isA<TimeoutException>()),
      );
    } finally {
      pulse.cancel();
      await source.close();
    }
  });
}
