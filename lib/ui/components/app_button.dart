import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_gradients.dart';

/// Visual variants for [AppButton]. Every variant is a pill (radius from
/// `design_tokens.dimension.radius_pill`) and pulls its colours from the
/// divergent design tokens — never hardcoded.
enum AppButtonVariant {
  /// Blue→teal gradient pill — the primary CTA (Start Cleaning, Start Free
  /// Trial, Start Today's Routine). Uses `gradient.primaryCta`.
  gradient,

  /// Solid primary-tinted fill (`color.button_blue`).
  solid,

  /// `design_tokens.button_style: tonal` — soft card-blue fill, primary text.
  tonal,

  /// Outlined pill in the primary tint.
  outlined,

  /// Destructive action (Stop) — `color.danger` tint.
  danger,
}

/// The one styled button every screen composes from.
///
/// Pill-shaped, honours `elevation_style: soft`, and takes an optional leading
/// [icon]. Set [expand] to stretch to the parent width (sticky CTAs).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.gradient,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  /// Convenience: primary gradient CTA.
  const AppButton.gradient({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool expand = true,
    bool loading = false,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.gradient,
          icon: icon,
          expand: expand,
          loading: loading,
        );

  /// Convenience: soft tonal button (design-token default `button_style`).
  const AppButton.tonal({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool expand = true,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.tonal,
          icon: icon,
          expand: expand,
        );

  /// Convenience: destructive Stop button.
  const AppButton.danger({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    IconData? icon,
    bool expand = true,
  }) : this(
          key: key,
          label: label,
          onPressed: onPressed,
          variant: AppButtonVariant.danger,
          icon: icon,
          expand: expand,
        );

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = onPressed != null && !loading;

    final labelStyle = text.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: _foregroundColor,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(_foregroundColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 20, color: _foregroundColor),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
      ],
    );

    final radius = BorderRadius.circular(AppDimens.radiusPill);
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        gradient: variant == AppButtonVariant.gradient
            ? AppGradients.primaryCta
            : null,
        color: _backgroundColor,
        borderRadius: radius,
        border: variant == AppButtonVariant.outlined
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
        boxShadow: _hasShadow && enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: content,
      ),
    );

    final button = Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: enabled ? onPressed : null,
        child: Opacity(opacity: enabled ? 1 : 0.5, child: pill),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  bool get _hasShadow =>
      variant == AppButtonVariant.gradient ||
      variant == AppButtonVariant.solid;

  Color? get _backgroundColor {
    switch (variant) {
      case AppButtonVariant.gradient:
      case AppButtonVariant.outlined:
        return null;
      case AppButtonVariant.solid:
        return AppColors.buttonBlue;
      case AppButtonVariant.tonal:
        return AppColors.cardBlue;
      case AppButtonVariant.danger:
        return AppColors.danger.withValues(alpha: 0.16);
    }
  }

  Color get _foregroundColor {
    switch (variant) {
      case AppButtonVariant.gradient:
      case AppButtonVariant.solid:
        return Colors.white;
      case AppButtonVariant.tonal:
      case AppButtonVariant.outlined:
        return AppColors.primary;
      case AppButtonVariant.danger:
        return AppColors.danger;
    }
  }
}
