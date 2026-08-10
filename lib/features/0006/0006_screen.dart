import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/state/app_scope.dart';
import '../../core/state/plan.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';

/// Screen 0006 — Run Complete.
///
/// The confirmation shown after a tone run or the water-eject maintenance run
/// finishes: a success mark, what just played, how long it took, and what to
/// check next.
///
/// Reached from the run flow (0008) with `{'title': …, 'durationSeconds': …}`
/// and, for the maintenance run, a `day`. When opened standalone (deep link /
/// web preview) it shows the maintenance run as an example and does NOT mutate
/// progress.
class Screen_0006 extends StatefulWidget {
  const Screen_0006({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0006';

  @override
  State<Screen_0006> createState() => _Screen_0006State();
}

class _Screen_0006State extends State<Screen_0006>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Resolved from route args once, on first build.
  String? _title;
  int _duration = kDefaultPlan.first.durationSeconds;
  int? _day;
  bool _wasPassedIn = false;

  @override
  void initState() {
    super.initState();
    _pop.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_title != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    final state = context.appState;
    if (args is Map) {
      _wasPassedIn = true;
      if (args['title'] is String) _title = args['title'] as String;
      if (args['durationSeconds'] is int) {
        _duration = args['durationSeconds'] as int;
      }
      if (args['day'] is int) _day = args['day'] as int;
    }
    _title ??= kDefaultPlan.first.title;

    if (_wasPassedIn) {
      // Arriving here means the run just finished. 0008 already recorded it the
      // moment the run ended; this is the belt-and-braces repeat (guarded by
      // completeDay, which no-ops when it is already recorded). The entitlement
      // is re-read too, so a fresh purchase is reflected straight away.
      final day = _day;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (state.hapticsEnabled) HapticFeedback.mediumImpact();
        await state.refreshEntitlement();
        if (day != null) await state.completeDay(day);
      });
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  /// Back to the Test Hub, dropping the run flow from the stack.
  void _backToTests(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    } else {
      nav.pushReplacementNamed('/');
    }
  }

  /// Play the same run once more.
  void _runAgain(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(
      '/0008',
      arguments: <String, Object?>{
        if (_day != null) 'day': _day,
        'title': _title,
        'durationSeconds': _duration,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = _title ?? kDefaultPlan.first.title;

    return AppScaffold(
      topBar: AppTopBar(
        showClose: true,
        onClose: () => _backToTests(context),
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.gradient(
            label: 'Back to tests',
            icon: Icons.arrow_forward_rounded,
            onPressed: () => _backToTests(context),
          ),
          const SizedBox(height: 10),
          AppButton.tonal(
            label: 'Run it again',
            icon: Icons.refresh_rounded,
            onPressed: () => _runAgain(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _pop,
                    curve: Curves.elasticOut,
                  ),
                  child: const AppHeroIcon(
                    icon: Icons.task_alt_rounded,
                    size: 108,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Run complete',
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _wasPassedIn
                    ? '"$title" finished playing.'
                    : 'This is how a finished "$title" run looks.',
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              _StatsCard(durationSeconds: _duration, isMaintenance: _day != null),
              const SizedBox(height: 16),
              _NextUpNote(isMaintenance: _day != null),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small run-summary card: how long it played and what kind of run it was.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.durationSeconds,
    required this.isMaintenance,
  });

  final int durationSeconds;
  final bool isMaintenance;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: _Stat(
              icon: Icons.timer_outlined,
              value: '${durationSeconds}s',
              label: 'Played for',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.separator,
          ),
          Expanded(
            child: _Stat(
              icon: isMaintenance
                  ? Icons.water_drop_outlined
                  : Icons.graphic_eq_rounded,
              value: isMaintenance ? 'Water eject' : 'Tone',
              label: 'Run type',
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
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
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// What to do with the result.
class _NextUpNote extends StatelessWidget {
  const _NextUpNote({required this.isMaintenance});

  final bool isMaintenance;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.cardBlue,
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMaintenance
                  ? 'Sound still muffled? Wipe the grille, then run it once '
                      'more before assuming the speaker is damaged.'
                  : 'Heard a buzz or a dead side? Try the channel test to work '
                      'out which driver it came from.',
              style: text.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
