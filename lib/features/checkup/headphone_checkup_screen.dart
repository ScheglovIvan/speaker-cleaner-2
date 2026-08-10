import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/audio_visibility.dart';
import '../../core/audio/cleaning_audio.dart';
import '../../core/audio/tone_bank.dart';
import '../../core/audio/waveform_source.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/remote_config.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';
import '../0012/phase_test_screen.dart';

/// Headphone & earbud checkup — a short guided sequence over the pieces the app
/// already has: the generated tone bank ([ToneBank]) played through the
/// existing [ChannelAudio] routing.
///
/// Five steps: left only, right only, both/balance, phase, and the optional
/// 20 Hz -> 20 kHz sweep. Each step says what a healthy pair sounds like, and
/// the listener records their own verdict — the app never claims to have
/// *measured* the headphones, because nothing on the device can hear them.
///
/// Pushed as a plain route from the Test Hub, so it adds no screen id and every
/// existing deep link keeps working.
class HeadphoneCheckupScreen extends StatefulWidget {
  const HeadphoneCheckupScreen({super.key});

  @override
  State<HeadphoneCheckupScreen> createState() => _HeadphoneCheckupScreenState();
}

/// What one step of the checkup drives.
enum _StepKind { tone, sweep }

class _CheckupStep {
  const _CheckupStep({
    required this.title,
    required this.instruction,
    required this.expectation,
    required this.icon,
    required this.balance,
    this.kind = _StepKind.tone,
    this.premium = false,
    this.optional = false,
    this.phase = false,
  });

  final String title;

  /// What to do at this step.
  final String instruction;

  /// What a healthy pair sounds like here.
  final String expectation;

  final IconData icon;

  /// Stereo balance this step routes the signal to.
  final double balance;

  final _StepKind kind;

  /// Behind the Pro entitlement (the sweep, like everywhere else).
  final bool premium;

  /// Can be skipped without breaking the sequence.
  final bool optional;

  /// The phase step, which also offers the standalone A/B check.
  final bool phase;
}

