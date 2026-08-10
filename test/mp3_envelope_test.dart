import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_cleaner/core/audio/mp3_envelope.dart';

/// Verifies the waveform envelope is normalised to each clip's OWN measured
/// range, so a continuous sweep with a tiny real dynamic range still draws a
/// readable waveform rather than a flat row of near-identical bars.
void main() {
  group('normalizeGranuleGains', () {
    test('a narrow dynamic range still spans most of 0..1', () {
      // A sweep whose loudness barely moves (gains within a few quantiser
      // steps): the source of the "row of identical dots" bug.
      final gains = List<int>.generate(64, (i) => 200 + (i % 4 == 0 ? 3 : 0));

      final levels = normalizeGranuleGains(gains)!;

      expect(levels.every((l) => l.isFinite), isTrue);
      final min = levels.reduce((a, b) => a < b ? a : b);
      final max = levels.reduce((a, b) => a > b ? a : b);
      // The clip's quietest slice sits near the floor, its loudest at the top,
      // so even a tiny input range covers most of the bar range.
      expect(max - min, greaterThan(0.8));
      expect(max, closeTo(1.0, 0.001));
    });

    test('a constant sequence draws a steady mid line, never NaN or zeros', () {
      final gains = List<int>.filled(64, 200);

      final levels = normalizeGranuleGains(gains)!;

      expect(levels.any((l) => l.isNaN), isFalse);
      expect(levels.any((l) => l != 0), isTrue); // not all-zero
      // max == min is guarded to a steady mid-height line.
      expect(levels.every((l) => (l - 0.5).abs() < 0.001), isTrue);
    });

    test('different clips still produce visibly different waveforms', () {
      final rising = List<int>.generate(64, (i) => 180 + i);
      final pulsed = List<int>.generate(64, (i) => 200 + (i % 8 < 4 ? 0 : 20));

      final a = normalizeGranuleGains(rising)!;
      final b = normalizeGranuleGains(pulsed)!;

      var differences = 0;
      for (var i = 0; i < a.length; i++) {
        if ((a[i] - b[i]).abs() > 0.05) differences++;
      }
      expect(differences, greaterThan(a.length ~/ 4));
    });

    test('too few granules yields null (no invented shape)', () {
      expect(normalizeGranuleGains(const [200, 201, 202]), isNull);
    });
  });
}
