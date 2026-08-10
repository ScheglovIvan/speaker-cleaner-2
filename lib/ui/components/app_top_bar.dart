import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_icon_button.dart';

/// The shared top navigation bar (implements [PreferredSizeWidget] so it drops
/// straight into `Scaffold.appBar`).
///
/// Covers screen titles, a back affordance, a close affordance (paywall modal)
/// and up to a trailing action. Restyles the source nav bar via design tokens.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.showBack = false,
    this.showClose = false,
    this.onBack,
    this.onClose,
    this.actions = const [],
    this.centerTitle = false,
    this.backgroundColor,
  });

  final String? title;
  final bool showBack;
  final bool showClose;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final List<Widget> actions;
  final bool centerTitle;
  final Color? backgroundColor;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget? leading;
    if (showBack) {
      leading = AppIconButton(
        icon: Icons.chevron_left_rounded,
        tooltip: 'Back',
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
      );
    } else if (showClose) {
      leading = AppIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close',
        onPressed: onClose ?? () => Navigator.of(context).maybePop(),
      );
    }

    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
        color: backgroundColor ?? Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 8)],
            Expanded(
              child: title == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      header: true,
                      child: Text(
                        title!,
                        textAlign:
                            centerTitle ? TextAlign.center : TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
            ),
            for (final a in actions) ...[a, const SizedBox(width: 4)],
          ],
        ),
      ),
    );
  }
}
