import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import 'library_providers.dart';
import 'study_store.dart';

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
    throw const FormatException('框选范围太小，请重新选择。');
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

/// Whether a crop rect covers the whole frame (nothing would be lost by
/// resetting it).
bool isFullFrameCrop(Rect crop) =>
    crop.left <= 0.001 &&
    crop.top <= 0.001 &&
    crop.right >= 0.999 &&
    crop.bottom >= 0.999;

/// Which part of the crop rect a normalized pointer position hits.
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

class StudyImageEditor extends ConsumerStatefulWidget {
  const StudyImageEditor({
    required this.attachment,
    this.ownerId = '',
    required this.isMistake,
    this.initialCrop,
    this.allowSplit = true,
    this.onCreate,
    this.createLabel = '确认范围并保存错题',
    this.title = '裁剪与分题',
    super.key,
  });
  final StudyAttachment attachment;
  final String ownerId;
  final bool isMistake, allowSplit;
  final Rect? initialCrop;
  final String createLabel, title;
  final Future<String> Function(Uint8List bytes, Rect crop, int turns)?
  onCreate;
  @override
  ConsumerState<StudyImageEditor> createState() => _StudyImageEditorState();
}

class _StudyImageEditorState extends ConsumerState<StudyImageEditor> {
  ui.Image? _image;
  String? _error;
  bool _saving = false;
  int _turns = 0;
  Rect _crop = const Rect.fromLTRB(0, 0, 1, 1);
  final _viewer = TransformationController();
  // One finger draws or adjusts the crop; the viewer only pans/zooms once a
  // second finger is down. A plain GestureDetector inside the viewer would
  // win the gesture arena for every drag and kill pinch zoom (probed), so the
  // crop uses a Listener overlay that never competes in the arena.
  bool _panEnabled = false;
  Size? _canvasSize;
  final _pointers = <int>{};
  CropHandle? _dragHandle;
  int? _dragPointer;
  Offset _dragStartPoint = Offset.zero;
  Rect _dragStartCrop = const Rect.fromLTRB(0, 0, 1, 1);
  @override
  void initState() {
    super.initState();
    _crop = widget.initialCrop ?? const Rect.fromLTRB(0, 0, 1, 1);
    _load();
  }

