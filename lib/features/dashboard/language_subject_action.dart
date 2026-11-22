import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";

import "../../core/l10n/app_strings.dart";

const _languageSubjects = {
  "语文",
  "中文",
  "汉语",
  "普通话",
  "chinese",
  "mandarin",
  "外语",
  "英语",
  "英文",
  "english",
  "日语",
  "日文",
  "japanese",
  "法语",
  "french",
  "德语",
  "german",
  "西班牙语",
  "spanish",
  "俄语",
  "russian",
  "韩语",
  "朝鲜语",
  "korean",
  "阿拉伯语",
  "arabic",
  "意大利语",
  "italian",
  "葡萄牙语",
  "portuguese",
};

bool isLanguageLearningSubject(String subject) {
  final label = subject.trim().toLowerCase();
  final qualifier = RegExp(r"\s*[（(]").firstMatch(label);
  return _languageSubjects.contains(label) ||
      qualifier != null &&
          _languageSubjects.contains(label.substring(0, qualifier.start));
}

class LanguageSubjectAction extends StatelessWidget {
  const LanguageSubjectAction({required this.subject, super.key});
  final String subject;

  @override
  Widget build(BuildContext context) {
    final visible = isLanguageLearningSubject(subject);
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
                    padding: EdgeInsets.zero,
                    child: OutlinedButton.icon(
                      key: const Key("open-language-learning"),
                      onPressed: () => context.push("/language"),
                      icon: const Icon(Icons.translate),
                      label: Text(context.l10n.languageLearning),
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
