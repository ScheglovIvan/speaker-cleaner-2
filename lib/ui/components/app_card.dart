import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';

/// A rounded, soft-shadowed container — the base surface for every tile,
/// routine card and info panel. Radius + elevation come from the design tokens
/// (`radius_md`, `elevation_style: soft`).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = AppDimens.radiusMd,
    this.elevated = true,
    this.border,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Surface fill (defaults to the page background surface).
  final Color? color;
  final double radius;

  /// Apply the soft drop shadow.
  final bool elevated;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final decorated = Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.background,
        borderRadius: borderRadius,
        border: border,
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}

/// A hero card filled with the primary CTA gradient (blue→teal) — used for the
/// "today's routine" / featured blocks. Text/children render on top in white.
class AppGradientCard extends StatelessWidget {
  const AppGradientCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppDimens.radiusLg,
    this.gradient,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final decorated = Container(
      decoration: BoxDecoration(
        gradient: gradient ?? AppGradients.primaryCta,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: decorated,
      ),
    );
  }
}