  Future<void> _load() async {
    try {
      final file = ref
          .read(appControllerProvider)
          .files
          .resolve(widget.attachment.relativePath);
      if (await file.length() > 8 * 1024 * 1024) {
        throw const FormatException('图片超过编辑器的 8 MB 上限。');
      }
      final bytes = await file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 32000000) {
          throw const FormatException('图片分辨率过大，请先缩小图片。原图记录未改变。');
        }
        final target = editorDecodeSize(descriptor.width, descriptor.height);
        final codec = await descriptor.instantiateCodec(
          targetWidth: target.width,
          targetHeight: target.height,
        );
        try {
          final image = (await codec.getNextFrame()).image;
          if (mounted) {
            setState(() => _image = image);
          } else {
            image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : '图片无法解码。原图记录仍然保留。',
        );
      }
    }
  }

  @override
  void dispose() {
    _viewer.dispose();
    _image?.dispose();
    super.dispose();
  }

  double get _scale => _viewer.value.getMaxScaleOnAxis();

  double get _thresholdX {
    final size = _canvasSize;
    if (size == null || size.width == 0) return 0.05;
    return 20 / (size.width * _scale);
  }

  double get _thresholdY {
    final size = _canvasSize;
    if (size == null || size.height == 0) return 0.05;
    return 20 / (size.height * _scale);
  }

  /// Convert a point in canvas (viewport) coordinates to normalized image
  /// coordinates, through the current zoom transform.
  Offset _toNormalized(Offset local) {
    final size = _canvasSize;
    if (size == null || size.isEmpty) return Offset.zero;
    final scene = _viewer.toScene(local);
    return Offset(
      (scene.dx / size.width).clamp(0.0, 1.0),
      (scene.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_saving || _image == null) return;
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      final point = _toNormalized(event.localPosition);
      _dragPointer = event.pointer;
      _dragStartPoint = point;
      _dragStartCrop = _crop;
      _dragHandle = isFullFrameCrop(_crop)
          ? CropHandle.outside
          : resolveCropHandle(point, _crop, _thresholdX, _thresholdY);
      if (_panEnabled) setState(() => _panEnabled = false);
    } else {
      // Second finger: cancel the crop drag and hand the gesture to the
      // viewer for pinch zoom / pan.
      _dragHandle = null;
      _dragPointer = null;
      if (!_panEnabled) setState(() => _panEnabled = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_saving || _dragHandle == null || event.pointer != _dragPointer) {
      return;
    }
    final point = _toNormalized(event.localPosition);
    final handle = _dragHandle!;
    setState(() {
      _crop = switch (handle) {
        CropHandle.outside => Rect.fromPoints(_dragStartPoint, point),
        CropHandle.inside => moveCropRect(
          _dragStartCrop,
          point - _dragStartPoint,
        ),
        _ => resizeCropRect(_dragStartCrop, handle, point),
      };
    });
  }

  void _endPointer(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _dragPointer) {
      _dragHandle = null;
      _dragPointer = null;
    }
    if (_pointers.isEmpty && _panEnabled) {
      setState(() => _panEnabled = false);
    }
  }

  void _zoomBy(double factor) {
    final size = _canvasSize;
    if (size == null || size.isEmpty || _image == null) return;
    final focal = _viewer.toScene(Offset(size.width / 2, size.height / 2));
    setState(() {
      _viewer.value = zoomTransform(_viewer.value, focal, factor);
    });
  }

  void _resetZoom() {
    setState(() => _viewer.value = Matrix4.identity());
  }

  Future<void> _rotate() async {
    if (_image == null || _saving) return;
    if (!isFullFrameCrop(_crop)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr("旋转会重置框选")),
          content: Text(context.tr("旋转后坐标系改变，当前框选将重置为全图。")),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr("取消")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr("旋转并重置")),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _turns = (_turns + 1) % 4;
      _crop = const Rect.fromLTRB(0, 0, 1, 1);
      _viewer.value = Matrix4.identity();
    });
  }

  Future<void> _save({bool split = false}) async {
    if (_image == null || _saving) return;
    setState(() => _saving = true);
    final store = ref.read(studyStoreProvider);
    final files = ref.read(appControllerProvider).files;
    final relative = 'attachments/${const Uuid().v4()}.png';
    String? newId;
    try {
      final bytes = await renderStudyCrop(_image!, _crop, _turns);
      if (bytes.length > 8 * 1024 * 1024) {
        throw const FormatException('编辑副本超过 8 MB，请框选更小区域后重试。');
      }
      if (widget.onCreate != null) {
        final created = await widget.onCreate!(bytes, _crop, _turns);
        if (mounted) Navigator.pop(context, created);
        return;
      }
      await files.resolve(relative).writeAsBytes(bytes, flush: true);
      await store.db.transaction(() async {
        if (split) {
          final original = await store.mistakeDetail(widget.ownerId);
          final row = await store.saveMistake(
            MistakeDraft(
              title: '${original.item.title.characters.take(145)} · 分题',
              subject: original.item.subject,
              chapter: original.item.chapter,
              tags: original.tags,
            ),
          );
          newId = row.id;
          final source =
              original.images.where((i) => i.role == 'original').firstOrNull ??
              widget.attachment;
          final reference = await store.addImageReference(
            row.id,
            source.relativePath,
            source.mime,
            source.byteLength,
            isMistake: true,
          );
          await store.addImageReference(
            row.id,
            relative,
            'image/png',
            bytes.length,
            isMistake: true,
            parentId: reference.id,
            role: 'crop',
          );
        } else {
          await store.addImageReference(
            widget.ownerId,
            relative,
            'image/png',
            bytes.length,
            isMistake: widget.isMistake,
            parentId: widget.attachment.id,
            role: 'crop',
          );
        }
      });
      store.changed();
      if (mounted) Navigator.pop(context, newId ?? widget.ownerId);
    } catch (e) {
      if (await files.resolve(relative).exists()) {
        await files.resolve(relative).delete();
      }
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : '图片保存失败，原图没有改变。',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.tr("取消编辑"),
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: Text(context.tr(widget.title)),
          actions: [
            IconButton(
              tooltip: context.tr("缩小"),
              onPressed: image == null || _saving
                  ? null
                  : () => _zoomBy(1 / 1.25),
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: context.tr("还原缩放"),
              onPressed: image == null || _saving ? null : _resetZoom,
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: context.tr("放大"),
              onPressed: image == null || _saving ? null : () => _zoomBy(1.25),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: context.tr("顺时针旋转"),
              onPressed: image == null || _saving ? null : _rotate,
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  context.tr(
                    "拖动框选要保留的区域；框内拖动可移动，拖动手柄可调整大小；双指缩放可放大查看。原图始终保留，编辑副本最长边为 2048 像素。",
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: image == null
                    ? Center(
                        child: _error == null
                            ? const CircularProgressIndicator()
                            : const Icon(Icons.broken_image_outlined, size: 40),
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: AspectRatio(
                            aspectRatio: _turns.isEven
                                ? image.width / image.height
                                : image.height / image.width,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                _canvasSize = Size(
                                  constraints.maxWidth,
                                  constraints.maxHeight,
                                );
                                final colors = Theme.of(context).colorScheme;
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fill(
                                      child: InteractiveViewer(
                                        transformationController: _viewer,
                                        minScale: 1,
                                        maxScale: 4,
                                        panEnabled: _panEnabled,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            RotatedBox(
                                              quarterTurns: _turns,
                                              child: RawImage(
                                                image: image,
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                            CustomPaint(
                                              painter: _CropPainter(
                                                _crop,
                                                primary: colors.primary,
                                                viewer: _viewer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Listener(
                                        key: const Key('crop-canvas'),
                                        behavior: HitTestBehavior.translucent,
                                        onPointerDown: _onPointerDown,
                                        onPointerMove: _onPointerMove,
                                        onPointerUp: _endPointer,
                                        onPointerCancel: _endPointer,
                                        child: const SizedBox.expand(),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    if (widget.onCreate == null && widget.allowSplit)
                      OutlinedButton(
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(),
                        child: Text(
                          _saving ? context.tr("保存中…") : context.tr("保存编辑副本"),
                        ),
                      ),
                    if (widget.isMistake && widget.allowSplit)
                      FilledButton(
                        key: const Key('split-mistake'),
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(split: true),
                        child: Text(
                          widget.onCreate != null
                              ? widget.createLabel
                              : context.tr("框选区域存为新错题"),
                        ),
                      ),
                    if (!widget.allowSplit)
                      FilledButton(
                        key: const Key('apply-image-edit'),
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(),
                        child: Text(
                          context.tr(_saving ? '保存中…' : widget.createLabel),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.crop, {required this.primary, required this.viewer})
    : super(repaint: viewer);
  final Rect crop;
  final Color primary;
  final TransformationController viewer;
  @override
  void paint(Canvas canvas, Size size) {
    // Border and handles keep a constant screen size whatever the zoom, so
    // they stay grabbable and readable on dense photos.
    final scale = viewer.value.getMaxScaleOnAxis();
    final rect = Rect.fromLTRB(
      crop.left * size.width,
      crop.top * size.height,
      crop.right * size.width,
      crop.bottom * size.height,
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(
      outside,
      Paint()..color = Colors.black.withValues(alpha: .45),
    );
    // High-contrast border: a white outer stroke reads on dark photos, the
    // theme primary inner stroke reads on light ones.
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 / scale,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / scale,
    );
    if (isFullFrameCrop(crop)) return;
    final half = 9 / scale;
    final border = 1.5 / scale;
    for (final point in [
      rect.topLeft,
      rect.topCenter,
      rect.topRight,
      rect.centerLeft,
      rect.centerRight,
      rect.bottomLeft,
      rect.bottomCenter,
      rect.bottomRight,
    ]) {
      final handle = Rect.fromCenter(
        center: point,
        width: half * 2,
        height: half * 2,
      );
      canvas.drawRect(handle, Paint()..color = Colors.white);
      canvas.drawRect(
        handle,
        Paint()
          ..color = primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = border,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.crop != crop || oldDelegate.primary != primary;
}

Future<void> cropImportedStudyPhoto(
  BuildContext context,
  String ownerId,
  StudyAttachment image, {
  required bool isMistake,
}) async {
  await showDialog<String>(
    context: context,
    useSafeArea: false,
    builder: (_) => StudyImageEditor(
      attachment: image,
      ownerId: ownerId,
      isMistake: isMistake,
      title: '编辑题目图片',
      createLabel: '保存图片编辑',
      allowSplit: false,
    ),
  );
}
