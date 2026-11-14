/// Pure model-space geometry for `circuit` elements.
///
/// All helpers work in model coordinates (y up) and return points or
/// segments the painter maps to canvas space. Keeping the geometry here
/// (no Canvas, no palette) makes the symbols unit-testable without a
/// widget or a picture recorder.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

/// Zigzag polyline for a `resistor` spanning `from` → `to`, including
/// the straight leads: the zigzag occupies the middle 60% of the
/// segment with three peaks, amplitude 12% of the segment length.
List<ui.Offset> circuitZigzagPoints(ui.Offset from, ui.Offset to) {
  final dir = to - from;
  final length = dir.distance;
  if (length <= 0) return [from, to];
  final unit = dir / length;
  final normal = ui.Offset(-unit.dy, unit.dx);
  final amp = 0.12 * length;
  final points = <ui.Offset>[from];
  // 20%..80% along, alternating +amp / -amp: three peaks up.
  const fractions = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8];
  for (var i = 0; i < fractions.length; i++) {
    final along = from + unit * (fractions[i] * length);
    final lift = (i == 0 || i == fractions.length - 1)
        ? 0.0
        : (i.isOdd ? amp : -amp);
    points.add(along + normal * lift);
  }
  points.add(to);
  return points;
}

/// The two plates of a `battery` spanning `from` → `to`.
///
/// The long plate (positive terminal) sits toward `from`, the short
/// plate toward `to`; both are perpendicular to the segment, separated
/// by a gap of 10% of the segment length. Plate lengths are 30% (long)
/// and 15% (short) of the segment length.
({ui.Offset longA, ui.Offset longB, ui.Offset shortA, ui.Offset shortB})
circuitBatteryPlates(ui.Offset from, ui.Offset to) {
  final dir = to - from;
  final length = dir.distance;
  final unit = length > 0 ? dir / length : const ui.Offset(1, 0);
  final normal = ui.Offset(-unit.dy, unit.dx);
  final mid = (from + to) / 2;
  final gap = 0.10 * length;
  final longCenter = mid - unit * (gap / 2);
  final shortCenter = mid + unit * (gap / 2);
  final longHalf = 0.15 * length;
  final shortHalf = 0.075 * length;
  return (
    longA: longCenter - normal * longHalf,
    longB: longCenter + normal * longHalf,
    shortA: shortCenter - normal * shortHalf,
    shortB: shortCenter + normal * shortHalf,
  );
}

/// Segments of a `switch` spanning `from` → `to`.
///
/// Closed: one straight segment. Open: a lead from `from` to 35% along
/// the segment, then a blade rising 30° (in model coordinates, y up)
/// from that point, 30% of the segment long.
List<(ui.Offset, ui.Offset)> circuitSwitchSegments(
  ui.Offset from,
  ui.Offset to,
  bool closed,
) {
  if (closed) return [(from, to)];
  final dir = to - from;
  final length = dir.distance;
  if (length <= 0) return [(from, to)];
  final unit = dir / length;
  final gapStart = from + unit * (0.35 * length);
  final bladeAngle = math.atan2(unit.dy, unit.dx) + math.pi / 6;
  final bladeEnd =
      gapStart +
      ui.Offset(math.cos(bladeAngle), math.sin(bladeAngle)) * (0.30 * length);
  return [(from, gapStart), (gapStart, bladeEnd)];
}
