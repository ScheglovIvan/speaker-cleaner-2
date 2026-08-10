import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';

/// The design-system app mark: a rounded-square gradient tile with a glyph.
///
/// Replaces the source app's logo (anti-clone: no source branding) on splash /
/// loading / paywall hero placements. Uses the primary CTA gradient.
class AppHeroIcon extends StatelessWidget {
  const AppHeroIcon({
    super.key,
    this.icon = Icons.graphic_eq_rounded,
    this.size = 96,
    this.gradient,
  });

  final IconData icon;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.primaryCta,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }

  /// A plain rounded illustration frame (no gradient) for section artwork.
  ///
  /// (For a mark that stands for the app itself, use [AppIconMark].)
  static Widget frame({
    required Widget child,
    double radius = AppDimens.radiusLg,
    Color? color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(color: color ?? AppColors.cardBlue, child: child),
    );
  }
}

/// The app's own launcher icon, drawn wherever the UI shows a mark that stands
/// for *this app* (splash, loading transition, paywall hero, the onboarding
/// welcome page).
///
/// The stored PNG is square because iOS masks it on the home screen, so the
/// same mask is applied here (a rounded rect at 22.5% of the side) — otherwise
/// it would read as a raw square inside the app. Functional glyphs (play,
/// speaker, checkmark, tab icons) are NOT app marks and keep using
/// [AppHeroIcon].
class AppIconMark extends StatelessWidget {
  const AppIconMark({super.key, this.size = 96});

  /// Side length of the (square) mark, matching the placement it sits in.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.225),
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          // The source is 1024px — medium quality keeps the downscale clean.
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
