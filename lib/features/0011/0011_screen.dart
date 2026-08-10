import 'package:flutter/material.dart';

import '../../core/router/app_shell.dart';
import '../../core/state/app_scope.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';
import '../checkup/headphone_checkup_screen.dart';

/// Screen 0011 — Test Hub (Home tab).
///
/// The landing tab of the bottom-tab shell: a list of the audio tests the app
/// offers, led by the channel test. Speaker maintenance (water eject) sits at
/// the bottom as a small secondary entry, not a hero. Copy and icons are
/// paraphrased / restyled per the anti-clone rules; the look is owned by
/// `lib/ui/theme/`.
class Screen_0011 extends StatelessWidget {
  const Screen_0011({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0011';

  /// Open a test. Tab members switch the shell in place; anything else (and the
  /// standalone `/screen/0011` preview) is pushed as a route.
  ///
  /// [kCheckupId] is not an app_spec screen — the guided Headphone Checkup is a
  /// pushed route, so it adds no id and leaves every deep link untouched.
  void _open(BuildContext context, String id) {
    if (id == kCheckupId) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HeadphoneCheckupScreen()),
      );
      return;
    }
    if (AppShell.openTab(context, id)) return;
    Navigator.of(context).pushNamed('/$id');
  }

  /// Sentinel id for the pushed (non-spec) Headphone Checkup route.
  static const String kCheckupId = 'checkup';

  /// Crown / Get Pro entry point → paywall (0001). Re-syncs the entitlement on
  /// return so the crown reflects a fresh purchase immediately.
  Future<void> _openPaywall(BuildContext context) async {
    await Navigator.of(context).pushNamed('/0001');
    if (context.mounted) {
      await context.appState.refreshEntitlement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isPro = context.watchAppState.isPro;

    return AppScaffold(
      scrollable: true,
      topBar: AppTopBar(
        title: 'Speaker & Headphone Test',
        actions: [
          AppIconButton(
            // Filled/highlighted crown once Premium is active; outlined "Go Pro"
            // affordance otherwise.
            icon: isPro
                ? Icons.workspace_premium_rounded
                : Icons.workspace_premium_outlined,
            tooltip: isPro ? 'Premium active' : 'Go Pro',
            color: isPro ? AppColors.success : AppColors.primary,
            onPressed: () => _openPaywall(context),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Check your speakers & headphones',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Play a signal, listen, and confirm each side actually works.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Featured test ───────────────────────────────────────────────
          _FeaturedTestCard(onStart: () => _open(context, '0002')),
          const SizedBox(height: 16),

          const AppSectionHeader(
            title: 'All tests',
            subtitle: 'Pick what you want to check',
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _tests.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            AppListTile(
              leadingIcon: _tests[i].icon,
              leadingColor: _tests[i].tint,
              title: _tests[i].title,
              subtitle: _tests[i].subtitle,
              onTap: () => _open(context, _tests[i].id),
            ),
          ],
          const SizedBox(height: 20),

          // ── Secondary entries, deliberately small ───────────────────────
          const AppSectionHeader(title: 'More'),
          AppListTile(
            leadingIcon: Icons.water_drop_outlined,
            leadingColor: AppColors.textSecondary,
            title: 'Speaker maintenance',
            subtitle: 'Water eject after the phone gets wet',
            onTap: () => Navigator.of(context).pushNamed('/0010'),
          ),
          const SizedBox(height: 10),
          AppListTile(
            leadingIcon: Icons.settings_outlined,
            leadingColor: AppColors.textSecondary,
            title: 'Settings',
            subtitle: 'Language, sound and your subscription',
            onTap: () => Navigator.of(context).pushNamed('/0003'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// The test entries, each wired to an existing screen id.
  static const List<_TestEntry> _tests = [
    _TestEntry(
      id: '0002',
      icon: Icons.compare_arrows_rounded,
      tint: AppColors.primary,
      title: 'Channel Test',
      subtitle: 'Left, right, both or the earpiece',
    ),
    _TestEntry(
      id: '0012',
      icon: Icons.graphic_eq_rounded,
      tint: AppColors.accentTeal,
      title: 'Tone Generator',
      subtitle: 'Real sine tones, 63 Hz to 16 kHz, plus a sweep',
    ),
    _TestEntry(
      id: '0013',
      icon: Icons.speed_rounded,
      tint: AppColors.accentOrange,
      title: 'Sound-Level Meter',
      subtitle: 'Measure how loud the output is, live',
    ),
    _TestEntry(
      id: kCheckupId,
      icon: Icons.headphones_rounded,
      tint: AppColors.success,
      title: 'Headphone Checkup',
      subtitle: 'Guided left, right, balance, phase and sweep',
    ),
  ];
}

/// A single entry in the test list.
class _TestEntry {
  const _TestEntry({
    required this.id,
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
  });

  /// The screen id this entry opens.
  final String id;
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
}

/// The gradient featured block that leads into the channel test.
class _FeaturedTestCard extends StatelessWidget {
  const _FeaturedTestCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const onGradient = Colors.white;

    return AppGradientCard(
      onTap: onStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: onGradient.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: onGradient,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start with the channel test',
                      style: text.titleLarge?.copyWith(
                        color: onGradient,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The quickest way to spot a dead or muffled side',
                      style: text.bodyMedium?.copyWith(
                        color: onGradient.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton.tonal(
            label: 'Run channel test',
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}
