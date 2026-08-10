/// Single source of truth for the app's legal links.
///
/// Referenced by the paywall/onboarding screen (0001) and Settings (0003) so
/// the Terms and Privacy links are identical everywhere. App Store review
/// requires a working Privacy Policy and Terms of Use link on any screen that
/// carries an auto-renewing subscription.
library;

/// Hosted privacy policy for the app.
const String kPrivacyPolicyUrl =
    'https://scheglovivan.github.io/speaker-cleaner-2/privacy';

/// Terms of Use — Apple's standard EULA for auto-renewable subscriptions.
const String kTermsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
