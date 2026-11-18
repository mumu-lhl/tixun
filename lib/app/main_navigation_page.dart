import 'package:material_ui/material_ui.dart';

/// A main destination keeps a stable Page type even when entered without a
/// bottom-bar gesture (deep links, shortcuts, or returning from a subpage).
class MainNavigationPage extends Page<void> {
  const MainNavigationPage({
    required this.child,
    this.direction = 0,
    super.key,
  });

  final Widget child;

  /// Physical horizontal direction in the navigation bar: -1 left, +1 right.
  /// Zero preserves the normal platform transition.
  final int direction;

  @override
  Route<void> createRoute(BuildContext context) => _MainNavigationRoute(this);
}

class _MainNavigationRoute extends PageRoute<void>
    with MaterialRouteTransitionMixin<void> {
  _MainNavigationRoute(MainNavigationPage page) : super(settings: page);

  MainNavigationPage get _page => settings as MainNavigationPage;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  bool get maintainState => true;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    if (_page.direction == 0) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    final progress = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_page.direction * .12, 0),
        end: Offset.zero,
      ).animate(progress),
      child: FadeTransition(opacity: progress, child: child),
    );
  }
}
