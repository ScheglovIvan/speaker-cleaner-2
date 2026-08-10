import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

import 'sound_envelope.dart';
import 'tone_bank.dart';

/// Supplies the per-bar amplitudes that `WaveformVisualizer` draws.
///
/// Implementations bind the bars to something real — the clip that is playing
/// ([PlaybackWaveform]), the clip a screen is previewing ([StaticWaveform]) or
/// live microphone levels ([LiveLevelWaveform]).
abstract class WaveformSource {
  const WaveformSource();

  /// Amplitude (0..1) of bar [index] out of [count], oldest bar first.
  double levelAt(int index, int count);

  /// Whether this source actually has audio data to draw. False when the clip
  /// has no measured envelope, so the visualiser falls back to its resting bars
  /// rather than to a flat line or an invented shape.
  bool get hasLevels => true;
}

/// Bars driven by a real [AudioPlayer]: the clip's amplitude envelope, read at
/// the player's actual playback position.
///
/// The player only reports its position a few times a second, so the position
/// is extrapolated with a stopwatch between updates — that keeps the bars
/// gliding at frame rate while staying anchored to what is really being heard.
/// When the player stops the position stops advancing and the bars freeze.
class PlaybackWaveform extends WaveformSource {
  PlaybackWaveform();

  /// Assumed clip length until the player reports the real one.
  static const double _fallbackClipSeconds = 12;

  String? _asset;
  SoundEnvelope? _envelope;
  double _clipSeconds = 0;

  /// Last position reported by the player, and the time since it arrived.
  double _syncSeconds = 0;
  final Stopwatch _sinceSync = Stopwatch();
  bool _playing = false;

  /// Externally-driven position (seconds) used when the clip is NOT playing —
  /// e.g. sound is off, so there is no real playback position to follow and the
  /// bars are scrolled from the run's own countdown progress instead. Ignored
  /// the moment the player actually starts playing (real position wins).
  double? _drivenSeconds;

  final List<StreamSubscription<dynamic>> _subs = [];

  /// Follow [player]'s real duration, position and play/stop state.
  void bind(AudioPlayer player) {
    if (_subs.isNotEmpty) return;
    _subs
      ..add(player.onDurationChanged.listen((d) {
        if (d > Duration.zero) _clipSeconds = d.inMicroseconds / 1e6;
      }))
      ..add(player.onPositionChanged.listen((p) {
        _syncSeconds = p.inMicroseconds / 1e6;
        _sinceSync
          ..reset()
          ..start();
      }))
      ..add(player.onPlayerStateChanged.listen((s) {
        _playing = s == PlayerState.playing;
        if (_playing) {
          _sinceSync
            ..reset()
            ..start();
        } else {
          _sinceSync.stop();
        }
      }));
  }

  /// Switch to the envelope of the clip that is about to play.
  void useAsset(String asset) {
    if (_asset != asset) {
      // A different clip — its length has to be measured again.
      _asset = asset;
      _envelope = SoundEnvelopes.forAsset(asset);
      _clipSeconds = 0;
    }
    _rewind();
  }

  /// Drive the scroll from an external position (seconds) when the tone isn't
  /// actually playing — the run's countdown supplies this so the bars still
  /// move in step with the clean even with sound off.
  void driveTo(double seconds) => _drivenSeconds = seconds;

  /// Back to the start of the clip (playback stopped).
  void reset() => _rewind();

  void _rewind() {
    _syncSeconds = 0;
    _playing = false;
    _drivenSeconds = null;
    _sinceSync
      ..reset()
      ..stop();
  }

  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
  }

  @override
  bool get hasLevels => _envelope != null;

  /// Playback position in seconds. While the player is really playing this is
  /// its true position, extrapolated since the last report. When nothing is
  /// playing but the run is driving the scroll (sound off), the countdown
  /// position is used instead so the bars keep moving with the clean.
  double get _positionSeconds {
    if (_playing) {
      return _syncSeconds + _sinceSync.elapsedMicroseconds / 1e6;
    }
    return _drivenSeconds ?? _syncSeconds;
  }

  @override
  double levelAt(int index, int count) {
    final env = _envelope;
    if (env == null) return 0;
    final clip = _clipSeconds > 0 ? _clipSeconds : _fallbackClipSeconds;
    // One envelope frame per bar: the bars are a window onto the clip that
    // scrolls right-to-left at exactly the rate the clip is being played.
    final head = _positionSeconds * env.length / clip;
    return env.at(head - (count - 1 - index));
  }
}

/// Shortest bar an oscilloscope trace draws at a zero crossing, so the wave
/// still reads as a shape rather than disappearing.
const double _traceFloor = 0.08;

/// Bar level for a signal sample in -1..1, full-wave rectified (the visualiser
/// mirrors every bar around the centre line, so only the magnitude matters).
double _traceLevel(double sample) =>
    (_traceFloor + (1 - _traceFloor) * sample.abs()).clamp(0.0, 1.0).toDouble();

