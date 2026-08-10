import 'package:flutter/material.dart';

import '../../core/audio/waveform_source.dart';
import '../theme/app_colors.dart';

/// A bar-style waveform, mirrored around the centre line.
///
/// The bars are NOT decorative motion: their heights come from [source], which
/// binds them to real audio — the amplitude envelope of the clip that is
/// playing, read at the player's actual position, or live microphone levels.
/// Two different sounds therefore draw two different patterns, and the bars
/// stop moving when playback stops.
///
/// When [active] is false (or no [source] is given) the bars settle to a low
/// resting height. Bar colour comes from `color.channel_purple`.
class WaveformVisualizer extends StatefulWidget {
  const WaveformVisualizer({
    super.key,
    this.active = true,
    this.barCount = 32,
    this.height = 120,
    this.color,
    this.source,
  });

  final bool active;
  final int barCount;
  final double height;

  /// Bar colour (defaults to the channel token colour).
  final Color? color;

  /// Where the bar heights come from. Without one the bars stay at rest —
  /// nothing is ever invented from a formula.
  final WaveformSource? source;

  @override
  State<WaveformVisualizer> createState() => _WaveformVisualizerState();
}

class _WaveformVisualizerState extends State<WaveformVisualizer>
    with SingleTickerProviderStateMixin {
  /// Resting bar height when there is no sound to show.
  static const double _idleLevel = 0.12;

  late final AnimationController _controller;

  /// True when there is real audio data to draw. A source whose clip was never
  /// measured reports `hasLevels == false` and rests like no source at all.
  bool get _live => widget.active && (widget.source?.hasLevels ?? false);

  @override
  void initState() {
    super.initState();
    // The controller is only a repaint clock — every bar height is read from
    // the source on each frame, never from the controller's value.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncClock();
  }

  @override
  void didUpdateWidget(covariant WaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  /// Only tick while there is live audio to follow — a resting or previewed
  /// waveform does not change between frames.
  void _syncClock() {
    final needsTicks = _live && widget.source is! StaticWaveform;
    if (needsTicks) {
      if (!_controller.isAnimating) _controller.repeat();
    } else if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _sampleLevels() {
    final source = widget.source;
    if (!_live || source == null) {
      return List<double>.filled(widget.barCount, _idleLevel);
    }
    return List<double>.generate(
      widget.barCount,
      (i) => source.levelAt(i, widget.barCount).clamp(0.0, 1.0).toDouble(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Purely visual — keep it out of the accessibility tree.
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _WaveformPainter(
                levels: _sampleLevels(),
                live: _live,
                color: widget.color ?? AppColors.channelPurple,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.levels,
    required this.live,
    required this.color,
  });

  /// One amplitude (0..1) per bar.
  final List<double> levels;

  /// Whether [levels] are real measured/played amplitudes (vs the resting bars).
  final bool live;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    final centerY = size.height / 2;
    final slot = size.width / levels.length;
    final barWidth = slot * 0.5;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < levels.length; i++) {
      final amp = levels[i];
      final double barHeight =
          ((size.height * 0.9) * amp).clamp(4.0, size.height).toDouble();

      final x = slot * i + (slot - barWidth) / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          centerY - barHeight / 2,
          barWidth,
          barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      // Louder bars read stronger; the resting state stays uniformly soft.
      paint.color = color.withValues(alpha: live ? 0.55 + 0.45 * amp : 0.4);
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    if (old.live != live || old.color != color) return true;
    if (old.levels.length != levels.length) return true;
    for (var i = 0; i < levels.length; i++) {
      if (old.levels[i] != levels[i]) return true;
    }
    return false;
  }
}
