part of "visual_scene.dart";

sealed class VisualControl {
  const VisualControl({required this.id, required this.label});

  final String id;
  final String label;

  String get kind;

  Map<String, dynamic> toJson();

  factory VisualControl.fromJson(Map<String, dynamic> json) {
    final kind = json["kind"];
    if (kind is! String) {
      throw const AppFormatException(
        AppErrorCode.errorParameterMustBeText,
        "控件的 kind 必须是文字。",
      );
    }
    switch (kind) {
      case "slider":
        checkNoUnknownFields(json, const {
          "id",
          "kind",
          "label",
          "min",
          "max",
          "step",
          "value",
        }, "slider 控件");
        final sliderMin = _controlNumber(json, "min");
        final sliderMax = _controlNumber(json, "max");
        final sliderStep = _controlNumber(json, "step");
        final sliderValue = _controlNumber(json, "value");
        if (sliderMin >= sliderMax) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "slider 控件的 min 必须小于 max。",
            ["min"],
          );
        }
        if (sliderStep <= 0) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "slider 控件的 step 必须大于 0。",
            ["step"],
          );
        }
        if (sliderValue < sliderMin || sliderValue > sliderMax) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "slider 控件的 value 必须在 [min, max] 之间。",
            ["value"],
          );
        }
        return SliderControl(
          id: _controlId(json),
          label: _controlLabel(json),
          min: sliderMin,
          max: sliderMax,
          step: sliderStep,
          value: sliderValue,
        );
      case "toggle":
        checkNoUnknownFields(json, const {
          "id",
          "kind",
          "label",
          "value",
        }, "toggle 控件");
        final value = json["value"];
        if (value is! bool) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "toggle 控件的 value 必须是布尔值。",
            ["value"],
          );
        }
        return ToggleControl(
          id: _controlId(json),
          label: _controlLabel(json),
          value: value,
        );
      case "choice":
        checkNoUnknownFields(json, const {
          "id",
          "kind",
          "label",
          "options",
          "value",
        }, "choice 控件");
        final options = json["options"];
        if (options is! List || options.any((o) => o is! String)) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "choice 控件的 options 必须是文字数组。",
            ["options"],
          );
        }
        if (options.isEmpty) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "choice 控件的 options 不能为空。",
            ["options"],
          );
        }
        final choiceValue = _controlString(json, "value");
        if (!options.contains(choiceValue)) {
          throw const AppFormatException(
            AppErrorCode.errorInvalidParameterType,
            "choice 控件的 value 必须是 options 中的一项。",
            ["value"],
          );
        }
        return ChoiceControl(
          id: _controlId(json),
          label: _controlLabel(json),
          options: options.cast<String>(),
          value: choiceValue,
        );
      default:
        throw AppFormatException(
          AppErrorCode.errorInvalidParameterType,
          "未知的控件类型：$kind。",
          [kind],
        );
    }
  }
}

String _controlId(Map<String, dynamic> json) {
  final id = json["id"];
  if (id is! String || id.isEmpty) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "控件的 id 必须是非空文字。",
      ["id"],
    );
  }
  return id;
}

String _controlLabel(Map<String, dynamic> json) {
  final label = json["label"];
  if (label is! String || label.isEmpty) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidParameterType,
      "控件的 label 必须是非空文字。",
      ["label"],
    );
  }
  return label;
}

double _controlNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.toDouble().isFinite) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeNumber,
      "控件的 $key 必须是有限数字。",
      [key],
    );
  }
  return value.toDouble();
}

String _controlString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw AppFormatException(
      AppErrorCode.errorParameterMustBeText,
      "控件的 $key 必须是文字。",
      [key],
    );
  }
  return value;
}

/// Numeric slider bound to a model parameter (its `id` must match a
/// `model.parameters` key).
class SliderControl extends VisualControl {
  const SliderControl({
    required super.id,
    required super.label,
    required this.min,
    required this.max,
    required this.step,
    required this.value,
  });

  final double min;
  final double max;
  final double step;
  final double value;

  @override
  String get kind => "slider";

  @override
  Map<String, dynamic> toJson() => {
    "id": id,
    "kind": kind,
    "label": label,
    "min": min,
    "max": max,
    "step": step,
    "value": value,
  };
}

/// On/off switch. A toggle may gate an element via its `visibleWhen`.
class ToggleControl extends VisualControl {
  const ToggleControl({
    required super.id,
    required super.label,
    required this.value,
  });

  final bool value;

  @override
  String get kind => "toggle";

  @override
  Map<String, dynamic> toJson() => {
    "id": id,
    "kind": kind,
    "label": label,
    "value": value,
  };
}

/// Single-choice selector; `value` must be one of [options].
class ChoiceControl extends VisualControl {
  const ChoiceControl({
    required super.id,
    required super.label,
    required this.options,
    required this.value,
  });

  final List<String> options;
  final String value;

  @override
  String get kind => "choice";

  @override
  Map<String, dynamic> toJson() => {
    "id": id,
    "kind": kind,
    "label": label,
    "options": options,
    "value": value,
  };
}
