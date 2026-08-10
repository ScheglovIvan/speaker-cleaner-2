/// Measures a bundled MP3's loudness envelope from the file's own bitstream.
///
/// `audioplayers` exposes no PCM/FFT tap and Flutter ships no MP3 decoder, so
/// the levels are read straight out of the encoded stream: every MP3 granule
/// carries a `global_gain` field — the quantiser scale the encoder needed for
/// that slice of audio — which tracks how loud the granule actually is. Walking
/// the frame headers therefore yields a real, measured loudness contour of that
/// exact file (see CAPABILITIES.md for why this stands in for a live analyser).
///
/// Everything here is derived from the audio data; nothing is synthesised. A
/// file that cannot be parsed returns null, and the visualiser then stays in its
/// idle state rather than drawing an invented shape.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Shortest bar drawn for the clip's own quietest slice — a floor so a quiet
/// passage still reads as a short bar rather than as nothing.
const double _floorLevel = 0.12;

/// MPEG-1 Layer III bitrates (kbps), indexed by the header's bitrate index.
const List<int> _bitratesV1 = <int>[
  0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0,
];

/// MPEG-2 / 2.5 Layer III bitrates (kbps).
const List<int> _bitratesV2 = <int>[
  0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0,
];

const List<int> _sampleRatesV1 = <int>[44100, 48000, 32000, 0];
const List<int> _sampleRatesV2 = <int>[22050, 24000, 16000, 0];
const List<int> _sampleRatesV25 = <int>[11025, 12000, 8000, 0];

/// Loudness of an MP3 as [frames] levels in 0..1, normalised to the clip's own
/// measured loudness range, or null when the file could not be measured.
List<double>? measureMp3Envelope(Uint8List bytes, {int frames = 64}) {
  return normalizeGranuleGains(_readGranuleGains(bytes), frames: frames);
}

/// Reduce a sequence of granule [gains] (MP3 `global_gain` quantiser exponents,
/// in playback order) into [frames] bar levels in 0..1.
///
/// These cleaning tones are continuous sweeps with a very small real dynamic
/// range, so mapping against a fixed dB window makes every bar land near the
/// top and the waveform reads as a flat line. Instead the clip is normalised to
/// its OWN measured range: the quietest measured slice maps towards the bottom
/// of the bar range and the loudest towards the top, so the real shape of that
/// clip is visible while different clips still draw visibly different shapes.
/// Nothing is synthesised — the levels are measured straight from the gains.
///
/// Returns null when there are too few granules to describe a shape.
@visibleForTesting
List<double>? normalizeGranuleGains(List<int> gains, {int frames = 64}) {
  // Too few granules to describe a shape — better nothing than a guess.
  if (gains.length < frames ~/ 4) return null;

  // global_gain is a power-of-2 quantiser exponent: amplitude ~ 2^((g-210)/4).
  // Per-slice loudness in dB, with the clip's own quietest/loudest extremes.
  final levels = List<double>.filled(frames, 0);
  var maxDb = double.negativeInfinity;
  var minDb = double.infinity;
  for (var i = 0; i < frames; i++) {
    final start = gains.length * i ~/ frames;
    final end = math.max(gains.length * (i + 1) ~/ frames, start + 1);
    var sum = 0.0;
    for (var g = start; g < end; g++) {
      final amp = math.pow(2.0, (gains[g] - 210) / 4.0).toDouble();
      sum += amp * amp;
    }
    final rms = math.sqrt(sum / (end - start));
    final db = rms > 0 ? 20 * (math.log(rms) / math.ln10) : double.negativeInfinity;
    levels[i] = db;
    if (db.isFinite) {
      if (db > maxDb) maxDb = db;
      if (db < minDb) minDb = db;
    }
  }
  if (!maxDb.isFinite) return null;
  if (!minDb.isFinite) minDb = maxDb;

  // Map the clip's own [minDb..maxDb] onto [_floorLevel..1]: quietest slice
  // short, loudest slice full. A perfectly constant clip (maxDb == minDb) would
  // divide by zero, so it draws as a steady mid-height line instead.
  final range = maxDb - minDb;
  for (var i = 0; i < frames; i++) {
    final db = levels[i];
    double norm;
    if (range <= 0) {
      norm = 0.5; // constant loudness — a steady mid line, never zeros/NaN.
    } else if (!db.isFinite) {
      norm = _floorLevel; // a silent slice still draws the floor, not nothing.
    } else {
      final rel = ((db - minDb) / range).clamp(0.0, 1.0).toDouble();
      norm = _floorLevel + (1 - _floorLevel) * rel;
    }
    levels[i] = norm.clamp(0.0, 1.0).toDouble();
  }
  return levels;
}

