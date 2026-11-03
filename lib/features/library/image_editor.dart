import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/controller.dart';
import '../../core/database/database.dart';
import 'library_providers.dart';
import 'study_store.dart';

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

class StudyImageEditor extends ConsumerStatefulWidget {
  const StudyImageEditor({
    required this.attachment,
    required this.ownerId,
    required this.isMistake,
    super.key,
  });
  final StudyAttachment attachment;
  final String ownerId;
  final bool isMistake;
  @override
  ConsumerState<StudyImageEditor> createState() => _StudyImageEditorState();
}

class _StudyImageEditorState extends ConsumerState<StudyImageEditor> {
  ui.Image? _image;
  String? _error;
  bool _saving = false;
  int _turns = 0;
  Rect _crop = const Rect.fromLTRB(0, 0, 1, 1);
  Offset? _start;
  @override
  void initState() {
    super.initState();
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
        final scale = math.min(
          1.0,
          2048 / math.max(descriptor.width, descriptor.height),
        );
        final codec = await descriptor.instantiateCodec(
          targetWidth: (descriptor.width * scale).round(),
          targetHeight: (descriptor.height * scale).round(),
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
    _image?.dispose();
    super.dispose();
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
            tooltip: '取消编辑',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
          title: const Text('裁剪与分题'),
          actions: [
            IconButton(
              tooltip: '顺时针旋转',
              onPressed: image == null || _saving
                  ? null
                  : () => setState(() {
                      _turns = (_turns + 1) % 4;
                      _crop = const Rect.fromLTRB(0, 0, 1, 1);
                    }),
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '拖动框选要保留的区域。原图始终保留，编辑副本最长边为 2048 像素。',
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
                              builder: (context, constraints) =>
                                  GestureDetector(
                                    key: const Key('crop-canvas'),
                                    onPanStart: _saving
                                        ? null
                                        : (d) {
                                            _start = Offset(
                                              (d.localPosition.dx /
                                                      constraints.maxWidth)
                                                  .clamp(0, 1),
                                              (d.localPosition.dy /
                                                      constraints.maxHeight)
                                                  .clamp(0, 1),
                                            );
                                          },
                                    onPanUpdate: _saving
                                        ? null
                                        : (d) {
                                            if (_start == null) return;
                                            final end = Offset(
                                              (d.localPosition.dx /
                                                      constraints.maxWidth)
                                                  .clamp(0, 1),
                                              (d.localPosition.dy /
                                                      constraints.maxHeight)
                                                  .clamp(0, 1),
                                            );
                                            setState(
                                              () => _crop = Rect.fromPoints(
                                                _start!,
                                                end,
                                              ),
                                            );
                                          },
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
                                          painter: _CropPainter(_crop),
                                        ),
                                      ],
                                    ),
                                  ),
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
                    OutlinedButton(
                      onPressed: image == null || _saving
                          ? null
                          : () => _save(),
                      child: Text(_saving ? '保存中…' : '保存编辑副本'),
                    ),
                    if (widget.isMistake)
                      FilledButton(
                        key: const Key('split-mistake'),
                        onPressed: image == null || _saving
                            ? null
                            : () => _save(split: true),
                        child: const Text('框选区域存为新错题'),
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
  const _CropPainter(this.crop);
  final Rect crop;
  @override
  void paint(Canvas canvas, Size size) {
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
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xffa5ead3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) => oldDelegate.crop != crop;
}