/// Oscilloscope bars for a GENERATED sine tone (`assets/audio/tone_<f>.wav`).
///
/// These clips are pure sines of constant amplitude, so a loudness envelope
/// would be a flat line and say nothing. Because the app generated the file
/// itself, the signal is known exactly — `sin(2*pi*f*t)` — so the bars draw the
/// real waveform at the player's REAL playback position instead: a short window
/// of the tone, scrolling at exactly the rate it is being played. Nothing is
/// invented; the trace is the same function the WAV holds, sampled at the
/// position the player reports (like an untriggered scope, so a high tone
/// shimmers as its phase races past the frame rate).
class ToneWaveform extends PlaybackWaveform {
  ToneWaveform();

  /// How many cycles of the tone the bars span.
  static const double _windowCycles = 2.4;

  double _hz = 0;

  /// The frequency currently being played (0 = nothing selected yet).
  double get frequencyHz => _hz;

  /// Point the trace at [hz], the tone about to play.
  void useTone(int hz) {
    _hz = hz.toDouble();
    reset();
  }

  /// The trace comes from the tone's frequency, not from a measured envelope,
  /// so there is no asset to read — just rewind to the start of playback.
  @override
  void useAsset(String asset) => reset();

  @override
  bool get hasLevels => _hz > 0;

  @override
  double levelAt(int index, int count) {
    if (_hz <= 0 || count <= 0) return 0;
    final dt = _windowCycles / _hz / count;
    final t = _positionSeconds - (count - 1 - index) * dt;
    return _traceLevel(math.sin(2 * math.pi * _hz * t));
  }
}

/// Oscilloscope bars for the GENERATED logarithmic sweep
/// (`assets/audio/sweep_20_20000.wav`).
///
/// Same idea as [ToneWaveform]: the sweep was generated by the app's own
/// `tool/generate_tones.py`, so its instantaneous phase at any moment is known
/// in closed form. The trace therefore visibly compresses as the chirp climbs
/// — the waveform that is actually in the file, followed at the player's real
/// position.
class SweepWaveform extends PlaybackWaveform {
  SweepWaveform({
    this.startHz = ToneBank.sweepStartHz,
    this.endHz = ToneBank.sweepEndHz,
    this.seconds = ToneBank.sweepSeconds,
  }) : _k = math.log(endHz / startHz);

  final double startHz;
  final double endHz;
  final double seconds;

  /// `ln(f1/f0)`, the exponent constant of the generator's log sweep.
  final double _k;

  static const double _windowCycles = 2.4;

  /// The trace is defined by the sweep's own formula, not a measured envelope.
  @override
  void useAsset(String asset) => reset();

  @override
  bool get hasLevels => true;

  /// Instantaneous frequency of the chirp at [t] seconds in.
  double _instantHz(double t) =>
      startHz * math.exp(_k * (t.clamp(0.0, seconds) / seconds));

  /// Instantaneous phase — the exact expression the generator integrates.
  double _phase(double t) {
    final tc = t.clamp(0.0, seconds);
    return 2 * math.pi * startHz * (seconds / _k) * (math.exp(_k * tc / seconds) - 1);
  }

  @override
  double levelAt(int index, int count) {
    if (count <= 0) return 0;
    final position = _positionSeconds;
    final dt = _windowCycles / _instantHz(position) / count;
    final t = position - (count - 1 - index) * dt;
    return _traceLevel(math.sin(_phase(t)));
  }
}

/// A still picture of a clip's envelope — the whole waveform spread across the
/// bars, like the track preview in a recorder app. Used where a screen shows
/// which sound it *would* play rather than playing one.
class StaticWaveform extends WaveformSource {
  const StaticWaveform(this.envelope);

  final SoundEnvelope? envelope;

  @override
  bool get hasLevels => envelope != null;

  @override
  double levelAt(int index, int count) {
    final env = envelope;
    if (env == null || count <= 0) return 0;
    return env.at(index * env.length / count);
  }
}

/// Bars driven by live measured levels (the dB Meter's microphone readings).
///
/// Each reading is pushed on the right and scrolls left, so the bars are a
/// rolling history of what the microphone actually heard.
class LiveLevelWaveform extends WaveformSource {
  LiveLevelWaveform({this.capacity = 64});

  /// How many past readings are kept.
  final int capacity;

  final List<double> _history = <double>[];

  /// Record one measured level (0..1).
  void push(double level) {
    _history.add(level.clamp(0.0, 1.0).toDouble());
    if (_history.length > capacity) {
      _history.removeRange(0, _history.length - capacity);
    }
  }

  /// Drop the history (measurement stopped or the session was reset).
  void clear() => _history.clear();

  @override
  double levelAt(int index, int count) {
    // Newest reading on the right; a history that isn't full yet reads as
    // silence on the left rather than inventing levels.
    final pos = _history.length - count + index;
    if (pos < 0 || pos >= _history.length) return 0;
    return _history[pos];
  }
}
