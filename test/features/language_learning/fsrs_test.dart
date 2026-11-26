import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:tixun/features/language_learning/fsrs.dart";

void main() {
  final fixture = jsonDecode(
    File("test/fixtures/fsrs_reference.json").readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final scenario in (fixture["scenarios"] as List).cast<Map>()) {
    test("${fixture["reference"]} parity for ${scenario["name"]}", () {
      final scheduler = Fsrs(
        retentionPercent: scenario["retention"] as int,
        maximumInterval: scenario["cap"] as int,
      );
      FsrsMemory? memory;
      DateTime? lastReview;
      if (scenario["initial"] case final Map initial) {
        memory = (
          stability: (initial["stability"] as num).toDouble(),
          difficulty: (initial["difficulty"] as num).toDouble(),
        );
        lastReview = DateTime.parse(initial["last_review"] as String);
      }
      for (final vector in (scenario["ratings"] as List).cast<Map>()) {
        final now = DateTime.parse(vector["at"] as String);
        final actual = scheduler.review(
          rating: RecallRating.values.byName(vector["rating"] as String),
          now: now,
          previous: memory,
          lastReview: lastReview,
        );
        expect(actual.memory.stability, closeTo(vector["stability"], 1e-6));
        expect(actual.memory.difficulty, closeTo(vector["difficulty"], 1e-6));
        expect(actual.intervalDays, vector["days"]);
        expect(actual.dueAt, DateTime.parse(vector["due"] as String));
        memory = actual.memory;
        lastReview = now;
      }
    });
  }
}