/// Every granule's `global_gain`, in playback order.
List<int> _readGranuleGains(Uint8List bytes) {
  final gains = <int>[];
  var offset = _skipId3(bytes);
  var misses = 0;

  while (offset + 4 <= bytes.length) {
    if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) {
      // Not on a frame boundary (tag padding, junk) — hunt for the next sync.
      offset++;
      if (++misses > 1 << 16) break;
      continue;
    }
    final b1 = bytes[offset + 1];
    final b2 = bytes[offset + 2];
    final b3 = bytes[offset + 3];

    final versionBits = (b1 >> 3) & 0x03; // 0=2.5, 2=MPEG2, 3=MPEG1
    final layerBits = (b1 >> 1) & 0x03; // 1 = Layer III
    final crcAbsent = b1 & 0x01;
    final bitrateIndex = (b2 >> 4) & 0x0F;
    final sampleIndex = (b2 >> 2) & 0x03;
    final padding = (b2 >> 1) & 0x01;
    final channelMode = (b3 >> 6) & 0x03;

    final isV1 = versionBits == 3;
    final validVersion = versionBits != 1;
    final bitrate = (isV1 ? _bitratesV1 : _bitratesV2)[bitrateIndex] * 1000;
    final sampleRate = (versionBits == 3
        ? _sampleRatesV1
        : versionBits == 2
            ? _sampleRatesV2
            : _sampleRatesV25)[sampleIndex];

    if (!validVersion || layerBits != 1 || bitrate == 0 || sampleRate == 0) {
      offset++;
      if (++misses > 1 << 16) break;
      continue;
    }

    final frameLength =
        (isV1 ? 144 : 72) * bitrate ~/ sampleRate + padding;
    if (frameLength < 24) break;

    final mono = channelMode == 3;
    final channels = mono ? 1 : 2;
    final sideInfo = offset + 4 + (crcAbsent == 1 ? 0 : 2);
    _readFrameGains(bytes, sideInfo, isV1, mono, channels, gains);

    offset += frameLength;
  }
  return gains;
}

/// Pull the `global_gain` of every granule/channel in one frame's side info.
///
/// Layout per ISO/IEC 11172-3 (MPEG-1) and 13818-3 (MPEG-2/2.5): a fixed header
/// followed by one 59-bit (MPEG-1) or 63-bit (MPEG-2) block per granule and
/// channel, with `global_gain` 21 bits into each block.
void _readFrameGains(
  Uint8List bytes,
  int start,
  bool isV1,
  bool mono,
  int channels,
  List<int> out,
) {
  final reader = _BitReader(bytes, start);
  if (isV1) {
    reader.skip(9); // main_data_begin
    reader.skip(mono ? 5 : 3); // private_bits
    reader.skip(4 * channels); // scfsi
  } else {
    reader.skip(8); // main_data_begin
    reader.skip(mono ? 1 : 2); // private_bits
  }
  final granules = isV1 ? 2 : 1;
  final blockBits = isV1 ? 59 : 63;
  for (var gr = 0; gr < granules; gr++) {
    // Channels of one granule share a moment in time — average them.
    var sum = 0;
    var seen = 0;
    for (var ch = 0; ch < channels; ch++) {
      reader.skip(12); // part2_3_length
      reader.skip(9); // big_values
      final gain = reader.read(8); // global_gain
      if (gain < 0) return;
      sum += gain;
      seen++;
      reader.skip(blockBits - 29); // rest of this granule/channel block
    }
    if (seen > 0) out.add(sum ~/ seen);
  }
}

/// Byte offset of the first audio frame, past any ID3v2 tag.
int _skipId3(Uint8List bytes) {
  if (bytes.length < 10) return 0;
  if (bytes[0] != 0x49 || bytes[1] != 0x44 || bytes[2] != 0x33) return 0;
  // Syncsafe 28-bit size, excluding the 10-byte header.
  final size = (bytes[6] & 0x7F) << 21 |
      (bytes[7] & 0x7F) << 14 |
      (bytes[8] & 0x7F) << 7 |
      (bytes[9] & 0x7F);
  final footer = (bytes[5] & 0x10) != 0 ? 10 : 0;
  final offset = 10 + size + footer;
  return offset < bytes.length ? offset : 0;
}

/// Big-endian bit cursor over the frame's side info.
class _BitReader {
  _BitReader(this._bytes, int byteOffset) : _bit = byteOffset * 8;

  final Uint8List _bytes;
  int _bit;

  void skip(int count) => _bit += count;

  /// Next [count] bits as an int, or -1 past the end of the buffer.
  int read(int count) {
    var value = 0;
    for (var i = 0; i < count; i++) {
      final byte = _bit >> 3;
      if (byte >= _bytes.length) return -1;
      value = (value << 1) | ((_bytes[byte] >> (7 - (_bit & 7))) & 1);
      _bit++;
    }
    return value;
  }
}
