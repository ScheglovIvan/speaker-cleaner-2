/// Apphud configuration (mirrors `apphud_config.json` — the single source of
/// truth for the key, the placement and the product ids).
///
/// Apphud auto-detects the StoreKit sandbox vs production, so purchases work in
/// the sandbox without a live App Store link. The paywall reads its products —
/// and every price/title — from the placement at runtime; nothing here is a
/// hardcoded price.
class ApphudConfig {
  ApphudConfig._();

  /// Apphud SDK key (`sdk_key`).
  static const String sdkKey = 'appstr_5boAubroQ5B8nPDcU7fQ9pwoXjxxRhVxLg1';

  /// Placement identifier whose paywall drives screen 0001 (`placement`).
  static const String placement = 'main_speaker-cleaner';

  /// Headline weekly plan (`products[0]`) — used only to preselect a row when
  /// the placement returns several products.
  static const String weeklyProductId =
      'com.chritech.speakercleaner.speaker_deep_clean_pro_weekly';

  /// App bundle id the Apphud app is configured for.
  static const String bundleId = 'com.chritech.speakercleaner';

  /// `production` — real StoreKit products (sandbox when the build is).
  static const String mode = 'production';
}
