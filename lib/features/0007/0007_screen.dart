import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/state/plan.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Screen 0007 — Water Eject detail.
///
/// The long-form description of the one maintenance run: what the tone does,
/// how long it plays, and what to do before starting it. The sticky CTA hands
/// off to the run flow (0008).
class Screen_0007 extends StatelessWidget {
  const Screen_0007({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0007';

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    final tool = state.plan.isEmpty ? kDefaultPlan.first : state.plan.first;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Water Eject', showBack: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _HeroCard(tool: tool),
          const SizedBox(height: 20),
          _StatsRow(tool: tool),
          const SizedBox(height: 8),
          const AppSectionHeader(
            title: 'How the run works',
            subtitle: 'A low tone drives the membrane and pushes water out.',
          ),
          _RoutineSteps(tool: tool),
          const SizedBox(height: 12),
          const AppSectionHeader(
            title: 'Before you begin',
            subtitle: 'A few seconds of prep makes the tone more effective.',
          ),
          const _Tips(),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: AppButton.gradient(
        label: 'Start water eject',
        icon: Icons.play_arrow_rounded,
        onPressed: () => Navigator.of(context)
            .pushNamed('/0008', arguments: {'day': tool.day}),
      ),
    );
  }
}

/// The gradient hero at the top: tool name and what it plays.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.tool});

  final PlanDay tool;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _GlassPill(label: 'Maintenance'),
              const SizedBox(width: 8),
              _GlassPill(
                label: _formatDuration(tool.durationSeconds),
                icon: Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tool.title,
            style: text.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A ${_formatDuration(tool.durationSeconds)} low-frequency tone for '
            'a speaker that just got wet.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 96,
            child: WaveformVisualizer(
              active: false,
              height: 96,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// A translucent pill used on top of the gradient hero.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three quick facts about the run.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.tool});

  final PlanDay tool;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.timer_outlined,
            value: _formatDuration(tool.durationSeconds),
            label: 'Run time',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.graphic_eq_rounded,
            value: 'Low',
            label: 'Frequency',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.speaker_rounded,
            value: 'Speaker',
            label: 'Output',
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// What the run actually does, as grouped rows inside one card.
class _RoutineSteps extends StatelessWidget {
  const _RoutineSteps({required this.tool});

  final PlanDay tool;

  @override
  Widget build(BuildContext context) {
    final steps = <(IconData, String, String)>[
      (
        Icons.graphic_eq_rounded,
        'Low tone starts',
        'Deep frequencies make the membrane travel as far as it can.',
      ),
      (
        Icons.water_drop_outlined,
        'Water is pushed out',
        'The movement forces droplets back through the grille opening.',
      ),
      (
        Icons.notifications_active_rounded,
        'Finish chime',
        'A soft tone signals the ${_formatDuration(tool.durationSeconds)} run is done.',
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            AppListTile(
              card: false,
              showChevron: false,
              leadingIcon: steps[i].$1,
              title: steps[i].$2,
              subtitle: steps[i].$3,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pre-run checklist tips.
class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        AppListTile(
          leadingIcon: Icons.volume_up_rounded,
          leadingColor: AppColors.accentTeal,
          title: 'Turn the volume most of the way up',
          subtitle: 'Higher output moves the membrane further.',
          showChevron: false,
        ),
        SizedBox(height: 10),
        AppListTile(
          leadingIcon: Icons.phone_iphone_rounded,
          leadingColor: AppColors.accentTeal,
          title: 'Point the speaker downward',
          subtitle: 'Let gravity help the droplets fall away.',
          showChevron: false,
        ),
        SizedBox(height: 10),
        AppListTile(
          leadingIcon: Icons.headset_off_rounded,
          leadingColor: AppColors.accentTeal,
          title: 'Unplug headphones first',
          subtitle: 'The tone should play through the built-in speaker.',
          showChevron: false,
        ),
      ],
    );
  }
}

/// Human-friendly duration: "45 sec" or "1 min 23 sec".
String _formatDuration(int seconds) {
  if (seconds < 60) return '$seconds sec';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min $s sec';
}
