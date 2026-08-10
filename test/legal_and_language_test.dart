import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_cleaner/core/legal_links.dart';
import 'package:speaker_cleaner/core/state/languages.dart';

/// App Store review readiness:
///  - the app ships English only until the string catalogue is complete
///    (Guideline 2.3), so the picker must offer exactly one language;
///  - the Terms and Privacy links are real and share a single source of truth.
void main() {
  group('supported languages', () {
    test('has exactly one entry, and it is English', () {
      expect(kSupportedLanguages, hasLength(1));
      final only = kSupportedLanguages.single;
      expect(only.code, 'en');
      expect(only.englishName, 'English');
      expect(kDefaultLanguageCode, 'en');
    });

    test('languageForCode always resolves to English, even for unknown codes', () {
      for (final code in ['en', 'fr', 'zh-Hans', 'ru', 'xx-unknown']) {
        expect(languageForCode(code).code, 'en');
      }
    });

    test('kSupportedLocales yields just the English locale', () {
      expect(kSupportedLocales, const [Locale('en')]);
    });
  });

  group('legal links', () {
    test('resolve to the shared constants', () {
      expect(kPrivacyPolicyUrl,
          'https://scheglovivan.github.io/speaker-cleaner-2/privacy');
      expect(kTermsOfUseUrl,
          'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/');
    });

    test('are well-formed absolute https URLs', () {
      for (final url in [kPrivacyPolicyUrl, kTermsOfUseUrl]) {
        final uri = Uri.parse(url);
        expect(uri.hasScheme, isTrue);
        expect(uri.scheme, 'https');
        expect(uri.host, isNotEmpty);
      }
    });
  });
}
