part of "visual_validator.dart";

extension _VisualInteractionValidation on _Validator {
  void _checkControls(dynamic raw) {
    if (raw == null) return;
    if (raw is! List) {
      _error("invalid_type", "controls 必须是数组。", "controls");
      return;
    }
    if (raw.length > visualMaxControls) {
      _error(
        "limit_exceeded",
        "控件数量超过 $visualMaxControls 个（共 ${raw.length} 个）。",
        "controls",
      );
    }
    for (var i = 0; i < raw.length; i++) {
      _checkControl(raw[i], "controls[$i]");
    }
  }

  void _checkControl(dynamic raw, String path) {
    if (!_isMap(raw)) {
      _error("invalid_type", "控件必须是对象。", path);
      return;
    }
    final control = raw as Map<String, dynamic>;
    final kind = control["kind"];
    const perKind = {
      "slider": {"min", "max", "step", "value"},
      "toggle": {"value"},
      "choice": {"options", "value"},
    };
    if (kind is! String) {
      _error("missing_field", "控件缺少字段：kind。", "$path.kind");
      _checkUnknownFields(control, const {"id", "kind", "label"}, "控件", path);
      return;
    }
    if (!perKind.containsKey(kind)) {
      _error("invalid_value", "未知的控件类型：$kind。", "$path.kind");
      _checkUnknownFields(control, const {"id", "kind", "label"}, "控件", path);
      return;
    }
    _checkUnknownFields(
      control,
      {"id", "kind", "label", ...perKind[kind]!},
      "$kind 控件",
      path,
    );
    final id = control["id"];
    if (id == null) {
      _error("missing_field", "控件缺少字段：id。", "$path.id");
    } else if (id is! String || id.isEmpty) {
      _error("invalid_type", "控件的 id 必须是非空文字。", "$path.id");
    } else if (_controlKinds.containsKey(id)) {
      _error("duplicate_id", "控件 id 重复：$id。", "$path.id");
    } else {
      _controlKinds[id] = kind;
    }
    final label = control["label"];
    if (label == null) {
      _error("missing_field", "控件缺少字段：label。", "$path.label");
    } else if (label is! String || label.isEmpty) {
      _error("invalid_type", "控件的 label 必须是非空文字。", "$path.label");
    }
    switch (kind) {
      case "slider":
        final min = _finiteNumber(control["min"], "$path.min", "slider 的 min");
        final max = _finiteNumber(control["max"], "$path.max", "slider 的 max");
        final step = _finiteNumber(
          control["step"],
          "$path.step",
          "slider 的 step",
        );
        final value = _finiteNumber(
          control["value"],
          "$path.value",
          "slider 的 value",
        );
        if (control["min"] == null) {
          _error("missing_field", "slider 控件缺少字段：min。", "$path.min");
        }
        if (control["max"] == null) {
          _error("missing_field", "slider 控件缺少字段：max。", "$path.max");
        }
        if (control["step"] == null) {
          _error("missing_field", "slider 控件缺少字段：step。", "$path.step");
        }
        if (control["value"] == null) {
          _error("missing_field", "slider 控件缺少字段：value。", "$path.value");
        }
        if (min != null && max != null && min >= max) {
          _error("invalid_range", "slider 的 min 必须小于 max。", "$path.min");
        }
        if (step != null && step <= 0) {
          _error("invalid_range", "slider 的 step 必须大于 0。", "$path.step");
        }
        if (min != null &&
            max != null &&
            value != null &&
            (value < min || value > max)) {
          _error(
            "invalid_range",
            "slider 的 value 必须在 [min, max] 之间。",
            "$path.value",
          );
        }
        if (id is String && id.isNotEmpty && !_parameters.contains(id)) {
          _error(
            "unknown_parameter",
            "slider 控件 $id 没有对应的 model.parameters 参数。",
            "$path.id",
          );
        }
      case "toggle":
        if (control["value"] == null) {
          _error("missing_field", "toggle 控件缺少字段：value。", "$path.value");
        } else if (control["value"] is! bool) {
          _error("invalid_type", "toggle 控件的 value 必须是布尔值。", "$path.value");
        }
      case "choice":
        final options = control["options"];
        if (options == null) {
          _error("missing_field", "choice 控件缺少字段：options。", "$path.options");
        } else if (options is! List || options.any((o) => o is! String)) {
          _error(
            "invalid_type",
            "choice 控件的 options 必须是文字数组。",
            "$path.options",
          );
        } else if (options.isEmpty) {
          // An empty choice cannot satisfy the value-membership requirement.
          _error("invalid_value", "choice 控件的 options 不能为空。", "$path.options");
        }
        final value = control["value"];
        if (value == null) {
          _error("missing_field", "choice 控件缺少字段：value。", "$path.value");
        } else if (value is! String) {
          _error("invalid_type", "choice 控件的 value 必须是文字。", "$path.value");
        } else if (options is List &&
            options.every((o) => o is String) &&
            !options.contains(value)) {
          _error(
            "invalid_value",
            "choice 控件的 value 必须是 options 中的一项。",
            "$path.value",
          );
        }
    }
  }

