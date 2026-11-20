import "dart:async";

import "package:tixun/core/l10n/app_error.dart";
import "package:tixun/core/l10n/app_error_localization.dart";

import "dart:math" as math;
import "dart:typed_data";
import "dart:ui" as ui;

import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:uuid/uuid.dart";

import "../../app/controller.dart";
import "../../core/database/database.dart";
import "../../core/l10n/app_strings.dart";
import "library_providers.dart";
import "study_store.dart";

part "image_crop_geometry.dart";

part "image_crop_save.dart";

class StudyImageEditor extends ConsumerStatefulWidget {
  const StudyImageEditor({
    required this.attachment,
    this.ownerId = "",
    required this.isMistake,
    this.initialCrop,
    this.allowSplit = true,
    this.onCreate,
    this.createLabel,
    this.title,
    super.key,
  });
  final StudyAttachment attachment;
  final String ownerId;
  final bool isMistake, allowSplit;
  final Rect? initialCrop;
  final String? createLabel, title;
  final Future<String> Function(Uint8List bytes, Rect crop, int turns)?
  onCreate;
  @override
  ConsumerState<StudyImageEditor> createState() => _StudyImageEditorState();
}

class _StudyImageEditorState extends ConsumerState<StudyImageEditor> {
  ui.Image? _image;
  Object? _error;
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
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final file = ref
          .read(appControllerProvider)
          .files
          .resolve(widget.attachment.relativePath);
      if (await file.length() > 8 * 1024 * 1024) {
        throw const AppFormatException(
          AppErrorCode.errorTheImageExceedsTheEditorS,
          "图片超过编辑器的 8 MB 上限。",
        );
      }
      final bytes = await file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > 32000000) {
          throw const AppFormatException(
            AppErrorCode.errorTheImageResolutionIsTooLarge,
            "图片分辨率过大，请先缩小图片。原图记录未改变。",
          );
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
          () => _error = e is FormatException
              ? e
              : const AppFormatException(
                  AppErrorCode.errorImageCouldNotBeDecoded,
                  "图片无法解码。原图记录仍然保留。",
                ),
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
          title: Text(context.l10n.rotatingResetsTheCrop),
          content: Text(context.l10n.rotationChangesTheCoordinateSystem),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.rotateAndReset),
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

  void _update(VoidCallback update) => setState(update);
  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.l10n.cancelEditing,
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: Text(widget.title ?? context.l10n.cropAndSplit),
          actions: [
            IconButton(
              tooltip: context.l10n.zoomOut,
              onPressed: image == null || _saving
                  ? null
                  : () => _zoomBy(1 / 1.25),
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: context.l10n.resetZoom,
              onPressed: image == null || _saving ? null : _resetZoom,
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: context.l10n.zoomIn,
              onPressed: image == null || _saving ? null : () => _zoomBy(1.25),
              icon: const Icon(Icons.zoom_in),
            ),
            IconButton(
              tooltip: context.l10n.rotateClockwise,
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
                  context.l10n.dragToSelectTheArea,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    failureText(context.l10n, _error!),
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
                                        key: const Key("crop-canvas"),
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
                          _saving
                              ? context.l10n.savingEllipsis
                              : context.l10n.saveEditedCopy,
                        ),
                      ),
                    if (widget.isMistake && widget.allowSplit)
                      FilledButton(
                        key: const Key("split-mistake"),
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(split: true),
                        child: Text(
                          widget.onCreate != null
                              ? (widget.createLabel ??
                                    context.l10n.confirmCropAndSaveMistake)
                              : context.l10n.saveSelectionAsANew,
                        ),
                      ),
                    if (!widget.allowSplit)
                      FilledButton(
                        key: const Key("apply-image-edit"),
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(),
                        child: Text(
                          _saving
                              ? context.l10n.savingEllipsis
                              : widget.createLabel ??
                                    context.l10n.confirmCropAndSaveMistake,
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
      title: context.l10n.editPhoto,
      createLabel: context.l10n.useEditedPhoto,
      allowSplit: false,
    ),
  );
}
