import 'package:tixun/core/l10n/app_error.dart';

import 'dart:math' as math;

class ReviewState {
  const ReviewState({
    this.repetitions = 0,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.lapses = 0,
  });
  final int repetitions, intervalDays, lapses;
  final double ease;
}

class ReviewDecision {
  const ReviewDecision(
    this.state,
    this.dueAt,
    this.quality,
    this.independent,
    this.reason,
  );
  final ReviewState state;
  final DateTime dueAt;
  final int quality;
  final bool independent;
  final String reason;
}

/// Transparent SM-2-inspired scheduling. Reading or a model's explanation never calls this.
ReviewDecision nextReview(
  ReviewState previous, {
  required bool correct,
  required bool hintUsed,
  required bool answerChecked,
  required DateTime now,
}) {
  if (previous.repetitions < 0 ||
      previous.intervalDays < 0 ||
      !previous.ease.isFinite ||
      previous.ease < 1.3 ||
      previous.ease > 3.5 ||
      previous.lapses < 0) {
    throw const AppFormatException(
      AppErrorCode.errorInvalidReviewStatus,
      '复习状态无效。',
    );
  }
  if (!correct) {
    return ReviewDecision(
      ReviewState(
        repetitions: 0,
        intervalDays: 0,
        ease: math.max(1.3, previous.ease - .2),
        lapses: previous.lapses + 1,
      ),
      now.add(const Duration(minutes: 10)),
      1,
      false,
      '本次需要订正，10 分钟后再尝试。',
    );
  }
  if (hintUsed || !answerChecked) {
    return ReviewDecision(
      ReviewState(
        repetitions: previous.repetitions,
        intervalDays: 1,
        ease: previous.ease,
        lapses: previous.lapses,
      ),
      now.add(const Duration(days: 1)),
      3,
      false,
      hintUsed ? '使用了提示，明天再独立检测。' : '参考答案尚未核对，明天再检测；不增加独立掌握次数。',
    );
  }
  final n = previous.repetitions + 1;
  final interval = n == 1
      ? 1
      : n == 2
      ? 6
      : (math.max(1, previous.intervalDays) * previous.ease).round().clamp(
          1,
          365,
        );
  return ReviewDecision(
    ReviewState(
      repetitions: n,
      intervalDays: interval,
      ease: previous.ease,
      lapses: previous.lapses,
    ),
    now.add(Duration(days: interval)),
    4,
    true,
    '独立做对，$interval 天后再次检测。',
  );
}
