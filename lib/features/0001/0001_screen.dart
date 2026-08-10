import 'package:apphud/apphud.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/apphud_config.dart';
import '../../core/legal_links.dart';
import '../../core/attribution/attribution_service.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/store_pricing.dart';
import '../../ui/components/app_button.dart';
import '../../ui/components/app_card.dart';
import '../../ui/components/app_chip.dart';
import '../../ui/components/app_hero_icon.dart';
import '../../ui/components/app_loader.dart';
import '../../ui/components/app_scaffold.dart';
import '../../ui/components/app_selectable_row.dart';
import '../../ui/components/app_top_bar.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Screen 0001 — Pro Audio Tools paywall.
///
/// Monetized through Apphud: the products (and every price/title) come from the
/// `ApphudConfig.placement` placement's paywall at runtime via
/// [Apphud.placements] — never hardcoded. The impression is reported with
/// [Apphud.paywallShown]; purchases go through [Apphud.purchase], restores
/// through [Apphud.restorePurchases], and premium unlocks only when
/// [Apphud.hasPremiumAccess] says so. Trial wording is gated on the
/// introductory offer the store attaches to the selected product, so the app
/// never promises a free trial a product does not carry.
///
/// All visuals compose from the frozen design system (`lib/ui/components`,
/// `lib/ui/theme`); this screen only arranges them.
class Screen_0001 extends StatefulWidget {
  const Screen_0001({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0001';

  @override
  State<Screen_0001> createState() => _Screen_0001State();
}

/// A single premium benefit line shown in the feature panel.
class _Benefit {
  const _Benefit(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

class _Screen_0001State extends State<Screen_0001> {
  /// Paraphrased benefits (anti-clone: same meaning, different wording than the
  /// source). Ad-free is framed as "distraction-free" — no ad SDK is shipped.
  static const List<_Benefit> _benefits = [
    _Benefit(Icons.graphic_eq_rounded, 'The full tone range',
        'Every labelled test tone, from deep bass to high treble.'),
    _Benefit(Icons.waves_rounded, 'Continuous 20 Hz – 20 kHz sweep',
        'Hear the whole range your gear can reproduce.'),
    _Benefit(Icons.compare_arrows_rounded, 'Every test',
        'Channel test, headphone checkup and the level meter.'),
    _Benefit(Icons.headphones_rounded, 'Headphone & earbud checkup',
        'Confirm sides, balance and phase on a new pair.'),
    _Benefit(Icons.blur_on_rounded, 'A calm, uninterrupted app',
        'No banners, no pop-ups — just the tools.'),
  ];

  bool _loading = true;
  bool _purchasing = false;
  // The paywall/product wrappers are held as `dynamic`: the `apphud` package
  // does not export its model classes from `package:apphud/apphud.dart`, and
  // every field below is already read defensively through `dynamic`.
  dynamic _paywall;
  List<dynamic> _products = const [];
  int _selected = 0;

  /// Whether the *selected* product carries an introductory offer. Starts false
  /// so trial copy only appears once the store product confirms one.
  bool _trialEligible = false;

  /// `paywallShown` is reported once per visit.
  bool _impressionSent = false;

  @override
  void initState() {
    super.initState();
    _loadPaywall();
  }

  /// Load the configured placement's paywall and its products. Guarded so an
  /// unsupported platform (e.g. headless web preview) or a misconfigured
  /// placement simply renders the empty state instead of crashing.
  ///
  /// [showLoader] is only set on a manual retry — the initial call from
  /// [initState] skips the synchronous `setState` (loading already starts true)
  /// so it never rebuilds mid-mount.
  Future<void> _loadPaywall({bool showLoader = false}) async {
    if (showLoader && mounted) setState(() => _loading = true);

    dynamic paywall;
    var products = const <dynamic>[];
    try {
      final placements = await Apphud.placements();
      dynamic match;
      for (final placement in placements) {
        if ('${(placement as dynamic).identifier}' == ApphudConfig.placement) {
          match = placement;
          break;
        }
      }
      // Fall back to whatever the dashboard returns if the id was renamed.
      if (match == null && placements.isNotEmpty) match = placements.first;
      final dynamic candidate = match?.paywall;
      if (candidate != null) {
        paywall = candidate;
        final dynamic list = candidate.products;
        if (list is List) products = List<dynamic>.from(list);
      }
    } catch (_) {
      // Leave the empty state to explain it.
    }

    if (!mounted) return;
    setState(() {
      _paywall = paywall;
      _products = products;
      _selected = _defaultSelection(products);
      _loading = false;
    });

    // Share the resolved product's price with the rest of the app (onboarding
    // offer, premium lock screens) so no screen can quote a different figure.
    final headline = _selectedProduct;
    if (headline != null) StorePricing.instance.adopt(headline);

    _reportImpression();
    await _refreshTrialEligibility();
  }

  /// Tell Apphud the paywall is on screen — without this there are no
  /// impressions, so conversion rates and A/B tests stay empty.
  Future<void> _reportImpression() async {
    final paywall = _paywall;
    if (paywall == null || _impressionSent) return;
    _impressionSent = true;
    try {
      await Apphud.paywallShown(paywall);
    } catch (_) {
      // Analytics only — never block the paywall.
    }
  }

  /// Prefer the headline weekly product when the placement returns several.
  int _defaultSelection(List<dynamic> products) {
    final idx = products
        .indexWhere((p) => _productId(p) == ApphudConfig.weeklyProductId);
    return idx >= 0 ? idx : 0;
  }

  dynamic get _selectedProduct => _products.isEmpty
      ? null
      : _products[_selected.clamp(0, _products.length - 1)];

  /// Only advertise the free trial when the store product Apphud returned
  /// actually carries an introductory offer. (The `apphud` package exposes no
  /// per-user introductory-offer eligibility call, so the offer attached to the
  /// store product is the closest real signal — see CAPABILITIES.md.)
  Future<void> _refreshTrialEligibility() async {
    final product = _selectedProduct;
    final eligible = product == null ? false : _hasIntroductoryOffer(product);
    if (!mounted || eligible == _trialEligible) return;
    setState(() => _trialEligible = eligible);
  }

  Future<void> _startTrial() async {
    if (_purchasing) return;
    final product = _selectedProduct;
    if (product == null) {
      // Nothing loaded (e.g. preview) — try again rather than fake a purchase.
      await _loadPaywall(showLoader: true);
      if (_products.isEmpty) {
        _showMessage('Subscriptions are unavailable right now.');
      }
      return;
    }

    setState(() => _purchasing = true);
    try {
      final dynamic result = await Apphud.purchase(product: product);
      // Apphud is the single source of truth — never trust a local flag.
      final isPro = await Apphud.hasPremiumAccess();
      if (isPro && !_purchaseFailed(result)) {
        // Revenue -> Tenjin, exactly once, from this purchase-result handler
        // only (never on launch, on a premium check or on a restore). The id,
        // price and currency come from the product that was actually bought.
        await AttributionService.instance.reportSubscription(product);
      }
      if (!mounted) return;
      await context.appState.setPro(isPro);
      if (isPro) {
        _onUnlocked();
      } else if (!_wasCancelled(result)) {
        _showMessage('Purchase could not be completed. Please try again.');
      }
    } catch (_) {
      _showMessage('Purchase could not be completed. Please try again.');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  /// Whether Apphud attached an error to the purchase result. Used to make sure
  /// revenue is only reported for a checkout that actually went through (a user
  /// who was already Pro can otherwise look "premium" after a failed attempt).
  bool _purchaseFailed(dynamic result) {
    try {
      return result?.error != null;
    } catch (_) {
      // No `error` field on this result shape — trust the premium check.
      return false;
    }
  }

  /// A user-cancelled checkout is not an error worth a snackbar.
  bool _wasCancelled(dynamic result) {
    String text;
    try {
      text = '${result?.error}';
    } catch (_) {
      text = '$result';
    }
    return text.toLowerCase().contains('cancel');
  }

  Future<void> _restore() async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    try {
      await Apphud.restorePurchases();
      final isPro = await Apphud.hasPremiumAccess();
      if (!mounted) return;
      await context.appState.setPro(isPro);
      if (isPro) {
        _onUnlocked();
      } else {
        _showMessage('No previous purchase was found on this account.');
      }
    } catch (_) {
      _showMessage('We could not restore purchases. Please try again.');
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  void _onUnlocked() {
    _showMessage('You’re all set — Pro is unlocked.');
    _close(unlocked: true);
  }

  void _close({bool unlocked = false}) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(unlocked);
    } else {
      nav.pushReplacementNamed('/');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Open a legal link (Terms / Privacy) in the external browser. Guarded so a
  /// launch failure shows a snackbar instead of crashing the paywall.
  Future<void> _openLink(String url) async {
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _showMessage('Could not open the link.');
    } catch (_) {
      _showMessage('Could not open the link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;

    // Already subscribed — show a compact confirmation instead of the offer.
    if (state.isPro) {
      return _buildProConfirmation(context);
    }

    final trialDays = state.freeTrialDays;
    return AppScaffold(
      backgroundColor: AppColors.backgroundSplash,
      topBar: AppTopBar(
        showClose: true,
        onClose: _close,
        actions: [
          TextButton(
            onPressed: _purchasing ? null : _restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHero(context, trialDays),
          const SizedBox(height: 24),
          _buildBenefits(context),
          const SizedBox(height: 20),
          _buildPlans(context, trialDays),
          const SizedBox(height: 16),
        ],
      ),
      bottomBar: _buildCta(context, trialDays),
    );
  }

  Widget _buildHero(BuildContext context, int trialDays) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        const SizedBox(height: 4),
        const AppIconMark(size: 84),
        const SizedBox(height: 18),
        Text(
          'Pro Audio Tools',
          textAlign: TextAlign.center,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _trialEligible
              ? '$trialDays-day free trial, then the full tone range, the '
                  '20 Hz – 20 kHz sweep and every test.'
              : 'Unlock the full tone range, the 20 Hz – 20 kHz sweep and '
                  'every test.',
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        // Qualitative only: the app has no install base yet, so it makes no
        // user-count, rating or award claim it cannot stand behind.
        const AppChip(
          label: 'The full audio test kit',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.accentTeal,
        ),
      ],
    );
  }

  Widget _buildBenefits(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Column(
        children: [
          for (var i = 0; i < _benefits.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.separator),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cardBlue,
                      borderRadius:
                          BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Icon(_benefits[i].icon,
                        size: 20, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _benefits[i].title,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _benefits[i].subtitle,
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlans(BuildContext context, int trialDays) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: AppLoader(status: 'Loading plans…')),
      );
    }

    if (_products.isEmpty) {
      // The placement returned no products (offline, or not configured yet).
      // Say so plainly and offer a retry — never invent a price, never show a
      // blank paywall. The rest of the app stays usable behind the close button.
      return AppCard(
        color: AppColors.background,
        border: Border.all(color: AppColors.primary, width: 1.5),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plans are unavailable right now',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'We could not reach the store. Check your connection and '
                    'try again — you can keep using the free tests meanwhile.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _loadPaywall(showLoader: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _products.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          AppSelectableRow(
            title: _periodLabel(_products[i]),
            subtitle: _priceLabel(_products[i], trialDays),
            selected: i == _selected,
            onTap: () {
              setState(() => _selected = i);
              // Eligibility is per product — re-check before promising a trial.
              _refreshTrialEligibility();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCta(BuildContext context, int trialDays) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton.gradient(
          label: _trialEligible
              ? 'Start my free trial'
              : 'Unlock Pro Audio Tools',
          icon: Icons.lock_open_rounded,
          loading: _purchasing,
          onPressed: _purchasing ? null : _startTrial,
        ),
        const SizedBox(height: 10),
        Text(
          _trialEligible
              ? 'Free for $trialDays days, then auto-renews until you cancel. '
                  'Manage anytime in Settings.'
              : 'Auto-renews until you cancel. Manage anytime in Settings.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        // Wrap (not Row) so the restore + legal links reflow onto a second line
        // on narrow screens instead of overflowing.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: _purchasing ? null : _restore,
              child: const Text('Restore purchase'),
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: () => _openLink(kTermsOfUseUrl),
              child: const Text('Terms of Use'),
            ),
            const Text('·',
                style: TextStyle(color: AppColors.textSecondary)),
            TextButton(
              onPressed: () => _openLink(kPrivacyPolicyUrl),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProConfirmation(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppScaffold(
      backgroundColor: AppColors.backgroundSplash,
      topBar: AppTopBar(showClose: true, onClose: _close),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppHeroIcon(
                icon: Icons.verified_rounded, size: 84),
            const SizedBox(height: 20),
            Text(
              'Pro is active',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The full tone range, the sweep and every test are yours.',
              textAlign: TextAlign.center,
              style:
                  text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            AppButton.gradient(
              label: 'Continue',
              expand: false,
              onPressed: () => _close(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Store metadata -----------------------------------------------------
  // Everything below reads the *store* product Apphud attached to the paywall,
  // through the shared readers in `core/state/store_pricing.dart` — the same
  // ones the onboarding offer and the premium lock screens use, so every screen
  // quotes exactly one price and none of them can drift into a literal.

  /// Whether the store product carries an introductory (free-trial) offer.
  bool _hasIntroductoryOffer(dynamic product) => hasIntroductoryOffer(product);

  String _productId(dynamic product) => productIdOf(product);

  /// Human-readable billing period from the store product.
  String _periodLabel(dynamic product) => periodLabelOf(product);

  /// Price line. The amount always comes from the store; the trial half of the
  /// sentence only appears when Apphud confirmed the intro offer is available.
  String _priceLabel(dynamic product, int trialDays) {
    final priced = priceWithPeriodOf(product);
    final amount = priced.isEmpty ? 'Price shown at checkout' : priced;
    if (_trialEligible && _selectedProduct != null &&
        _productId(product) == _productId(_selectedProduct!)) {
      return '$trialDays-day free trial, then $amount';
    }
    return amount;
  }
}
