import 'package:audioplayers/audioplayers.dart';

import 'waveform_source.dart';

/// The two bundled clips the app still uses.
///
/// The test signals themselves are NOT here — every tone the user can select is
/// generated at a real frequency into `assets/audio/tone_<hz>.wav` (see
/// `tone_bank.dart`). What remains from `app_spec.json` `content.audio` is the
/// pair that is not a labelled frequency:
///  * [waterTone]     — audio_1: the low water-eject clip driving the one
///                      maintenance run.
///  * [completeChime] — audio_result: the "this test finished" sound.
///
/// The `tone_vibrate` / `tone_air` clips backed the old "cleaning modes"; no
/// screen references them any more, so they are no longer bundled.
///
/// Paths are relative to `assets/` (the `audioplayers` [AssetSource] convention).
class CleaningTones {
  CleaningTones._();

  static const String waterTone = 'audio/tone_water.mp3';
  static const String completeChime = 'audio/chime_complete.mp3';

  /// Default tone when a caller doesn't specify one (the maintenance run).
  static const String defaultTone = waterTone;

  /// Fire-and-forget completion chime (audio_result) that is NOT tied to any
  /// screen's lifecycle. The cleaning run screen tears itself down the instant a
  /// run finishes (it routes on to the Day Complete / result screen), so a
  /// chime played through that screen's [CleaningAudio] would be cut off the
  /// moment its player is disposed. This spins up an independent one-shot player
  /// that disposes itself once playback completes, so the "run finished" sound
  /// always plays in full on its trigger.
  ///
  /// Best-effort: on a preview / headless environment with no audio backend it
  /// fails silently so the completion flow never crashes.
  static Future<void> playCompletionChime() async {
    final player = AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.release);
      await player.setAudioContext(AppAudioContext.speaker);
      // Reclaim the player once the one-shot finishes so it doesn't leak.
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
      await player.play(AssetSource(completeChime));
    } catch (_) {
      try {
        await player.dispose();
      } catch (_) {}
    }
  }
}

/// Centralised iOS/Android audio-session configuration for `audioplayers`.
///
/// A speaker-cleaning app must play its tuned tones at full output through the
/// loudspeaker even when the hardware mute (silent) switch is on. On iOS that
/// requires the `playback` audio-session category (which routes to the speaker
/// and ignores the silent switch). Without this the tones are silently muted —
/// which is exactly the "tapping Play produces no sound" bug.
class AppAudioContext {
  AppAudioContext._();

  /// Loud speaker output that ignores the silent switch (category `playback`).
  /// Used for cleaning tones and the speaker/left/right/auto stereo channels.
  static final AudioContext speaker = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  /// Route to the top **earpiece / receiver**. On iOS the public way to target
  /// the receiver is the `playAndRecord` category with no `defaultToSpeaker`
  /// option (see CAPABILITIES.md — this needs the microphone entitlement, and
  /// the OS chooses the receiver as the default output). Falls back gracefully
  /// to [speaker] on platforms/devices that can't honour it.
  static final AudioContext earpiece = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playAndRecord,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.voiceCommunication,
      audioFocus: AndroidAudioFocus.gain,
    ),
  );

  /// Apply the loud-speaker context as the process-wide default. Called once in
  /// `main()` so every player (including one-shots) plays through the speaker.
  /// Best-effort: guarded so an unsupported/preview platform never crashes.
  static Future<void> configureGlobal() async {
    try {
      await AudioPlayer.global.setAudioContext(speaker);
    } catch (_) {
      // No audio backend (preview / test) — ignore.
    }
  }
}

/// Plays the cleaning tone (looped for the run's duration) and the completion
/// chime. One instance per running clean; dispose when the run screen leaves.
///
/// All playback is best-effort: on a preview / headless environment without an
/// audio backend the futures fail silently so the flow never crashes.
class CleaningAudio {
  CleaningAudio() {
    waveform.bind(_tone);
  }

  final AudioPlayer _tone = AudioPlayer();
  bool _disposed = false;

  /// Bar levels for the waveform visualiser, read from the playing tone's
  /// amplitude envelope at this player's real position.
  final PlaybackWaveform waveform = PlaybackWaveform();

  /// Tell the waveform which clip the run uses, without starting playback.
  ///
  /// The visualiser needs the clip's measured envelope to draw a waveform at
  /// all (otherwise it rests as uniform dots). `startTone` is skipped when sound
  /// is off, so the run screen calls this regardless of the sound toggle and
  /// then scrolls the bars from its countdown via [PlaybackWaveform.driveTo].
  void prepareWaveform(String asset) {
    if (_disposed) return;
    waveform.useAsset(asset);
  }

