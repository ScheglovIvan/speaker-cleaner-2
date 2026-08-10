import 'package:apphud/apphud.dart';

/// Thin wrapper around Apphud that reports whether premium access is active.
///
/// [Apphud.hasPremiumAccess] is the single source of truth for the Pro gate —
/// there is no local "is pro" flag that can unlock features on its own; the
/// cached value in `AppState` only mirrors the last answer Apphud gave.
///
/// Every call is guarded so an unsupported platform (e.g. the headless web
/// preview, where the plugin has no implementation) or an unconfigured SDK
/// never crashes the app — they simply report "not Pro".
class EntitlementService {
  EntitlementService();

  void Function(bool isPro)? _onChanged;

  /// Ask Apphud whether the user currently has premium access.
  static Future<bool> hasPremiumAccess() async {
    try {
      return await Apphud.hasPremiumAccess();
    } catch (_) {
      // SDK not available / not started — treat as free tier.
      return false;
    }
  }

  /// Push an initial value and remember [onChanged] for later refreshes
  /// (launch, app resume, and after every purchase/restore).
  Future<void> start(void Function(bool isPro) onChanged) async {
    _onChanged = onChanged;
    await refresh();
  }

  /// Re-read premium access from Apphud (called at launch, on resume, and after
  /// a purchase or restore) and publish the result.
  Future<bool> refresh() async {
    final isPro = await hasPremiumAccess();
    _onChanged?.call(isPro);
    return isPro;
  }

  void dispose() {
    _onChanged = null;
  }
}