  void _checkTimeline(dynamic raw) {
    if (raw == null) return;
    if (!_isMap(raw)) {
      _error("invalid_type", "timeline 必须是对象。", "timeline");
      return;
    }
    final timeline = raw as Map<String, dynamic>;
    _checkUnknownFields(
      timeline,
      const {"durationMs", "tracks", "steps"},
      "timeline",
      "timeline",
    );
    final durationMs = timeline["durationMs"];
    if (durationMs == null) {
      _error(
        "missing_field",
        "timeline 缺少字段：durationMs。",
        "timeline.durationMs",
      );
      return;
    }
    if (durationMs is! int) {
      _error(
        "invalid_type",
        "timeline 的 durationMs 必须是整数。",
        "timeline.durationMs",
      );
      return;
    }
    if (durationMs <= 0) {
      _error(
        "invalid_range",
        "timeline 的 durationMs 必须是正整数。",
        "timeline.durationMs",
      );
      return;
    }
    if (timeline["tracks"] != null) {
      final tracks = timeline["tracks"];
      if (tracks is! List) {
        _error("invalid_type", "timeline 的 tracks 必须是数组。", "timeline.tracks");
      } else {
        if (tracks.length > visualMaxTracks) {
          _error(
            "limit_exceeded",
            "动画轨道数量超过 $visualMaxTracks 条（共 ${tracks.length} 条）。",
            "timeline.tracks",
          );
        }
        final trackIds = <String>{};
        for (var i = 0; i < tracks.length; i++) {
          _checkTrack(tracks[i], "timeline.tracks[$i]", durationMs, trackIds);
        }
      }
    }
    if (timeline["steps"] != null) {
      final steps = timeline["steps"];
      if (steps is! List) {
        _error("invalid_type", "timeline 的 steps 必须是数组。", "timeline.steps");
      } else {
        if (steps.length > visualMaxSteps) {
          _error(
            "limit_exceeded",
            "教学步骤数量超过 $visualMaxSteps 步（共 ${steps.length} 步）。",
            "timeline.steps",
          );
        }
        int? previousAtMs;
        for (var i = 0; i < steps.length; i++) {
          final atMs = _checkStep(steps[i], "timeline.steps[$i]", durationMs);
          if (atMs != null) {
            if (previousAtMs != null && atMs < previousAtMs) {
              _warning(
                "steps_out_of_order",
                "教学步骤没有按 atMs 排序。",
                "timeline.steps[$i].atMs",
              );
            }
            previousAtMs = atMs;
          }
        }
      }
    }
  }

