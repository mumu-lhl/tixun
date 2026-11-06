import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'messages_en.g.dart';

Locale resolveAppLocale(Iterable<Locale> requested) {
  for (final locale in requested) {
    if (['zh', 'en'].contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('en');
}

/// Source-language keys keep the original Chinese wording readable in widgets.
/// Arguments are inserted after lookup; user material is never translated.
class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  static const delegate = _AppStringsDelegate();
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings(Locale('zh'));
  String text(String key, [List<Object?> arguments = const []]) {
    final text = locale.languageCode == 'en'
        ? englishMessages[key] ?? key
        : key;
    return text.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < arguments.length
          ? arguments[index]?.toString() ?? ''
          : match[0]!;
    });
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale));
  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

extension LocalizedContext on BuildContext {
  String subjectName(String value) =>
      AppStrings.of(this).locale.languageCode == 'en'
      ? const {
              '数学': 'Mathematics',
              '物理': 'Physics',
              '化学': 'Chemistry',
              '语文': 'Chinese',
              '英语': 'English',
              '地理': 'Geography',
              '生物': 'Biology',
              '历史': 'History',
              '政治': 'Politics',
            }[value] ??
            value
      : value;
  String tr(String key, [List<Object?> arguments = const []]) =>
      AppStrings.of(this).text(key, arguments);
}
