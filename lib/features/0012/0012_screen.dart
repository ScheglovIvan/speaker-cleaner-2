import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_visibility.dart';
import '../../core/audio/cleaning_audio.dart';
import '../../core/audio/tone_bank.dart';
import '../../core/audio/waveform_source.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/remote_config.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';
import 'phase_test_screen.dart';

/// Screen 0012 — Tone Generator ("Tones" tab).
///
/// A real generator, not a menu of clips: picking 1 kHz plays
/// `assets/audio/tone_1000.wav`, a sine generated at exactly 1000 Hz by
/// `tool/generate_tones.py`. The frequency on screen is always the frequency
/// coming out of the speaker.
///
/// What it drives:
///  * a held tone — the selected sine, looped seamlessly (the clips are cut to
///    a whole number of cycles) until the user stops it;
///  * channel targeting — Left / Both / Right through the existing
///    [ChannelAudio.setBalance], applied live while the tone is sounding;
///  * the 20 Hz -> 20 kHz sweep — the generated 12 s chirp, played once;
///  * the phase check — handed to [PhaseTestScreen].
///
/// Pro gates the top of the range (1 kHz and up), continuous play (free tones
/// stop after [ToneBank.freePlaySeconds]) and the sweep, using the same
/// [PremiumFeature.allModes] entitlement as the rest of the app.
class Screen_0012 extends StatefulWidget {
  const Screen_0012({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0012';

  @override
  State<Screen_0012> createState() => _Screen_0012State();
}

/// Where the generator sends the tone.
enum ToneChannel { left, both, right }

extension _ToneChannelX on ToneChannel {
  /// The `audioplayers` balance this targeting maps to.
  double get balance {
    switch (this) {
      case ToneChannel.left:
        return -1.0;
      case ToneChannel.both:
        return 0.0;
      case ToneChannel.right:
        return 1.0;
    }
  }

  String get label {
    switch (this) {
      case ToneChannel.left:
        return 'Left';
      case ToneChannel.both:
        return 'Both';
      case ToneChannel.right:
        return 'Right';
    }
  }

  IconData get icon {
    switch (this) {
      case ToneChannel.left:
        return Icons.align_horizontal_left_rounded;
      case ToneChannel.both:
        return Icons.align_horizontal_center_rounded;
      case ToneChannel.right:
        return Icons.align_horizontal_right_rounded;
    }
  }
}

class _Screen_0012State extends State<Screen_0012>
    with WidgetsBindingObserver, AudioVisibilityGuard<Screen_0012> {
  /// The held tone, drawn as an oscilloscope trace of its own frequency.
  final ChannelAudio _tone = ChannelAudio(waveform: ToneWaveform());

  /// The sweep, drawn from the chirp's own formula.
  final ChannelAudio _sweep = ChannelAudio(waveform: SweepWaveform());

  ToneWaveform get _toneWave => _tone.waveform as ToneWaveform;
  SweepWaveform get _sweepWave => _sweep.waveform as SweepWaveform;

  /// Index into [ToneBank.frequencies]; starts on 500 Hz (free, and the easiest
  /// tone to judge on any speaker).
  int _index = ToneBank.frequencies.indexOf(ToneBank.phaseToneHz);

  ToneChannel _channel = ToneChannel.both;

  bool _tonePlaying = false;
  bool _sweepPlaying = false;

  /// Stops a free user's tone after [ToneBank.freePlaySeconds] — continuous
  /// play is the Pro half of this feature.
  Timer? _freeLimit;

  /// Set when that timer actually cut a tone short, so the screen can say why.
  bool _hitFreeLimit = false;

  StreamSubscription<void>? _sweepDone;

  int get _frequency => ToneBank.frequencies[_index];

  @override
  void initState() {
    super.initState();
    _toneWave.useTone(_frequency);
    // The sweep is a one-shot: reset the UI when the chirp reaches its end.
    _sweepDone = _sweep.onComplete.listen((_) {
      if (mounted) setState(() => _sweepPlaying = false);
    });
  }

  @override
  void dispose() {
    _freeLimit?.cancel();
    _sweepDone?.cancel();
    _tone.dispose();
    _sweep.dispose();
    super.dispose();
  }

  /// The tab shell keeps this screen alive in its `IndexedStack`, so `dispose`
  /// does not run on a tab switch — silence everything the moment the screen
  /// stops being visible (or the app is backgrounded).
  @override
  void onScreenHidden() {
    if (!_tonePlaying && !_sweepPlaying) return;
    _stopAll();
  }

  // ── Entitlement ────────────────────────────────────────────────────────────

  /// True when the premium half of the generator is gated for this (free) user.
  bool get _gated => context.appState.isFeatureLocked(PremiumFeature.allModes);

  bool _isLocked(int hz) => _gated && !ToneBank.isFree(hz);

  Future<void> _openPaywall() async {
    await Navigator.of(context).pushNamed('/0001');
    if (!mounted) return;
    await context.appState.refreshEntitlement();
  }

  // ── Playback ───────────────────────────────────────────────────────────────

  Future<void> _stopAll() async {
    _freeLimit?.cancel();
    _freeLimit = null;
    await _tone.stop();
    await _sweep.stop();
    if (mounted) {
      setState(() {
        _tonePlaying = false;
        _sweepPlaying = false;
      });
    }
  }

  /// Start (or restart) the selected sine on the selected channel.
  Future<void> _startTone() async {
    await _sweep.stop();
    _freeLimit?.cancel();
    _toneWave.useTone(_frequency);
    await _tone.play(
      SpeakerChannel.auto,
      ToneBank.assetFor(_frequency),
      balance: _channel.balance,
    );
    if (!mounted) return;
    setState(() {
      _tonePlaying = true;
      _sweepPlaying = false;
      _hitFreeLimit = false;
    });
    if (_gated) {
      _freeLimit = Timer(
        const Duration(seconds: ToneBank.freePlaySeconds),
        () async {
          await _tone.stop();
          if (!mounted) return;
          setState(() {
            _tonePlaying = false;
            _hitFreeLimit = true;
          });
        },
      );
    }
  }

  Future<void> _toggleTone() async {
    if (_isLocked(_frequency)) {
      await _openPaywall();
      return;
    }
    if (_tonePlaying) {
      _freeLimit?.cancel();
      await _tone.stop();
      if (mounted) setState(() => _tonePlaying = false);
    } else {
      await _startTone();
    }
  }

  Future<void> _onFrequencyTap(int index) async {
    final hz = ToneBank.frequencies[index];
    if (_isLocked(hz)) {
      await _openPaywall();
      if (!mounted) return;
      if (_isLocked(hz)) return;
      setState(() => _index = index);
      return;
    }
    setState(() {
      _index = index;
      _hitFreeLimit = false;
    });
    // A different sine means a different clip — restart so the tone that is
    // sounding always matches the label.
    if (_tonePlaying) {
      await _startTone();
    } else {
      _toneWave.useTone(hz);
    }
  }

  void _onChannelTap(ToneChannel channel) {
    setState(() => _channel = channel);
    // Re-pan live, without interrupting the tone.
    if (_tonePlaying) _tone.setBalance(channel.balance);
    if (_sweepPlaying) _sweep.setBalance(channel.balance);
  }

  Future<void> _toggleSweep() async {
    if (_gated) {
      await _openPaywall();
      return;
    }
    if (_sweepPlaying) {
      await _sweep.stop();
      if (mounted) setState(() => _sweepPlaying = false);
      return;
    }
    _freeLimit?.cancel();
    await _tone.stop();
    await _sweep.play(
      SpeakerChannel.auto,
      ToneBank.sweepAsset,
      balance: _channel.balance,
      loop: false, // the chirp runs exactly once, end to end
    );
    if (!mounted) return;
    setState(() {
      _sweepPlaying = true;
      _tonePlaying = false;
      _hitFreeLimit = false;
    });
  }

  Future<void> _openPhaseTest() async {
    await _stopAll();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PhaseTestScreen()),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Rebuild when the Pro entitlement changes so the locks fall away instantly.
    context.watchAppState;
    final playing = _tonePlaying || _sweepPlaying;
    final locked = _isLocked(_frequency);

    return AppScaffold(
      backgroundColor: AppColors.background,
      topBar: const AppTopBar(title: 'Tone Generator'),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          _GeneratorHero(
            title: _sweepPlaying
                ? '20 Hz → 20 kHz'
                : ToneBank.label(_frequency),
            subtitle: _sweepPlaying
                ? 'Logarithmic sweep · ${ToneBank.sweepSeconds.round()} s'
                : 'Sine wave · ${_channel.label.toLowerCase()}',
            playing: playing,
            source: _sweepPlaying ? _sweepWave : _toneWave,
          ),
          const SizedBox(height: 16),
          const AppSectionHeader(
            title: 'Frequency',
            subtitle: 'Every tone is a real sine at the frequency shown.',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < ToneBank.frequencies.length; i++)
                _FrequencyChip(
                  label: ToneBank.label(ToneBank.frequencies[i]),
                  selected: i == _index,
                  locked: _isLocked(ToneBank.frequencies[i]),
                  onTap: () => _onFrequencyTap(i),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ToneBank.hint(_frequency),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          const AppSectionHeader(
            title: 'Play through',
            subtitle: 'Send the tone to one side or to both.',
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final c in ToneChannel.values) ...[
                if (c != ToneChannel.values.first) const SizedBox(width: 8),
                Expanded(
                  child: _ChannelButton(
                    channel: c,
                    selected: _channel == c,
                    onTap: () => _onChannelTap(c),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          _SweepCard(
            playing: _sweepPlaying,
            locked: _gated,
            onTap: _toggleSweep,
          ),
          const SizedBox(height: 10),
          AppListTile(
            leadingIcon: Icons.swap_horiz_rounded,
            leadingColor: AppColors.accentTeal,
            title: 'Phase check',
            subtitle: 'In phase vs one side alone — for headphones',
            onTap: _openPhaseTest,
          ),
          const SizedBox(height: 16),
          if (_gated) _FreeTierNote(hitLimit: _hitFreeLimit),
          if (_gated) const SizedBox(height: 10),
          const _GeneratorHint(),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: locked
          ? AppButton.gradient(
              label: 'Unlock ${ToneBank.label(_frequency)}',
              icon: Icons.lock_open_rounded,
              onPressed: _openPaywall,
            )
          : AppButton(
              label: _tonePlaying
                  ? 'Stop'
                  : 'Play ${ToneBank.label(_frequency)}',
              icon: _tonePlaying
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              variant: _tonePlaying
                  ? AppButtonVariant.danger
                  : AppButtonVariant.gradient,
              onPressed: _toggleTone,
            ),
    );
  }
}

/// Gradient hero: what is playing right now, plus the live trace of the signal.
class _GeneratorHero extends StatelessWidget {
  const _GeneratorHero({
    required this.title,
    required this.subtitle,
    required this.playing,
    required this.source,
  });

  final String title;
  final String subtitle;
  final bool playing;
  final WaveformSource source;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(playing: playing),
            ],
          ),
          const SizedBox(height: 14),
          // The bars are the signal itself: the generated sine (or chirp) drawn
          // at the player's real position, so they only move while it sounds.
          WaveformVisualizer(
            active: playing,
            height: 84,
            color: Colors.white,
            source: source,
          ),
        ],
      ),
    );
  }
}