  void _checkTrack(
    dynamic raw,
    String path,
    int durationMs,
    Set<String> trackIds,
  ) {
    if (!_isMap(raw)) {
      _error("invalid_type", "track 必须是对象。", path);
      return;
    }
    final track = raw as Map<String, dynamic>;
    _checkUnknownFields(
      track,
      const {"id", "target", "from", "to", "startMs", "endMs"},
      "track",
      path,
    );
    final id = track["id"];
    if (id == null) {
      _error("missing_field", "track 缺少字段：id。", "$path.id");
    } else if (id is! String || id.isEmpty) {
      _error("invalid_type", "track 的 id 必须是非空文字。", "$path.id");
    } else if (!trackIds.add(id)) {
      _error("duplicate_id", "track id 重复：$id。", "$path.id");
    }
    final target = track["target"];
    if (target == null) {
      _error("missing_field", "track 缺少字段：target。", "$path.target");
    } else if (target is! String || target.isEmpty) {
      _error("invalid_type", "track 的 target 必须是非空文字。", "$path.target");
    } else if (!_controlKinds.containsKey(target)) {
      _error(
        "unknown_control",
        "track 的 target 引用了不存在的控件：$target。",
        "$path.target",
      );
    } else if (_controlKinds[target] != "slider") {
      _error(
        "invalid_track_target",
        "track 的 target 必须是 slider 控件：$target。",
        "$path.target",
      );
    }
    _finiteNumber(track["from"], "$path.from", "track 的 from");
    _finiteNumber(track["to"], "$path.to", "track 的 to");
    if (track["from"] == null) {
      _error("missing_field", "track 缺少字段：from。", "$path.from");
    }
    if (track["to"] == null) {
      _error("missing_field", "track 缺少字段：to。", "$path.to");
    }
    final startMs = track["startMs"];
    final endMs = track["endMs"];
    if (startMs == null) {
      _error("missing_field", "track 缺少字段：startMs。", "$path.startMs");
    } else if (startMs is! int) {
      _error("invalid_type", "track 的 startMs 必须是整数。", "$path.startMs");
    } else if (startMs < 0 || startMs > durationMs) {
      _error(
        "invalid_range",
        "track 的 startMs 必须在 [0, durationMs] 之间。",
        "$path.startMs",
      );
    }
    if (endMs == null) {
      _error("missing_field", "track 缺少字段：endMs。", "$path.endMs");
    } else if (endMs is! int) {
      _error("invalid_type", "track 的 endMs 必须是整数。", "$path.endMs");
    } else if (endMs < 0 || endMs > durationMs) {
      _error(
        "invalid_range",
        "track 的 endMs 必须在 [0, durationMs] 之间。",
        "$path.endMs",
      );
    }
    if (startMs is int && endMs is int && startMs >= endMs) {
      _error("invalid_range", "track 的 startMs 必须小于 endMs。", "$path.startMs");
    }
  }

  int? _checkStep(dynamic raw, String path, int durationMs) {
    if (!_isMap(raw)) {
      _error("invalid_type", "step 必须是对象。", path);
      return null;
    }
    final step = raw as Map<String, dynamic>;
    _checkUnknownFields(
      step,
      const {"atMs", "show", "hide", "note"},
      "step",
      path,
    );
    final atMsRaw = step["atMs"];
    int? atMs;
    if (atMsRaw == null) {
      _error("missing_field", "step 缺少字段：atMs。", "$path.atMs");
    } else if (atMsRaw is! int) {
      _error("invalid_type", "step 的 atMs 必须是整数。", "$path.atMs");
    } else if (atMsRaw < 0 || atMsRaw > durationMs) {
      _error(
        "invalid_range",
        "step 的 atMs 必须在 [0, durationMs] 之间。",
        "$path.atMs",
      );
    } else {
      atMs = atMsRaw;
    }
    for (final key in ["show", "hide"]) {
      final list = step[key];
      if (list == null) continue;
      if (list is! List || list.any((v) => v is! String)) {
        _error("invalid_type", "step 的 $key 必须是文字数组。", "$path.$key");
        continue;
      }
      for (final id in list.cast<String>()) {
        if (!_elementIds.contains(id)) {
          _error(
            "unknown_element_reference",
            "step 的 $key 引用了不存在的图元：$id。",
            "$path.$key",
          );
        }
      }
    }
    if (step["note"] != null && step["note"] is! String) {
      _error("invalid_type", "step 的 note 必须是文字。", "$path.note");
    }
    return atMs;
  }
}
