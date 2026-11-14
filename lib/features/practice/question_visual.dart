import 'dart:ui' as ui;

import '../../core/l10n/app_error.dart';
import '../../core/visual/model/visual_scene.dart';
import '../../core/visual/render/visual_animator.dart';
import '../../core/visual/render/visual_painter.dart';
import 'question_spec.dart';

/// Dedicated assessment prompts contain only their static question surface.
/// Content can still imply an answer: this is not a semantic secrecy proof.
void validateAssessmentScene(VisualScene scene) {
  bool hidden(List<VisualElement> elements) => elements.any(
    (e) =>
        !e.visible ||
        e.visibleWhen != null ||
        (e is GroupElement && hidden(e.children)),
  );
  if (scene.timeline != null ||
      scene.controls.isNotEmpty ||
      hidden(scene.elements)) {
    throw const AppFormatException(
      AppErrorCode.errorAssessmentFigureMustBeStatic,
      '题面图不能包含动画、参数控件或隐藏图元。',
    );
  }
}

/// Checks the actual pinned, initial frame, not a possibly newer live scene.
/// Used by the question Store for every write, including manual revisions.
void validateQuestionVisual(QuestionSpec spec, VisualScene scene) {
  if (!const {
    'point_select',
    'drag_to_target',
    'region_select',
  }.contains(spec.kind)) {
    return;
  }
  Never invalid() => throw const AppFormatException(
    AppErrorCode.errorVisualQuestionNotAnswerable,
    '图形缺少可见、可操作的作答目标，或区域选项与图形不一致。',
  );
  final frame = resolveVisualFrame(scene, 0);
  final mapper = VisualCoordinateMapper.fromScene(
    scene,
    const ui.Size(400, 300),
  );
  final view = mapper.modelRect;
  bool inView(ui.Offset p) =>
      p.dx >= view.left &&
      p.dx <= view.right &&
      p.dy >= view.top &&
      p.dy <= view.bottom;
  final visible = visualVisibleElements(
    scene,
    frame.toggles,
    frame.hiddenElementIds,
  );
  if (spec.kind == 'point_select' || spec.kind == 'drag_to_target') {
    final answer = parseVisualPoint(spec.answers.single.single);
    if (answer == null || !inView(ui.Offset(answer.$1, answer.$2))) invalid();
    if (spec.kind == 'drag_to_target' &&
        !visible.whereType<PointElement>().any((p) {
          final at = resolvePoint(p.at, frame.parameters);
          return p.draggable && p.at.isLiteral && at != null && inView(at);
        })) {
      invalid();
    }
    return;
  }

  // Subtract upper polygons just as region hit testing picks the topmost
  // one. A hidden, outside, degenerate or fully covered region is not an
  // answer control, even when its id exists in the source JSON.
  // Skia paths use float32 coordinates. Transform first so large model
  // offsets do not collapse otherwise-visible polygons to zero area.
  final viewPath = ui.Path()..addRect(mapper.canvasRect);
  var covered = ui.Path();
  final selectable = <String>{};
  for (final polygon in visible.whereType<PolygonElement>().toList().reversed) {
    final points = polygon.points
        .map((p) => resolvePoint(p, frame.parameters))
        .toList();
    if (points.any((p) => p == null)) continue;
    final first = mapper.modelToCanvas(points.first!);
    final path = ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final canvas = mapper.modelToCanvas(point!);
      path.lineTo(canvas.dx, canvas.dy);
    }
    path.close();
    final clipped = ui.Path.combine(ui.PathOperation.intersect, path, viewPath);
    final available = ui.Path.combine(
      ui.PathOperation.difference,
      clipped,
      covered,
    );
    if (!available.getBounds().isEmpty &&
        available.computeMetrics().any((m) => m.length > 0)) {
      selectable.add(polygon.id);
    }
    covered = ui.Path.combine(ui.PathOperation.union, covered, clipped);
  }
  if (!selectable.containsAll(spec.options.keys)) invalid();
}
