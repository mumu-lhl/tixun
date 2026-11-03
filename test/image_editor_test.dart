import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/library/image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
}
