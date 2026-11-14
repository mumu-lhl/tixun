import 'package:tixun/core/visual/model/visual_scene.dart';

/// One resolved frame of a scene's timeline: the complete input the
/// renderer needs for a given moment. Deterministic and seekable —
/// [resolveVisualFrame] is a pure function of (scene, timeMs[, stepIndex]).
class VisualFrame {
  const VisualFrame({
    required this.parameters,
    required this.toggles,
    required this.hiddenElementIds,
    required this.timeMs,
    required this.stepIndex,
  });

  /// Current slider/parameter values (control defaults + tracks).
  final Map<String, double> parameters;

  /// Current toggle values (control defaults; tracks never touch them).
  final Map<String, bool> toggles;

  /// Element ids hidden by the teaching steps at this moment. Base
  /// visibility (`visible: false`) and toggle gates are NOT in this set —
  /// the painter applies those itself.
  final Set<String> hiddenElementIds;

  /// The resolved moment in milliseconds.
  final double timeMs;

  /// Index of the current step (last step with `atMs <= timeMs`), or -1
  /// when no step applies yet. When [resolveVisualFrame] is called with
  /// an explicit `stepIndex`, this is that step's index.
  final int stepIndex;
}

/// Total timeline length in milliseconds, or 0 when the scene has no
/// timeline.
double visualDurationMs(VisualScene scene) =>
    (scene.timeline?.durationMs ?? 0).toDouble();

/// Resolves the frame of [scene] at [timeMs].
///
/// Tracks are applied in order: each track linearly interpolates its
/// target slider control from `from` to `to` over `[startMs, endMs]`
/// (clamped — before the window the value is `from`, after it `to`).
/// Later tracks on the same target override earlier ones. Steps with
/// `atMs <= timeMs` are applied in ascending `atMs` order; a later step
/// overrides an earlier one (`show` removes an id from the hidden set,
/// `hide` adds it).
///
/// When [stepIndex] is given, time is ignored for steps: exactly
/// `steps[stepIndex]` is applied on top of the track-resolved parameters
/// evaluated at that step's `atMs`, and the returned frame's [VisualFrame.timeMs]
/// is that step's `atMs`.
///
/// Never throws on a malformed timeline (defensive: unknown track
/// targets, non-finite values and degenerate windows are skipped);
/// validation owns rejecting bad timelines.
VisualFrame resolveVisualFrame(
  VisualScene scene, [
  double timeMs = 0,
  int? stepIndex,
]) {
  final parameters = Map<String, double>.of(scene.model?.parameters ?? {});
  for (final control in scene.controls.whereType<SliderControl>()) {
    parameters[control.id] = control.value;
  }
  final toggles = <String, bool>{
    for (final control in scene.controls.whereType<ToggleControl>())
      control.id: control.value,
  };

  final timeline = scene.timeline;
  if (timeline == null) {
    return VisualFrame(
      parameters: parameters,
      toggles: toggles,
      hiddenElementIds: const {},
      timeMs: timeMs,
      stepIndex: -1,
    );
  }

  final steps = List<VisualStep>.of(timeline.steps)
    ..sort((a, b) => a.atMs.compareTo(b.atMs));

  double resolvedTimeMs = timeMs;
  int resolvedStepIndex = -1;
  final hidden = <String>{};

  if (stepIndex != null &&
      stepIndex >= 0 &&
      stepIndex < timeline.steps.length) {
    final step = timeline.steps[stepIndex];
    resolvedTimeMs = step.atMs.toDouble();
    resolvedStepIndex = stepIndex;
    _applyTracks(timeline.tracks, parameters, resolvedTimeMs);
    hidden.addAll(step.hide);
    hidden.removeAll(step.show);
  } else {
    _applyTracks(timeline.tracks, parameters, timeMs);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      if (step.atMs > timeMs) break;
      resolvedStepIndex = _indexOf(timeline.steps, step);
      hidden.addAll(step.hide);
      hidden.removeAll(step.show);
    }
  }

  return VisualFrame(
    parameters: parameters,
    toggles: toggles,
    hiddenElementIds: hidden,
    timeMs: resolvedTimeMs,
    stepIndex: resolvedStepIndex,
  );
}

/// Index of [step] in the original (unsorted) step list; -1 if absent
/// (cannot happen for steps taken from the timeline itself).
int _indexOf(List<VisualStep> steps, VisualStep step) {
  for (var i = 0; i < steps.length; i++) {
    if (identical(steps[i], step)) return i;
  }
  return -1;
}

void _applyTracks(
  List<VisualTrack> tracks,
  Map<String, double> parameters,
  double timeMs,
) {
  for (final track in tracks) {
    if (!track.from.isFinite || !track.to.isFinite) continue;
    // Unknown target or a target with no current value: skip, never throw.
    if (!parameters.containsKey(track.target)) continue;
    final value = _trackValueAt(track, timeMs);
    if (value == null) continue;
    parameters[track.target] = value;
  }
}

/// Linear interpolation of [track] at [timeMs], clamped to [from, to].
/// Returns null for a degenerate window with no usable value.
double? _trackValueAt(VisualTrack track, double timeMs) {
  if (track.endMs == track.startMs) {
    // Instant jump at startMs (defensive: the validator requires
    // startMs < endMs, but the animator never throws).
    return timeMs < track.startMs ? track.from : track.to;
  }
  if (timeMs <= track.startMs) return track.from;
  if (timeMs >= track.endMs) return track.to;
  final t = (timeMs - track.startMs) / (track.endMs - track.startMs);
  final value = track.from + (track.to - track.from) * t;
  return value.isFinite ? value : null;
}
