import 'package:flutter/material.dart';

import '../../core/router/app_shell.dart';
import '../../core/state/app_scope.dart';
import 'onboarding_flow.dart';

/// The initial `/` destination.
///
/// On the very first launch (no persisted `onboardingComplete` flag) it shows
/// the [OnboardingFlow]; on every subsequent launch it shows the normal tab
/// shell. Because it watches [AppState], finishing onboarding (which sets the
/// flag) rebuilds this straight into [AppShell] — no manual navigation needed.
///
/// Only the `/` route uses this gate, so deep links (`iosforge://screen/<id>`)
/// and the `/#/screen/<id>` web-preview routes still resolve directly to their
/// screens.
class LaunchGate extends StatelessWidget {
  const LaunchGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    if (!state.onboardingComplete) {
      return const OnboardingFlow();
    }
    return const AppShell();
  }
}
