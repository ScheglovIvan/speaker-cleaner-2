import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/audio_visibility.dart';
import '../../core/audio/cleaning_audio.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/app_state.dart';
import '../../core/state/plan.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';

/// Screen 0008 — "Before You Play" checklist + timed tone run.
///
/// This is the shared playback flow (state-machine: Instructions -> Playing ->
/// Complete). It:
///  1. Shows the volume / case / flat-surface checklist (paraphrased; the
///     source's native-ad card, banner and "Loading ads…" interstitial are
///     removed — the ad-free clone reflows the list up).
///  2. On the start CTA pushes the full-screen [_ToneRunScreen], which plays
///     the mapped tone for the run's fixed duration (a live countdown +
///     waveform), then plays the completion chime.
///  3. Hands off to screen 0006 (run complete) when the run finishes
///     (navigation.map edge 0008 -> 0006).
///
/// What to play comes from the route arguments (see [_RunArgs]): the
/// maintenance entry from the water-eject screens, or a tone's
/// title/asset/duration from the Tone Generator. Launched standalone
/// (`/screen/0008`) with no arguments it falls back to the maintenance run so
/// the preview renders.
class Screen_0008 extends StatelessWidget {
  const Screen_0008({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0008';

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    final run = _RunArgs.resolve(
      ModalRoute.of(context)?.settings.arguments,
      state,
    );

    return AppScaffold(
      topBar: AppTopBar(
        title: run.title,
        showBack: true,
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          const AppSectionHeader(
            title: 'Before You Begin',
            subtitle: 'Three quick steps for a clear result.',
          ),
          const SizedBox(height: 8),
          const _InstructionList(),
          const SizedBox(height: 16),
          _RunSummary(run: run),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: AppButton.gradient(
        label: 'Start ${run.title}',
        icon: Icons.play_arrow_rounded,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _ToneRunScreen(run: run),
          ),
        ),
      ),
    );
  }
}

/// A resolved run: what to play, for how long, and whether it is the
/// maintenance entry.
class _RunArgs {
  const _RunArgs({
    required this.title,
    required this.durationSeconds,
    required this.toneAsset,
    this.day,
  });

  /// Display name of the run.
  final String title;

  /// Fixed run length in seconds.
  final int durationSeconds;

  /// The looped tone asset (a [CleaningTones] path).
  final String toneAsset;

  /// The maintenance entry this run belongs to, or `null` for a tone from the
  /// generator. When set, finishing the run records it via 0006.
  final int? day;

  /// Build a run from a route-argument map, filling gaps from the tool/state.
  static _RunArgs resolve(Object? args, AppState state) {
    int? day;
    String? title;
    int? duration;
    String? tone;

    if (args is int) {
      day = args;
    } else if (args is Map) {
      if (args['day'] is int) day = args['day'] as int;
      if (args['title'] is String) title = args['title'] as String;
      if (args['durationSeconds'] is int) {
        duration = args['durationSeconds'] as int;
      }
      if (args['toneAsset'] is String) tone = args['toneAsset'] as String;
    }

    // Nothing supplied at all (standalone preview): fall back to the
    // maintenance entry so the screen still resolves a real run.
    if (day == null && title == null && duration == null && tone == null) {
      day = kDefaultPlan.first.day;
    }

    // Maintenance run: fill title/duration from the (remote-config) entry.
    if (day != null) {
      final d = day.clamp(1, kPlanLength);
      final planDay = state.plan.firstWhere(
        (p) => p.day == d,
        orElse: () => kDefaultPlan.firstWhere(
          (p) => p.day == d,
          orElse: () => kDefaultPlan.first,
        ),
      );
      return _RunArgs(
        title: title ?? planDay.title,
        durationSeconds: duration ?? planDay.durationSeconds,
        toneAsset: tone ?? CleaningTones.defaultTone,
        day: d,
      );
    }

    // Tone run: use whatever the caller supplied.
    return _RunArgs(
      title: title ?? 'Test Tone',
      durationSeconds: duration ?? 36,
      toneAsset: tone ?? CleaningTones.defaultTone,
      day: null,
    );
  }
}

/// A compact card summarising the run about to start (length + what it does).
class _RunSummary extends StatelessWidget {
  const _RunSummary({required this.run});

  final _RunArgs run;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.cardBlue,
      elevated: false,
      child: Row(
        children: [
          const Icon(Icons.graphic_eq_rounded,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Plays for ${_formatDuration(run.durationSeconds)} — listen '
                  'until the chime.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppChip(
            label: _formatDuration(run.durationSeconds),
            icon: Icons.timer_outlined,
          ),
        ],
      ),
    );
  }
}

/// The three pre-run tips, rendered as design-system list tiles.
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

/// Full-screen "now playing" state: plays the looped tone, counts down the
/// run's fixed duration behind a ring + waveform, then plays the completion
/// chime and routes to the result screen (0006).
class _ToneRunScreen extends StatefulWidget {
  const _ToneRunScreen({required this.run});

