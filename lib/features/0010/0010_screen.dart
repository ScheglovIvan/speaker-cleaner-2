import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/state/plan.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';

/// Screen 0010 — Speaker Maintenance.
///
/// The app's one maintenance utility, reached from the Test Hub rather than a
/// primary tab: a single low-frequency water-eject run that vibrates trapped
/// water out of the speaker after the phone gets wet. It explains what the tone
/// does (and what it cannot do), then hands off to the run flow (0008).
class Screen_0010 extends StatelessWidget {
  const Screen_0010({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0010';

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    final tool = state.plan.isEmpty ? kDefaultPlan.first : state.plan.first;

    return AppScaffold(
      scrollable: true,
      topBar: const AppTopBar(title: 'Speaker Maintenance', showBack: true),
      bottomBar: AppButton.gradient(
        label: 'Start water eject',
        icon: Icons.play_arrow_rounded,
        onPressed: () => Navigator.of(context)
            .pushNamed('/0008', arguments: {'day': tool.day}),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ToolHeader(durationSeconds: tool.durationSeconds),
          const SizedBox(height: 12),
          AppListTile(
            leadingIcon: Icons.help_outline_rounded,
            title: 'How the run works',
            subtitle: 'What the tone does, step by step',
            onTap: () => Navigator.of(context).pushNamed('/0007'),
          ),
          const SizedBox(height: 8),
          const AppSectionHeader(
            title: 'How to use it',
            subtitle: 'A few seconds of prep makes the tone work harder',
          ),
          const _Steps(),
          const SizedBox(height: 16),
          const _HonestNote(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Gradient header describing the water-eject tone and its run length.
class _ToolHeader extends StatelessWidget {
  const _ToolHeader({required this.durationSeconds});

  final int durationSeconds;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined,
                  color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Water eject',
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AppChip(
                label: '${durationSeconds}s',
                icon: Icons.timer_outlined,
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A low tone vibrates the speaker membrane so water trapped behind '
            'the grille is pushed back out. Use it once after the phone gets '
            'wet — it is not a routine.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// The prep steps for a water-eject run.
class _Steps extends StatelessWidget {
  const _Steps();

  static const List<(IconData, String, String)> _steps = [
    (
      Icons.volume_up_rounded,
      'Turn the volume all the way up',
      'A stronger signal moves the membrane further.',
    ),
    (
      Icons.flip_to_back_rounded,
      'Point the speaker downward',
      'Lets the water fall clear instead of running back in.',
    ),
    (
      Icons.table_bar_rounded,
      'Rest the phone on a towel or flat surface',
      'Keeps the vibration steady and catches the droplets.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          AppListTile(
            leadingIcon: _steps[i].$1,
            leadingColor: AppColors.accentTeal,
            title: _steps[i].$2,
            subtitle: _steps[i].$3,
            showChevron: false,
          ),
        ],
      ],
    );
  }
}

/// Sets expectations honestly: the tone helps, it is not a repair.
class _HonestNote extends StatelessWidget {
  const _HonestNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.cardBlue,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This shifts surface water sitting in the speaker opening. It '
              'cannot dry the inside of a phone — if the device took a real '
              'soaking, power it down and let it dry out.',
              style: text.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
