import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_strings.dart';

/// One image shown by [showImageViewer].
class ImageViewerItem {
  const ImageViewerItem({
    required this.file,
    this.heroTag,
    this.cacheWidth = 1600,
    this.errorText,
  });

  final File file;

  /// Hero tag shared with the thumbnail. Null disables the hero animation.
  final String? heroTag;

  final int? cacheWidth;

  /// Text shown when the file cannot be read; defaults to '图片无法读取'.
  final String? errorText;
}

/// Shows [images] in a full-screen viewer: double-tap/pinch zoom with
/// inertia, drag-down-to-dismiss, hero transition, swipe between images.
///
/// [title] is shown in the top bar; with more than one image a page counter
/// is appended. [actions] builds the bottom action row; it receives a
/// callback that closes the viewer (actions that open another page, e.g. the
/// crop editor, should close first). [footnote] is shown under the actions.
Future<void> showImageViewer(
  BuildContext context, {
  required List<ImageViewerItem> images,
  int initialIndex = 0,
  String? title,
  List<Widget> Function(VoidCallback closeViewer)? actions,
  String? footnote,
}) {
  assert(images.isNotEmpty);
  assert(initialIndex >= 0 && initialIndex < images.length);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) => _ImageViewerPage(
        images: images,
        initialIndex: initialIndex,
        title: title,
        actions: actions,
        footnote: footnote,
      ),
    ),
  );
}

class _ImageViewerPage extends StatefulWidget {
  const _ImageViewerPage({
    required this.images,
    required this.initialIndex,
    required this.title,
    required this.actions,
    required this.footnote,
  });

  final List<ImageViewerItem> images;
  final int initialIndex;
  final String? title;
  final List<Widget> Function(VoidCallback closeViewer)? actions;
  final String? footnote;

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late final ExtendedPageController _pageController;
  late int _index;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = ExtendedPageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  Widget _image(ImageViewerItem item) {
    final image = ExtendedImage.file(
      item.file,
      fit: BoxFit.contain,
      cacheWidth: item.cacheWidth,
      mode: ExtendedImageMode.gesture,
      enableSlideOutPage: true,
      initGestureConfigHandler: (_) => GestureConfig(
        minScale: 0.8,
        maxScale: 5.0,
        inPageView: widget.images.length > 1,
        cacheGesture: true,
      ),
      onDoubleTap: (ExtendedImageGestureState state) {
        final scale = state.gestureDetails?.totalScale ?? 1.0;
        state.handleDoubleTap(scale: scale > 1.5 ? 1.0 : 2.5);
      },
      loadStateChanged: (ExtendedImageState state) {
        if (state.extendedImageLoadState == LoadState.failed) {
          return Center(child: Text(item.errorText ?? context.tr('图片无法读取')));
        }
        return null;
      },
    );
    if (item.heroTag == null) return image;
    return Hero(tag: item.heroTag!, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = widget.actions?.call(_close);
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.both,
      slideType: SlideType.onlyImage,
      onSlidingPage: (state) {
        final showChrome = !state.isSliding;
        if (showChrome != _showChrome) {
          setState(() => _showChrome = showChrome);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                if (index != _index) setState(() => _index = index);
              },
              itemBuilder: (context, index) => _image(widget.images[index]),
            ),
            if (_showChrome)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.images.length > 1
                              ? '${widget.title ?? ''}  ${_index + 1} / ${widget.images.length}'
                              : (widget.title ?? ''),
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: context.tr('关闭预览'),
                        onPressed: _close,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showChrome && (actions != null || widget.footnote != null))
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (actions != null)
                          Wrap(spacing: 8, children: actions),
                        if (widget.footnote != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              widget.footnote!,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