  final _RunArgs run;

  @override
  State<_ToneRunScreen> createState() => _ToneRunScreenState();
}

class _ToneRunScreenState extends State<_ToneRunScreen>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AudioVisibilityGuard<_ToneRunScreen> {
  late final AnimationController _timer;
  final CleaningAudio _audio = CleaningAudio();
  bool _finishing = false;

  /// Set once the run has actually been kicked off (after the first frame), so
  /// the visibility guard never starts the tone before the run begins.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timer = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.run.durationSeconds),
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      })
      ..addListener(_driveWaveformFromCountdown);

    // Start the run after the first frame so we can read AppState (sound toggle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Always tell the visualiser which clip the run uses so it draws that
      // clip's measured envelope — even with sound off, when nothing plays.
      _audio.prepareWaveform(widget.run.toneAsset);
      if (context.appState.soundEnabled) {
        _audio.startTone(widget.run.toneAsset);
      }
      _timer.forward();
      // Rebuild so the visualiser re-evaluates its repaint clock now that the
      // waveform knows the clip (hasLevels flips true).
      setState(() => _started = true);
    });
  }

  /// With sound OFF there is no playback position to follow, so scroll the
  /// waveform from the run's own countdown progress — the bars still move in
  /// step with the run and draw the clip's measured envelope. With sound ON
  /// the bars follow the player's real position and this is a no-op.
  void _driveWaveformFromCountdown() {
    if (!_started || context.appState.soundEnabled) return;
    _audio.waveform.driveTo(_timer.value * widget.run.durationSeconds);
  }

  /// Same audit as the Channel Test: never leave a tone sounding once this
  /// screen is no longer the visible one (app backgrounded / hidden). The run
  /// is paused rather than abandoned, and picks up again on the way back.
  @override
  void onScreenHidden() {
    if (!_started || _finishing) return;
    _timer.stop();
    _audio.stopTone();
  }

  @override
  void onScreenVisible() {
    if (!_started || _finishing || !mounted) return;
    if (_timer.isAnimating || _timer.value >= 1.0) return;
    if (context.appState.soundEnabled) {
      _audio.startTone(widget.run.toneAsset);
    }
    _timer.forward();
  }

  @override
  void dispose() {
    _timer.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// User bailed out — stop the tone and return to the instructions.
  Future<void> _stop() async {
    _timer.stop();
    await _audio.stopTone();
    if (mounted) Navigator.of(context).pop();
  }

  /// Run finished naturally — chime, then continue to the completion screen.
  Future<void> _finish() async {
    if (_finishing || !mounted) return;
    _finishing = true;

    final state = context.appState;
    await _audio.stopTone();

    // Record the maintenance run the moment it actually finishes — NOT only
    // once the result screen (0006) renders, so a user who leaves right after
    // the chime is still credited. `completeDay` is idempotent, so 0006
    // recording it again is harmless.
    final day = widget.run.day;
    if (day != null) await state.completeDay(day);

    if (state.soundEnabled) {
      // completion chime (audio_result) — the "result state" sound.
      await _audio.playCompletionChime();
    }
    if (state.hapticsEnabled) HapticFeedback.mediumImpact();

    if (!mounted) return;
    // navigation.map: 0008 -> 0006 ("run complete"). The title travels with it
    // so the result screen names whatever just played.
    Navigator.of(context).pushReplacementNamed(
      '/0006',
      arguments: <String, Object?>{
        if (day != null) 'day': day,
        'title': widget.run.title,
        'durationSeconds': widget.run.durationSeconds,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      topBar: AppTopBar(
        title: widget.run.title,
        showClose: true,
        onClose: _stop,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Now playing',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 28),
            _CountdownRing(controller: _timer, total: widget.run.durationSeconds),
            const SizedBox(height: 36),
            WaveformVisualizer(
              active: true,
              height: 96,
              color: AppColors.primary,
              // Bars come from the run's tone (its measured envelope): tracked
              // at the player's real position with sound on, and scrolled from
              // the countdown with sound off — always the running clip.
              source: _audio.waveform,
            ),
            const SizedBox(height: 24),
            Text(
              'Keep the volume up and listen for anything that buzzes, drops '
              'out or stays silent. A chime plays when the run finishes.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      bottomBar: AppButton.danger(
        label: 'Stop',
        icon: Icons.stop_rounded,
        onPressed: _stop,
      ),
    );
  }
}

/// A circular progress ring with the remaining time in the centre.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({required this.controller, required this.total});

  final AnimationController controller;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final remaining = (total * (1 - controller.value)).ceil();
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: controller.value,
                    strokeWidth: 12,
                    backgroundColor: AppColors.cardBlue,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatClock(remaining),
                      style: text.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'remaining',
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "1:23" clock format for the countdown ring.
String _formatClock(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Human-friendly duration: "36 sec" or "1 min 23 sec".
String _formatDuration(int seconds) {
  if (seconds < 60) return '$seconds sec';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return s == 0 ? '$m min' : '$m min $s sec';
}