  /// Start looping [asset] as the cleaning tone. Loops so tones that are
  /// shorter than the routine keep vibrating the speaker for the full duration.
  Future<void> startTone(String asset) async {
    if (_disposed) return;
    waveform.useAsset(asset);
    try {
      // Force the loud-speaker playback session so the tone is audible even
      // with the silent switch on (a speaker-cleaning app must be).
      await _tone.setAudioContext(AppAudioContext.speaker);
      await _tone.setReleaseMode(ReleaseMode.loop);
      await _tone.setVolume(1.0);
      await _tone.play(AssetSource(asset));
    } catch (_) {
      // No audio backend (preview / test) — ignore.
    }
  }

  /// Stop the tone (user pressed Stop, or the run finished).
  Future<void> stopTone() async {
    waveform.reset();
    try {
      await _tone.stop();
    } catch (_) {}
  }

  /// Play the one-shot completion chime (the "result state" sound). Delegates to
  /// the detached one-shot player so it plays in full even though the caller
  /// (the run screen) disposes itself immediately after a run finishes.
  Future<void> playCompletionChime() async {
    if (_disposed) return;
    await CleaningTones.playCompletionChime();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await waveform.dispose();
    try {
      await _tone.dispose();
    } catch (_) {}
  }
}

/// The output channel the Stereo Mixer routes the test tone through.
///
/// The routing is baked into the *asset*, not into a runtime pan: each signal
/// ships as a mono "both channels" file plus a `_l` / `_r` stereo variant that
/// carries the signal in one channel and digital silence in the other. See
/// [ChannelAudio] for why.
enum SpeakerChannel {
  /// Left driver only — plays the `_l.wav` variant (signal left, silent right).
  left,

  /// Right driver only — plays the `_r.wav` variant (silent left, signal right).
  right,

  /// Top earpiece / receiver — attempts the `playAndRecord` receiver route,
  /// playing the centred (mono) variant.
  earpiece,

  /// Both drivers, centred — plays the base mono asset.
  auto,
}

/// Real per-channel playback for the Stereo Mixer (screen 0002).
///
/// **Channel separation comes from the audio files, not from a pan control.**
/// `audioplayers`' [AudioPlayer.setBalance] is a documented no-op on iOS
/// (`audioplayers_darwin`: "setBalance is not currently implemented on iOS"), so
/// panning a mono clip there plays it centred on both drivers and every
/// left/right test silently fails. Instead each signal is bundled three times:
///
///  * `tone_<hz>.wav` / `sweep_20_20000.wav` — mono, i.e. both channels;
///  * `tone_<hz>_l.wav` — stereo with the signal in the LEFT channel only;
///  * `tone_<hz>_r.wav` — stereo with the signal in the RIGHT channel only.
///
/// This class resolves the caller's channel/balance to one *effective* channel
/// and hands the matching variant to the player, so the separation is real on
/// every platform. [setBalance] therefore restarts playback when the effective
/// channel changes (a brief gap is the cost of true separation).
/// [AudioPlayer.setBalance] is still applied — it is harmless on iOS and keeps
/// helping Android — and the loud-speaker [AudioContext] makes the tone audible
/// with the silent switch on. Earpiece routing switches the player to the
/// receiver session (best-effort; see CAPABILITIES.md).
class ChannelAudio {
  ChannelAudio({PlaybackWaveform? waveform})
      : waveform = waveform ?? PlaybackWaveform() {
    this.waveform.bind(_player);
  }

  final AudioPlayer _player = AudioPlayer();
  bool _disposed = false;

  /// The last asset [play] was asked for — always the BASE (mono) name. The
  /// per-channel variant is derived from it on every (re)start.
  String? _baseAsset;

  /// Whether the current clip loops, remembered so a channel change can restart
  /// it the same way.
  bool _loop = true;

  /// The channel the currently loaded variant belongs to.
  SpeakerChannel _channel = SpeakerChannel.auto;

  /// Bar levels for the waveform visualiser, tracked at this player's real
  /// position. Defaults to the clip's measured amplitude envelope; the tone
  /// generator injects a [ToneWaveform] / [SweepWaveform] instead, which draws
  /// the generated signal itself.
  final PlaybackWaveform waveform;

  /// Fires when a one-shot ([play] with `loop: false`) reaches its end.
  Stream<void> get onComplete => _player.onPlayerComplete;

