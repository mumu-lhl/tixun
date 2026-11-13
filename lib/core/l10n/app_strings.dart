import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

const supportedAppLocales = AppLocalizations.supportedLocales;

/// Preserves the legacy null-to-empty behavior when passing dynamic data to
/// generated String parameters.
String l10nArgument(Object? value) => value?.toString() ?? '';

Locale resolveAppLocale(Iterable<Locale> requested) {
  for (final locale in requested) {
    if (supportedAppLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    )) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('en');
}

extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      lookupAppLocalizations(const Locale('zh'));
  String subjectName(String value) => l10n.localeName == 'en'
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
}
