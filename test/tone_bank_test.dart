import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_cleaner/core/audio/tone_bank.dart';
import 'package:speaker_cleaner/core/audio/waveform_source.dart';

/// The reported issue: the "tone generator" was four bundled clips wearing
/// frequency labels. These guard the replacement — the label a screen prints
/// must be the file it plays, and the waveform must be the signal in that file.
void main() {
  group('ToneBank', () {
    test('every labelled frequency maps to its own generated file', () {
      final assets = <String>{};
      for (final hz in ToneBank.frequencies) {
        final asset = ToneBank.assetFor(hz);
        // The frequency is IN the filename the player is handed, so a label can
        // never drift away from the sound.
        expect(asset, 'audio/tone_$hz.wav');
        assets.add(asset);
      }
      expect(assets.length, ToneBank.frequencies.length,
          reason: 'no two frequencies may share a clip');
    });

    test('labels read as the frequency that is played', () {
      expect(ToneBank.label(63), '63 Hz');
      expect(ToneBank.label(500), '500 Hz');
      expect(ToneBank.label(1000), '1 kHz');
      expect(ToneBank.label(16000), '16 kHz');
    });

    test('the free tier gets the low tones, Pro the top of the range', () {
      expect(ToneBank.freeFrequencies, isNotEmpty);
      for (final hz in ToneBank.freeFrequencies) {
        expect(ToneBank.frequencies, contains(hz));
        expect(ToneBank.isFree(hz), isTrue);
      }
      // Everything above the free set is gated, and the top of the range is.
      expect(ToneBank.isFree(ToneBank.frequencies.last), isFalse);
      expect(ToneBank.isFree(1000), isFalse);
    });

    test('the phase tone and the sweep come from the bank', () {
      expect(ToneBank.frequencies, contains(ToneBank.phaseToneHz));
      expect(ToneBank.sweepAsset, 'audio/sweep_20_20000.wav');
      expect(ToneBank.allAssets, contains(ToneBank.sweepAsset));
      expect(ToneBank.allAssets.length, ToneBank.frequencies.length + 1);
    });
  });

  group('ToneWaveform', () {
    test('draws nothing until a tone is selected', () {
      final wave = ToneWaveform();
      expect(wave.hasLevels, isFalse);
      wave.useTone(1000);
      expect(wave.hasLevels, isTrue);
      expect(wave.frequencyHz, 1000);
    });

    test('traces the sine itself, not a flat line', () {
      final wave = ToneWaveform()..useTone(1000);
      const bars = 32;
      final levels = [
        for (var i = 0; i < bars; i++) wave.levelAt(i, bars),
      ];

      expect(levels.every((l) => l >= 0 && l <= 1), isTrue);
      // A rectified sine spans the bar range: a constant clip's *envelope*
      // would be flat, which is exactly the failure this replaces.
      final min = levels.reduce((a, b) => a < b ? a : b);
      final max = levels.reduce((a, b) => a > b ? a : b);
      expect(max - min, greaterThan(0.5));
    });
  });

  group('SweepWaveform', () {
    test('is always drawable and stays inside the bar range', () {
      final wave = SweepWaveform();
      expect(wave.hasLevels, isTrue);
      const bars = 32;
      for (var i = 0; i < bars; i++) {
        final level = wave.levelAt(i, bars);
        expect(level.isFinite, isTrue);
        expect(level, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
