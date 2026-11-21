import "package:material_ui/material_ui.dart";

/// Centers a page body while letting narrow windows use the full width.
class PageContent extends StatelessWidget {
  const PageContent({required this.maxWidth, required this.child, super.key});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: maxWidth, child: child),
  );
}
