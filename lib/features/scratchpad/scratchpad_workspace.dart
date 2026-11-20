part of "scratchpad_screen.dart";

extension _ScratchpadWorkspace on _ScratchpadScreenState {
  Widget _buildWorkspace(BuildContext context) {
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
              key: "scratch-undo",
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
              key: "scratch-reset",
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
                                  key: Key("scratch-tool-${value.name}"),
                                  isSelected: tool == value,
                                  tooltip: switch (value) {
                                    _Tool.pen => context.l10n.pen,
                                    _Tool.eraser => context.l10n.eraser,
                                    _Tool.move => context.l10n.panAndZoom,
                                  },
                                  onPressed: () {
                                    _finish();
                                    _updateWorkspace(
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
                                    key: const Key("scratch-colors"),
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
                                                "scratch-color-$value",
                                              ),
                                              onPressed: () {
                                                _finish();
                                                _updateWorkspace(
                                                  () => color = value,
                                                );
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
                                    key: const Key("scratch-size"),
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
                                      _updateWorkspace(() {
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
                          key: const Key("scratch-canvas"),
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
                                  _updateWorkspace(
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
                                _updateWorkspace(
                                  () => error = ScratchpadError.tooManyPages,
                                );
                              }
                            },
                            key: "scratch-add-page",
                          ),
                          action(
                            context.l10n.deletePage,
                            Icons.delete_outline,
                            () => _confirm(true),
                            key: "scratch-delete-page",
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
                        _updateWorkspace(() => error = null);
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
