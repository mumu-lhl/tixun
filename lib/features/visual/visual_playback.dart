part of "visual_card.dart";

extension _VisualPlayback on _VisualFullscreenPageState {
  void _startPlaying() {
    if (_durationMs <= 0) return;
    if (MediaQuery.of(context).disableAnimations) return;
    // Restart the authored animation: manual overrides for tracked
    // parameters give way to the tracks.
    for (final track in widget.scene.timeline?.tracks ?? const []) {
      _manualParameters.remove(track.target);
    }
    if (_timeMs >= _durationMs) _timeMs = 0;
    final controller = _controller ??=
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: (_durationMs / _speed).round()),
          )
          ..addListener(_onTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _updatePlayback(() {
                _playing = false;
                _timeMs = _durationMs;
              });
            }
          });
    controller.value = (_timeMs / _durationMs).clamp(0, 1);
    controller.forward();
    _updatePlayback(() => _playing = true);
  }

  void _onTick() {
    final controller = _controller;
    if (controller == null) return;
    _updatePlayback(() => _timeMs = controller.value * _durationMs);
  }

  void _pause() {
    _controller?.stop();
    _updatePlayback(() => _playing = false);
  }

  /// Switches playback speed, keeping the current position: the
  /// controller's value is a fraction of the authored duration, so
  /// changing its duration leaves `_timeMs` (value × duration) alone.
  /// Setting `duration` alone does not change a running controller's
  /// rate — the running simulation captured the old duration when
  /// `forward()` was called — so a playing controller is restarted
  /// from its current value for the new speed to take effect at once.
  void _setSpeed(double speed) {
    _updatePlayback(() => _speed = speed);
    final controller = _controller;
    if (controller != null) {
      controller.duration = Duration(
        milliseconds: (_durationMs / _speed).round(),
      );
      if (_playing) {
        controller.forward(from: controller.value);
      }
    }
  }

  void _seekTo(double timeMs) {
    final clamped = timeMs.clamp(0, _durationMs).toDouble();
    _controller?.value = _durationMs > 0 ? clamped / _durationMs : 0;
    _updatePlayback(() => _timeMs = clamped);
  }

  void _jumpToStep(int index) {
    final steps = _sortedSteps;
    if (index < 0 || index >= steps.length) return;
    _seekTo(steps[index].atMs.toDouble());
  }

  /// Two-finger pinch/pan on the canvas (a `Listener`, not a gesture
  /// recogniser, so it never competes with the point-drag recogniser
  /// below: one-finger drags keep dragging points, and the pinch only
  /// starts when the second finger lands).
  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length == 2) {
      final points = _activePointers.values.toList();
      _pinchStartDistance = (points[0] - points[1]).distance;
      _pinchStartMidpoint = (points[0] + points[1]) / 2;
      _pinchStartZoom = _zoom;
      _pinchStartPan = _pan;
      _updatePlayback(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.localPosition;
    if (_activePointers.length != 2 || _pinchStartDistance <= 0) return;
    final points = _activePointers.values.toList();
    final distance = (points[0] - points[1]).distance;
    final midpoint = (points[0] + points[1]) / 2;
    _updatePlayback(() {
      _zoom = (_pinchStartZoom * distance / _pinchStartDistance).clamp(
        0.5,
        4.0,
      );
      _pan = _pinchStartPan + (midpoint - _pinchStartMidpoint);
    });
  }

  void _onPointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2 && _pinching) {
      _updatePlayback(() => _pinching = false);
    }
  }

  Future<void> _exportPng(
    VisualPalette palette,
    Map<String, double> parameters,
    Map<String, bool> toggles,
  ) async {
    try {
      final bytes = await renderVisualPng(
        widget.scene,
        palette,
        parameters: parameters,
        toggles: toggles,
        pointOverrides: _pointOverrides,
        timeMs: _timeMs,
      );
      final dir = await getTemporaryDirectory();
      final file = File(
        "${dir.path}/visual-${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.visualSavedTo(file.path))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.visualExportFailed)));
    }
  }
}
