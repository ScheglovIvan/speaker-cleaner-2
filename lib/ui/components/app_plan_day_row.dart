import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';

/// Lifecycle of a day in the 7-Day Cleaning Plan.
enum PlanDayState {
  /// Finished — green check, re-runnable.
  completed,

  /// The next available day — highlighted with a play affordance.
  current,

  /// Not yet unlocked — dimmed with a lock.
  locked,
}

/// A single row in the 7-Day Cleaning Plan list.
///
/// Renders a leading day badge, the day title + target/duration, and a state
/// glyph (check / play / lock). Only [PlanDayState.completed] and
/// [PlanDayState.current] are tappable.
class AppPlanDayRow extends StatelessWidget {
  const AppPlanDayRow({
    super.key,
    required this.dayLabel,
    required this.title,
    required this.state,
    this.subtitle,
    this.onTap,
  });

  /// Short badge label, e.g. "Day 1".
  final String dayLabel;
  final String title;
  final PlanDayState state;

  /// Optional target / duration line, e.g. "83 seconds".
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final locked = state == PlanDayState.locked;
    final current = state == PlanDayState.current;
    final radius = BorderRadius.circular(AppDimens.radiusMd);

    final badgeColor = switch (state) {
      PlanDayState.completed => AppColors.success,
      PlanDayState.current => AppColors.primary,
      PlanDayState.locked => AppColors.textSecondary,
    };

    final trailing = switch (state) {
      PlanDayState.completed =>
        const Icon(Icons.check_circle_rounded, color: AppColors.success),
      PlanDayState.current =>
        const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary),
      PlanDayState.locked =>
        const Icon(Icons.lock_rounded, color: AppColors.textSecondary),
    };

    final content = Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: current ? AppColors.cardBlue : AppColors.background,
          borderRadius: radius,
          border: Border.all(
            color: current ? AppColors.primary : AppColors.separator,
            width: current ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Text(
                dayLabel,
                textAlign: TextAlign.center,
                style: text.labelMedium?.copyWith(
                  color: badgeColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );

    if (locked || onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}
