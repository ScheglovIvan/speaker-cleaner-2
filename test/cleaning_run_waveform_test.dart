import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_cleaner/core/audio/cleaning_audio.dart';
import 'package:speaker_cleaner/core/audio/sound_envelope.dart';
import 'package:speaker_cleaner/core/state/app_scope.dart';
import 'package:speaker_cleaner/core/state/app_state.dart';
import 'package:speaker_cleaner/features/0008/0008_screen.dart';
import 'package:speaker_cleaner/ui/components/waveform_visualizer.dart';

/// The reported bug: with the sound toggle OFF the tone run's visualiser never
/// learned which clip it was drawing, so `hasLevels` stayed false and the bars
/// rested as uniform dots. The run must now report `hasLevels == true`
/// regardless of the sound toggle, driven by the clip's measured envelope.
void main() {
  testWidgets('tone run reports hasLevels with sound off', (tester) async {
    // Measure the tone's envelope up front (as main() does before first frame).
    await SoundEnvelopes.preload(const [CleaningTones.waterTone]);

    final state = AppState();
    await state.setSoundEnabled(false);

    await tester.pumpWidget(
      // AppScope above MaterialApp so pushed routes (the run screen) can reach
      // it, exactly as the real app wires it.
      AppScope(
        state: state,
        child: const MaterialApp(home: Screen_0008()),
      ),
    );

    await tester.tap(find.textContaining('Start '));
    await tester.pump(); // schedule the push
    await tester.pump(const Duration(milliseconds: 400)); // transition + postFrame
    await tester.pump(); // flush the rebuild that flips hasLevels

    final visualizer =
        tester.widget<WaveformVisualizer>(find.byType(WaveformVisualizer));
    expect(visualizer.source, isNotNull);
    expect(visualizer.source!.hasLevels, isTrue,
        reason: 'the run must draw the tone even with sound off');

    // Tear down so the repeating waveform ticker does not outlive the test.
    await tester.pumpWidget(const SizedBox());
  });
}
