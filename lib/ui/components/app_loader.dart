import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Indeterminate loader styles.
enum AppLoaderStyle {
  /// A circular spinner (compact inline / button loading).
  spinner,

  /// A slim rounded indeterminate progress bar (splash / loading screens).
  bar,
}

/// The shared indeterminate loader used on the splash, loading-transition and
/// "before you start" loading screens. Optionally shows a status caption below.
class AppLoader extends StatelessWidget {
  const AppLoader({
    super.key,
    this.style = AppLoaderStyle.spinner,
    this.status,
    this.color,
    this.size = 28,
  });

  final AppLoaderStyle style;

  /// Optional caption rendered under the indicator (e.g. "Loading…").
  final String? status;

  /// Indicator colour (defaults to the warm accent token used by loaders).
  final Color? color;

  /// Diameter of the spinner (ignored for the bar style).
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = color ?? AppColors.accentOrange;

    final indicator = style == AppLoaderStyle.spinner
        ? SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(tint),
              backgroundColor: tint.withValues(alpha: 0.15),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              width: 160,
              height: 6,
              child: LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation(tint),
                backgroundColor: tint.withValues(alpha: 0.15),
              ),
            ),
          );

    if (status == null) return indicator;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(height: 14),
        Text(
          status!,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
