import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'entitlement_service.dart';
import 'languages.dart';
import 'plan.dart';
import 'remote_config.dart';

/// Central app state + local persistence.
///
/// Owns the five cross-screen concerns for this build:
///  * Maintenance history (which runs have been completed)
///  * Pro entitlement (cached locally, synced from Apphud)
///  * Selected language (persists + drives re-localization)
///  * Settings (onboarding flag, sound/haptics toggles)
///  * Remote-config gating (paywall-on-launch, premium feature locks)
///
/// Exposed to the widget tree via `AppScope`. It is a [ChangeNotifier]; screens
/// call the mutators below and rebuild from `notifyListeners()`. Every write is
/// persisted to [SharedPreferences] so state survives relaunches (the app has
/// no cloud sync — all state is on-device).
class AppState extends ChangeNotifier {
  AppState({
    RemoteConfigService? remoteConfigService,
    EntitlementService? entitlementService,
  })  : _remoteConfig = remoteConfigService ?? RemoteConfigService(),
        _entitlement = entitlementService ?? EntitlementService();

  // --- Persistence keys ---------------------------------------------------
  static const String _kCompletedDays = 'plan.completed_days';
  static const String _kIsPro = 'entitlement.is_pro';
  static const String _kLanguage = 'settings.language';
  static const String _kOnboardingComplete = 'settings.onboarding_complete';
  static const String _kSoundEnabled = 'settings.sound_enabled';
  static const String _kHapticsEnabled = 'settings.haptics_enabled';

  final RemoteConfigService _remoteConfig;
  final EntitlementService _entitlement;

  SharedPreferences? _prefs;
  bool _initialized = false;
  bool get isReady => _initialized;

  // --- Plan progress ------------------------------------------------------
  final Set<int> _completedDays = <int>{};

  /// Days (1-based) the user has finished at least once.
  Set<int> get completedDays => Set.unmodifiable(_completedDays);

  /// The effective plan (durations may be overridden by remote config).
  List<PlanDay> get plan => _remoteConfig.current.resolvePlan();

  /// The highest day the user is currently allowed to reach by *progress*
  /// alone (ignores the premium gate): 1 until a day is done, then max+1.
  int get nextSequentialDay {
    if (_completedDays.isEmpty) return 1;
    final maxDone = _completedDays.reduce((a, b) => a > b ? a : b);
    return (maxDone + 1).clamp(1, kPlanLength);
  }

  bool isDayCompleted(int day) => _completedDays.contains(day);

  /// A day is unlocked when the user has progressed to it sequentially AND the
  /// premium gate allows it (Day 1 is always free; later days need Pro when the
  /// `fullPlan` feature is gated).
  bool isDayUnlocked(int day) {
    if (day < 1 || day > kPlanLength) return false;
    if (day > nextSequentialDay) return false;
    final planDay = _dayConfig(day);
    if (planDay.premium && isFeatureLocked(PremiumFeature.fullPlan)) {
      return false;
    }
    return true;
  }

  PlanDay _dayConfig(int day) =>
      plan.firstWhere((d) => d.day == day, orElse: () => kDefaultPlan.first);

  /// Mark [day] complete. Persists and unlocks the next day. No-op if the day
  /// is not currently unlocked (can't skip ahead).
  Future<void> completeDay(int day) async {
    if (!isDayUnlocked(day)) return;
    if (_completedDays.add(day)) {
      await _persistCompletedDays();
      notifyListeners();
    }
  }

  /// Reset all plan progress (used by "Restart plan" affordances).
  Future<void> resetPlanProgress() async {
    if (_completedDays.isEmpty) return;
    _completedDays.clear();
    await _persistCompletedDays();
    notifyListeners();
  }

  Future<void> _persistCompletedDays() async {
    await _prefs?.setStringList(
      _kCompletedDays,
      _completedDays.map((d) => d.toString()).toList(),
    );
  }

  // --- Pro entitlement ----------------------------------------------------
  bool _isPro = false;

  /// Whether the user currently holds Pro.
  ///
  /// This mirrors the last answer from `Apphud.hasPremiumAccess()` (the single
  /// source of truth); the persisted copy only avoids a free-tier flash while
  /// Apphud is being queried at launch. It is re-read at launch, on app resume
  /// and after every purchase/restore.
  bool get isPro => _isPro;

