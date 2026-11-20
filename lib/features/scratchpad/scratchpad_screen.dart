import "../../core/ui/app_menu.dart";

import "dart:async";
import "dart:math" as math;

import "package:flutter/gestures.dart";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../app/controller.dart";
import "../../core/l10n/app_strings.dart";
import "scratch_document.dart";
import "scratchpad_exception.dart";
import "scratch_store.dart";

part "scratchpad_workspace.dart";

class ScratchpadButton extends StatelessWidget {
  const ScratchpadButton(this.contextKey, {super.key});
  final String contextKey;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey("scratchpad-$contextKey"),
    tooltip: context.l10n.scratchpad,
    icon: const Icon(Icons.draw_outlined),
    onPressed: () {
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => ScratchpadScreen(contextKey),
        ),
      );
    },
  );
}

enum _Tool { pen, eraser, move }

class ScratchpadScreen extends ConsumerStatefulWidget {
  const ScratchpadScreen(this.contextKey, {super.key});
  final String contextKey;
  @override
  ConsumerState<ScratchpadScreen> createState() => _ScratchpadScreenState();
}

class _ScratchpadScreenState extends ConsumerState<ScratchpadScreen> {
  late final ScratchStore store;
  late final AppLifecycleListener lifecycle;
  ScratchDocument? document;
  Object? error;

  String _errorText(Object issue) => switch (issue) {
    ScratchpadError.unreadable => context.l10n.cannotReadThisScratchpadThe,
    ScratchpadError.saveFailed => context.l10n.couldNotSaveTheScratchpad,
    ScratchpadError.tooManyPages => context.l10n.aScratchpadSupportsUpTo,
    ScratchpadError.tooLarge => context.l10n.thisScratchpadIsTooLarge,
    ScratchpadError.invalidContext => context.l10n.invalidScratchpadContext,
    _ => issue.toString(),
  };
  _Tool tool = _Tool.pen;
  int color = 0xff1f2937;
  double width = 3, eraserSize = 24;
  final undo = <ScratchDocument>[], redo = <ScratchDocument>[];
  List<Offset>? ink;
  ScratchDocument? gestureStart;
  Offset? lastPoint;
  Offset focalWorld = Offset.zero;
  double startScale = 1;
  int? activePointer;
  Timer? strokeTimer;
  bool closing = false;

  @override
  void initState() {
    super.initState();
    store = ref.read(appControllerProvider).scratch;
    lifecycle = AppLifecycleListener(
      onInactive: () {
        _finish();
        unawaited(_flushQuietly());
      },
    );
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final value = await store.load(widget.contextKey);
      if (mounted) {
        setState(() {
          document = value;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = ScratchpadError.unreadable);
    }
  }

  @override
  void dispose() {
    strokeTimer?.cancel();
    if (document != null && gestureStart != null) {
      // Best effort: commit an in-progress stroke so the store's autosave
      // timer can still persist it. dispose cannot await the flush itself.
      var committed = document!;
      if (ink != null) {
        committed = committed.replace(
          committed.page.copyWith(
            strokes: [
              ...committed.page.strokes,
              InkStroke(color, width / committed.page.scale, ink!),
            ],
          ),
        );
        ink = null;
      }
      gestureStart = null;
      try {
        store.stage(widget.contextKey, committed);
      } catch (_) {}
    }
    lifecycle.dispose();
    super.dispose();
  }

  Offset _world(Offset p) => (p - document!.page.offset) / document!.page.scale;
  void _beginInk(Offset local) {
    gestureStart = document;
    startScale = document!.page.scale;
    lastPoint = _world(local);
    if (tool == _Tool.pen) {
      ink = [lastPoint!];
    } else {
      document = document!.replace(
        document!.page.copyWith(
          strokes: eraseInk(
            document!.page.strokes,
            lastPoint!,
            eraserSize / 2 / startScale,
          ),
        ),
      );
    }
    strokeTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _stage(),
    );
    setState(() {});
  }

