import "dart:math" as math;

enum RecallRating { again, hard, good, easy }

typedef FsrsMemory = ({double stability, double difficulty});

/// FSRS-6 with the weights and day intervals of Py-FSRS 6.3.3.
/// Short learning steps belong to the practice queue.
class Fsrs {
  const Fsrs({this.retentionPercent = 90, this.maximumInterval = 180});

  static const version = "fsrs-6-py-6.3.3";
  static const _weights = [
    .212,
    1.2931,
    2.3065,
    8.2956,
    6.4133,
    .8334,
    3.0194,
    .001,
    1.8722,
    .1666,
    .796,
    1.4835,
    .0614,
    .2629,
    1.6483,
    .6014,
    1.8729,
    .5425,
    .0912,
    .0658,
    .1542,
  ];
  static const _decay = -.1542;
  static final _factor = math.pow(.9, 1 / _decay) - 1;
  final int retentionPercent;
  final int maximumInterval;

  ({FsrsMemory memory, int intervalDays, DateTime dueAt}) review({
    required RecallRating rating,
    required DateTime now,
    FsrsMemory? previous,
    DateTime? lastReview,
  }) {
    final grade = rating.index + 1;
    final memory = previous == null
        ? (
            stability: _weights[grade - 1],
            difficulty: _initialDifficulty(grade).clamp(1.0, 10.0),
          )
        : _update(previous, grade, now.difference(lastReview!).inDays);
    final interval =
        (memory.stability / _factor) *
        (math.pow(retentionPercent / 100, 1 / _decay) - 1);
    // Python rounds exact ties to the nearest even integer.
    final lower = interval.floor();
    final rounded = interval - lower == .5 && lower.isEven
        ? lower
        : interval.round();
    final days = rounded.clamp(1, maximumInterval);
    return (
      memory: memory,
      intervalDays: days,
      dueAt: now.toUtc().add(Duration(days: days)),
    );
  }

  static double _initialDifficulty(int grade) =>
      _weights[4] - math.exp(_weights[5] * (grade - 1)) + 1;

  static FsrsMemory _update(FsrsMemory previous, int grade, int elapsedDays) {
    final (:stability, :difficulty) = previous;
    final w = _weights;
    final nextDifficulty =
        w[7] * _initialDifficulty(4) +
        (1 - w[7]) * (difficulty - (10 - difficulty) * w[6] * (grade - 3) / 9);
    final double nextStability;
    if (elapsedDays <= 0) {
      final multiplier =
          math.exp(w[17] * (grade - 3 + w[18])) * math.pow(stability, -w[19]);
      nextStability =
          stability * (grade == 1 ? multiplier : math.max(1, multiplier));
    } else {
      final recallProbability = math.pow(
        1 + _factor * elapsedDays / stability,
        _decay,
      );
      if (grade == 1) {
        final longTerm =
            w[11] *
            math.pow(difficulty, -w[12]) *
            (math.pow(stability + 1, w[13]) - 1) *
            math.exp((1 - recallProbability) * w[14]);
        nextStability = math.min(longTerm, stability / math.exp(w[17] * w[18]));
      } else {
        final hardPenalty = grade == 2 ? w[15] : 1;
        final easyBonus = grade == 4 ? w[16] : 1;
        nextStability =
            stability *
            (1 +
                math.exp(w[8]) *
                    (11 - difficulty) *
                    math.pow(stability, -w[9]) *
                    (math.exp((1 - recallProbability) * w[10]) - 1) *
                    hardPenalty *
                    easyBonus);
      }
    }
    return (
      stability: math.max(.001, nextStability),
      difficulty: nextDifficulty.clamp(1.0, 10.0),
    );
  }
}
