import 'package:flutter/widgets.dart' show Locale;

/// Supported display languages for the app.
///
/// The app targets a broad, global audience, so it ships 10+ locales. The
/// selected language persists locally and (per REQ-change-language) re-localizes
/// the UI. Language names are functional identifiers, so they are kept accurate
/// (not paraphrased).
class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.flag,
  });

  /// BCP-47-ish code, persisted as the selected-language key.
  final String code;

  /// Name in English (for reference / fallback labelling).
  final String englishName;

  /// Endonym shown in the picker row.
  final String nativeName;

  /// Emoji flag used as the row's circular glyph.
  final String flag;
}

/// The catalogue of languages offered in the Language screen (id `0004`).
///
/// The app ships English only for now: the string catalogue
/// (`lib/core/l10n/app_localizations.dart`) does not yet cover the full UI in
/// the other locales, and App Store review (Guideline 2.3) rejects a
/// half-translated interface. Until the translations are complete the picker
/// offers this single entry. (The [LanguageOption] type and the l10n catalogue
/// are intentionally kept so the extra locales can be restored later.)
const List<LanguageOption> kSupportedLanguages = <LanguageOption>[
  LanguageOption(
      code: 'en', englishName: 'English', nativeName: 'English', flag: '🇬🇧'),
];

/// Default language code when nothing is persisted yet.
const String kDefaultLanguageCode = 'en';

/// Look up a language by code, falling back to English if unknown.
LanguageOption languageForCode(String code) {
  for (final lang in kSupportedLanguages) {
    if (lang.code == code) return lang;
  }
  return kSupportedLanguages.first;
}

/// Convert a supported language [code] into a Flutter [Locale] (splitting off a
/// script subtag like `Hans`/`Hant` for Chinese). Drives `MaterialApp.locale`
/// so the framework's own widgets re-localize with the app's string catalogue.
Locale localeForCode(String code) {
  final parts = code.split('-');
  if (parts.length == 2 && parts[1].length == 4) {
    // language + script (e.g. zh-Hans / zh-Hant)
    return Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1]);
  }
  return Locale(parts.first);
}

/// The set of [Locale]s the app advertises to the framework — one per supported
/// language.
List<Locale> get kSupportedLocales =>
    kSupportedLanguages.map((l) => localeForCode(l.code)).toList();
