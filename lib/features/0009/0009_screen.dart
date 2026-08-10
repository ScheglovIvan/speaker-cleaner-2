import 'package:flutter/material.dart';

import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Screen 0009 — the transient loading state of "Before You Begin".
///
/// Renders the same pre-run checklist as screen 0008, dimmed behind a centred
/// loading spinner while a run is being staged. Kept self-contained so it also
/// renders standalone at the `/screen/0009` web-preview route. Per the ad-free
/// spec the overlay is a generic spinner (never the source's "Loading ads…").
class Screen_0009 extends StatelessWidget {
  const Screen_0009({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0009';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The instructions, shown dimmed underneath the loading overlay.
        IgnorePointer(
          child: Opacity(
            opacity: 0.6,
            child: AppScaffold(
              topBar: AppTopBar(showBack: true),
              scrollable: true,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SizedBox(height: 4),
                  AppSectionHeader(
                    title: 'Before You Begin',
                    subtitle: 'Three quick steps for a clear result.',
                  ),
                  SizedBox(height: 8),
                  _InstructionList(),
                  SizedBox(height: 8),
                ],
              ),
              bottomBar: const AppButton(
                label: 'Start',
                icon: Icons.play_arrow_rounded,
                onPressed: null,
              ),
            ),
          ),
        ),
        // Dimming scrim + centred loading card (tap to return to instructions).
        Positioned.fill(
          child: Semantics(
            button: true,
            label: 'Dismiss and go back',
            child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: ColoredBox(
              color: AppColors.textPrimary.withValues(alpha: 0.45),
              child: Center(
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 26,
                  ),
                  radius: AppDimens.radiusMd,
                  child: const AppLoader(
                    style: AppLoaderStyle.spinner,
                    size: 38,
                    status: 'Preparing your test…',
                  ),
                ),
              ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}

/// The three pre-run tips rendered as design-system list tiles.
class _InstructionList extends StatelessWidget {
  const _InstructionList();

  static const List<(IconData, String, String)> _tips = [
    (
      Icons.volume_up_rounded,
      'Turn the volume up',
      'A stronger signal makes faults easier to hear.',
    ),
    (
      Icons.smartphone_outlined,
      'Take off any case or cover',
      'Nothing should sit over the speaker opening.',
    ),
    (
      Icons.table_bar_rounded,
      'Rest the phone on a level surface',
      'Keeps the output steady while it plays.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _tips.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          AppListTile(
            leadingIcon: _tips[i].$1,
            title: _tips[i].$2,
            subtitle: _tips[i].$3,
            showChevron: false,
          ),
        ],
      ],
    );
  }
}
