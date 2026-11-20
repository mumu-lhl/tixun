part of 'chat_screen.dart';

class Conversation extends ConsumerStatefulWidget {
  const Conversation({super.key});
  @override
  ConsumerState<Conversation> createState() => _ConversationState();
}

class _ConversationState extends ConsumerState<Conversation> {
  late final _scroll = ScrollController(
    onAttach: (position) =>
        position.isScrollingNotifier.addListener(_refreshScrollState),
    onDetach: (position) =>
        position.isScrollingNotifier.removeListener(_refreshScrollState),
  );
  late final TextEditingController _input;
  final _focus = FocusNode();
  bool _stick = true, _scrolling = false, _followScheduled = false;
  int _targetRevision = 0;
  int? _anchorIndex;
  final _anchorKey = GlobalKey();
  Size? _reportedViewport;
  String? _reportedSessionId;
  String? _composerSessionId;
  Offset? _lastComposerPoint;
  @override
  void initState() {
    super.initState();
    _input = TextEditingController(
      text: ref.read(appControllerProvider).selected?.draft ?? '',
    );
    _scroll.addListener(() => _refreshScrollState(positionChanged: true));
  }

  void _refreshScrollState({bool positionChanged = false}) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshScrollState(positionChanged: positionChanged),
      );
      return;
    }
    final position = _scroll.hasClients ? _scroll.position : null;
    final active = position?.isScrollingNotifier.value ?? false;
    final stick = positionChanged
        ? position == null || position.maxScrollExtent - position.pixels <= 24
        : _stick;
    if (active != _scrolling || stick != _stick) {
      setState(() {
        _scrolling = active;
        _stick = stick;
      });
    }
  }

  void _followBottom() {
    if (!_stick || _scrolling || _followScheduled) return;
    _followScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followScheduled = false;
      if (mounted && _scroll.hasClients && _stick && !_scrolling) {
        final bottom = _scroll.position.maxScrollExtent;
        if ((bottom - _scroll.offset).abs() > .5) _scroll.jumpTo(bottom);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() => ref.read(appControllerProvider).send(_input.text);

  Future<void> _import(String type) async {
    final c = ref.read(appControllerProvider);
    await act(context, () async {
      final picked = await pickPhotos(
        context,
        takePhoto: type == 'camera',
        filesOnly: type == 'file',
      );
      final added = <Attachment>[];
      for (final file in picked) {
        added.add(await c.addImage(file.path));
      }
      for (final image in added) {
        if (!mounted) break;
        await editChatPhoto(context, c, image);
      }
    });
  }

  // Demo-only geometry reporting for the GUI smoke script.
  //
  // The send point is reported once the draft can be sent. Typing updates the
  // draft without notifying the controller, so the button builder also asks
  // for a report when it observes a non-empty draft.
  void _scheduleComposerReport(Size viewport, String? sessionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reportedViewport == viewport) return;
      RenderBox? input, send;
      void visit(Element e) {
        if (e.widget.key == const Key('chat-input')) {
          input = e.findRenderObject() as RenderBox?;
        }
        if (e.widget.key == const Key('send-message')) {
          send = e.findRenderObject() as RenderBox?;
        }
        e.visitChildElements(visit);
      }

      context.visitChildElements(visit);
      if (input?.hasSize == true) {
        final ratio = MediaQuery.devicePixelRatioOf(context);
        final p =
            input!.localToGlobal(
              Offset(input!.size.width / 2, input!.size.height / 2),
            ) *
            ratio;
        if (_composerSessionId != sessionId || _lastComposerPoint != p) {
          debugPrint('TIXUN_COMPOSER_POINT ${p.dx.round()} ${p.dy.round()}');
          _lastComposerPoint = p;
          _composerSessionId = sessionId;
        }
        if (send?.hasSize == true) {
          final button =
              send!.localToGlobal(send!.size.center(Offset.zero)) * ratio;
          debugPrint(
            'TIXUN_SEND_POINT ${button.dx.round()} ${button.dy.round()}',
          );
          _reportedViewport = viewport;
        }
      }
    });
  }

  void _stickToBottom() => setState(() => _stick = true);

  @override
  Widget build(BuildContext context) {
    final c = ref.watch(appControllerProvider);
    final colors = Theme.of(context).colorScheme;
    final keyboard =
        MediaQuery.viewInsetsOf(context).bottom > 0 ||
        View.of(context).viewInsets.bottom > 0;
    final shortInput = keyboard || MediaQuery.sizeOf(context).height < 700;
    final reserveQuickActions = c.messages.isNotEmpty && !shortInput;
    final showQuickActions = reserveQuickActions && !c.busy;
    final viewport = MediaQuery.sizeOf(context);
    // A new session re-reports the composer geometry: the smoke script
    // waits for a fresh composer point after Ctrl+N.
    final sessionId = c.selected?.id;
    if (sessionId != _reportedSessionId) {
      _reportedSessionId = sessionId;
      _reportedViewport = null;
      _anchorIndex = null;
      _stick = true;
    }
    if (c.demo && _reportedViewport != viewport) {
      _scheduleComposerReport(viewport, sessionId);
    }

    final pending = c.attachments.where((a) => a.messageId == null).toList();
    if (_targetRevision != c.searchTargetRevision) {
      _targetRevision = c.searchTargetRevision;
      final index = c.messages.indexWhere(
        (m) => m.id == c.searchTargetMessageId,
      );
      if (index >= 0) {
        _anchorIndex = index;
        _stick = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
        });
      }
    }
    _followBottom();
    // Data-writing flows can send outside this widget. Observe committed
    // messages rather than a local send-button flag, including instant replies.
    // A newer draft or different text must survive the send.
    final sent = c.messages.where((m) => m.role == 'user').lastOrNull;
    if (c.selected?.draft.isEmpty == true &&
        _input.text.isNotEmpty &&
        _input.text.trim() == sent?.content.trim()) {
      _input.clear();
    }
    return LayoutBuilder(
      builder: (context, constraints) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter, control: true):
              _SendIntent(),
        },
        child: Actions(
          actions: {
            _SendIntent: CallbackAction<_SendIntent>(
              onInvoke: (_) {
                // Read the live state: typing does not rebuild this widget,
                // so the emptiness check must not rely on build-time values.
                final hasText = _input.text.trim().isNotEmpty;
                final hasPending = c.attachments.any(
                  (a) => a.messageId == null,
                );
                if (!c.busy && (hasText || hasPending)) _send();
                return null;
              },
            ),
          },
          child: Column(
            children: [
              _messagesPanel(context, c, colors),
              // Hide optional actions while typing, leaving room for photos
              // and the send button above the keyboard.
              Visibility(
                visible: showQuickActions,
                maintainState: reserveQuickActions,
                maintainAnimation: reserveQuickActions,
                maintainSize: reserveQuickActions,
                child: SizedBox(
                  height: 40,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 830),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          for (final text in [
                            context.l10n.giveMeAHint,
                            context.l10n.explainDifferently,
                            context.l10n.makeItSimpler,
                            context.l10n.showTheAnswer,
                            context.l10n.giveMeAnotherQuestion,
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(
                                  text,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onPressed: () {
                                  _input.text = text;
                                  c.draft(text);
                                  _focus.requestFocus();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _composer(
                context,
                c,
                colors,
                constraints,
                pending,
                viewport,
                keyboard: keyboard,
                shortInput: shortInput,
                sessionId: sessionId,
                reserveQuickActions: reserveQuickActions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}
