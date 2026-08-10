import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/audio/audio_visibility.dart';
import '../../core/audio/waveform_source.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/remote_config.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';
import '../premium/premium_benefits.dart';

/// Screen 0013 — the live Sound-Level Meter.
///
/// A real microphone meter: `permission_handler` triggers the iOS microphone
/// permission dialog at the natural moment (the first Start tap) and
/// `noise_meter` streams live decibel readings from the mic.
///
/// Behaviour rules (reworked):
///  * On open it is STOPPED / idle — it never auto-starts measuring.
///  * Measuring begins ONLY after the user taps Start (and grants the mic).
///  * Stop fully stops the stream; re-opening the screen is idle again.
///
/// The Sound-Level Meter is a Premium feature: free users see the
/// [PremiumLockView].
class Screen_0013 extends StatelessWidget {
  const Screen_0013({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0013';

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    if (state.isFeatureLocked(PremiumFeature.dbMeter)) {
      return const PremiumLockView(
        featureName: 'The Sound-Level Meter',
        title: 'Sound Level',
        icon: Icons.speed_rounded,
      );
    }
    return const _DbMeter();
  }
}

class _DbMeter extends StatefulWidget {
  const _DbMeter();

  @override
  State<_DbMeter> createState() => _DbMeterState();
}

class _DbMeterState extends State<_DbMeter>
    with WidgetsBindingObserver, AudioVisibilityGuard<_DbMeter> {
  /// Displayable range. The floor is 0, NOT a comfortable ambient minimum —
  /// clamping the bottom away is exactly what stopped a quiet room from ever
  /// reading as quiet.
  static const double _minDb = 0;
  static const double _maxDb = 100;

  /// Shown wherever there is no measurement yet.
  static const String _noReading = '—';

  /// `noise_meter` does **not** report dBFS. Its own maths is
  ///
  ///     meanDecibel = 20 * log10(2^15 * meanAmplitude)   // meanAmplitude 0..1
  ///
  /// so its zero point is an amplitude of one quantisation step — digital
  /// silence, which a microphone never produces. Every real sound therefore
  /// lands high on that scale (a quiet room reads ~50) and its low end is
  /// unreachable: the number is "dB above the quantisation floor", not SPL.
  ///
  /// The ceiling of that scale is `meanAmplitude == 1`, i.e. the clipping
  /// point: `20 * log10(32768) ≈ 90.3`.
  static final double _packageCeiling = 20 * (math.log(1 << 15) / math.ln10);

  /// A covered microphone never reaches the package's zero point either — it
  /// settles on the iOS input's own self-noise, roughly this far below the
  /// clipping point. That level, not the package's zero, is the *practical*
  /// floor of the package's scale.
  static const double _coveredMicBelowCeiling = 70;

  /// Calibration offset subtracted from every raw value so that the practical
  /// floor maps to 0: covering the microphone drives the reading to the bottom
  /// of the scale, a quiet room lands in the low tens instead of mid-scale, and
  /// everyday rooms sit in the familiar 40–60 band. It is derived from the
  /// package's own zero point rather than tuned to a flattering number — the
  /// result is an approximate sound level, not certified SPL (an uncalibrated
  /// phone microphone has no reference level and iOS applies its own gain; see
  /// CAPABILITIES.md).
  static final double _calibrationOffset =
      _packageCeiling - _coveredMicBelowCeiling;

  NoiseMeter? _meter;
  StreamSubscription<NoiseReading>? _sub;

  bool _measuring = false;
  String? _notice;

  /// Null until the first real reading arrives — never a stand-in number.
  double? _current;
  double? _sessionMin;
  double? _sessionPeak;
  double _sum = 0;
  int _samples = 0;

  /// Rolling history of the measured levels, drawn as the waveform bars.
  final LiveLevelWaveform _levels = LiveLevelWaveform();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Same audit as the audio screens: the shell's `IndexedStack` keeps this tab
  /// alive, so `dispose` does not run on a tab switch. Release the microphone
  /// the moment the meter stops being visible — never leave the mic streaming
  /// (and the iOS recording indicator lit) behind another tab.
  @override
  void onScreenHidden() {
    if (!_measuring) return;
    _stop();
  }

  /// Explicit Start: request the mic permission (real iOS dialog) then begin
  /// streaming live decibels. Never called automatically.
  Future<void> _start() async {
    if (_measuring) return;
    setState(() => _notice = null);

    // Real permission request — triggers the system microphone dialog.
    PermissionStatus status;
    try {
      status = await Permission.microphone.request();
    } catch (_) {
      // Platform without permission_handler support (e.g. web preview).
      setState(() =>
          _notice = 'Microphone access is unavailable on this device.');
      return;
    }

    if (!mounted) return;
    if (!status.isGranted) {
      setState(() {
        _notice = status.isPermanentlyDenied
            ? 'Microphone access is off. Enable it in Settings to measure.'
            : 'Microphone permission is needed to measure sound levels.';
      });
      if (status.isPermanentlyDenied) {
        // Best-effort: offer the system settings so they can re-enable it.
        unawaited(openAppSettings());
      }
      return;
    }

    try {
      _meter ??= NoiseMeter();
      _sub = _meter!.noise.listen(
        _onReading,
        onError: _onError,
        cancelOnError: true,
      );
      setState(() {
        _measuring = true;
        _resetStats();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'Could not start the microphone meter.');
    }
  }

  /// Explicit Stop: fully stop the stream and return to the idle state.
  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) setState(() => _measuring = false);
  }

