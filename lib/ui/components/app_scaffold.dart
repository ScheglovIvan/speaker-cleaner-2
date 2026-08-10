import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import 'app_top_bar.dart';

/// A standard page shell every screen builds on.
///
/// Wraps [Scaffold] with the token background, an optional [AppTopBar], the
/// standard horizontal `screen_padding`, and an optional sticky [bottomBar]
/// (used for the always-visible CTA on paywall / instructions screens).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomBar,
    this.backgroundColor,
    this.padded = true,
    this.scrollable = false,
    this.safeTop = true,
  });

  final Widget body;

  /// Optional [AppTopBar] rendered at the top of the page.
  final AppTopBar? topBar;

  /// Optional sticky footer (e.g. a CTA [AppButton]); gets screen padding + a
  /// safe-area inset automatically.
  final Widget? bottomBar;

  final Color? backgroundColor;

  /// Apply the standard horizontal `screen_padding` to [body].
  final bool padded;

  /// Wrap [body] in a scroll view (handles keyboard / small screens).
  final bool scrollable;

  final bool safeTop;

  @override
  Widget build(BuildContext context) {
    Widget content = body;
    if (padded) {
      content = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.screenPadding,
        ),
        child: content,
      );
    }
    if (scrollable) {
      content = SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      body: Column(
        children: [
          if (topBar != null) topBar!,
          Expanded(
            child: SafeArea(
              top: safeTop && topBar == null,
              bottom: false,
              child: content,
            ),
          ),
        ],
      ),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.screenPadding,
                  8,
                  AppDimens.screenPadding,
                  12,
                ),
                child: bottomBar,
              ),
            ),
    );
  }
}
