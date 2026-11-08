import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

class InkStroke {
  InkStroke(this.color, this.width, List<Offset> points)
    : points = List.unmodifiable(points);
  final int color;
  final double width;
  final List<Offset> points;
  late final Path path = Path()..addPolygon(points, false);
  late final Rect bounds = path.getBounds().inflate(width / 2);
  Map<String, dynamic> toJson() => {
    'color': color,
    'width': width,
    'points': [
      for (final p in points) [p.dx, p.dy],
    ],
  };
}

class ScratchPage {
  ScratchPage({
    List<InkStroke> strokes = const [],
    this.offset = Offset.zero,
    this.scale = 1,
  }) : strokes = List.unmodifiable(strokes);
  final List<InkStroke> strokes;
  final Offset offset;
  final double scale;
  ScratchPage copyWith({
    List<InkStroke>? strokes,
    Offset? offset,
    double? scale,
  }) => ScratchPage(
    strokes: strokes ?? this.strokes,
    offset: offset ?? this.offset,
    scale: scale ?? this.scale,
  );
  Map<String, dynamic> toJson() => {
    'offset': [offset.dx, offset.dy],
    'scale': scale,
    'strokes': strokes.map((s) => s.toJson()).toList(),
  };
}

class ScratchDocument {
  ScratchDocument({List<ScratchPage>? pages, this.index = 0})
    : pages = List.unmodifiable(pages ?? [ScratchPage()]);
  final List<ScratchPage> pages;
  final int index;
  ScratchPage get page => pages[index];
  ScratchDocument replace(ScratchPage value) => ScratchDocument(
    pages: [...pages.take(index), value, ...pages.skip(index + 1)],
    index: index,
  );
  ScratchDocument select(int value) =>
      ScratchDocument(pages: pages, index: value.clamp(0, pages.length - 1));
  ScratchDocument addPage() {
    if (pages.length >= 100) throw const FormatException('一个草稿最多支持 100 页。');
    return ScratchDocument(
      pages: [...pages, ScratchPage()],
      index: pages.length,
    );
  }

  ScratchDocument deletePage() => pages.length == 1
      ? ScratchDocument()
      : ScratchDocument(
          pages: [...pages.take(index), ...pages.skip(index + 1)],
          index: math.min(index, pages.length - 2),
        );
  String encode() {
    final value = jsonEncode({
      'version': 1,
      'index': index,
      'pages': pages.map((p) => p.toJson()).toList(),
    });
    if (value.length > 8 * 1024 * 1024) {
      throw const FormatException('草稿内容过大，请整理后重试。');
    }
    return value;
  }

  factory ScratchDocument.decode(String text) {
    try {
      if (text.length > 8 * 1024 * 1024) throw const FormatException();
      final data = jsonDecode(text) as Map;
      if (data['version'] != 1) throw const FormatException();
      final rows = data['pages'] as List;
      if (rows.isEmpty || rows.length > 100) throw const FormatException();
      var pointCount = 0;
      double number(dynamic n, double min, double max) {
        if (n is! num || !n.isFinite || n < min || n > max) {
          throw const FormatException();
        }
        return n.toDouble();
      }

      Offset point(dynamic row) =>
          Offset(number(row[0], -1e9, 1e9), number(row[1], -1e9, 1e9));
      final pages = <ScratchPage>[];
      for (final row in rows) {
        final strokes = <InkStroke>[];
        for (final s in row['strokes'] as List) {
          final points = (s['points'] as List).map(point).toList();
          pointCount += points.length;
          if (points.isEmpty ||
              pointCount > 150000 ||
              s['color'] is! int ||
              s['color'] < 0 ||
              s['color'] > 0xffffffff) {
            throw const FormatException();
          }
          strokes.add(
            InkStroke(s['color'], number(s['width'], 0.01, 1000), points),
          );
        }
        pages.add(
          ScratchPage(
            strokes: strokes,
            offset: point(row['offset']),
            scale: number(row['scale'], 0.1, 8),
          ),
        );
      }
      final index = data['index'];
      if (index is! int || index < 0 || index >= pages.length) {
        throw const FormatException();
      }
      return ScratchDocument(pages: pages, index: index);
    } catch (_) {
      throw const FormatException('草稿无法读取，原内容仍保留。');
    }
  }
}

/// Sample continuous pointer motion so a fast stroke/eraser never skips gaps.
List<Offset> interpolate(Offset a, Offset b, double step) {
  final count = ((b - a).distance / step).ceil().clamp(1, 2000);
  return [for (var i = 1; i <= count; i++) Offset.lerp(a, b, i / count)!];
}

List<InkStroke> eraseInk(
  List<InkStroke> strokes,
  Offset center,
  double radius,
) {
  final result = <InkStroke>[];
  for (final stroke in strokes) {
    final limit = radius + stroke.width / 2;
    if (!stroke.bounds.inflate(radius).contains(center)) {
      result.add(stroke);
      continue;
    }
    if (!stroke.points.any((p) => (p - center).distance <= limit)) {
      result.add(stroke);
      continue;
    }
    var part = <Offset>[];
    for (final p in stroke.points) {
      if ((p - center).distance <= limit) {
        if (part.isNotEmpty) {
          result.add(InkStroke(stroke.color, stroke.width, part));
        }
        part = [];
      } else {
        part.add(p);
      }
    }
    if (part.isNotEmpty) {
      result.add(InkStroke(stroke.color, stroke.width, part));
    }
  }
  return result;
}
