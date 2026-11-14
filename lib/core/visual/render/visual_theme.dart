import 'dart:ui';

import 'package:material_ui/material_ui.dart' show ColorScheme;
import 'package:tixun/core/visual/model/visual_elements.dart';

/// Resolved colors for rendering a [VisualScene].
///
/// All colors are plain [Color]s resolved in `build()` from the theme's
/// [ColorScheme] — the painter never touches `Theme.of` inside `paint()`.
/// See [VisualPalette.fromColorScheme] for the DSL style → scheme mapping.
class VisualPalette {
  const VisualPalette({
    required this.primary,
    required this.highlight,
    required this.muted,
    required this.success,
    required this.danger,
    required this.axis,
    required this.grid,
    required this.background,
    required this.onBackground,
    required this.textMuted,
  });

  /// `primary` style; also the curve color for `model.expression`.
  final Color primary;

  /// `highlight` style.
  final Color highlight;

  /// `muted` style.
  final Color muted;

  /// `success` style. There is no green in the seed-based scheme, so this
  /// is a primary variant; success elements are additionally drawn dashed,
  /// so color alone never carries meaning.
  final Color success;

  /// `danger` style.
  final Color danger;

  /// Axis lines.
  final Color axis;

  /// Gridlines.
  final Color grid;

  /// Canvas background.
  final Color background;

  /// Default text / foreground on [background].
  final Color onBackground;

  /// Muted text (tick labels, annotations).
  final Color textMuted;

  /// DSL style → [ColorScheme] mapping:
  ///
  /// * `primary` → `colorScheme.primary`
  /// * `highlight` → `colorScheme.tertiary`
  /// * `muted` → `colorScheme.onSurfaceVariant`
  /// * `success` → `colorScheme.primary` (same hue as primary; the
  ///   renderer distinguishes success with a dashed line style instead —
  ///   there is no green role in the scheme)
  /// * `danger` → `colorScheme.error`
  ///
  /// Canvas chrome: gridlines → `outlineVariant`, axis lines →
  /// `onSurface` at 60% alpha, background → `surfaceContainerLow`,
  /// foreground → `onSurface`, muted text → `onSurfaceVariant`.
  factory VisualPalette.fromColorScheme(ColorScheme scheme) {
    return VisualPalette(
      primary: scheme.primary,
      highlight: scheme.tertiary,
      muted: scheme.onSurfaceVariant,
      success: scheme.primary,
      danger: scheme.error,
      axis: scheme.onSurface.withValues(alpha: 0.6),
      grid: scheme.outlineVariant,
      background: scheme.surfaceContainerLow,
      onBackground: scheme.onSurface,
      textMuted: scheme.onSurfaceVariant,
    );
  }

  Color colorForStyle(VisualStyle style) => switch (style) {
    VisualStyle.primary => primary,
    VisualStyle.highlight => highlight,
    VisualStyle.muted => muted,
    VisualStyle.success => success,
    VisualStyle.danger => danger,
  };

  @override
  bool operator ==(Object other) =>
      other is VisualPalette &&
      primary == other.primary &&
      highlight == other.highlight &&
      muted == other.muted &&
      success == other.success &&
      danger == other.danger &&
      axis == other.axis &&
      grid == other.grid &&
      background == other.background &&
      onBackground == other.onBackground &&
      textMuted == other.textMuted;

  @override
  int get hashCode => Object.hash(
    primary,
    highlight,
    muted,
    success,
    danger,
    axis,
    grid,
    background,
    onBackground,
    textMuted,
  );
}