  /// Update the cached Pro state (called by the entitlement refresh and after
  /// a purchase/restore). Persists and notifies when it changes.
  Future<void> setPro(bool value) async {
    if (_isPro == value) return;
    _isPro = value;
    await _prefs?.setBool(_kIsPro, value);
    notifyListeners();
  }

  /// Re-read premium access from Apphud (at launch, on resume, after returning
  /// from the paywall, and after a purchase/restore). Safe to call when the SDK
  /// is unavailable.
  Future<bool> refreshEntitlement() => _entitlement.refresh();

  // --- Language -----------------------------------------------------------
  String _languageCode = kDefaultLanguageCode;

  /// Currently selected language code (persisted).
  String get languageCode => _languageCode;

  /// The full option for the selected language.
  LanguageOption get language => languageForCode(_languageCode);

  /// All selectable languages.
  List<LanguageOption> get languages => kSupportedLanguages;

  /// Persist a new language selection and re-localize (screens rebuild on
  /// notify). No-op if unchanged or unknown.
  Future<void> setLanguage(String code) async {
    if (code == _languageCode) return;
    final known = kSupportedLanguages.any((l) => l.code == code);
    if (!known) return;
    _languageCode = code;
    await _prefs?.setString(_kLanguage, code);
    notifyListeners();
  }

  // --- Settings -----------------------------------------------------------
  bool _onboardingComplete = false;
  bool _soundEnabled = true;
  bool _hapticsEnabled = true;

  bool get onboardingComplete => _onboardingComplete;
  bool get soundEnabled => _soundEnabled;
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> setOnboardingComplete(bool value) async {
    if (_onboardingComplete == value) return;
    _onboardingComplete = value;
    await _prefs?.setBool(_kOnboardingComplete, value);
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    await _prefs?.setBool(_kSoundEnabled, value);
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    await _prefs?.setBool(_kHapticsEnabled, value);
    notifyListeners();
  }

  // --- Remote-config gating ----------------------------------------------
  RemoteConfig get remoteConfig => _remoteConfig.current;

  /// Whether [feature] is locked for the current user: gated by remote config
  /// AND the user is not Pro. Pro unlocks everything.
  bool isFeatureLocked(PremiumFeature feature) {
    // Premium access (from Apphud) unlocks every gated feature.
    if (isPro) return false;
    return _remoteConfig.current.gatedFeatures.contains(feature);
  }

  /// Where the launch flow should route after initialization (Home unless
  /// remote config asks for the paywall AND the user isn't already Pro).
  LaunchDestination get launchDestination {
    // Subscribers never get routed into the paywall.
    if (isPro) return LaunchDestination.home;
    return _remoteConfig.current.launchDestination;
  }

  /// Trial length to surface on the paywall.
  int get freeTrialDays => _remoteConfig.current.freeTrialDays;

  // --- Lifecycle ----------------------------------------------------------

  /// Load persisted state, fetch remote config, and begin syncing the
  /// entitlement. Guarded so a preview/test environment never blocks launch.
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadFromPrefs();
    } catch (_) {
      // Persistence unavailable — continue with in-memory defaults.
    }

    // Remote config (splash-time load). Never throws.
    await _remoteConfig.fetch();

    // Entitlement sync: seed from Apphud (`hasPremiumAccess`) at launch; the
    // app re-checks on resume and after every purchase/restore.
    await _entitlement.start((isPro) {
      // Fire-and-forget persist; setPro no-ops when unchanged.
      setPro(isPro);
    });

    _initialized = true;
    notifyListeners();
  }

  void _loadFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;

    _completedDays
      ..clear()
      ..addAll((prefs.getStringList(_kCompletedDays) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .where((d) => d >= 1 && d <= kPlanLength));

    _isPro = prefs.getBool(_kIsPro) ?? false;
    _languageCode = prefs.getString(_kLanguage) ?? kDefaultLanguageCode;
    _onboardingComplete = prefs.getBool(_kOnboardingComplete) ?? false;
    _soundEnabled = prefs.getBool(_kSoundEnabled) ?? true;
    _hapticsEnabled = prefs.getBool(_kHapticsEnabled) ?? true;
  }

  @override
  void dispose() {
    _entitlement.dispose();
    super.dispose();
  }
}
