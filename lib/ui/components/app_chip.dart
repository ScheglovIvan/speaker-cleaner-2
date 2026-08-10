import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// A small pill label with an optional leading icon.
///
/// Used for qualitative badges, offer tags ("3-day free trial") and inline
/// status markers. Selectable when [onTap] is provided. Never use it to state a
/// user count, rating or award — the app has no such data to stand behind.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.filled = true,
    this.onTap,
    this.selected = false,
  });

  final String label;
  final IconData? icon;

  /// Accent colour (defaults to the primary token).
  final Color? color;

  /// Solid tint fill vs. an outlined pill.
  final bool filled;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = color ?? AppColors.primary;
    final solid = filled || selected;
    final radius = BorderRadius.circular(AppDimens.radiusPill);

    final body = Container(
      decoration: BoxDecoration(
        color: solid ? tint.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: solid ? Colors.transparent : AppColors.separator,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: tint),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: onTap, child: body),
    );
  }
}