class _HeadphoneCheckupScreenState extends State<HeadphoneCheckupScreen>
    with WidgetsBindingObserver, AudioVisibilityGuard<HeadphoneCheckupScreen> {
  static const List<_CheckupStep> _steps = [
    _CheckupStep(
      title: 'Left side',
      instruction: 'Wear both earpieces. Play the tone and listen.',
      expectation:
          'A clean, steady tone in the LEFT ear only, with silence on the '
          'right. Nothing rattling, crackling or cutting in and out.',
      icon: Icons.align_horizontal_left_rounded,
      balance: -1.0,
    ),
    _CheckupStep(
      title: 'Right side',
      instruction: 'Same tone, other side. Do not move the earpieces.',
      expectation:
          'The same tone in the RIGHT ear only — and just as loud as the left '
          'one was. A quieter or duller side is the usual sign of a failing '
          'driver or a blocked mesh.',
      icon: Icons.align_horizontal_right_rounded,
      balance: 1.0,
    ),
    _CheckupStep(
      title: 'Both sides, balance',
      instruction: 'Now both channels together.',
      expectation:
          'One solid tone sitting dead centre between your ears. If it leans '
          'to one side, the two drivers are not matched — or one earpiece is '
          'not seated properly.',
      icon: Icons.align_horizontal_center_rounded,
      balance: 0.0,
    ),
    _CheckupStep(
      title: 'Phase',
      instruction:
          'Both channels in phase. Concentrate on WHERE the tone appears.',
      expectation:
          'Centred and full, like a single source in the middle of your head. '
          'Thin, hollow and impossible to place means the pair is wired out of '
          'phase. Open the full phase check to A/B it against each side alone.',
      icon: Icons.swap_horiz_rounded,
      balance: 0.0,
      phase: true,
    ),
    _CheckupStep(
      title: 'Full-range sweep',
      instruction: 'A 12-second climb from 20 Hz to 20 kHz.',
      expectation:
          'A smooth, unbroken rise. Buzzes, dropouts or a sudden change in '
          'loudness mark the trouble spots. Losing the very top is normal — '
          'most adults do.',
      icon: Icons.waves_rounded,
      balance: 0.0,
      kind: _StepKind.sweep,
      premium: true,
      optional: true,
    ),
  ];

  final ChannelAudio _tone = ChannelAudio(waveform: ToneWaveform());
  final ChannelAudio _sweep = ChannelAudio(waveform: SweepWaveform());

  ToneWaveform get _toneWave => _tone.waveform as ToneWaveform;
  SweepWaveform get _sweepWave => _sweep.waveform as SweepWaveform;

  StreamSubscription<void>? _sweepDone;

  int _index = 0;
  bool _playing = false;

  /// The listener's own verdict per step: true = sounded right, false = not,
  /// absent = skipped.
  final Map<int, bool> _results = <int, bool>{};

  /// True once the sequence has run to the end.
  bool _finished = false;

  _CheckupStep get _step => _steps[_index];

  bool get _isSweep => _step.kind == _StepKind.sweep;

  @override
  void initState() {
    super.initState();
    _toneWave.useTone(ToneBank.phaseToneHz);
    _sweepDone = _sweep.onComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _sweepDone?.cancel();
    _tone.dispose();
    _sweep.dispose();
    super.dispose();
  }

  @override
  void onScreenHidden() {
    if (!_playing) return;
    _stop();
  }

  bool get _sweepLocked =>
      _isSweep &&
      _step.premium &&
      context.appState.isFeatureLocked(PremiumFeature.allModes);

  Future<void> _stop() async {
    await _tone.stop();
    await _sweep.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _stop();
      return;
    }
    if (_sweepLocked) {
      await _openPaywall();
      return;
    }
    if (_isSweep) {
      await _tone.stop();
      await _sweep.play(
        SpeakerChannel.auto,
        ToneBank.sweepAsset,
        balance: _step.balance,
        loop: false,
      );
    } else {
      await _sweep.stop();
      _toneWave.useTone(ToneBank.phaseToneHz);
      await _tone.play(
        SpeakerChannel.auto,
        ToneBank.assetFor(ToneBank.phaseToneHz),
        balance: _step.balance,
      );
    }
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).pushNamed('/0001');
    if (!mounted) return;
    await context.appState.refreshEntitlement();
    setState(() {});
  }

  /// Record the verdict for this step (or skip it) and move on.
  Future<void> _advance({bool? verdict}) async {
    await _stop();
    if (!mounted) return;
    setState(() {
      if (verdict != null) {
        _results[_index] = verdict;
      } else {
        _results.remove(_index);
      }
      if (_index < _steps.length - 1) {
        _index++;
      } else {
        _finished = true;
      }
    });
    if (_finished) await _celebrate();
  }

  /// End-of-test feedback: the same completion chime the maintenance run uses.
  Future<void> _celebrate() async {
    final state = context.appState;
    if (state.soundEnabled) await CleaningTones.playCompletionChime();
    if (state.hapticsEnabled) HapticFeedback.mediumImpact();
  }

  Future<void> _restart() async {
    await _stop();
    if (!mounted) return;
    setState(() {
      _index = 0;
      _finished = false;
      _results.clear();
    });
  }

  Future<void> _openPhaseTest() async {
    await _stop();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PhaseTestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watchAppState;
    if (_finished) return _buildSummary(context);

    final text = Theme.of(context).textTheme;
    final locked = _sweepLocked;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Headphone Checkup', showBack: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _StepProgress(index: _index, total: _steps.length),
          const SizedBox(height: 14),
          AppGradientCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_step.icon, color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _step.title,
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (locked)
                      const AppBadge(
                        label: 'PRO',
                        icon: Icons.workspace_premium_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isSweep
                      ? '20 Hz → 20 kHz · ${ToneBank.sweepSeconds.round()} s'
                      : '${ToneBank.label(ToneBank.phaseToneHz)} sine',
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                WaveformVisualizer(
                  active: _playing,
                  height: 76,
                  color: Colors.white,
                  source: _isSweep ? _sweepWave : _toneWave,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _step.instruction,
            style: text.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.cardBlue,
            elevated: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A healthy result',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _step.expectation,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_step.phase) ...[
            AppListTile(
              leadingIcon: Icons.open_in_new_rounded,
              leadingColor: AppColors.accentTeal,
              title: 'Open the full phase check',
              subtitle: 'A/B the centre image against each side',
              onTap: _openPhaseTest,
            ),
            const SizedBox(height: 12),
          ],
          AppButton.tonal(
            label: locked
                ? 'Unlock the sweep'
                : _playing
                    ? 'Stop'
                    : 'Play this step',
            icon: locked
                ? Icons.lock_open_rounded
                : _playing
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
            onPressed: _togglePlay,
          ),
          const SizedBox(height: 8),
          if (_step.optional)
            Center(
              child: TextButton(
                onPressed: () => _advance(),
                child: Text(
                  _index == _steps.length - 1
                      ? 'Skip and finish'
                      : 'Skip this step',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: Row(
        children: [
          Expanded(
            child: AppButton(
              label: "Something's off",
              icon: Icons.report_gmailerrorred_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: () => _advance(verdict: false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton.gradient(
              label: 'Sounds right',
              icon: Icons.check_rounded,
              onPressed: () => _advance(verdict: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final failed = <String>[
      for (final e in _results.entries)
        if (e.value == false) _steps[e.key].title,
    ];
    final checked = _results.length;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Checkup Complete', showBack: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: AppHeroIcon(
              icon: failed.isEmpty
                  ? Icons.verified_rounded
                  : Icons.warning_amber_rounded,
              size: 84,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            failed.isEmpty
                ? 'Everything you checked sounded right'
                : '${failed.length} of $checked checks need a second look',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            failed.isEmpty
                ? 'Based on what you heard, both sides, the balance and the '
                    'phase behaved the way a healthy pair should.'
                : 'You flagged: ${failed.join(', ')}. Re-seat the earpieces, '
                    'try another cable or port, then run the checkup again — a '
                    'fault that follows the earpiece is the earpiece.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < _steps.length; i++) ...[
            _ResultRow(title: _steps[i].title, verdict: _results[i]),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text(
            'These results are your own listening notes — the app plays the '
            'test signals, it cannot hear your headphones.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.gradient(
            label: 'Run it again',
            icon: Icons.refresh_rounded,
            onPressed: _restart,
          ),
          const SizedBox(height: 8),
          AppButton.tonal(
            label: 'Done',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// "Step 2 of 5" plus a segmented progress bar.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step ${index + 1} of $total',
          style: text.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= index ? AppColors.primary : AppColors.separator,
                    borderRadius: BorderRadius.circular(AppDimens.radiusPill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// One line of the summary: the step and what the listener said about it.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.title, required this.verdict});

  final String title;

  /// `true` sounded right, `false` flagged, `null` skipped.
  final bool? verdict;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final IconData icon;
    final Color tint;
    final String label;
    if (verdict == true) {
      icon = Icons.check_circle_rounded;
      tint = AppColors.success;
      label = 'Sounded right';
    } else if (verdict == false) {
      icon = Icons.error_rounded;
      tint = AppColors.danger;
      label = 'Flagged';
    } else {
      icon = Icons.remove_circle_outline_rounded;
      tint = AppColors.textSecondary;
      label = 'Skipped';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.separator),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: text.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: tint),
          ),
        ],
      ),
    );
  }
}
