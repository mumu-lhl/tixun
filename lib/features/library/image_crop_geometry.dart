part of "image_editor.dart";

/// Decode size for the editor: longest edge 2048px, never a zero edge.
/// An extreme aspect ratio such as 5000x1 would otherwise round the short
/// edge to 0 and make instantiateCodec throw, leaving the image uneditable.
({int width, int height}) editorDecodeSize(int width, int height) {
  final scale = math.min(1.0, 2048 / math.max(width, height));
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}

/// A normalized crop is applied after clockwise rotation. Original bytes remain intact.
Future<Uint8List> renderStudyCrop(
  ui.Image image,
  Rect normalized,
  int turns,
) async {
  final q = turns % 4;
  final w = (q.isEven ? image.width : image.height).toDouble();
  final h = (q.isEven ? image.height : image.width).toDouble();
  final crop = Rect.fromLTRB(
    normalized.left.clamp(0, 1) * w,
    normalized.top.clamp(0, 1) * h,
    normalized.right.clamp(0, 1) * w,
    normalized.bottom.clamp(0, 1) * h,
  );
  if (crop.width < 2 || crop.height < 2) {
    throw const AppFormatException(
      AppErrorCode.errorTheSelectedAreaIsTooSmall,
      "框选范围太小，请重新选择。",
    );
  }
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(-crop.left, -crop.top);
  switch (q) {
    case 1:
      canvas.translate(image.height.toDouble(), 0);
      canvas.rotate(math.pi / 2);
    case 2:
      canvas.translate(image.width.toDouble(), image.height.toDouble());
      canvas.rotate(math.pi);
    case 3:
      canvas.translate(0, image.width.toDouble());
      canvas.rotate(-math.pi / 2);
  }
  canvas.drawImage(
    image,
    Offset.zero,
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final result = await picture.toImage(crop.width.round(), crop.height.round());
  try {
    return (await result.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    result.dispose();
    picture.dispose();
  }
}

bool isFullFrameCrop(Rect crop) =>
    crop.left <= 0.001 &&
    crop.top <= 0.001 &&
    crop.right >= 0.999 &&
    crop.bottom >= 0.999;

enum CropHandle {
  outside,
  inside,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  top,
  right,
  bottom,
}

/// Hit-test a normalized [point] against [crop]. Thresholds are in normalized
/// units per axis (already scaled for the current zoom).
CropHandle resolveCropHandle(
  Offset point,
  Rect crop,
  double thresholdX,
  double thresholdY,
) {
  bool nearX(double value) => (point.dx - value).abs() <= thresholdX;
  bool nearY(double value) => (point.dy - value).abs() <= thresholdY;
  if (nearX(crop.left) && nearY(crop.top)) return CropHandle.topLeft;
  if (nearX(crop.right) && nearY(crop.top)) return CropHandle.topRight;
  if (nearX(crop.left) && nearY(crop.bottom)) return CropHandle.bottomLeft;
  if (nearX(crop.right) && nearY(crop.bottom)) return CropHandle.bottomRight;
  final withinY =
      point.dy >= crop.top - thresholdY && point.dy <= crop.bottom + thresholdY;
  final withinX =
      point.dx >= crop.left - thresholdX && point.dx <= crop.right + thresholdX;
  if (nearX(crop.left) && withinY) return CropHandle.left;
  if (nearX(crop.right) && withinY) return CropHandle.right;
  if (nearY(crop.top) && withinX) return CropHandle.top;
  if (nearY(crop.bottom) && withinX) return CropHandle.bottom;
  if (crop.contains(point)) return CropHandle.inside;
  return CropHandle.outside;
}

/// Shift [start] by [delta], keeping it inside the 0..1 frame.
Rect moveCropRect(Rect start, Offset delta) {
  final dx = (start.left + delta.dx).clamp(0.0, 1.0 - start.width);
  final dy = (start.top + delta.dy).clamp(0.0, 1.0 - start.height);
  return Rect.fromLTWH(dx, dy, start.width, start.height);
}

/// Move the dragged corner/edge of [start] to [pointer] (normalized, clamped
/// to the frame). The opposite side stays fixed; sides never cross below a
/// 0.02 minimum size. Returns [start] unchanged for inside/outside handles.
Rect resizeCropRect(Rect start, CropHandle handle, Offset pointer) {
  const minSize = 0.02;
  final px = pointer.dx.clamp(0.0, 1.0);
  final py = pointer.dy.clamp(0.0, 1.0);
  var left = start.left;
  var top = start.top;
  var right = start.right;
  var bottom = start.bottom;
  double clampLo(double value, double upper) =>
      value.clamp(0.0, math.max(0.0, upper));
  double clampHi(double value, double lower) =>
      value.clamp(math.min(1.0, lower), 1.0);
  switch (handle) {
    case CropHandle.topLeft:
      left = clampLo(px, right - minSize);
      top = clampLo(py, bottom - minSize);
    case CropHandle.topRight:
      right = clampHi(px, left + minSize);
      top = clampLo(py, bottom - minSize);
    case CropHandle.bottomLeft:
      left = clampLo(px, right - minSize);
      bottom = clampHi(py, top + minSize);
    case CropHandle.bottomRight:
      right = clampHi(px, left + minSize);
      bottom = clampHi(py, top + minSize);
    case CropHandle.left:
      left = clampLo(px, right - minSize);
    case CropHandle.right:
      right = clampHi(px, left + minSize);
    case CropHandle.top:
      top = clampLo(py, bottom - minSize);
    case CropHandle.bottom:
      bottom = clampHi(py, top + minSize);
    case CropHandle.inside:
    case CropHandle.outside:
      return start;
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

/// Scale [current] by [factor] around [focalScene] (a point in scene
/// coordinates), clamping the resulting scale to 1..4.
Matrix4 zoomTransform(Matrix4 current, Offset focalScene, double factor) {
  final scale = current.getMaxScaleOnAxis();
  final target = (scale * factor).clamp(1.0, 4.0);
  final effective = target / scale;
  if (effective == 1.0) return current;
  return current.clone()
    ..translateByDouble(focalScene.dx, focalScene.dy, 0, 1)
    ..scaleByDouble(effective, effective, effective, 1)
    ..translateByDouble(-focalScene.dx, -focalScene.dy, 0, 1);
}
