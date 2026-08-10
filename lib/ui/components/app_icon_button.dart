import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A circular, soft-filled icon button used for back / close / crown
/// affordances in top bars and hero overlays.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.background,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Icon tint (defaults to the primary token colour).
  final Color? color;

  /// Circle fill (defaults to the muted card fill).
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Keep the visible circle at [size] but guarantee at least a 44×44 hit area
    // for accessibility (Apple/Material minimum touch target).
    final double dimension = size < 44 ? 44.0 : size;
    Widget button = Material(
      color: background ?? AppColors.backgroundMuted,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: dimension,
          height: dimension,
          child: Icon(icon, size: dimension * 0.5, color: color ?? AppColors.primary),
        ),
      ),
    );
    if (tooltip != null) {
      // Tooltip supplies the screen-reader label; also flag it as a button so
      // assistive tech announces the affordance.
      button = Tooltip(
        message: tooltip!,
        child: Semantics(button: true, label: tooltip, child: button),
      );
    }
    return button;
  }
}
