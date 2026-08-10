import 'dart:async';

import 'package:apphud/apphud.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/apphud_config.dart';
import 'core/attribution/attribution_service.dart';
import 'core/audio/cleaning_audio.dart';
import 'core/audio/sound_envelope.dart';
import 'core/router/app_router.dart';
import 'core/router/deep_link_handler.dart';
import 'core/state/state.dart';
import 'core/state/store_pricing.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _startApphud();

  // Configure the loud-speaker audio session so test tones play at full
  // output through the speaker even with the silent switch on (never auto-plays
  // — this only prepares the session; playback starts on an explicit user tap).
  await AppAudioContext.configureGlobal();

  // Measure the two remaining MP3 clips' loudness envelopes once, before the
  // first frame, so the waveform bars can follow what is actually playing (the
  // lookup screens need them synchronously). The generated sine/sweep WAVs need
  // no measurement: their signal is known exactly, so `ToneWaveform` /
  // `SweepWaveform` draw the real waveform instead of an envelope.
  await SoundEnvelopes.preload(const [
    CleaningTones.waterTone,
    CleaningTones.completeChime,
  ]);

  // Load persisted state (maintenance history, language, entitlement, settings)
  // and remote config before the first frame so screens read stable values.
  final appState = AppState();
  await appState.initialize();

  runApp(SpeakerCleanerApp(appState: appState));
}

/// Start Apphud before the first frame so the paywall placement and the
/// premium check are ready. Guarded (and the empty key short-circuits) so a
/// missing/invalid key or an unsupported platform never crashes launch. Apphud
/// auto-detects the StoreKit sandbox vs production — nothing to configure here.
Future<void> _startApphud() async {
  final key = ApphudConfig.sdkKey.trim();
  if (key.isEmpty) return;
  try {
    await Apphud.start(apiKey: key);
    // Warm the real subscription price in the background so the onboarding
    // offer and the premium lock screens can quote the same figure as the
    // paywall (they omit it until this resolves — never a literal).
    unawaited(StorePricing.instance.ensureLoaded());
  } catch (_) {
    // Ignore start failures (e.g. unsupported platform in the web preview).
  }
}

class SpeakerCleanerApp extends StatefulWidget {
  const SpeakerCleanerApp({super.key, required this.appState});

  /// Shared app state + local persistence, exposed to the tree via [AppScope].
  final AppState appState;

  @override
  State<SpeakerCleanerApp> createState() => _SpeakerCleanerAppState();
}

class _SpeakerCleanerAppState extends State<SpeakerCleanerApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final DeepLinkHandler _deepLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deepLinks = DeepLinkHandler(_navKey);
    // Fire-and-forget; failures inside are swallowed by the handler.
    _deepLinks.init();

    // Attribution (Tenjin) runs AFTER the first frame: Apple only presents the
    // ATT dialog while the app is visible, so this cannot move pre-runApp. It
    // also initializes + connects Tenjin on EVERY launch (not just the first)
    // and shares the IDFA with Apphud. Fire-and-forget and fully guarded
    // inside, so it never blocks the UI or breaks launch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AttributionService.instance.start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-check premium access with Apphud whenever the app comes back to the
    // foreground (a subscription may have been bought, cancelled or expired
    // outside the app — e.g. in the App Store's Manage Subscriptions sheet).
    if (state == AppLifecycleState.resumed) {
      widget.appState.refreshEntitlement();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinks.dispose();
    // AppState lives for the whole app; disposing it releases the entitlement
    // listener.
    widget.appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AppScope wraps MaterialApp so every screen (in-app or web-preview route)
    // can read state via `context.watchAppState`. The MaterialApp is rebuilt on
    // every state notify (via AnimatedBuilder) so a language change re-drives
    // `locale` and re-localizes the framework's own widgets alongside the app's
    // string catalogue (REQ-change-language: re-localize the entire UI).
    return AppScope(
      state: widget.appState,
      child: AnimatedBuilder(
        animation: widget.appState,
        builder: (context, _) => MaterialApp(
          title: 'Speaker & Headphone Test',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          theme: AppTheme.light(),
          locale: localeForCode(widget.appState.languageCode),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRouter.initialRoute,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
  }
}
