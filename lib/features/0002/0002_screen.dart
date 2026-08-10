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
import '../premium/premium_benefits.dart';

/// Screen 0002 — Channel Test.
///
/// Route the test tone through a specific speaker channel and watch a live
/// waveform. The functions are laid out as a GRID of separate interactive cards
/// (Left Speaker / Right Speaker / Earpiece / Auto Balance), each with a clear
/// selected/active state, matching the original's arrangement.
///
/// Real playback: `audioplayers` `setBalance()` targets the left (-1.0) / right
/// (+1.0) driver, both/centred (0.0) for Auto Balance (and Left+Right together),
/// and the loud-speaker audio session so the tone is actually audible. Earpiece
/// attempts the iOS receiver route (see CAPABILITIES.md). Nothing plays until
/// the user taps Play.
///
/// The Channel Test is a Premium feature: free users see the [PremiumLockView].
class Screen_0002 extends StatelessWidget {
  const Screen_0002({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0002';

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    if (state.isFeatureLocked(PremiumFeature.stereoMixer)) {
      return const PremiumLockView(
        featureName: 'The Channel Test',
        title: 'Channel Test',
        icon: Icons.compare_arrows_rounded,
      );
    }
    return const _ChannelMixer();
  }
}

class _ChannelMixer extends StatefulWidget {
  const _ChannelMixer();