/// "Playing / Idle" marker in the hero.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.playing});

  final bool playing;

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
          Icon(
            playing ? Icons.graphic_eq_rounded : Icons.pause_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            playing ? 'Playing' : 'Idle',
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

/// One frequency in the selector row.
class _FrequencyChip extends StatelessWidget {
  const _FrequencyChip({
    required this.label,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppDimens.radiusPill);
    final tint = selected ? AppColors.primary : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, Premium' : label,
      child: Material(
        color: selected ? AppColors.cardBlue : AppColors.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.separator,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(Icons.lock_rounded, size: 14, color: tint),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: text.labelLarge?.copyWith(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Left / Both / Right targeting button.
class _ChannelButton extends StatelessWidget {
  const _ChannelButton({
    required this.channel,
    required this.selected,
    required this.onTap,
  });

  final ToneChannel channel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppDimens.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      label: channel.label,
      child: Material(
        color: selected ? AppColors.cardBlue : AppColors.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.separator,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  channel.icon,
                  size: 22,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  channel.label,
                  style: text.labelLarge?.copyWith(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20 Hz -> 20 kHz sweep, with its own play/stop control.
class _SweepCard extends StatelessWidget {
  const _SweepCard({
    required this.playing,
    required this.locked,
    required this.onTap,
  });

  final bool playing;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: AppColors.cardBlue,
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.waves_rounded,
                  size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sweep 20 Hz → 20 kHz',
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (locked)
                const AppBadge(
                  label: 'PRO',
                  icon: Icons.workspace_premium_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'One continuous 12-second climb through the whole audible range. '
            'Listen for anything that buzzes, drops out or suddenly goes quiet '
            '— and note where you stop hearing it at all.',
            style: text.bodySmall?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          AppButton.tonal(
            label: locked
                ? 'Unlock the sweep'
                : playing
                    ? 'Stop sweep'
                    : 'Run the sweep',
            icon: locked
                ? Icons.lock_open_rounded
                : playing
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

/// Explains the free tier's continuous-play limit honestly.
class _FreeTierNote extends StatelessWidget {
  const _FreeTierNote({required this.hitLimit});

  /// True once the limit has actually cut a tone short.
  final bool hitLimit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      elevated: false,
      border: Border.all(color: AppColors.separator),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hitLimit ? Icons.timer_off_outlined : Icons.timer_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hitLimit
                  ? 'That tone stopped after '
                      '${ToneBank.freePlaySeconds} seconds. Pro plays any tone '
                      'continuously and unlocks 1 kHz and above plus the sweep.'
                  : 'Free tones play for up to '
                      '${ToneBank.freePlaySeconds} seconds at a time. Pro plays '
                      'them continuously and unlocks 1 kHz and above plus the '
                      'sweep.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// How to get a useful result out of the generator.
class _GeneratorHint extends StatelessWidget {
  const _GeneratorHint();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Start at a moderate volume — a loud pure tone is hard on both your '
            'ears and a small driver. Left/Right targeting needs a device or '
            'headset with independent drivers; a single mono speaker plays the '
            'same tone whichever side you pick.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
