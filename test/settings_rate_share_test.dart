import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_cleaner/core/state/app_scope.dart';
import 'package:speaker_cleaner/core/state/app_state.dart';
import 'package:speaker_cleaner/features/0003/0003_screen.dart';

/// App Store review readiness (Guideline 2.1): the Settings "Rate the app" and
/// "Tell a friend" rows used to be dead placeholders that only popped a toast.
/// They now perform real actions (store review deep link / system share sheet),
/// so tapping them must never surface the old toast-only copy.
void main() {
  // The old placeholder strings the two rows used to show. Neither must appear.
  const rateToast = 'Thanks! This opens the store rating.';
  const shareToast = 'Sharing sheet would open here.';

  testWidgets('Rate and Share rows do not call a toast-only handler',
      (tester) async {
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: Screen_0003()),
      ),
    );
    await tester.pumpAndSettle();

    // Both rows resolve to their English titles from the string catalogue.
    final rateRow = find.text('Rate the app');
    final shareRow = find.text('Tell a friend');
    expect(rateRow, findsOneWidget);
    expect(shareRow, findsOneWidget);

    // Tapping Rate: hits the real store-review launch (no toast). Any platform
    // failure is swallowed by the handler, so the tap is safe under test.
    await tester.ensureVisible(rateRow);
    await tester.tap(rateRow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Tapping Share: opens the real system share sheet (no toast).
    await tester.ensureVisible(shareRow);
    await tester.tap(shareRow);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The decisive assertion: neither placeholder toast was ever shown.
    expect(find.text(rateToast), findsNothing);
    expect(find.text(shareToast), findsNothing);
  });
}
