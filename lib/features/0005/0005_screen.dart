import 'package:flutter/material.dart';

import '../../ui/components/app_hero_icon.dart';
import '../../ui/components/app_loader.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/theme/app_colors.dart';

/// Screen 0005 — Loading transition.
///
/// The interstitial "please wait" screen shown between actions. It mirrors the
/// splash (0000) but, per the native ground truth (source/0005.json), the whole
/// content block sits lower on the page and there is no ad banner. It shows the
/// app's real launcher icon ([AppIconMark]) over the splash background token,
/// with the design-system [AppLoader] bar.
///
/// The original's "…may contain Ads" line and banner are dropped (ad-free).
class Screen_0005 extends StatefulWidget {
  const Screen_0005({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0005';

  @override
  State<Screen_0005> createState() => _Screen_0005State();
}

class _Screen_0005State extends State<Screen_0005>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
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
          // Shifted lower than the splash (native: icon at y209 vs y184).
          const Spacer(flex: 34),
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
            'Just a moment',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(flex: 46),
          const SafeArea(
            top: false,
            child: AppLoader(
              style: AppLoaderStyle.bar,
              status: 'Preparing your session…',
            ),
          ),
          const Spacer(flex: 6),
        ],
      ),
    );
  }
}
