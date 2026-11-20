part of "visual_painter.dart";

extension _VisualElementPainting on VisualPainter {
  void _paintText(
    ui.Canvas canvas,
    ui.Offset at,
    String text,
    TextStyle style,
    ui.Color color, {
    bool centerX = false,
    bool alignRight = false,
    bool centerY = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: color),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    var offset = at;
    if (centerX) offset -= ui.Offset(painter.width / 2, 0);
    if (alignRight) offset -= ui.Offset(painter.width, 0);
    if (centerY) offset -= ui.Offset(0, painter.height / 2);
    painter.paint(canvas, offset);
  }

  void _paintCurve(
    ui.Canvas canvas,
    VisualCoordinateMapper mapper,
    String expression,
    ui.Color color, {
    double width = 2,
    bool dashed = false,
    int maxSamples = 1024,
    (double, double)? domain,
  }) {
    final range = domain ?? (mapper.modelRect.left, mapper.modelRect.right);
    List<SampledSegment> segments;
    try {
      segments = sampleFunction(
        expression,
        variables: parameters,
        min: range.$1,
        max: range.$2,
        maxSamples: maxSamples,
      );
    } catch (_) {
      return; // Bad expression: skip silently, never crash paint().
    }
    final paint = ui.Paint()
      ..color = color
      ..strokeWidth = width
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;
    for (final segment in segments) {
      if (segment.points.isEmpty) continue;
      if (segment.points.length == 1) {
        // An isolated sample (e.g. a peak narrower than the sampling
        // step, or the only defined sample in the range) has no line
        // to draw — paint it as a dot instead of dropping it
        // silently, or the peak simply vanishes from the figure.
        canvas.drawCircle(
          mapper.modelToCanvas(segment.points.single),
          width,
          ui.Paint()..color = color,
        );
        continue;
      }
      final points = [for (final p in segment.points) mapper.modelToCanvas(p)];
      if (dashed) {
        _drawDashedPath(canvas, points, paint);
      } else {
        final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
        for (final p in points.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  /// Draws a polyline as dashes (6px on, 4px off).
  void _drawDashedPath(
    ui.Canvas canvas,
    List<ui.Offset> points,
    ui.Paint paint,
  ) {
    const dash = 6.0;
    const gap = 4.0;
    var draw = true;
    var remaining = dash;
    for (var i = 0; i + 1 < points.length; i++) {
      var a = points[i];
      final b = points[i + 1];
      var left = (b - a).distance;
      while (left > 0) {
        final step = math.min(remaining, left);
        final dir = (b - a) / (b - a).distance;
        final end = a + dir * step;
        if (draw) canvas.drawLine(a, end, paint);
        a = end;
        left -= step;
        remaining -= step;
        if (remaining <= 0) {
          draw = !draw;
          remaining = draw ? dash : gap;
        }
      }
    }
  }

  void _paintElement(
    ui.Canvas canvas,
    VisualCoordinateMapper mapper,
    VisualElement element,
  ) {
    final color = palette.colorForStyle(element.style);
    // Success is drawn dashed (same hue as primary): color alone never
    // carries meaning.
    final dashed = element.style == VisualStyle.success;
    ui.Paint stroke({double width = 2}) => ui.Paint()
      ..color = color
      ..strokeWidth = width
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round;

    switch (element) {
      case PointElement(at: final at, label: final label):
        final point =
            pointOverrides[element.id] ?? resolvePoint(at, parameters);
        if (point == null) return;
        final center = mapper.modelToCanvas(point);
        canvas.drawCircle(center, 4, ui.Paint()..color = color);
        if (label != null) {
          _paintText(
            canvas,
            center + const ui.Offset(7, -7),
            label,
            const TextStyle(fontSize: 12),
            palette.textMuted,
          );
        }
      case LineElement(p1: final p1, p2: final p2, dashed: final isDashed):
        final a = resolvePoint(p1, parameters);
        final b = resolvePoint(p2, parameters);
        if (a == null || b == null) return;
        final pa = mapper.modelToCanvas(a);
        final pb = mapper.modelToCanvas(b);
        if (isDashed || dashed) {
          _drawDashedPath(canvas, [pa, pb], stroke());
        } else {
          canvas.drawLine(pa, pb, stroke());
        }
      case PolylineElement(points: final points):
        final resolved = [for (final p in points) resolvePoint(p, parameters)];
        if (resolved.any((p) => p == null) || resolved.length < 2) return;
        final canvasPoints = [
          for (final p in resolved) mapper.modelToCanvas(p!),
        ];
        _drawDashedPathOrLine(canvas, canvasPoints, stroke(), dashed);
      case PolygonElement(points: final points, fill: final fill):
        final resolved = [for (final p in points) resolvePoint(p, parameters)];
        if (resolved.any((p) => p == null) || resolved.length < 3) return;
        final canvasPoints = [
          for (final p in resolved) mapper.modelToCanvas(p!),
        ];
        final path = ui.Path()
          ..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
        for (final p in canvasPoints.skip(1)) {
          path.lineTo(p.dx, p.dy);
        }
        path.close();
        if (fill) {
          canvas.drawPath(
            path,
            ui.Paint()
              ..color = color.withValues(alpha: 0.15)
              ..style = ui.PaintingStyle.fill,
          );
        }
        canvas.drawPath(path, stroke());
      case CircleElement(center: final center, r: final r):
        final c = resolvePoint(center, parameters);
        if (c == null) return;
        canvas.drawCircle(mapper.modelToCanvas(c), r * mapper.scale, stroke());
      case ArcElement(
        center: final center,
        r: final r,
        startDeg: final startDeg,
        sweepDeg: final sweepDeg,
      ):
        final c = resolvePoint(center, parameters);
        if (c == null) return;
        // Model angles are counter-clockwise from +x with y up; canvas
        // angles run clockwise with y down, hence the sign flip.
        canvas.drawArc(
          ui.Rect.fromCircle(
            center: mapper.modelToCanvas(c),
            radius: r * mapper.scale,
          ),
          -startDeg * math.pi / 180,
          -sweepDeg * math.pi / 180,
          false,
          stroke(),
        );
      case ArrowElement(from: final from, to: final to):
        final a = resolvePoint(from, parameters);
        final b = resolvePoint(to, parameters);
        if (a == null || b == null) return;
        final pa = mapper.modelToCanvas(a);
        final pb = mapper.modelToCanvas(b);
        final paint = stroke(width: 2);
        if (dashed) {
          _drawDashedPath(canvas, [pa, pb], paint);
        } else {
          canvas.drawLine(pa, pb, paint);
        }
        final dir = (pb - pa);
        final length = dir.distance;
        if (length > 0) {
          final unit = dir / length;
          const headLength = 12.0;
          const headAngle = 25 * math.pi / 180;
          for (final sign in const [1.0, -1.0]) {
            final angle = math.atan2(unit.dy, unit.dx) + sign * headAngle;
            final tip = ui.Offset(
              math.cos(angle + math.pi),
              math.sin(angle + math.pi),
            );
            canvas.drawLine(pb, pb + tip * headLength, paint);
          }
        }
      case TextElement(at: final at, text: final text):
        final point = resolvePoint(at, parameters);
        if (point == null) return;
        _paintText(
          canvas,
          mapper.modelToCanvas(point) + const ui.Offset(4, -8),
          text,
          const TextStyle(fontSize: 14),
          color,
        );
      case MathLabelElement():
        // Rendered as a Math.tex overlay by the widget, never on canvas.
        return;
      case GroupElement():
        // Flattened before painting; unreachable.
        return;
      case PlotElement(
        expression: final expression,
        domain: final domain,
        samples: final samples,
      ):
        _paintCurve(
          canvas,
          mapper,
          expression,
          color,
          width: 2,
          dashed: dashed,
          maxSamples: samples ?? 1024,
          domain: domain,
        );
      case CircuitElement(
        component: final component,
        from: final from,
        to: final to,
        at: final at,
        closed: final closed,
        meter: final meter,
        label: final label,
      ):
        // A const-constructed element may lack the fields its component
        // requires; fromJson guarantees them, so treat a missing one as
        // unresolvable (skip the element) rather than throwing.
        ui.Offset? pointOf(VisualPoint? p) =>
            p == null ? null : resolvePoint(p, parameters);
        ui.Offset? mid;
        switch (component) {
          case CircuitComponent.wire:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final pa = mapper.modelToCanvas(a);
            final pb = mapper.modelToCanvas(b);
            if (dashed) {
              _drawDashedPath(canvas, [pa, pb], stroke());
            } else {
              canvas.drawLine(pa, pb, stroke());
            }
            final dot = ui.Paint()..color = color;
            canvas.drawCircle(pa, 2.5, dot);
            canvas.drawCircle(pb, 2.5, dot);
          case CircuitComponent.resistor:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final canvasPoints = [
              for (final p in circuitZigzagPoints(a, b))
                mapper.modelToCanvas(p),
            ];
            final path = ui.Path()
              ..moveTo(canvasPoints.first.dx, canvasPoints.first.dy);
            for (final p in canvasPoints.skip(1)) {
              path.lineTo(p.dx, p.dy);
            }
            canvas.drawPath(path, stroke());
          case CircuitComponent.battery:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            final plates = circuitBatteryPlates(a, b);
            final longCenter = (plates.longA + plates.longB) / 2;
            final shortCenter = (plates.shortA + plates.shortB) / 2;
            canvas.drawLine(
              mapper.modelToCanvas(a),
              mapper.modelToCanvas(longCenter),
              stroke(),
            );
            canvas.drawLine(
              mapper.modelToCanvas(shortCenter),
              mapper.modelToCanvas(b),
              stroke(),
            );
            canvas.drawLine(
              mapper.modelToCanvas(plates.longA),
              mapper.modelToCanvas(plates.longB),
              stroke(width: 2.5),
            );
            canvas.drawLine(
              mapper.modelToCanvas(plates.shortA),
              mapper.modelToCanvas(plates.shortB),
              stroke(width: 2.5),
            );
          case CircuitComponent.powerSwitch:
            final a = pointOf(from);
            final b = pointOf(to);
            if (a == null || b == null) return;
            mid = (a + b) / 2;
            for (final (s, e) in circuitSwitchSegments(a, b, closed)) {
              final ps = mapper.modelToCanvas(s);
              final pe = mapper.modelToCanvas(e);
              if (dashed) {
                _drawDashedPath(canvas, [ps, pe], stroke());
              } else {
                canvas.drawLine(ps, pe, stroke());
              }
            }
            if (!closed) {
              final contact = a + (b - a) * 0.65;
              canvas.drawCircle(
                mapper.modelToCanvas(contact),
                2.5,
                ui.Paint()..color = color,
              );
            }
          case CircuitComponent.meter:
            final point = pointOf(at);
            if (point == null) return;
            mid = point;
            final center = mapper.modelToCanvas(point);
            canvas.drawCircle(center, 14, stroke());
            _paintText(
              canvas,
              center + const ui.Offset(-4, -8),
              meter == CircuitMeterKind.ammeter ? "A" : "V",
              const TextStyle(fontSize: 14),
              color,
            );
        }
        if (label != null) {
          _paintText(
            canvas,
            mapper.modelToCanvas(mid) + const ui.Offset(7, -7),
            label,
            const TextStyle(fontSize: 12),
            palette.textMuted,
          );
        }
    }
  }

  void _drawDashedPathOrLine(
    ui.Canvas canvas,
    List<ui.Offset> points,
    ui.Paint paint,
    bool dashed,
  ) {
    if (dashed) {
      _drawDashedPath(canvas, points, paint);
      return;
    }
    final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }
}