  /// Convert one raw `noise_meter` value to the displayed level, or null when
  /// the sample carries no usable level (a digitally silent buffer yields
  /// -infinity / NaN).
  ///
  /// Every displayed figure — the live reading and the Lowest / Average / Peak
  /// tiles, which are all accumulated from this result — goes through here, so
  /// they always share one scale.
  double? _toLevel(double raw) {
    if (!raw.isFinite) return null;
    return (raw - _calibrationOffset).clamp(_minDb, _maxDb).toDouble();
  }

  void _onReading(NoiseReading reading) {
    if (!mounted) return;
    final db = _toLevel(reading.meanDecibel);
    if (db == null) return;
    setState(() {
      _current = db;
      _sessionMin = _sessionMin == null ? db : math.min(_sessionMin!, db);
      _sessionPeak = _sessionPeak == null ? db : math.max(_sessionPeak!, db);
      _sum += db;
      _samples++;
      // Feed the bars the level that was actually measured.
      _levels.push((db - _minDb) / (_maxDb - _minDb));
    });
  }

  void _onError(Object error) {
    if (!mounted) return;
    setState(() {
      _measuring = false;
      _notice = 'The microphone meter stopped unexpectedly.';
    });
  }

  void _resetStats() {
    // No statistics at all until there is data to build them from.
    _current = null;
    _sessionMin = null;
    _sessionPeak = null;
    _sum = 0;
    _samples = 0;
    _levels.clear();
  }

  void _reset() {
    setState(_resetStats);
  }

  double get _normalized {
    final db = _current;
    if (db == null) return 0;
    return ((db - _minDb) / (_maxDb - _minDb)).clamp(0.0, 1.0);
  }

  double? get _average => _samples == 0 ? null : _sum / _samples;

  /// Band edges, anchored to the CALIBRATED scale (where a covered microphone
  /// reads ~0 and everyday rooms sit near 40–60) — not to the package's raw
  /// scale, on which the old 55 / 78 edges would now never be crossed sensibly.
  static const double _calmBelow = 40;
  static const double _moderateBelow = 62;

  /// Loudness zone → design-token colour + label.
  ({Color color, String label}) get _zone {
    final db = _current ?? 0;
    if (db < _calmBelow) {
      return (color: AppColors.success, label: 'Calm');
    }
    if (db < _moderateBelow) {
      return (color: AppColors.primary, label: 'Moderate');
    }
    return (color: AppColors.danger, label: 'Loud');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final zone = _zone;
    final showData = _measuring && _current != null;

    return AppScaffold(
      backgroundColor: AppColors.background,
      topBar: AppTopBar(
        title: 'Sound Level',
        actions: [
          AppIconButton(
            icon: Icons.restart_alt_rounded,
            tooltip: 'Reset readings',
            onPressed: _measuring ? _reset : null,
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            _measuring
                ? 'Listening to the room'
                : 'Tap Start to measure the sound level',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Live gauge — the hero readout.
          Center(
            child: LevelGauge(
              value: showData ? _normalized : 0.0,
              label: showData ? _current!.round().toString() : _noReading,
              unit: 'decibels',
              size: 260,
              color: showData ? zone.color : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Current loudness zone (only meaningful while measuring).
          Center(
            child: AppChip(
              label: showData ? zone.label : 'Idle',
              icon: showData ? Icons.volume_up_rounded : Icons.mic_off_rounded,
              color: showData ? zone.color : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Bars drawn from the levels the microphone actually measured.
          WaveformVisualizer(
            active: _measuring,
            height: 84,
            color: showData ? zone.color : AppColors.separator,
            source: _levels,
          ),
          const SizedBox(height: 20),

          // Running session summary.
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  caption: 'Lowest',
                  value: showData ? _sessionMin!.round().toString() : _noReading,
                  icon: Icons.south_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  caption: 'Average',
                  value: showData && _average != null
                      ? _average!.round().toString()
                      : _noReading,
                  icon: Icons.remove_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  caption: 'Peak',
                  value:
                      showData ? _sessionPeak!.round().toString() : _noReading,
                  icon: Icons.north_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_notice != null) ...[
            AppCard(
              color: AppColors.cardBlue,
              elevated: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.mic_off_rounded,
                      size: 20, color: AppColors.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _notice!,
                      style: text.bodyMedium?.copyWith(
                          color: AppColors.textPrimary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // A short explainer of what the reading means.
          AppCard(
            color: AppColors.cardBlue,
            elevated: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Everyday spaces sit near 40–60 dB. Sustained loud levels '
                    'can strain your hearing over time — find a quieter spot '
                    'when the meter climbs into the loud range. Readings are '
                    'an approximate sound level from the phone microphone, not '
                    'a certified measurement.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textPrimary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start / stop control.
          _measuring
              ? AppButton.danger(
                  label: 'Stop',
                  icon: Icons.stop_rounded,
                  onPressed: _stop,
                )
              : AppButton.gradient(
                  label: 'Start',
                  icon: Icons.mic_rounded,
                  onPressed: _start,
                ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// A compact readout tile (label + big number) for the session summary row.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.caption,
    required this.value,
    required this.icon,
  });

  final String caption;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      radius: AppDimens.radiusMd,
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: text.labelMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
