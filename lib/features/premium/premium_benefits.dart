import 'package:flutter/material.dart';

import '../../core/state/app_scope.dart';
import '../../core/state/store_pricing.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// A single premium benefit line.
class PremiumBenefit {
  const PremiumBenefit(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// The canonical Premium value list: the full generated tone range (and
/// continuous play), the 20 Hz – 20 kHz sweep, every test and an ad-free
/// experience. Reused by the
/// onboarding offer, the paywall and every feature lock screen so the promise
/// is identical everywhere.
const List<PremiumBenefit> kPremiumBenefits = [
  PremiumBenefit(Icons.graphic_eq_rounded, 'The full tone range',
      'Every sine up to 16 kHz, played continuously — not just the free '
          'low tones for 30 seconds at a time.'),
  PremiumBenefit(Icons.waves_rounded, 'The 20 Hz – 20 kHz sweep',
      'Hear the whole range your speakers or headphones reproduce.'),
  PremiumBenefit(Icons.compare_arrows_rounded, 'Channel test',
      'Drive the left, right, earpiece or both outputs on demand.'),
  PremiumBenefit(Icons.speed_rounded, 'Sound-level meter',
      'Measure how loud the output is, live, with the pro gauge.'),
  PremiumBenefit(Icons.block, 'Ad-free, always',
      'A calm, distraction-free app with nothing in the way.'),
];

/// A reusable Premium benefits panel (icon bubble + title + copy per benefit).
/// Composed only from the design system so it matches the rest of the app.
class PremiumBenefitsList extends StatelessWidget {
  const PremiumBenefitsList({super.key, this.onDark = false});

  /// Render for placement on a gradient/dark surface (white text).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final titleColor = onDark ? Colors.white : AppColors.textPrimary;
    final subColor =
        onDark ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary;
    final bubble =
        onDark ? Colors.white.withValues(alpha: 0.18) : AppColors.cardBlue;
    final iconColor = onDark ? Colors.white : AppColors.primary;

    return Column(
      children: [
        for (var i = 0; i < kPremiumBenefits.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bubble,
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                ),
                child: Icon(kPremiumBenefits[i].icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kPremiumBenefits[i].title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kPremiumBenefits[i].subtitle,
                      style: text.bodySmall?.copyWith(color: subColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A full-screen Premium lock / benefits gate.
///
/// Shown when a free user reaches a Premium-gated feature (Channel Test,
/// Sound-Level Meter, a premium tone) — it explains what Premium unlocks and
/// routes to the paywall (0001). After returning from the paywall the
/// entitlement is re-synced; if the user is now Pro the gate rebuilds into the
/// real feature.
///
/// [featureName] names the tapped feature; [icon] is its glyph.
class PremiumLockView extends StatelessWidget {
  const PremiumLockView({
    super.key,
    required this.featureName,
    required this.icon,
    this.title,
    this.showBack = false,
  });

  final String featureName;
  final IconData icon;
  final String? title;
  final bool showBack;

  Future<void> _openPaywall(BuildContext context) async {
    await Navigator.of(context).pushNamed('/0001');
    if (context.mounted) {
      await context.appState.refreshEntitlement();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trialDays = context.watchAppState.freeTrialDays;

    return AppScaffold(
      backgroundColor: AppColors.backgroundSplash,
      topBar: AppTopBar(title: title ?? featureName, showBack: showBack),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Center(child: AppHeroIcon(icon: icon, size: 84)),
          const SizedBox(height: 20),
          Text(
            '$featureName is a Premium feature',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade to Pro Audio Tools to use it — plus everything else '
            'below.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: const PremiumBenefitsList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton.gradient(
            label: 'Start my $trialDays-day free trial',
            icon: Icons.lock_open_rounded,
            onPressed: () => _openPaywall(context),
          ),
          const SizedBox(height: 8),
          // The price comes from the SAME store product the paywall charges —
          // never a literal. Until the store answers it is left out entirely
          // rather than quoting a figure that may not match the checkout.
          StorePriceBuilder(
            builder: (context, price) => Text(
              price == null
                  ? 'Free for $trialDays days. Cancel anytime.'
                  : 'Free for $trialDays days, then $price. Cancel anytime.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
