part of "visual_scene.dart";

class VisualTrack {
  const VisualTrack({
    required this.id,
    required this.target,
    required this.from,
    required this.to,
    required this.startMs,
    required this.endMs,
  });

  /// Track id (unique within the timeline).
  final String id;

  final String target;
  final double from;
  final double to;
  final int startMs;
  final int endMs;

  factory VisualTrack.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      "id",
      "target",
      "from",
      "to",
      "startMs",
      "endMs",
    }, "track");
    final id = json["id"];
    if (id is! String || id.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "track 的 id 必须是非空文字。",
        ["id"],
      );
    }
    final target = json["target"];
    if (target is! String || target.isEmpty) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "track 的 target 必须是非空文字。",
        ["target"],
      );
    }
    final trackStartMs = _trackInt(json, "startMs");
    final trackEndMs = _trackInt(json, "endMs");
    if (trackStartMs < 0 || trackEndMs < 0) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "track 的 startMs/endMs 不能小于 0。",
        ["startMs"],
      );
    }
    if (trackStartMs >= trackEndMs) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "track 的 startMs 必须小于 endMs。",
        ["startMs"],
      );
    }
    return VisualTrack(
      id: id,
      target: target,
      from: _trackNumber(json, "from"),
      to: _trackNumber(json, "to"),
      startMs: trackStartMs,
      endMs: trackEndMs,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "target": target,
    "from": from,
    "to": to,
    "startMs": startMs,
    "endMs": endMs,
  };
}

double _trackNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      "track 的 $key 必须是有限数字。",
      [key],
    );
  }
  return value.toDouble();
}

int _trackInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      "track 的 $key 必须是整数。",
      [key],
    );
  }
  return value;
}

/// One teaching step: show/hide elements at [atMs], with an optional note.
class VisualStep {
  const VisualStep({
    required this.atMs,
    this.show = const [],
    this.hide = const [],
    this.note,
  });

  final int atMs;
  final List<String> show;
  final List<String> hide;
  final String? note;

  factory VisualStep.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {"atMs", "show", "hide", "note"}, "step");
    final atMs = json["atMs"];
    if (atMs is! int) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        "step 的 atMs 必须是整数。",
      );
    }
    if (atMs < 0) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "step 的 atMs 不能小于 0。",
        ["atMs"],
      );
    }
    List<String> idList(String key) {
      final value = json[key];
      if (value == null) return const [];
      if (value is! List || value.any((v) => v is! String)) {
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "step 的 $key 必须是文字数组。",
          [key],
        );
      }
      return value.cast<String>();
    }

    final note = json["note"];
    if (note != null && note is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "step 的 note 必须是文字。",
      );
    }
    return VisualStep(
      atMs: atMs,
      show: idList("show"),
      hide: idList("hide"),
      note: note as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    "atMs": atMs,
    "show": show,
    "hide": hide,
    if (note != null) "note": note,
  };
}

class VisualTimeline {
  const VisualTimeline({
    required this.durationMs,
    this.tracks = const [],
    this.steps = const [],
  });

  final int durationMs;
  final List<VisualTrack> tracks;
  final List<VisualStep> steps;

  factory VisualTimeline.fromJson(Map<String, dynamic> json) {
    checkNoUnknownFields(json, const {
      "durationMs",
      "tracks",
      "steps",
    }, "timeline");
    final durationMs = json["durationMs"];
    if (durationMs is! int) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeNumber,
        "timeline 的 durationMs 必须是整数。",
      );
    }
    if (durationMs <= 0) {
      throw const AppFormatException(
        AppErrorCode.errorInvalidParameterType,
        "timeline 的 durationMs 必须是正整数。",
        ["durationMs"],
      );
    }
    List<VisualTrack> tracks = const [];
    if (json["tracks"] != null) {
      final raw = json["tracks"];
      if (raw is! List) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "timeline 的 tracks 必须是数组。",
          ["tracks"],
        );
      }
      tracks = raw.map((t) {
        if (t is! Map<String, dynamic>) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "track 必须是对象。",
            ["track"],
          );
        }
        return VisualTrack.fromJson(t);
      }).toList();
    }
    List<VisualStep> steps = const [];
    if (json["steps"] != null) {
      final raw = json["steps"];
      if (raw is! List) {
        throw const AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "timeline 的 steps 必须是数组。",
          ["steps"],
        );
      }
      steps = raw.map((s) {
        if (s is! Map<String, dynamic>) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "step 必须是对象。",
            ["step"],
          );
        }
        return VisualStep.fromJson(s);
      }).toList();
    }
    return VisualTimeline(durationMs: durationMs, tracks: tracks, steps: steps);
  }

  Map<String, dynamic> toJson() => {
    "durationMs": durationMs,
    "tracks": tracks.map((t) => t.toJson()).toList(),
    "steps": steps.map((s) => s.toJson()).toList(),
  };
}
