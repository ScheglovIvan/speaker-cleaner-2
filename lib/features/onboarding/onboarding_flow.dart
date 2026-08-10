import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/legal_links.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/store_pricing.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';
import '../premium/premium_benefits.dart';

/// First-launch onboarding — a short welcome → how-it-works → subscribe-offer
/// sequence, shown ONLY on the very first launch (gated by the persisted
/// `onboardingComplete` flag via [LaunchGate]). It ends by presenting the
/// Premium offer.
///
/// NOTE: the exact original onboarding screens were not captured in the crawl,
/// so this is a faithful reconstruction (see CAPABILITIES.md). Styling is pure
/// design system.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _lastPage = 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _lastPage) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Finish onboarding: persist the "seen" flag so it never shows again, then
  /// let [LaunchGate] rebuild into the app shell.
  Future<void> _finish() async {
    await context.appState.setOnboardingComplete(true);
  }

  /// Present the paywall as the subscribe offer, then finish regardless of the
  /// outcome (bought → Pro; skipped → free tier). Entitlement is re-synced.
  Future<void> _startTrial() async {
    await Navigator.of(context).pushNamed('/0001');
    if (!mounted) return;
    await context.appState.refreshEntitlement();
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final trialDays = context.watchAppState.freeTrialDays;

    return AppScaffold(
      backgroundColor: AppColors.backgroundSplash,
      body: Column(
        children: [
          // Skip (hidden on the final offer page).
          SizedBox(
            height: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: _page < _lastPage
                  ? TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                const _OnboardPage(
                  // No glyph: the welcome page shows the app's own icon.
                  title: 'Welcome to Speaker & Headphone Test',
                  body:
                      'A hands-on kit for checking your speakers, earpiece, '
                      'headphones and earbuds actually work the way they '
                      'should.',
                ),
                const _OnboardPage(
                  icon: Icons.graphic_eq_rounded,
                  title: 'How it works',
                  body:
                      'Pick a test, turn the volume up and listen. Drive one '
                      'channel at a time, play labelled tones or measure the '
                      'level — anything dead, muffled or wired backwards shows '
                      'up straight away.',
                ),
                _OfferPage(trialDays: trialDays),
              ],
            ),
          ),

          // Page indicator dots.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i <= _lastPage; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        i == _page ? AppColors.primary : AppColors.separator,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Bottom CTA.
          SafeArea(
            top: false,
            child: _page < _lastPage
                ? AppButton.gradient(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton.gradient(
                        label: 'Start my $trialDays-day free trial',
                        icon: Icons.workspace_premium_rounded,
                        onPressed: _startTrial,
                      ),
                      const SizedBox(height: 8),
                      AppButton.tonal(
                        label: 'Continue with the free tests',
                        onPressed: _finish,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// A single centred welcome/how-it-works page.
class _OnboardPage extends StatelessWidget {
  const _OnboardPage({
    this.icon,
    required this.title,
    required this.body,
  });

  /// The page's mark. `null` shows the app's own icon — used by the welcome
  /// page, whose mark stands for the app itself rather than a feature.
  final IconData? icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const AppIconMark(size: 108)
            else
              AppHeroIcon(icon: icon!, size: 108),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The final onboarding page — the Premium subscribe offer.
class _OfferPage extends StatelessWidget {
  const _OfferPage({required this.trialDays});

  final int trialDays;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const Center(
            child: AppIconMark(size: 84),
          ),
          const SizedBox(height: 18),
          Text(
            'Unlock Pro Audio Tools',
            textAlign: TextAlign.center,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Price straight from the store product the paywall sells (shared via
          // StorePricing) — omitted, never faked, until the store answers.
          StorePriceBuilder(
            builder: (context, price) => Text(
              price == null
                  ? '$trialDays-day free trial. Everything unlocked:'
                  : '$trialDays-day free trial, then $price. '
                      'Everything unlocked:',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          AppCard(
            radius: AppDimens.radiusLg,
            child: const PremiumBenefitsList(),
          ),
          const SizedBox(height: 12),
          // App Store requires working Terms/Privacy links on any auto-renewal
          // subscribe offer.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => _openLink(context, kTermsOfUseUrl),
                child: const Text('Terms of Use'),
              ),
              const Text('·', style: TextStyle(color: AppColors.textSecondary)),
              TextButton(
                onPressed: () => _openLink(context, kPrivacyPolicyUrl),
                child: const Text('Privacy Policy'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Open a legal link in the external browser, guarded with a snackbar on
  /// failure rather than crashing.
  Future<void> _openLink(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
              const SnackBar(content: Text('Could not open the link.')));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Could not open the link.')));
    }
  }
}
