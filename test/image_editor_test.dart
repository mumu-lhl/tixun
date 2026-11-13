import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/app/controller.dart';
import 'package:tixun/core/ai/chat_provider.dart';
import 'package:tixun/core/database/database.dart';
import 'package:tixun/core/platform/attachment_store.dart';
import 'package:tixun/core/platform/key_store.dart';
import 'package:tixun/features/library/image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Compares rect edges with a tolerance for binary float noise
  /// (e.g. 0.2 + 0.1 is 0.30000000000000004).
  void expectRect(Rect actual, double l, double t, double r, double b) {
    expect(actual.left, closeTo(l, 1e-9));
    expect(actual.top, closeTo(t, 1e-9));
    expect(actual.right, closeTo(r, 1e-9));
    expect(actual.bottom, closeTo(b, 1e-9));
  }

  test(
    'editorDecodeSize never yields a zero edge for extreme aspect ratios',
    () {
      expect(editorDecodeSize(5000, 1), (width: 2048, height: 1));
      expect(editorDecodeSize(1, 5000), (width: 1, height: 2048));
      expect(editorDecodeSize(4000, 3000), (width: 2048, height: 1536));
      expect(editorDecodeSize(800, 600), (width: 800, height: 600));
    },
  );
  test('Crop after rotation produces bounded pixels without modifying the original', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 40, 20),
      Paint()..color = const Color(0xffff0000),
    );
    canvas.drawRect(
      const Rect.fromLTWH(20, 0, 20, 20),
      Paint()..color = const Color(0xff0000ff),
    );
    final picture = recorder.endRecording();
    final source = await picture.toImage(40, 20);
    picture.dispose();
    addTearDown(source.dispose);
    final png = await renderStudyCrop(
      source,
      const Rect.fromLTRB(0, 0, 1, .5),
      1,
    );
    final codec = await ui.instantiateImageCodec(png);
    final result = (await codec.getNextFrame()).image;
    addTearDown(codec.dispose);
    addTearDown(result.dispose);
    expect(result.width, 20);
    expect(result.height, 20);
    final pixels = (await result.toByteData())!.buffer.asUint8List();
    expect(pixels[0], 255);
    expect(pixels[2], 0);
    expect(source.width, 40);
    expect(source.height, 20);
    await expectLater(
      renderStudyCrop(source, const Rect.fromLTRB(0, 0, 0, 0), 0),
      throwsFormatException,
    );
  });

  group('crop handle hit-testing', () {
    const crop = Rect.fromLTRB(0.2, 0.3, 0.8, 0.7);
    test('corners win over edges, edges over inside', () {
      expect(
        resolveCropHandle(const Offset(0.2, 0.3), crop, 0.05, 0.05),
        CropHandle.topLeft,
      );
      expect(
        resolveCropHandle(const Offset(0.8, 0.7), crop, 0.05, 0.05),
        CropHandle.bottomRight,
      );
      expect(
        resolveCropHandle(const Offset(0.5, 0.3), crop, 0.05, 0.05),
        CropHandle.top,
      );
      expect(
        resolveCropHandle(const Offset(0.2, 0.5), crop, 0.05, 0.05),
        CropHandle.left,
      );
      expect(
        resolveCropHandle(const Offset(0.5, 0.5), crop, 0.05, 0.05),
        CropHandle.inside,
      );
      expect(
        resolveCropHandle(const Offset(0.05, 0.05), crop, 0.05, 0.05),
        CropHandle.outside,
      );
    });

    test('edge hit needs the point to span the edge', () {
      // Above the top edge but outside its x-range: not a top hit.
      expect(
        resolveCropHandle(const Offset(0.05, 0.3), crop, 0.05, 0.05),
        CropHandle.outside,
      );
    });
  });

  group('moveCropRect', () {
    test('shifts and clamps into the unit square', () {
      const start = Rect.fromLTRB(0.2, 0.3, 0.5, 0.6);
      expectRect(
        moveCropRect(start, const Offset(0.1, -0.1)),
        0.3,
        0.2,
        0.6,
        0.5,
      );
      expectRect(
        moveCropRect(start, const Offset(0.9, 0.9)),
        0.7,
        0.7,
        1.0,
        1.0,
      );
      expectRect(
        moveCropRect(start, const Offset(-0.9, -0.9)),
        0.0,
        0.0,
        0.3,
        0.3,
      );
    });
  });

  group('resizeCropRect', () {
    test('dragging a corner moves only that corner, min size 0.02', () {
      const start = Rect.fromLTRB(0.2, 0.3, 0.8, 0.7);
      expectRect(
        resizeCropRect(start, CropHandle.bottomRight, const Offset(0.9, 0.9)),
        0.2,
        0.3,
        0.9,
        0.9,
      );
      expectRect(
        resizeCropRect(start, CropHandle.topLeft, const Offset(0.0, 0.0)),
        0.0,
        0.0,
        0.8,
        0.7,
      );
      // Dragging bottom-right past top-left clamps at the minimum size.
      expectRect(
        resizeCropRect(start, CropHandle.bottomRight, const Offset(0.0, 0.0)),
        0.2,
        0.3,
        0.22,
        0.32,
      );
    });

    test('dragging an edge moves only that edge', () {
      const start = Rect.fromLTRB(0.2, 0.3, 0.8, 0.7);
      expectRect(
        resizeCropRect(start, CropHandle.left, const Offset(0.1, 0.5)),
        0.1,
        0.3,
        0.8,
        0.7,
      );
      expectRect(
        resizeCropRect(start, CropHandle.bottom, const Offset(0.5, 0.95)),
        0.2,
        0.3,
        0.8,
        0.95,
      );
    });
  });

  group('isFullFrameCrop', () {
    test('tolerates rounding noise', () {
      expect(isFullFrameCrop(const Rect.fromLTRB(0, 0, 1, 1)), isTrue);
      expect(
        isFullFrameCrop(const Rect.fromLTRB(0.0005, 0, 0.9995, 1)),
        isTrue,
      );
      expect(isFullFrameCrop(const Rect.fromLTRB(0.01, 0, 1, 1)), isFalse);
    });
  });

  group('zoomTransform', () {
    test('scales around the focal point and clamps to 1..4', () {
      final identity = Matrix4.identity();
      final zoomed = zoomTransform(identity, const Offset(100, 100), 2);
      expect(zoomed.storage[0], 2);
      // The focal point stays fixed: scale 2 around (100,100) shifts by -100.
      expect(zoomed.storage[12], -100);
      expect(zoomed.storage[13], -100);
      // Clamped at max 4.
      expect(zoomTransform(identity, Offset.zero, 100).storage[0], 4);
      // No-op zoom returns the same matrix.
      final current = zoomTransform(identity, const Offset(50, 50), 1.25);
      expect(zoomTransform(current, const Offset(50, 50), 1), current);
    });
  });

  group('StudyImageEditor widget', () {
    late AppController c;
    late Uint8List png;
    late ProviderContainer container;
    Rect? capturedCrop;

    Future<void> pumpEditor(WidgetTester tester) async {
      await tester.runAsync(() async {
        final root = await Directory.systemTemp.createTemp(
          'tixun-editor-widget',
        );
        c = AppController(
          AppDatabase.memory(),
          AttachmentStore(root),
          MemoryKeyStore(),
          MockChatProvider(),
        );
        await c.initialize();
        png = await _testPng();
        final file = c.files.resolve('attachments/test.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png);
      });
      container = ProviderContainer(
        overrides: [appControllerProvider.overrideWith((ref) => c)],
      );
      addTearDown(() async {
        await tester.runAsync(() async {
          container.dispose();
          await c.db.close();
          if (await c.files.root.exists()) {
            await c.files.root.delete(recursive: true);
          }
        });
      });
      capturedCrop = null;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyImageEditor(
              attachment: StudyAttachment(
                id: 'a1',
                relativePath: 'attachments/test.png',
                mime: 'image/png',
                byteLength: png.length,
                role: 'original',
                deleted: false,
              ),
              isMistake: true,
              title: '编辑题目图片',
              createLabel: '保存图片编辑',
              onCreate: (bytes, crop, turns) async {
                capturedCrop = crop;
                return 'new-id';
              },
            ),
          ),
        ),
      );
      // Poll for the canvas: the async image load runs outside the
      // fake-async zone, so give it real time and pump between waits.
      var loaded = false;
      for (var i = 0; i < 50 && !loaded; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        loaded = find.byKey(const Key('crop-canvas')).evaluate().isNotEmpty;
      }
      expect(
        loaded,
        isTrue,
        reason:
            'editor image did not load (spinner: '
            '${find.byType(CircularProgressIndicator).evaluate().isNotEmpty}, '
            'error: ${find.textContaining('无法解码').evaluate().isNotEmpty})',
      );
      await tester.pumpAndSettle();
    }

    Future<void> dragCrop(WidgetTester tester) async {
      final canvasRect = tester.getRect(find.byKey(const Key('crop-canvas')));
      final start =
          canvasRect.topLeft +
          Offset(canvasRect.width * 0.25, canvasRect.height * 0.25);
      final end =
          canvasRect.topLeft +
          Offset(canvasRect.width * 0.75, canvasRect.height * 0.75);
      await tester.dragFrom(start, end - start);
      await tester.pump();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('split-mistake')));
      // The render + onCreate run outside the fake-async zone; poll until
      // the crop is reported instead of trusting a fixed delay.
      for (var i = 0; i < 50 && capturedCrop == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      expect(capturedCrop, isNotNull, reason: 'save never reported a crop');
      await tester.pumpAndSettle();
    }

    testWidgets('drag draws a crop box and save reports it via onCreate', (
      tester,
    ) async {
      await pumpEditor(tester);
      expect(find.byKey(const Key('crop-canvas')), findsOneWidget);
      await dragCrop(tester);
      await save(tester);
      expect(capturedCrop, isNotNull);
      expect(capturedCrop!.left, closeTo(0.25, 0.02));
      expect(capturedCrop!.top, closeTo(0.25, 0.02));
      expect(capturedCrop!.right, closeTo(0.75, 0.02));
      expect(capturedCrop!.bottom, closeTo(0.75, 0.02));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'rotating a custom crop asks first, then resets to full frame',
      (tester) async {
        await pumpEditor(tester);
        // Full-frame crop rotates directly, no dialog.
        await tester.tap(find.byTooltip('顺时针旋转'));
        await tester.pumpAndSettle();
        expect(find.text('旋转会重置框选'), findsNothing);
        // A custom crop asks for confirmation.
        await dragCrop(tester);
        await tester.tap(find.byTooltip('顺时针旋转'));
        await tester.pumpAndSettle();
        expect(find.text('旋转会重置框选'), findsOneWidget);
        await tester.tap(find.text('旋转并重置'));
        await tester.pumpAndSettle();
        expect(find.text('旋转会重置框选'), findsNothing);
        await save(tester);
        expect(capturedCrop, const Rect.fromLTRB(0, 0, 1, 1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<Uint8List> _testPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 400, 200),
    Paint()..color = const Color(0xff3366cc),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(400, 200);
  picture.dispose();
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
      .asUint8List();
  image.dispose();
  return bytes;
}
