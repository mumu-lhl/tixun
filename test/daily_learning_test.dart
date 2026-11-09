import 'package:flutter_test/flutter_test.dart';
import 'package:tixun/features/dashboard/daily_learning.dart';

void main() {
  test('examDatePassed compares calendar dates, not the time of day', () {
    final now = DateTime(2026, 11, 10, 10, 30);
    // The exam day itself (picked as midnight) is not past at any hour.
    expect(examDatePassed(DateTime(2026, 11, 10), now), isFalse);
    expect(examDatePassed(DateTime(2026, 11, 10, 23, 59), now), isFalse);
    expect(examDatePassed(DateTime(2026, 11, 11), now), isFalse);
    // Yesterday is past even when compared early in the morning.
    expect(examDatePassed(DateTime(2026, 11, 9), now), isTrue);
    expect(
      examDatePassed(DateTime(2026, 11, 9), DateTime(2026, 11, 10, 0, 0, 1)),
      isTrue,
    );
  });
}
