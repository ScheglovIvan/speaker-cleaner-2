import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A tiny numeric / status badge (e.g. a "PRO" crown marker or a count dot).
/// Distinct from [AppChip] — meant to overlay or sit inline with an icon.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    this.label,
    this.icon,
    this.color,
  });

  /// Short text; omit for an icon-only or dot badge.
  final String? label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = color ?? AppColors.accentOrange;
    final onTint = _readableOn(tint);

    return Container(
      padding: label == null
          ? const EdgeInsets.all(5)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 12, color: onTint),
          if (icon != null && label != null) const SizedBox(width: 4),
          if (label != null)
            Text(
              label!,
              style: text.labelSmall?.copyWith(
                color: onTint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
        ],
      ),
    );
  }

  static Color _readableOn(Color bg) {
    return bg.computeLuminance() > 0.5
        ? AppColors.textPrimary
        : Colors.white;
  }
}
