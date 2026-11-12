import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart' as assets;
import 'package:tixun/core/platform/photo_picker_delegate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/platform/photo_picker.dart';
import 'package:tixun/core/platform/camera_capture_screen.dart';
import 'package:wechat_camera_picker/wechat_camera_picker.dart' as camera;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final english in [false, true]) {
    testWidgets(
      'Photo counts hide unlimited sentinel in both views ($english)',
      (t) async {
        final first = assets.AssetEntity(
          id: 'first',
          typeInt: 1,
          width: 10,
          height: 10,
        );
        final second = assets.AssetEntity(
          id: 'second',
          typeInt: 1,
          width: 10,
          height: 10,
        );
        final selected = assets.DefaultAssetPickerProvider.forTest(
          maxAssets: 0x7fffffff,
          selectedAssets: [first],
        );
        final picker = PhotoPickerBuilder(
          provider: selected,
          initialPermission: assets.PermissionState.authorized,
          pickerTheme: ThemeData(),
          textDelegate: english
              ? const assets.EnglishAssetPickerTextDelegate()
              : const assets.AssetPickerTextDelegate(),
        );
        final viewerProvider =
            assets.AssetPickerViewerProvider<assets.AssetEntity>(
              selected.selectedAssets,
              maxAssets: selected.maxAssets,
            );
        final viewer = PhotoViewerBuilder(
          currentIndex: 0,
          previewAssets: [first, second],
          selectedAssets: selected.selectedAssets,
          selectorProvider: selected,
          provider: viewerProvider,
          maxAssets: selected.maxAssets,
          themeData: ThemeData(),
        );
        final label = english ? 'Confirm' : '确认';
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Builder(builder: picker.confirmButton),
                  Builder(builder: viewer.confirmButton),
                ],
              ),
            ),
          ),
        );
        expect(find.text('$label (1)'), findsNWidgets(2));
        expect(find.textContaining('2147483647'), findsNothing);
        selected.selectAsset(second);
        viewerProvider.selectAsset(second);
        await t.pump();
        expect(find.text('$label (2)'), findsNWidgets(2));
        selected.unSelectAsset(first);
        selected.unSelectAsset(second);
        viewerProvider.unSelectAsset(first);
        viewerProvider.unSelectAsset(second);
        await t.pump();
        expect(find.text(label), findsNWidgets(2));
        await t.pumpWidget(const SizedBox.shrink());
        selected.dispose();
        viewerProvider.dispose();
      },
    );
  }
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
          await t.pumpWidget(MaterialApp(home: const Scaffold()));
          final request = captureSystemPhoto();
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
              result == null ? <String>[] : [result.path],
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
  testWidgets(
    'Embedded camera failure shows an error and can release to the system fallback',
    (t) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channels = [
        'plugins.flutter.io/camera',
        'dev.fluttercommunity.plus/sensors/method',
        'dev.fluttercommunity.plus/sensors/accelerometer',
      ];
      for (final name in channels) {
        messenger.setMockMethodCallHandler(
          MethodChannel(name),
          (call) async => call.method == 'availableCameras' ? <Object>[] : null,
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(MethodChannel(name), null),
        );
      }
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const Scaffold()),
      );
      final result = nav.currentState!.push<CameraCaptureResult>(
        MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
      );
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 30));
      }
      expect(find.byType(camera.CameraPicker), findsOneWidget);
      expect(find.text('相机报告异常，可返回重试或使用系统相机。'), findsOneWidget);
      await t.tap(find.byKey(const Key('system-camera-fallback')));
      await t.pumpAndSettle();
      expect((await result)?.useSystemCamera, true);
      expect(t.takeException(), isNull);
    },
  );
}
