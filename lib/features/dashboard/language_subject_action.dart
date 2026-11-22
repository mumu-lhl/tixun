import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../core/l10n/app_strings.dart";

class LanguageSubjectAction extends StatelessWidget {
  const LanguageSubjectAction({required this.visible, super.key});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(
        ignoring: !visible,
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: AlignmentDirectional.topStart,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              alignment: Alignment.topCenter,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: visible
                ? Padding(
                    key: const ValueKey("language-action-visible"),
                    padding: const EdgeInsets.only(top: 16),
                    child: Card.filled(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        key: const Key("open-language-learning"),
                        leading: const Icon(Icons.translate),
                        title: Text(context.l10n.languageLearning),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push("/language"),
                      ),
                    ),
                  )
                : const SizedBox.shrink(
                    key: ValueKey("language-action-hidden"),
                  ),
          ),
        ),
      ),
    );
  }
}
