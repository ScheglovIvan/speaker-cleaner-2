import 'package:flutter/material.dart';

import '../../core/audio/audio_visibility.dart';
import '../../core/audio/cleaning_audio.dart';
import '../../core/audio/tone_bank.dart';
import '../../core/audio/waveform_source.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Phase / stereo-image check for headphones and earbuds.
///
/// Plays the generated 500 Hz sine ([ToneBank.phaseToneHz]) through the
/// existing [ChannelAudio] routing and lets the listener A/B the stereo image:
/// both channels together (a solid centre) against each side on its own.
///
/// HONEST LIMITATION — see CAPABILITIES.md. A textbook phase test inverts the
/// polarity of one channel, which `audioplayers` cannot do: it exposes volume
/// and stereo balance, not per-channel polarity, and the app plays bundled
/// mono WAVs. So this screen delivers the closest thing the current engine
/// allows — the in-phase reference plus hard-panned left/right — and states in
/// the UI what a genuinely out-of-phase pair would sound like instead of
/// pretending to produce one.
///
/// Pushed as a plain route from the Tone Generator and the Headphone Checkup,
/// so it adds no screen id and leaves every deep link untouched.
class PhaseTestScreen extends StatefulWidget {
  const PhaseTestScreen({super.key});

  @override
  State<PhaseTestScreen> createState() => _PhaseTestScreenState();
}

/// One A/B position of the check.
enum PhaseStep { inPhase, leftOnly, rightOnly }

extension PhaseStepX on PhaseStep {
  double get balance {
    switch (this) {
      case PhaseStep.inPhase:
        return 0.0;
      case PhaseStep.leftOnly:
        return -1.0;
      case PhaseStep.rightOnly:
        return 1.0;
    }
  }

  String get title {
    switch (this) {
      case PhaseStep.inPhase:
        return 'Both channels, in phase';
      case PhaseStep.leftOnly:
        return 'Left channel only';
      case PhaseStep.rightOnly:
        return 'Right channel only';
    }
  }

  /// What a healthy pair should sound like at this position.
  String get expectation {
    switch (this) {
      case PhaseStep.inPhase:
        return 'Centred and full — the tone should sit solidly between your '
            'ears, as if it came from a single point in the middle of your '
            'head. If it instead sounds thin, hollow and hard to place, the '
            'two sides are wired out of phase.';
      case PhaseStep.leftOnly:
        return 'Everything on the left, nothing on the right. If you hear it '
            'on the right, the sides are swapped; if you hear nothing at all, '
            'that driver is dead.';
      case PhaseStep.rightOnly:
        return 'Everything on the right, nothing on the left. Both sides '
            'should sound equally loud and equally clean as the left one.';
    }
  }

  IconData get icon {
    switch (this) {
      case PhaseStep.inPhase:
        return Icons.align_horizontal_center_rounded;
      case PhaseStep.leftOnly:
        return Icons.align_horizontal_left_rounded;
      case PhaseStep.rightOnly:
        return Icons.align_horizontal_right_rounded;
    }
  }
}

class _PhaseTestScreenState extends State<PhaseTestScreen>
    with WidgetsBindingObserver, AudioVisibilityGuard<PhaseTestScreen> {
  final ChannelAudio _audio = ChannelAudio(waveform: ToneWaveform());

  ToneWaveform get _wave => _audio.waveform as ToneWaveform;

  PhaseStep _step = PhaseStep.inPhase;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _wave.useTone(ToneBank.phaseToneHz);
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  void onScreenHidden() {
    if (!_playing) return;
    _audio.stop();
    if (mounted) setState(() => _playing = false);
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _audio.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _audio.play(
      SpeakerChannel.auto,
      ToneBank.assetFor(ToneBank.phaseToneHz),
      balance: _step.balance,
    );
    if (mounted) setState(() => _playing = true);
  }

  void _select(PhaseStep step) {
    setState(() => _step = step);
    // Switch the image live so the A/B is instant — the ear compares much
    // better without a gap between the two positions.
    if (_playing) _audio.setBalance(step.balance);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Phase Check', showBack: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${ToneBank.label(ToneBank.phaseToneHz)} sine',
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                WaveformVisualizer(
                  active: _playing,
                  height: 76,
                  color: Colors.white,
                  source: _wave,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AppSectionHeader(
            title: 'Wear both earpieces',
            subtitle: 'Switch between the three positions while the tone plays.',
          ),
          const SizedBox(height: 8),
          for (final s in PhaseStep.values) ...[
            AppSelectableRow(
              title: s.title,
              leadingIcon: s.icon,
              selected: _step == s,
              onTap: () => _select(s),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          AppCard(
            color: AppColors.cardBlue,
            elevated: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.hearing_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What you should hear',
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
          const _PhaseLimitationNote(),
          const SizedBox(height: 8),
        ],
      ),
      bottomBar: AppButton(
        label: _playing ? 'Stop tone' : 'Play tone',
        icon: _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        variant:
            _playing ? AppButtonVariant.danger : AppButtonVariant.gradient,
        onPressed: _toggle,
      ),
    );
  }
}

/// States plainly what this build can and cannot do, rather than dressing the
/// A/B up as a real polarity inversion.
class _PhaseLimitationNote extends StatelessWidget {
  const _PhaseLimitationNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.separator),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This check compares the in-phase centre image against each side '
              'on its own. The audio engine here can pan a channel but cannot '
              'flip its polarity, so the app does not generate a truly '
              'out-of-phase signal — the description above tells you what one '
              'sounds like so you can recognise it on your own gear.',
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
