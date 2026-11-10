import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/platform/photo_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/image_picker');
  for (final outcome in <Object?>[
    '/camera/original.jpg',
    null,
    PlatformException(code: 'camera_access_denied'),
  ]) {
    final description = outcome is PlatformException
        ? 'reports a readable failure'
        : outcome == null
        ? 'handles cancellation'
        : 'returns the original photo';
    testWidgets(
      'Android system camera $description without an embedded preview',
      (t) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          final calls = <MethodCall>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (outcome is PlatformException) throw outcome;
            return outcome;
          });
          addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
          late BuildContext context;
          await t.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (c) {
                  context = c;
                  return const Scaffold();
                },
              ),
            ),
          );
          final request = pickPhotos(context, takePhoto: true);
          if (outcome is PlatformException) {
            await expectLater(
              request,
              throwsA(
                isA<FormatException>().having(
                  (e) => e.message,
                  'message',
                  contains('系统相机'),
                ),
              ),
            );
          } else {
            final result = await request;
            expect(
              result.map((f) => f.path).toList(),
              outcome == null ? isEmpty : [outcome],
            );
          }
          expect(calls, hasLength(1));
          expect(calls.single.method, 'pickImage');
          final args = calls.single.arguments as Map;
          expect(args['source'], 0);
          expect(args['maxWidth'], isNull);
          expect(args['maxHeight'], isNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
