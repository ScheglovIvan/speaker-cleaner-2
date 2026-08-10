import 'plan.dart';

/// Premium-gated feature areas. Remote config decides which of these are locked
/// for free users; the Pro entitlement always unlocks everything.
enum PremiumFeature {
  allModes,
  fullPlan,
  stereoMixer,
  dbMeter,
  adFree,
}

/// Where the launch flow should route once initialization finishes.
enum LaunchDestination { home, paywall }

/// Immutable snapshot of remote-config values.
///
/// In the original app these come from Firebase Remote Config (paywall
/// placement, gated features, plan durations). This build has no custom
/// backend, so [RemoteConfigService] resolves them locally from safe defaults,
/// but the shape and gating semantics match remote-config-driven behaviour and
/// can be swapped for a real fetch without touching call sites.
class RemoteConfig {
  const RemoteConfig({
    required this.showPaywallOnLaunch,
    required this.paywallVariant,
    required this.gatedFeatures,
    required this.planDurationOverridesSeconds,
    required this.freeTrialDays,
  });

  /// If true, the splash routes straight to the paywall instead of Home.
  final bool showPaywallOnLaunch;

  /// A/B variant key for the paywall layout (screen tasks may read this).
  final String paywallVariant;

  /// Features that are locked behind Pro for free users.
  final Set<PremiumFeature> gatedFeatures;

  /// Optional per-day duration override, keyed by 1-based day index. Empty when
  /// the defaults in [kDefaultPlan] apply.
  final Map<int, int> planDurationOverridesSeconds;

  /// Trial length surfaced on the paywall (matches the 3-day free trial).
  final int freeTrialDays;

  /// Safe defaults used when no remote values have been fetched.
  static const RemoteConfig defaults = RemoteConfig(
    showPaywallOnLaunch: false,
    paywallVariant: 'default',
    gatedFeatures: <PremiumFeature>{
      PremiumFeature.allModes,
      PremiumFeature.fullPlan,
      PremiumFeature.stereoMixer,
      PremiumFeature.dbMeter,
      PremiumFeature.adFree,
    },
    planDurationOverridesSeconds: <int, int>{},
    freeTrialDays: 3,
  );

  LaunchDestination get launchDestination =>
      showPaywallOnLaunch ? LaunchDestination.paywall : LaunchDestination.home;

  RemoteConfig copyWith({
    bool? showPaywallOnLaunch,
    String? paywallVariant,
    Set<PremiumFeature>? gatedFeatures,
    Map<int, int>? planDurationOverridesSeconds,
    int? freeTrialDays,
  }) {
    return RemoteConfig(
      showPaywallOnLaunch: showPaywallOnLaunch ?? this.showPaywallOnLaunch,
      paywallVariant: paywallVariant ?? this.paywallVariant,
      gatedFeatures: gatedFeatures ?? this.gatedFeatures,
      planDurationOverridesSeconds:
          planDurationOverridesSeconds ?? this.planDurationOverridesSeconds,
      freeTrialDays: freeTrialDays ?? this.freeTrialDays,
    );
  }

  /// Resolve the effective plan, applying any duration overrides.
  List<PlanDay> resolvePlan() {
    if (planDurationOverridesSeconds.isEmpty) return kDefaultPlan;
    return kDefaultPlan
        .map((d) => PlanDay(
              day: d.day,
              title: d.title,
              durationSeconds:
                  planDurationOverridesSeconds[d.day] ?? d.durationSeconds,
              premium: d.premium,
            ))
        .toList(growable: false);
  }
}

/// Fetches [RemoteConfig]. This local implementation simply returns defaults
/// after a short delay to mimic the launch-time remote-config load ("splash
/// loads remote config"); a Firebase-backed fetch can replace [fetch] without
/// changing [AppState] or any screen.
class RemoteConfigService {
  RemoteConfigService();

  RemoteConfig _current = RemoteConfig.defaults;

  RemoteConfig get current => _current;

  /// Simulate the launch-time remote-config load. Never throws.
  Future<RemoteConfig> fetch() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // No backend in this build: keep the defaults. Kept async + guarded so a
      // real fetch can drop in here.
      _current = RemoteConfig.defaults;
    } catch (_) {
      _current = RemoteConfig.defaults;
    }
    return _current;
  }
}
