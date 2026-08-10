import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_card.dart';

/// A card-wrapped list row: leading icon bubble, title + optional subtitle, and
/// a trailing widget (chevron by default).
///
/// The workhorse for Settings rows, "Before You Start" tips, mode entries and
/// any tappable info line.
class AppListTile extends StatelessWidget {
  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingColor,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.card = true,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;

  /// Tint for the leading icon bubble (defaults to the primary token).
  final Color? leadingColor;

  /// Explicit trailing widget; when null and [showChevron] is true a chevron
  /// is shown.
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  /// Wrap the row in an [AppCard]; set false to embed inside a grouped list.
  final bool card;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tint = leadingColor ?? AppColors.primary;

    final row = Row(
      children: [
        if (leadingIcon != null) ...[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: Icon(leadingIcon, size: 22, color: tint),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (showChevron)
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
      ],
    );

    if (!card) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: row,
        ),
      );
    }
    return AppCard(onTap: onTap, child: row);
  }
}
