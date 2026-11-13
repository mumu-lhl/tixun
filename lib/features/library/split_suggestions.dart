import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' hide Column;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/controller.dart';
import '../../core/ai/region_tool.dart';
import '../../core/database/database.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/ui/actions.dart';
import 'image_editor.dart';
import 'study_store.dart';

Future<String> saveSplitSuggestion(
  StudyStore store,
  String operationId,
  int index,
  Uint8List bytes,
  Rect crop,
  int turns,
) => store.acceptQuestionRegion(operationId, index, bytes, (
  left: crop.left,
  top: crop.top,
  right: crop.right,
  bottom: crop.bottom,
), turns);

final _splitImageProvider = FutureProvider.autoDispose
    .family<Attachment?, String>((ref, id) {
      final db = ref.read(appControllerProvider).db;
      return (db.select(
        db.attachments,
      )..where((a) => a.id.equals(id))).getSingleOrNull();
    });

/// The rect an [image] occupies inside [box] under BoxFit.contain.
Rect displayRectForContain(Size box, Size image) {
  if (box.isEmpty || image.isEmpty) {
    return Rect.fromLTWH(0, 0, box.width, box.height);
  }
  final scale = math.min(box.width / image.width, box.height / image.height);
  final width = image.width * scale;
  final height = image.height * scale;
  return Rect.fromLTWH(
    (box.width - width) / 2,
    (box.height - height) / 2,
    width,
    height,
  );
}

/// Preview image with the AI-suggested regions drawn on top, each badged with
/// its list index so the user can match rows to boxes without opening the
/// editor per region. Tapping opens a zoomable view with the same overlay.
class _SplitPreview extends StatefulWidget {
  const _SplitPreview({required this.file, required this.regions});
  final File file;
  final List<QuestionRegion> regions;
  @override
  State<_SplitPreview> createState() => _SplitPreviewState();
}

class _SplitPreviewState extends State<_SplitPreview> {
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  @override
  void initState() {
    super.initState();
    final image = FileImage(widget.file);
    _stream = image.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      }
    });
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  Widget _content(BoxConstraints constraints, Size imageSize) {
    final box = Size(constraints.maxWidth, constraints.maxHeight);
    final display = displayRectForContain(box, imageSize);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(
            widget.file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(context.tr("图片无法解码。")),
          ),
        ),
        Positioned.fromRect(
          rect: display,
          child: CustomPaint(
            painter: _RegionOverlayPainter(
              widget.regions,
              border: colors.primary,
              badgeFill: colors.primary,
              badgeText: colors.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openZoom(Size imageSize) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    context.tr("分题原图 · 双指缩放查看"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.tr("关闭预览"),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.85,
                height: MediaQuery.sizeOf(context).height * 0.7,
                child: LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    minScale: 1,
                    maxScale: 6,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: _content(constraints, imageSize),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null) {
      return Image.file(
        widget.file,
        height: 200,
        cacheWidth: 700,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Text(context.tr("图片无法解码。")),
      );
    }
    return Semantics(
      label: context.tr("分题原图，点击放大查看"),
      button: true,
      child: InkWell(
        onTap: () => _openZoom(imageSize),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) => _content(constraints, imageSize),
          ),
        ),
      ),
    );
  }
}

class _RegionOverlayPainter extends CustomPainter {
  const _RegionOverlayPainter(
    this.regions, {
    required this.border,
    required this.badgeFill,
    required this.badgeText,
  });
  final List<QuestionRegion> regions;
  final Color border, badgeFill, badgeText;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < regions.length; i++) {
      final region = regions[i];
      final rect = Rect.fromLTRB(
        region.left * size.width,
        region.top * size.height,
        region.right * size.width,
        region.bottom * size.height,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final badgeCenter = Offset(rect.left + 13, rect.top + 13);
      canvas.drawCircle(badgeCenter, 11, Paint()..color = badgeFill);
      canvas.drawCircle(
        badgeCenter,
        11,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: badgeText,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        badgeCenter - Offset(label.width / 2, label.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_RegionOverlayPainter oldDelegate) =>
      oldDelegate.regions != regions ||
      oldDelegate.border != border ||
      oldDelegate.badgeFill != badgeFill ||
      oldDelegate.badgeText != badgeText;
}

class SplitSuggestionCard extends ConsumerWidget {
  const SplitSuggestionCard(this.operation, {super.key});
  final AiToolOperation operation;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(appControllerProvider);
    try {
      final data = (jsonDecode(operation.result!) as Map)
          .cast<String, dynamic>();
      final regions = (data['regions'] as List)
          .map(
            (r) => QuestionRegion.fromJson((r as Map).cast<String, dynamic>()),
          )
          .toList();
      final accepted = (data['accepted'] as Map? ?? {}).cast<String, dynamic>();
      final imageId = data['image_id'] as String;
      return ref
          .watch(_splitImageProvider(imageId))
          .when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(context.tr("正在读取…")),
              ],
            ),
            error: (_, _) => Row(
              children: [
                Expanded(child: Text(context.tr("分题原图读取失败。"))),
                TextButton(
                  onPressed: () => ref.invalidate(_splitImageProvider(imageId)),
                  child: Text(context.tr("重试")),
                ),
              ],
            ),
            data: (image) {
              if (image == null || image.sessionId != operation.sessionId) {
                return Text(context.tr("原图记录不存在，无法继续分题。"));
              }
              return Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("分题建议 · {0} 个范围", [regions.length]),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr("AI 边界可能不准确。逐题打开检查，可重新框选、旋转后保存；原图与裁剪结果都会保留。"),
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    _SplitPreview(
                      file: c.files.resolve(image.relativePath),
                      regions: regions,
                    ),
                    for (var i = 0; i < regions.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(regions[i].label),
                        subtitle: Text(context.subjectName(regions[i].subject)),
                        trailing: TextButton(
                          key: Key('check-region-$i'),
                          onPressed: () => act(context, () async {
                            final prior = accepted['$i'];
                            if (prior is String) {
                              context.push('/mistakes/$prior');
                              return;
                            }
                            final region = regions[i];
                            final selected = await showDialog<String>(
                              context: context,
                              useSafeArea: false,
                              builder: (_) => StudyImageEditor(
                                attachment: StudyAttachment(
                                  id: image.id,
                                  mistakeId: null,
                                  knowledgeId: null,
                                  relativePath: image.relativePath,
                                  mime: image.mime,
                                  byteLength: image.byteLength,
                                  parentId: null,
                                  role: 'original',
                                  deleted: false,
                                ),
                                isMistake: true,
                                initialCrop: Rect.fromLTRB(
                                  region.left,
                                  region.top,
                                  region.right,
                                  region.bottom,
                                ),
                                onCreate: (bytes, crop, turns) =>
                                    saveSplitSuggestion(
                                      c.study,
                                      operation.id,
                                      i,
                                      bytes,
                                      crop,
                                      turns,
                                    ),
                              ),
                            );
                            if (selected != null && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(context.tr("分题已保存，原图已保留。")),
                                  action: SnackBarAction(
                                    label: context.tr("查看"),
                                    onPressed: () =>
                                        context.push('/mistakes/$selected'),
                                  ),
                                ),
                              );
                            }
                          }),
                          child: Text(
                            accepted['$i'] is String
                                ? context.tr("查看错题")
                                : context.tr("检查并保存"),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
    } catch (_) {
      return Text(context.tr("分题建议数据不完整，请重新请求；已有资料未改变。"));
    }
  }
}
