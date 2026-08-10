/// The app's generated tone bank — honest sine waves at real frequencies.
///
/// Every asset referenced here is produced by `tool/generate_tones.py`, which
/// writes 16-bit PCM WAVs straight from `sin(2*pi*f*t)`. `tone_1000.wav` really
/// is a 1 kHz sine, so a screen that prints "1 kHz" plays 1 kHz — there is no
/// re-labelled clip anywhere in the signal path.
///
/// Each tone's length is snapped to a whole number of cycles near 2 s, so
/// `ReleaseMode.loop` repeats it seamlessly and a "continuous" tone really is
/// continuous. The sweep is a single 12 s logarithmic chirp from 20 Hz to
/// 20 kHz and is played once, never looped.
///
/// Paths are `assets/`-relative, the `audioplayers` [AssetSource] convention.
library;

class ToneBank {
  ToneBank._();

  /// The labelled frequencies in the generator, ascending.
  static const List<int> frequencies = <int>[
    63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// The tones a free user can play. Pro unlocks the top of the range
  /// (everything from 1 kHz up) — see [isFree].
  static const List<int> freeFrequencies = <int>[63, 125, 250, 500];

  /// How long a free user's tone plays before it stops on its own. Continuous
  /// playback is a Pro feature; the free tier still hears the real tone, just
  /// not indefinitely.
  static const int freePlaySeconds = 30;

  /// The generated sine for [hz] (must be one of [frequencies]).
  static String assetFor(int hz) => 'audio/tone_$hz.wav';

  /// The 12 s logarithmic 20 Hz -> 20 kHz sweep.
  static const String sweepAsset = 'audio/sweep_20_20000.wav';

  /// Sweep bounds + length, mirroring `tool/generate_tones.py` exactly so the
  /// on-screen trace follows the signal that is really in the file.
  static const double sweepStartHz = 20;
  static const double sweepEndHz = 20000;
  static const double sweepSeconds = 12;

  /// Mid tone used for the phase / left-right checks: high enough to localise
  /// clearly, low enough that every driver reproduces it.
  static const int phaseToneHz = 500;

  /// The single low tone the water-eject maintenance run may use.
  static const int waterEjectHz = 125;

  /// Every asset in the bank, for bundling/preload checks.
  static List<String> get allAssets =>
      <String>[for (final f in frequencies) assetFor(f), sweepAsset];

  /// Whether [hz] is playable without Pro.
  static bool isFree(int hz) => freeFrequencies.contains(hz);

  /// "63 Hz" / "1 kHz" — the frequency this entry actually plays.
  static String label(int hz) {
    if (hz < 1000) return '$hz Hz';
    final k = hz / 1000;
    final text = k == k.roundToDouble() ? k.toStringAsFixed(0) : '$k';
    return '$text kHz';
  }

  /// Compact form for a chip in the frequency row ("63" / "1k").
  static String shortLabel(int hz) =>
      hz < 1000 ? '$hz' : '${(hz / 1000).round()}k';

  /// One-line description of what that part of the range tells the listener.
  static String hint(int hz) {
    if (hz <= 125) return 'Deep bass — you should feel it as much as hear it.';
    if (hz <= 500) return 'Low mids — body and warmth; listen for rattle.';
    if (hz <= 2000) return 'Midrange — where voices sit. Should be clean.';
    if (hz <= 8000) return 'Treble — detail and sibilance.';
    return 'Very high treble — many adults stop hearing this at all.';
  }
}