  /// Start (or restart) the test [asset] on the given [channel].
  ///
  /// [balance] lets the caller express Left+Right selected together as a
  /// centred (0.0) mix, and is what the tone generator / checkup screens use to
  /// target a side while passing [SpeakerChannel.auto]; when null the balance is
  /// derived from [channel]. Whichever of the two resolves to a side decides
  /// which stereo variant of [asset] is loaded.
  /// [loop] repeats the clip until stopped (a held tone); pass `false` for a
  /// one-shot such as the 20 Hz -> 20 kHz sweep, which must run exactly once.
  Future<void> play(
    SpeakerChannel channel,
    String asset, {
    double? balance,
    bool loop = true,
  }) async {
    if (_disposed) return;
    _baseAsset = asset;
    _loop = loop;
    _channel = _effectiveChannel(channel, balance);
    // The visualiser is keyed on the BASE clip — the variants share its
    // envelope, so it must not be handed the `_l` / `_r` name.
    waveform.useAsset(asset);
    await _start(balance);
  }

  /// Retarget the signal from a balance value (e.g. the user toggled
  /// Left/Right while the tone is already playing).
  ///
  /// Because the separation lives in the asset, a side change re-plays the
  /// matching variant instead of panning; when the side is unchanged this is a
  /// no-op so an unrelated rebuild never interrupts the tone.
  Future<void> setBalance(double balance) async {
    if (_disposed) return;
    final next = _effectiveChannel(SpeakerChannel.auto, balance);
    if (next == _channel) return;
    _channel = next;
    await _start(balance);
  }

  /// Switch the routing live mid-play: reloads the variant for [channel] (or
  /// for [balance] when [channel] is [SpeakerChannel.auto]) and re-applies the
  /// earpiece / loud-speaker session.
  Future<void> setChannel(SpeakerChannel channel, {double? balance}) async {
    if (_disposed) return;
    _channel = _effectiveChannel(channel, balance);
    await _start(balance);
  }

  Future<void> stop() async {
    waveform.reset();
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// (Re)start the variant for [_channel] from the remembered base asset.
  ///
  /// Best-effort: on a preview / headless environment with no audio backend it
  /// fails silently so the screens never crash.
  Future<void> _start(double? balance) async {
    final base = _baseAsset;
    if (base == null) return;
    try {
      final context = _channel == SpeakerChannel.earpiece
          ? AppAudioContext.earpiece
          : AppAudioContext.speaker;
      await _player.setAudioContext(context);
      await _player.setReleaseMode(_loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _player.setVolume(1.0);
      // A no-op on iOS (hence the stereo variants), but still real panning on
      // Android — keep applying it.
      await _player.setBalance(balance ?? _balanceFor(_channel));
      await _player.play(AssetSource(_variantOf(base, _channel)));
    } catch (_) {
      // Best-effort — ignore on a preview / unsupported platform.
    }
  }

  /// Resolve the channel the signal actually plays on: an explicit side wins,
  /// otherwise a hard-panned [balance] picks the side, otherwise both.
  static SpeakerChannel _effectiveChannel(
    SpeakerChannel channel,
    double? balance,
  ) {
    if (channel != SpeakerChannel.auto) return channel;
    if (balance == null) return SpeakerChannel.auto;
    if (balance <= -0.5) return SpeakerChannel.left;
    if (balance >= 0.5) return SpeakerChannel.right;
    return SpeakerChannel.auto;
  }

  /// The bundled file that carries [channel]: `_l` / `_r` for a single side,
  /// the base (mono => both channels) clip otherwise.
  static String _variantOf(String asset, SpeakerChannel channel) {
    switch (channel) {
      case SpeakerChannel.left:
        return _withSuffix(asset, '_l');
      case SpeakerChannel.right:
        return _withSuffix(asset, '_r');
      case SpeakerChannel.earpiece:
      case SpeakerChannel.auto:
        return asset;
    }
  }

  /// Insert [suffix] before a trailing `.wav` only — anything else (the `.mp3`
  /// clips) has no stereo variant and is left exactly as it is.
  static String _withSuffix(String asset, String suffix) {
    const ext = '.wav';
    if (!asset.endsWith(ext)) return asset;
    return '${asset.substring(0, asset.length - ext.length)}$suffix$ext';
  }

  static double _balanceFor(SpeakerChannel channel) {
    switch (channel) {
      case SpeakerChannel.left:
        return -1.0;
      case SpeakerChannel.right:
        return 1.0;
      case SpeakerChannel.earpiece:
      case SpeakerChannel.auto:
        return 0.0;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await waveform.dispose();
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
