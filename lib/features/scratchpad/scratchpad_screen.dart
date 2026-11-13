import '../../core/ui/app_menu.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/controller.dart';
import '../../core/l10n/app_strings.dart';
import 'scratch_document.dart';
import 'scratchpad_exception.dart';
import 'scratch_store.dart';

class ScratchpadButton extends StatelessWidget {
  const ScratchpadButton(this.contextKey, {super.key});
  final String contextKey;
  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey('scratchpad-$contextKey'),
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
    _load();
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
      if (error != null && document != null) throw StateError('save');
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

  @override
  Widget build(BuildContext context) {
    final doc = document;
    Widget action(
      String tip,
      IconData icon,
      VoidCallback? onPressed, {
      String? key,
    }) => IconButton(
      key: key == null ? null : Key(key),
      tooltip: tip,
      onPressed: closing || onPressed == null
          ? null
          : () {
              _finish();
              onPressed();
            },
      icon: Icon(icon),
    );
    final screen = PopScope(
      canPop: closing || doc == null,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) unawaited(_close());
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: action(context.l10n.closeScratchpad, Icons.close, _close),
          title: Text(context.l10n.scratchpad),
          bottom: ref.read(appControllerProvider).demo
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(24),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      context.l10n.mockIsolatedDataNoAPI,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                )
              : null,
          actions: [
            action(
              context.l10n.undo,
              Icons.undo,
              undo.isEmpty
                  ? null
                  : () {
                      _finish();
                      redo.add(document!);
                      final value = undo.removeLast();
                      _change(value, remember: false);
                    },
              key: 'scratch-undo',
            ),
            action(
              context.l10n.redo,
              Icons.redo,
              redo.isEmpty
                  ? null
                  : () {
                      undo.add(document!);
                      _change(redo.removeLast(), remember: false);
                    },
            ),
            action(
              context.l10n.resetView,
              Icons.center_focus_strong,
              doc == null
                  ? null
                  : () => _change(
                      document!.replace(
                        document!.page.copyWith(offset: Offset.zero, scale: 1),
                      ),
                      remember: false,
                    ),
              key: 'scratch-reset',
            ),
          ],
        ),
        body: doc == null
            ? Center(
                child: error == null
                    ? const CircularProgressIndicator()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_errorText(error!)),
                          TextButton(
                            onPressed: _load,
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 384),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final value in _Tool.values)
                                IconButton.filledTonal(
                                  key: Key('scratch-tool-${value.name}'),
                                  isSelected: tool == value,
                                  tooltip: switch (value) {
                                    _Tool.pen => context.l10n.pen,
                                    _Tool.eraser => context.l10n.eraser,
                                    _Tool.move => context.l10n.panAndZoom,
                                  },
                                  onPressed: () {
                                    _finish();
                                    setState(
                                      () => tool =
                                          value == _Tool.move &&
                                              tool == _Tool.move
                                          ? _Tool.pen
                                          : value,
                                    );
                                  },
                                  icon: Icon(switch (value) {
                                    _Tool.pen => Icons.edit,
                                    _Tool.eraser => Icons.auto_fix_normal,
                                    _Tool.move => Icons.pan_tool_outlined,
                                  }),
                                ),
                              if (tool == _Tool.pen)
                                Flexible(
                                  child: SingleChildScrollView(
                                    key: const Key('scratch-colors'),
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final value in [
                                          0xff1f2937,
                                          0xff2563eb,
                                          0xffdc3d43,
                                          0xff177d56,
                                          0xff8b5cf6,
                                        ])
                                          Semantics(
                                            label: context.l10n.penColor(
                                              l10nArgument((switch (value) {
                                                0xff1f2937 =>
                                                  context.l10n.black,
                                                0xff2563eb => context.l10n.blue,
                                                0xffdc3d43 => context.l10n.red,
                                                0xff177d56 =>
                                                  context.l10n.green,
                                                _ => context.l10n.purple,
                                              })),
                                            ),
                                            selected: color == value,
                                            child: IconButton(
                                              key: ValueKey(
                                                'scratch-color-$value',
                                              ),
                                              onPressed: () {
                                                _finish();
                                                setState(() => color = value);
                                              },
                                              icon: Icon(
                                                color == value
                                                    ? Icons.check_circle
                                                    : Icons.circle,
                                                color: Color(value),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (tool != _Tool.move)
                          SizedBox(
                            width: 210,
                            child: Row(
                              children: [
                                Text(
                                  (tool == _Tool.pen
                                      ? context.l10n.width
                                      : context.l10n.eraserSize),
                                ),
                                Expanded(
                                  child: Slider(
                                    key: const Key('scratch-size'),
                                    min: tool == _Tool.pen ? 1 : 8,
                                    max: tool == _Tool.pen ? 12 : 64,
                                    value: tool == _Tool.pen
                                        ? width
                                        : eraserSize,
                                    label:
                                        (tool == _Tool.pen ? width : eraserSize)
                                            .round()
                                            .toString(),
                                    onChanged: (value) {
                                      _finish();
                                      setState(() {
                                        if (tool == _Tool.pen) {
                                          width = value;
                                        } else {
                                          eraserSize = value;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        action(
                          context.l10n.clearPage,
                          Icons.layers_clear_outlined,
                          () => _confirm(false),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ClipRect(
                      child: Listener(
                        onPointerDown: (event) {
                          if (tool == _Tool.move ||
                              activePointer != null ||
                              (event.buttons != 0 &&
                                  event.buttons & kPrimaryButton == 0)) {
                            return;
                          }
                          activePointer = event.pointer;
                          _beginInk(event.localPosition);
                        },
                        onPointerMove: (event) {
                          if (event.pointer == activePointer) {
                            _moveInk(event.localPosition);
                          }
                        },
                        onPointerUp: (event) {
                          if (event.pointer == activePointer) _finish();
                        },
                        onPointerCancel: (event) {
                          if (event.pointer == activePointer) _finish();
                        },
                        onPointerSignal: (event) {
                          if (tool != _Tool.move ||
                              event is! PointerScrollEvent) {
                            return;
                          }
                          final anchor = _world(event.localPosition);
                          final scale =
                              (doc.page.scale *
                                      math.exp(-event.scrollDelta.dy * .002))
                                  .clamp(.1, 8.0);
                          _change(
                            doc.replace(
                              doc.page.copyWith(
                                scale: scale,
                                offset: event.localPosition - anchor * scale,
                              ),
                            ),
                            remember: false,
                          );
                        },
                        child: GestureDetector(
                          key: const Key('scratch-canvas'),
                          behavior: HitTestBehavior.opaque,
                          onScaleStart: tool != _Tool.move
                              ? null
                              : (details) {
                                  gestureStart = document;
                                  startScale = document!.page.scale;
                                  focalWorld = _world(details.localFocalPoint);
                                  strokeTimer = Timer.periodic(
                                    const Duration(milliseconds: 500),
                                    (_) => _stage(),
                                  );
                                },
                          onScaleUpdate: tool != _Tool.move
                              ? null
                              : (details) {
                                  final scale = (startScale * details.scale)
                                      .clamp(.1, 8.0);
                                  setState(
                                    () => document = document!.replace(
                                      document!.page.copyWith(
                                        scale: scale,
                                        offset:
                                            details.localFocalPoint -
                                            focalWorld * scale,
                                      ),
                                    ),
                                  );
                                },
                          onScaleEnd: tool != _Tool.move
                              ? null
                              : (_) => _finish(),
                          child: CustomPaint(
                            painter: _InkPainter(
                              document!.page,
                              ink == null
                                  ? null
                                  : InkStroke(
                                      color,
                                      width / document!.page.scale,
                                      ink!,
                                    ),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          action(
                            context.l10n.previousPage,
                            Icons.chevron_left,
                            doc.index == 0
                                ? null
                                : () => _change(
                                    document!.select(document!.index - 1),
                                    remember: false,
                                  ),
                          ),
                          AppSelectField<int>(
                            compact: true,
                            initialValue: doc.index,
                            items: [
                              for (var i = 0; i < doc.pages.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    context.l10n.pageOfTotal(
                                      l10nArgument((i + 1)),
                                      l10nArgument((doc.pages.length)),
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (i) {
                              if (i != null) {
                                _change(document!.select(i), remember: false);
                              }
                            },
                          ),
                          action(
                            context.l10n.nextPage,
                            Icons.chevron_right,
                            doc.index == doc.pages.length - 1
                                ? null
                                : () => _change(
                                    document!.select(document!.index + 1),
                                    remember: false,
                                  ),
                          ),
                          action(
                            context.l10n.newPage,
                            Icons.note_add_outlined,
                            () {
                              try {
                                _change(document!.addPage());
                              } catch (_) {
                                setState(
                                  () => error = ScratchpadError.tooManyPages,
                                );
                              }
                            },
                            key: 'scratch-add-page',
                          ),
                          action(
                            context.l10n.deletePage,
                            Icons.delete_outline,
                            () => _confirm(true),
                            key: 'scratch-delete-page',
                          ),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: store,
                              builder: (_, _) => Text(
                                error != null || store.failure != null
                                    ? _errorText(error ?? store.failure!)
                                    : context.l10n.autoSaveMayLoseLastStroke,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: error != null || store.failure != null
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (error != null || store.failure != null)
                    TextButton(
                      onPressed: () async {
                        setState(() => error = null);
                        _stage();
                        await _flushQuietly();
                      },
                      child: Text(context.l10n.retrySaving),
                    ),
                ],
              ),
      ),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          _finish();
          if (document == null || undo.isEmpty || closing) return;
          redo.add(document!);
          _change(undo.removeLast(), remember: false);
        },
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () {
          _finish();
          if (document == null || redo.isEmpty || closing) return;
          undo.add(document!);
          _change(redo.removeLast(), remember: false);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            unawaited(_close()),
      },
      child: Focus(autofocus: true, child: screen),
    );
  }
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