  @override
  State<_ChannelMixer> createState() => _ChannelMixerState();
}

/// One selectable channel tile in the grid.
class _ChannelDef {
  const _ChannelDef({
    required this.channel,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final SpeakerChannel channel;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _ChannelMixerState extends State<_ChannelMixer>
    with WidgetsBindingObserver, AudioVisibilityGuard<_ChannelMixer> {
  static const List<_ChannelDef> _channels = [
    _ChannelDef(
      channel: SpeakerChannel.left,
      title: 'Left Speaker',
      subtitle: 'Left driver only',
      icon: Icons.align_horizontal_left_rounded,
    ),
    _ChannelDef(
      channel: SpeakerChannel.right,
      title: 'Right Speaker',
      subtitle: 'Right driver only',
      icon: Icons.align_horizontal_right_rounded,
    ),
    _ChannelDef(
      channel: SpeakerChannel.earpiece,
      title: 'Earpiece',
      subtitle: 'Top receiver speaker',
      icon: Icons.hearing_rounded,
    ),
    _ChannelDef(
      channel: SpeakerChannel.auto,
      title: 'Auto Balance',
      subtitle: 'Both sides, centred',
      icon: Icons.sync_alt_rounded,
    ),
  ];

  /// The channel-test signal: the generated 500 Hz sine from the tone bank —
  /// a real, steady tone that every driver reproduces, so a dull or silent
  /// side is unmistakable.
  static final String _toneAsset = ToneBank.assetFor(ToneBank.phaseToneHz);

  /// The player, with an oscilloscope trace of that sine (drawn from its own
  /// frequency, since a constant tone has no loudness envelope to follow).
  final ChannelAudio _audio = ChannelAudio(
    waveform: ToneWaveform()..useTone(ToneBank.phaseToneHz),
  );

  /// Selected channels. Left+Right can be selected together (=> centred/both);
  /// Earpiece and Auto Balance are singular modes.
  final Set<SpeakerChannel> _selected = {SpeakerChannel.auto};
  bool _playing = false;

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  /// The tab shell keeps this screen alive in its `IndexedStack`, so `dispose`
  /// does NOT run when the user switches tabs. Silence the tone as soon as the
  /// screen stops being the visible tab (or the app is backgrounded) — the
  /// screen itself stays mounted, only the playback stops.
  @override
  void onScreenHidden() {
    if (!_playing) return;
    _audio.stop();
    if (mounted) setState(() => _playing = false);
  }

  bool _isSelected(SpeakerChannel c) => _selected.contains(c);

  void _onTapChannel(SpeakerChannel c) {
    setState(() {
      if (c == SpeakerChannel.left || c == SpeakerChannel.right) {
        // Left/Right are additive toggles — clear the singular modes first.
        _selected
          ..remove(SpeakerChannel.earpiece)
          ..remove(SpeakerChannel.auto);
        if (_selected.contains(c)) {
          _selected.remove(c);
        } else {
          _selected.add(c);
        }
        // Never leave nothing selected — fall back to Auto Balance.
        if (_selected.isEmpty) _selected.add(SpeakerChannel.auto);
      } else {
        // Earpiece / Auto Balance are exclusive.
        _selected
          ..clear()
          ..add(c);
      }
    });
    // Apply the new routing live if a tone is already playing.
    if (_playing) {
      _audio.setChannel(_effectiveChannel, balance: _effectiveBalance);
    }
  }

  /// The single channel/route the current selection resolves to.
  SpeakerChannel get _effectiveChannel {
    if (_selected.contains(SpeakerChannel.earpiece)) {
      return SpeakerChannel.earpiece;
    }
    if (_selected.contains(SpeakerChannel.auto)) return SpeakerChannel.auto;
    final hasL = _selected.contains(SpeakerChannel.left);
    final hasR = _selected.contains(SpeakerChannel.right);
    if (hasL && hasR) return SpeakerChannel.auto; // both => centred
    if (hasL) return SpeakerChannel.left;
    if (hasR) return SpeakerChannel.right;
    return SpeakerChannel.auto;
  }

  double get _effectiveBalance {
    switch (_effectiveChannel) {
      case SpeakerChannel.left:
        return -1.0;
      case SpeakerChannel.right:
        return 1.0;
      case SpeakerChannel.earpiece:
      case SpeakerChannel.auto:
        return 0.0;
    }
  }

  String get _routingLabel {
    final hasL = _selected.contains(SpeakerChannel.left);
    final hasR = _selected.contains(SpeakerChannel.right);
    if (_selected.contains(SpeakerChannel.earpiece)) return 'Earpiece';
    if (_selected.contains(SpeakerChannel.auto)) return 'Auto Balance';
    if (hasL && hasR) return 'Left + Right';
    if (hasL) return 'Left Speaker';
    if (hasR) return 'Right Speaker';
    return 'Auto Balance';
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _audio.stop();
      if (mounted) setState(() => _playing = false);
    } else {
      await _audio.play(
        _effectiveChannel,
        _toneAsset,
        balance: _effectiveBalance,
      );
      if (mounted) setState(() => _playing = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      topBar: const AppTopBar(title: 'Channel Test'),
      bottomBar: AppButton(
        label: _playing ? 'Stop Tone' : 'Play Test Tone',
        icon: _playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        variant: _playing ? AppButtonVariant.danger : AppButtonVariant.gradient,
        onPressed: _togglePlay,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        children: [
          // Live-output hero: current routing + animated waveform.
          AppGradientCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Now routing',
                            style: text.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _routingLabel,
                            style: text.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(playing: _playing),
                  ],
                ),
                const SizedBox(height: 16),
                WaveformVisualizer(
                  active: _playing,
                  height: 96,
                  color: Colors.white,
                  // Bars come from the routed test tone itself, tracked at the
                  // player's real position.
                  source: _audio.waveform,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const AppSectionHeader(
            title: 'Output channel',
            subtitle: 'Tap a card to choose where the tone plays',
          ),
          const SizedBox(height: 8),
          // 2×2 grid of interactive channel cards.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.22,
            children: [
              for (final def in _channels)
                _ChannelCard(
                  def: def,
                  selected: _isSelected(def.channel),
                  active: _playing && _isSelected(def.channel),
                  onTap: () => _onTapChannel(def.channel),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _MixerHint(),
        ],
      ),
    );
  }
}

/// A single interactive channel card in the grid.
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.def,
    required this.selected,
    required this.active,
    required this.onTap,
  });

  final _ChannelDef def;
  final bool selected;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppDimens.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      label: def.title,
      child: Material(
        color: selected ? AppColors.cardBlue : AppColors.background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.separator,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.14)
                            : AppColors.backgroundMuted,
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Icon(
                        def.icon,
                        size: 20,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      selected
                          ? (active
                              ? Icons.graphic_eq_rounded
                              : Icons.check_circle_rounded)
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color:
                          selected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  def.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? 'Playing…' : def.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color:
                        active ? AppColors.primary : AppColors.textSecondary,
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

/// Small "Playing / Idle" status marker sitting in the hero card.
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

/// Footnote reminding the user what the channel test is for.
class _MixerHint extends StatelessWidget {
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
            'The signal is a real 500 Hz sine. Isolate one side to confirm '
            'that driver responds — useful for '
            'checking a new pair of headphones is not wired backwards. Pick '
            'Left + Right together to centre it, or Auto Balance to play both. '
            'Channel separation only applies on devices/headsets with '
            'independent left/right drivers.',
            style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
