import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:apphud/apphud.dart';
import 'package:flutter/foundation.dart';
import 'package:tenjin_plugin/tenjin_sdk.dart';

import '../attribution_config.dart';

/// Tenjin attribution — installs, sessions and subscription revenue.
///
/// MEASUREMENT ONLY: nothing here serves an ad. Tenjin only tells the dashboard
/// which campaign/creative a user came from and what that user was worth; the
/// traffic sources themselves are connected in the Tenjin dashboard, never in
/// the app.
///
/// Launch sequence (driven from `main.dart` after the FIRST FRAME, because
/// Apple only shows the ATT dialog while the app is actually visible):
///   1. `AppTrackingTransparency.requestTrackingAuthorization()`
///   2. `TenjinSDK.instance.initialize(sdkKey: ...)`
///   3. `optIn()` when ATT was authorized, otherwise `optOut()`
///   4. `TenjinSDK.instance.connect()` — required on EVERY launch, not just the
///      first, which is why this runs on the normal startup path
///   5. IDFA (when granted) -> `Apphud.setAdvertisingIdentifier(...)` so the
///      subscription Apphud records is tied back to the acquiring campaign
///   6. `Apphud.collectSearchAdsAttribution()` — Apple Search Ads
///
/// Every step is individually guarded: an empty key short-circuits the whole
/// thing, and a missing plugin implementation (web preview / non-iOS) degrades
/// to "no attribution" instead of crashing launch or blocking the UI.
class AttributionService {
  AttributionService._();

  /// Single instance — the launch sequence must run exactly once per launch.
  static final AttributionService instance = AttributionService._();

  /// iOS returns this placeholder instead of a real IDFA when there is none.
  static const String _zeroIdfa = '00000000-0000-0000-0000-000000000000';

  bool _started = false;

  /// Run the full launch sequence. Safe to call more than once — only the first
  /// call does any work.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final key = AttributionConfig.sdkKey.trim();
    // No key configured (or no native side, e.g. the headless web preview) —
    // attribution is simply off; every other feature keeps working.
    if (key.isEmpty || kIsWeb) return;

    // The very first frame has been rendered by the time this runs, but iOS
    // still needs the app to reach the *active* state before it will present
    // the ATT dialog; requesting a beat later avoids a silently-dropped prompt.
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final authorized = await _requestTracking();

    try {
      TenjinSDK.instance.initialize(sdkKey: key);
      // Consent mirrors the ATT answer: attributed data only flows when the
      // user actually allowed tracking.
      if (authorized) {
        TenjinSDK.instance.optIn();
      } else {
        TenjinSDK.instance.optOut();
      }
      // Tenjin needs initialize + connect on every launch to register the
      // session (installs are deduplicated server-side).
      TenjinSDK.instance.connect();
    } catch (_) {
      // Plugin unavailable / not configured — skip attribution silently.
    }

    if (authorized) await _shareIdfaWithApphud();
    await _collectSearchAds();
  }

  /// Present the ATT system dialog and report whether tracking was authorized.
  /// (Re-requesting after the user already answered is a no-op on iOS — the
  /// plugin returns the stored status.)
  Future<bool> _requestTracking() async {
    try {
      final status =
          await AppTrackingTransparency.requestTrackingAuthorization();
      return status == TrackingStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  /// Hand the IDFA to Apphud so a subscription can be attributed to the
  /// campaign that acquired the user. Only reachable when ATT was granted; the
  /// all-zero IDFA means "no identifier" and is never forwarded.
  Future<void> _shareIdfaWithApphud() async {
    try {
      final idfa = await AppTrackingTransparency.getAdvertisingIdentifier();
      if (idfa.isEmpty || idfa == _zeroIdfa) return;
      await Apphud.setAdvertisingIdentifier(idfa);
    } catch (_) {
      // Not available on this platform — nothing to attribute.
    }
  }

  /// Apple Search Ads attribution (iOS only; a no-op elsewhere).
  Future<void> _collectSearchAds() async {
    try {
      await Apphud.collectSearchAdsAttribution();
    } catch (_) {
      // Non-iOS / unavailable.
    }
  }

  /// Report a subscription purchase to Tenjin so revenue lands on the right
  /// campaign and creative.
  ///
  /// MUST be called EXACTLY ONCE per successful purchase, from the
  /// purchase-result handler only — never on launch, never from a
  /// `hasPremiumAccess()` check, never on restore and never from a rebuild;
  /// repeated sends inflate revenue and corrupt ROAS.
  ///
  /// [product] is the Apphud product that was actually bought, so the reported
  /// id / price / currency always match what the store charged. Fields are read
  /// through `dynamic` (the `apphud` package does not export its model classes)
  /// and a missing price means the event is skipped rather than reported with a
  /// made-up amount.
  Future<void> reportSubscription(dynamic product) async {
    if (AttributionConfig.sdkKey.trim().isEmpty || kIsWeb) return;

    final productId = _productId(product);
    final price = _unitPrice(product);
    final currency = _currencyCode(product);
    if (productId.isEmpty || price == null || currency.isEmpty) return;

    try {
      TenjinSDK.instance.subscriptionWithStoreKit(
        productId: productId,
        currencyCode: currency,
        unitPrice: price,
      );
    } catch (_) {
      // Analytics only — a failed report must never affect the purchase.
    }
  }

  // --- Store-product field readers -----------------------------------------
  // Same defensive shape the paywall uses: the underlying wrapper differs per
  // store (`skProduct` on iOS, `productDetails` on Android), so every field is
  // probed through `dynamic` and falls through to the next candidate name.

  dynamic _storeProduct(dynamic product) {
    try {
      final dynamic sk = product.skProduct;
      if (sk != null) return sk;
    } catch (_) {
      // Not an iOS product wrapper.
    }
    try {
      final dynamic details = product.productDetails;
      if (details != null) return details;
    } catch (_) {
      // No store product attached.
    }
    return null;
  }

  String _productId(dynamic product) {
    for (final read in <String Function()>[
      () => '${product.productId}',
      () => '${product.id}',
      () => '${_storeProduct(product).productIdentifier}',
    ]) {
      try {
        final value = read();
        if (value.isNotEmpty && value != 'null') return value;
      } catch (_) {
        // Try the next field name.
      }
    }
    return '';
  }

  /// The numeric amount the store charges, exactly as the store reports it.
  double? _unitPrice(dynamic product) {
    final dynamic sp = _storeProduct(product);
    for (final read in <dynamic Function()>[
      () => sp.price,
      () => sp.rawPrice,
      () => product.price,
    ]) {
      try {
        final dynamic value = read();
        if (value == null) continue;
        if (value is num) return value.toDouble();
        final parsed = double.tryParse('$value');
        if (parsed != null) return parsed;
      } catch (_) {
        // Try the next field name.
      }
    }
    return null;
  }

  /// ISO currency code of that amount (e.g. `USD`).
  String _currencyCode(dynamic product) {
    final dynamic sp = _storeProduct(product);
    for (final read in <String Function()>[
      () => '${sp.priceLocale.currencyCode}',
      () => '${sp.currencyCode}',
      () => '${product.currencyCode}',
    ]) {
      try {
        final value = read();
        if (value.isNotEmpty && value != 'null') return value.toUpperCase();
      } catch (_) {
        // Try the next field name.
      }
    }
    return '';
  }
}
