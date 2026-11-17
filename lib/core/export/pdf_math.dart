/// Rasterize formulas at print resolution using the same engine as the UI.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:val_latex_flutter/val_latex_flutter.dart' as latex;

class PdfFormulaImage {
  const PdfFormulaImage(this.bytes, this.width, this.height, this.depth);
  final Uint8List bytes;

  /// Dimensions in em, relative to the surrounding text size.
  final double width, height, depth;
}

Future<PdfFormulaImage?> renderPdfFormula(
  String source, {
  required bool display,
}) async {
  final parsed = latex.parseLatex(
    source,
    options: const latex.ParseOptions(strict: latex.Strict.ignore),
  );
  if (parsed.hasErrors || parsed.incomplete) return null;
  final shaper = latex.ParagraphTextShaper();
  final layout = latex.layoutFormula(
    parsed,
    options: latex.LayoutOptions(displayMode: display),
    shaper: shaper,
  );
  if (!layout.width.isFinite ||
      !layout.height.isFinite ||
      !layout.depth.isFinite ||
      layout.width <= 0 ||
      layout.height + layout.depth <= 0) {
    return null;
  }
  // Bound individual allocations, including maliciously large input.
  const scale = 48.0;
  const padding = 4.0;
  final width = (layout.width * scale + 2 * padding).ceil();
  final height = ((layout.height + layout.depth) * scale + 2 * padding).ceil();
  if (width > 8192 || height > 2048 || width * height > 4000000) return null;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final painter = latex.MathPainter(shaper);
  await latex.MathPainter.preloadFontsOf(layout.items);
  painter.paint(
    canvas,
    ui.Offset(padding, padding + layout.height * scale),
    layout.items,
    fontSize: scale,
    color: const ui.Color(0xff000000),
    devicePixelRatio: 1,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(math.max(width, 1), math.max(height, 1));
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) return null;
  return PdfFormulaImage(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    width / scale,
    height / scale,
    (layout.depth * scale + padding) / scale,
  );
}
