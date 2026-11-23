import "package:material_ui/material_ui.dart";
import "package:flutter/rendering.dart" show ScrollDirection;

import "../l10n/app_strings.dart";
import "learning_markdown.dart";

/// Only provider-returned text or public summaries belong here.
class ReasoningPanel extends StatefulWidget {
  const ReasoningPanel({
    required this.text,
    this.generating = false,
    this.locked = false,
    super.key,
  });
  final String text;
  final bool generating, locked;
  @override
  State<ReasoningPanel> createState() => _ReasoningPanelState();
}

class _ReasoningPanelState extends State<ReasoningPanel>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    lowerBound: .35,
    upperBound: 1,
    value: 1,
  );
  bool expanded = false, _follow = true, _scheduled = false;
  bool _autoScrolling = false;
  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updatePulse();
  }

  @override
  void didUpdateWidget(ReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locked) expanded = false;
    _updatePulse();
    if (widget.text != oldWidget.text) _followBottom();
  }

  void _updatePulse() {
    if (widget.generating && !widget.locked && !_reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  void _followBottom() {
    if (!expanded ||
        widget.locked ||
        !_follow ||
        _scheduled ||
        _autoScrolling) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted ||
          !expanded ||
          widget.locked ||
          !_follow ||
          !_scroll.hasClients) {
        return;
      }
      final target = _scroll.position.maxScrollExtent;
      if ((target - _scroll.offset).abs() < 1) return;
      if (_reduceMotion) {
        _scroll.jumpTo(target);
        return;
      }
      _autoScrolling = true;
      try {
        await _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _autoScrolling = false;
        // Text may have grown while the previous follow animation was running.
        if (mounted && _follow) _followBottom();
      }
    });
  }

  bool _onScroll(ScrollNotification notice) {
    if (notice.depth != 0) return false;
    if (notice is UserScrollNotification) {
      // Do not pull the reader back down while they inspect earlier reasoning.
      if (notice.direction == ScrollDirection.forward) {
        _follow = false;
      } else if (notice.direction == ScrollDirection.idle) {
        _follow = notice.metrics.extentAfter <= 28;
        if (_follow) _followBottom();
      }
    }
    return false;
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = _reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: FadeTransition(
              opacity: _pulse,
              child: Icon(
                widget.locked ? Icons.lock_outline : Icons.psychology_outlined,
                color: widget.generating && !widget.locked
                    ? colors.primary
                    : null,
              ),
            ),
            title: AnimatedSwitcher(
              duration: duration,
              child: Align(
                key: ValueKey(widget.generating),
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.generating
                      ? context.l10n.thinking
                      : context.l10n.modelReasoning,
                ),
              ),
            ),
            trailing: widget.locked
                ? null
                : AnimatedRotation(
                    turns: expanded ? .5 : 0,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: const Icon(Icons.expand_more),
                  ),
            onTap: widget.locked
                ? null
                : () {
                    setState(() {
                      expanded = !expanded;
                      if (expanded) _follow = true;
                    });
                    _followBottom();
                  },
          ),
          // Locked content is replaced immediately, without an outgoing
          // crossfade that could leave answers mounted or exposed to semantics.
          if (!widget.locked)
            AnimatedSize(
              duration: duration,
              reverseDuration: duration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 8),
                          child: child,
                        ),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          border: Border.all(
                            color: colors.primary.withValues(alpha: .12),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: NotificationListener<ScrollMetricsNotification>(
                          onNotification: (_) {
                            _followBottom();
                            return false;
                          },
                          child: NotificationListener<ScrollNotification>(
                            onNotification: _onScroll,
                            child: Scrollbar(
                              controller: _scroll,
                              child: SingleChildScrollView(
                                controller: _scroll,
                                child: widget.text.isEmpty
                                    ? Text(
                                        context.l10n.waitingForReasoningFromThe,
                                      )
                                    : LearningMarkdown(
                                        widget.text,
                                        streaming: widget.generating,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
