import "dart:async";

import "package:flutter/foundation.dart";

enum GenerationPhase { generating, validating, saving, comparing }

typedef GenerationActivity = ({
  String feature,
  GenerationPhase phase,
  int? completed,
  int? total,
});

final _activityKey = Object();

Future<T> trackLanguageGeneration<T>(
  ValueNotifier<GenerationActivity?> activity,
  Future<T> Function() action,
) async {
  activity.value = null;
  try {
    return await runZoned(action, zoneValues: {_activityKey: activity});
  } finally {
    activity.value = null;
  }
}

void reportLanguageGeneration(
  String feature,
  GenerationPhase phase, {
  int? completed,
  int? total,
}) {
  final activity =
      Zone.current[_activityKey] as ValueNotifier<GenerationActivity?>?;
  if (activity != null) {
    activity.value = (
      feature: feature,
      phase: phase,
      completed: completed,
      total: total,
    );
  }
}
