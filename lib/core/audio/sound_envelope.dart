/// Per-sound amplitude envelopes for the waveform visualiser.
///
/// `audioplayers` exposes no real-time amplitude/FFT tap, so the bars cannot be
/// driven by a live analyser without swapping the whole audio stack. Instead
/// every bundled clip carries its own **amplitude envelope**: a fixed list of
/// 0..1 levels describing how loud that clip is across its own length. The
/// visualiser walks that list with the player's REAL playback position, so the
/// bars stay in step with what is actually heard, differ from clip to clip, and
/// are identical every time the same sound plays.
///
/// The levels are **measured from the audio files themselves**: on startup each
/// bundled clip is read out of the asset bundle and its loudness contour is
/// taken from the MP3 bitstream (see `mp3_envelope.dart`), 64 levels per clip
/// normalised to that clip's own measured loudness range so its real shape is
/// visible. Nothing here is authored or synthesised —
/// a clip that cannot be measured simply has no envelope, and the visualiser
/// then stays in its idle state.
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;

import 'mp3_envelope.dart';

/// The amplitude envelope of one sound: `levels[i]` is the loudness (0..1) of
/// the clip during frame `i` of [length] equal slices.
class SoundEnvelope {
  const SoundEnvelope(this.levels);

  /// Loudness per frame, 0 (silence) .. 1 (the clip's loudest passage).
  final List<double> levels;

  int get length => levels.length;

  /// Level at the (fractional, possibly out-of-range) frame [index].
  ///
  /// The index wraps, so a looped clip reads continuously across the loop
  /// point, and neighbouring frames are interpolated so the bars glide with
  /// playback instead of stepping.
  double at(double index) {
    final n = levels.length;
    if (n == 0) return 0;
    var x = index % n;
    if (x < 0) x += n;
    final i = x.floor();
    final f = x - i;
    final a = levels[i];
    final b = levels[(i + 1) % n];
    return a + (b - a) * f;
  }
}

/// The envelope catalogue, backed entirely by measurements of the bundled
/// clips.
///
/// Measuring means reading the asset, which is asynchronous, while callers
/// (waveform sources, widget `build` methods) need an envelope synchronously.
/// So the clips are measured once — [preload] in `main()`, before the first
/// frame — and kept in a cache keyed by the audio file's name
/// (`tone_water.mp3`), since callers hold the `assets/`-relative path
/// `audioplayers` wants (`audio/tone_water.mp3`).
class SoundEnvelopes {
  SoundEnvelopes._();

  /// Measure [assets] (the `assets/`-relative paths) into the cache.
  ///
  /// Best-effort: a clip that cannot be read or parsed is simply left without an
  /// envelope, so a preview / test environment never blocks launch.
  static Future<void> preload(Iterable<String> assets) async {
    await Future.wait(assets.map(_measure));
  }

  /// Envelope for the given `assets/`-relative [asset], or null when the clip
  /// was not measured (the visualiser then stays in its idle state instead of
  /// drawing an invented shape).
  static SoundEnvelope? forAsset(String? asset) {
    if (asset == null) return null;
    final cached = _cache[_nameOf(asset)];
    if (cached != null) return cached;
    // Not measured yet (a clip outside the preloaded set) — measure it now so
    // the bars follow it from the next frame on.
    unawaited(_measure(asset));
    return null;
  }

  static Future<void> _measure(String asset) async {
    final name = _nameOf(asset);
    if (_cache.containsKey(name) ||
        _pending.contains(name) ||
        _unmeasurable.contains(name)) {
      return;
    }
    _pending.add(name);
    try {
      final data = await rootBundle.load('assets/$asset');
      final levels = measureMp3Envelope(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (levels != null && levels.isNotEmpty) {
        _cache[name] = SoundEnvelope(levels);
      } else {
        _unmeasurable.add(name);
      }
    } catch (_) {
      // Unreadable clip — no envelope, so the bars stay at rest.
      _unmeasurable.add(name);
    } finally {
      _pending.remove(name);
    }
  }

  static String _nameOf(String asset) =>
      asset.substring(asset.lastIndexOf('/') + 1);

  /// Wrappers are reused so repeated lookups (e.g. from a widget's `build`)
  /// don't reallocate.
  static final Map<String, SoundEnvelope> _cache = <String, SoundEnvelope>{};

  /// Clips currently being measured, so a repeated lookup doesn't read the same
  /// asset twice.
  static final Set<String> _pending = <String>{};

  /// Clips that could not be read or parsed — remembered so a lookup from a
  /// widget's `build` doesn't reread the file on every frame.
  static final Set<String> _unmeasurable = <String>{};
}