  void _moveInk(Offset local) {
    final point = _world(local);
    if (tool == _Tool.pen) {
      ink?.addAll(interpolate(lastPoint!, point, 1.5 / startScale));
    } else {
      var strokes = document!.page.strokes;
      for (final p in interpolate(
        lastPoint!,
        point,
        eraserSize / 4 / startScale,
      )) {
        strokes = eraseInk(strokes, p, eraserSize / 2 / startScale);
      }
      document = document!.replace(document!.page.copyWith(strokes: strokes));
    }
    lastPoint = point;
    setState(() {});
  }

  void _remember(ScratchDocument previous) {
    undo.add(previous);
    if (undo.length > 30) undo.removeAt(0);
    redo.clear();
  }

  void _stage() {
    if (document == null) return;
    try {
      final snapshot = ink == null
          ? document!
          : document!.replace(
              document!.page.copyWith(
                strokes: [
                  ...document!.page.strokes,
                  InkStroke(color, width / document!.page.scale, ink!),
                ],
              ),
            );
      store.stage(widget.contextKey, snapshot);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ScratchpadException
              ? e.code
              : e is FormatException
              ? e.message
              : ScratchpadError.saveFailed,
        );
      }
    }
  }

  Future<void> _flushQuietly() async {
    try {
      await store.flush();
    } catch (_) {}
  }

  void _finish() {
    strokeTimer?.cancel();
    activePointer = null;
    if (document == null || gestureStart == null) return;
    if (ink != null) {
      document = document!.replace(
        document!.page.copyWith(
          strokes: [
            ...document!.page.strokes,
            InkStroke(color, width / document!.page.scale, ink!),
          ],
        ),
      );
      ink = null;
    }
    if (tool != _Tool.move) _remember(gestureStart!);
    gestureStart = null;
    _stage();
    if (mounted) setState(() {});
  }

  Future<void> _close() async {
    if (closing) return;
    _finish();
    setState(() => closing = true);
    try {
      if (error != null && document != null) throw StateError("save");
      await store.flush();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        closing = false;
        error = ScratchpadError.saveFailed;
      });
      // A persistently failing save must not trap the user in the board:
      // offer an explicit discard-and-exit path instead of blocking forever.
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.saveFailedDiscardUnsavedContent),
          content: Text(ctx.l10n.unsavedStrokesWillBeLost),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.keepRetrying),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.discardAndExit),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _change(ScratchDocument next, {bool remember = true}) {
    _finish();
    if (remember) _remember(document!);
    setState(() {
      document = next;
      error = null;
    });
    _stage();
  }

  Future<void> _confirm(bool deletePage) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          (deletePage
              ? context.l10n.deleteThisPage
              : context.l10n.clearThisPage),
        ),
        content: Text(context.l10n.youCanUndoThisDuring),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      _change(
        deletePage
            ? document!.deletePage()
            : document!.replace(document!.page.copyWith(strokes: [])),
      );
    }
  }

  void _updateWorkspace(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildWorkspace(context);
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.page, this.active);
  final ScratchPage page;
  final InkStroke? active;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xfffffefa), BlendMode.src);
    canvas.save();
    canvas.translate(page.offset.dx, page.offset.dy);
    canvas.scale(page.scale);
    final grid = Paint()
      ..color = const Color(0xffe8e9eb)
      ..strokeWidth = .7 / page.scale;
    final step = 32 / page.scale;
    final left = -page.offset.dx / page.scale,
        top = -page.offset.dy / page.scale;
    for (
      double x = (left / step).floor() * step;
      x < left + size.width / page.scale;
      x += step
    ) {
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + size.height / page.scale),
        grid,
      );
    }
    for (
      double y = (top / step).floor() * step;
      y < top + size.height / page.scale;
      y += step
    ) {
      canvas.drawLine(
        Offset(left, y),
        Offset(left + size.width / page.scale, y),
        grid,
      );
    }
    for (final s in [...page.strokes, ?active]) {
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(
          s.points.single,
          s.width / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        canvas.drawPath(s.path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InkPainter oldDelegate) => true;
}
