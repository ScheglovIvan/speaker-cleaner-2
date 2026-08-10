/// Tenjin attribution configuration (mirrors `attribution_config.json` — the
/// single source of truth for the provider and the SDK key).
///
/// MEASUREMENT ONLY: Tenjin attributes installs and subscription revenue back to
/// the campaign/creative that brought the user in. Traffic sources are connected
/// in the Tenjin dashboard, never in the app, so no ad network, campaign,
/// creative or tracking link is ever hardcoded here — and no ad SDK ships.
class AttributionConfig {
  AttributionConfig._();

  /// `provider` — the MMP this build reports to.
  static const String provider = 'tenjin';

  /// Tenjin SDK key (`sdk_key`). Empty disables attribution entirely.
  static const String sdkKey = '4S71O63SYK2Q4KAJOWYJWWB1ZJKDSAYQ';

  /// `att_usage_description` — mirrored into `ios_permissions.json` as
  /// `NSUserTrackingUsageDescription` (the copy shown in the ATT system dialog).
  static const String attUsageDescription =
      'Allow tracking so we can measure which ads bring people here and keep '
      'improving the app for you.';
}
