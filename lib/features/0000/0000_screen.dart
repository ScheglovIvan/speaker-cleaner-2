import 'package:flutter/material.dart';

import '../../ui/components/app_hero_icon.dart';
import '../../ui/components/app_loader.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/theme/app_colors.dart';

/// Screen 0000 — Splash.
///
/// Launch screen shown while the app boots. Layout follows the native ground
/// truth (source/0000.json): app mark in the upper third, product title just
/// below it, and a loading caption + indeterminate progress bar near the
/// bottom. The mark is the app's real launcher icon ([AppIconMark]); the rest
/// comes from the design system (splash background token, [AppLoader] bar).
///
/// The original had an ad banner and an "…may contain Ads" line; this ad-free
/// clone drops both and lets the layout breathe.
class Screen_0000 extends StatefulWidget {
  const Screen_0000({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0000';

  @override
  State<Screen_0000> createState() => _Screen_0000State();
}

class _Screen_0000State extends State<Screen_0000>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // Gentle, always-visible breathing pulse on the app mark. It settles at a
    // fully-visible state so a standalone screenshot never catches it blank.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.97,
      upperBound: 1.03,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      backgroundColor: AppColors.backgroundSplash,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon sits in the upper third (native: y184 of 667).
          const Spacer(flex: 30),
          ScaleTransition(
            scale: _pulse,
            child: const AppIconMark(size: 112),
          ),
          const SizedBox(height: 22),
          Text(
            'Speaker & Headphone Test',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Check your speakers & headphones',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          // Large gap, then the loader near the bottom (native: y531/y564).
          const Spacer(flex: 40),
          const SafeArea(
            top: false,
            child: AppLoader(
              style: AppLoaderStyle.bar,
              status: 'Getting your test kit ready…',
            ),
          ),
          const Spacer(flex: 10),
        ],
      ),
    );
  }
}
