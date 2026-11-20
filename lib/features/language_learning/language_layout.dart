import "dart:math" as math;

import "package:material_ui/material_ui.dart";

Widget languagePage({
  required List<Widget> children,
  double maxWidth = 760,
  double gap = 12,
}) => LayoutBuilder(
  builder: (context, constraints) {
    final inset = math.max(
      constraints.maxWidth < 560 ? 18.0 : 24.0,
      (constraints.maxWidth - maxWidth) / 2,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(inset, 20, inset, 32),
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0 && gap > 0) SizedBox(height: gap),
          child,
        ],
      ],
    );
  },
);
