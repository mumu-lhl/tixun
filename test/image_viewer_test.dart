import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/core/ui/image_viewer.dart';

Future<File> _makePng(Directory dir, String name, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 300), Paint()..color = color);
  final image = await recorder.endRecording().toImage(400, 300);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

void main() {
  late Directory dir;
  late List<File> files;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('tixun-image-viewer-test');
    files = [
      await _makePng(dir, 'red.png', Colors.red),
      await _makePng(dir, 'green.png', Colors.green),
      await _makePng(dir, 'blue.png', Colors.blue),
    ];
    // Pre-decode each fixture with the exact provider ExtendedImage.file
    // (cacheWidth: 1600) builds: real file decoding never completes inside
    // a testWidgets body (fake async zone), so the viewer would otherwise
    // stay in LoadState.loading forever and never build its gesture widget.
    for (final file in files) {
      final provider = ExtendedResizeImage.resizeIfNeeded(
        provider: ExtendedFileImageProvider(file),
        cacheWidth: 1600,
      );
      final stream = provider.resolve(ImageConfiguration.empty);
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!completer.isCompleted) completer.complete(info);
          stream.removeListener(listener);
        },
        onError: (Object e, StackTrace? stack) {
          if (!completer.isCompleted) completer.completeError(e, stack);
        },
      );
      stream.addListener(listener);
      await completer.future;
    }
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  Future<void> openViewer(
    WidgetTester tester, {
    List<ImageViewerItem>? images,
    int initialIndex = 0,
    String title = '题目图片',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showImageViewer(
                context,
                images:
                    images ??
                    [for (final file in files) ImageViewerItem(file: file)],
                initialIndex: initialIndex,
                title: title,
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    // Real file decoding (FileImage.readAsBytes + the image codec) runs on
    // the real event loop, which the test's fake async zone never advances.
    // Give it real time, then pump so the viewer rebuilds with the result.
    // This is what makes both the completed state (gesture widget) and the
    // failed state (error text) observable in a widget test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'viewer opens, renders the image and closes via the close button',
    (tester) async {
      await openViewer(tester);

      expect(find.textContaining('1 / 3'), findsOneWidget);
      expect(find.byType(ExtendedImage), findsOneWidget);

      await tester.tap(find.byTooltip('关闭预览'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 / 3'), findsNothing);
    },
  );

  testWidgets('double-tap toggles the zoom scale', (tester) async {
    await openViewer(tester, images: [ImageViewerItem(file: files.first)]);

    final state = tester.state<ExtendedImageGestureState>(
      find.byType(ExtendedImageGesture),
    );
    expect(state.gestureDetails?.totalScale, 1.0);

    await tester.tap(find.byType(ExtendedImage));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(ExtendedImage));
    await tester.pumpAndSettle();
    expect(state.gestureDetails?.totalScale, 2.5);

    await tester.tap(find.byType(ExtendedImage));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(ExtendedImage));
    await tester.pumpAndSettle();
    expect(state.gestureDetails?.totalScale, 1.0);
  });

  testWidgets('swiping moves to the next image and updates the counter', (
    tester,
  ) async {
    await openViewer(tester);

    expect(find.textContaining('1 / 3'), findsOneWidget);
    await tester.fling(
      find.byType(ExtendedImageGesturePageView),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2 / 3'), findsOneWidget);

    await tester.fling(
      find.byType(ExtendedImageGesturePageView),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3 / 3'), findsOneWidget);
  });

  testWidgets('unreadable file shows the error text', (tester) async {
    await openViewer(
      tester,
      images: [
        ImageViewerItem(
          file: File('${dir.path}/missing.png'),
          errorText: '图片无法读取',
        ),
      ],
    );

    expect(find.text('图片无法读取'), findsOneWidget);
  });
}
