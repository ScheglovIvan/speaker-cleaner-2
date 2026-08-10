import 'package:apphud/apphud.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/legal_links.dart';
import '../../core/state/app_scope.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Screen 0003 — Settings.
///
/// Layout (from source/0003.json): a scrolling column led by a "Get Pro"
/// banner, followed by grouped list rows (preferences, tools, account/support)
/// and a version footer. Everything is composed from the shared design system;
/// no bespoke colours/fonts/gradients live here.
///
/// Copy is paraphrased and icons use the app's rounded Material set (anti-clone).
class Screen_0003 extends StatefulWidget {
  const Screen_0003({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0003';

  @override
  State<Screen_0003> createState() => _Screen_0003State();
}

class _Screen_0003State extends State<Screen_0003> {
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watchAppState;
    final l = context.l10n;

    return AppScaffold(
      topBar: AppTopBar(title: l.t('settings_title'), showBack: true),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          _proBanner(context, isPro: state.isPro),
          const SizedBox(height: 20),

          AppSectionHeader(title: l.t('prefs_header')),
          const SizedBox(height: 4),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                AppToggleRow(
                  title: l.t('sound_title'),
                  subtitle: l.t('sound_sub'),
                  leadingIcon: Icons.volume_up_rounded,
                  value: state.soundEnabled,
                  onChanged: (v) => context.appState.setSoundEnabled(v),
                ),
                const _RowDivider(),
                AppToggleRow(
                  title: l.t('haptics_title'),
                  subtitle: l.t('haptics_sub'),
                  leadingIcon: Icons.vibration_rounded,
                  value: state.hapticsEnabled,
                  onChanged: (v) => context.appState.setHapticsEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppListTile(
            title: l.t('app_language'),
            subtitle: state.language.nativeName,
            leadingIcon: Icons.translate_rounded,
            trailing: _trailingWithChevron(
              Text(
                state.language.flag,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            onTap: () => Navigator.of(context).pushNamed('/0004'),
          ),
          const SizedBox(height: 24),

          AppSectionHeader(title: l.t('routine_header')),
          const SizedBox(height: 4),
          AppListTile(
            title: l.t('plan_title'),
            subtitle: l.t('plan_sub'),
            leadingIcon: Icons.water_drop_outlined,
            onTap: () => Navigator.of(context).pushNamed('/0010'),
          ),
          const SizedBox(height: 24),

          AppSectionHeader(title: l.t('account_header')),
          const SizedBox(height: 4),
          AppListTile(
            title: l.t('restore_title'),
            subtitle: l.t('restore_sub'),
            leadingIcon: Icons.restore_rounded,
            trailing: _restoring
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: AppLoader(size: 20),
                  )
                : null,
            showChevron: !_restoring,
            onTap: _restoring ? null : () => _restore(context),
          ),
          const SizedBox(height: 12),
          AppListTile(
            title: l.t('rate_title'),
            leadingIcon: Icons.star_rounded,
            onTap: () => _openLink(
              context,
              'https://apps.apple.com/app/id6793187697?action=write-review',
            ),
          ),
          const SizedBox(height: 12),
          AppListTile(
            title: l.t('share_title'),
            leadingIcon: Icons.ios_share_rounded,
            onTap: () => _share(context),
          ),
          const SizedBox(height: 12),
          AppListTile(
            title: l.t('privacy_title'),
            leadingIcon: Icons.privacy_tip_rounded,
            onTap: () => _openLink(context, kPrivacyPolicyUrl),
          ),
          const SizedBox(height: 12),
          AppListTile(
            title: l.t('terms_title'),
            leadingIcon: Icons.description_rounded,
            onTap: () => _openLink(context, kTermsOfUseUrl),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              '${l.t('version_label')} 1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  /// The "Get Pro" banner. Shows an upsell gradient card for free users and a
  /// soft confirmation card once Premium is active.
  Widget _proBanner(BuildContext context, {required bool isPro}) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    if (isPro) {
      return AppCard(
        color: AppColors.cardBlue,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppColors.success, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.t('premium_active_title'),
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.t('premium_active_sub'),
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppGradientCard(
      onTap: () => Navigator.of(context)
          .pushNamed('/0001')
          .then((_) => context.appState.refreshEntitlement()),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.t('upgrade_title'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  l.t('upgrade_sub'),
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ],
      ),
    );
  }

  Widget _trailingWithChevron(Widget leading) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary),
        ],
      );

  Future<void> _restore(BuildContext context) async {
    setState(() => _restoring = true);
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      await Apphud.restorePurchases();
      // Apphud decides — the restore call itself never unlocks anything locally.
      final isPro = await Apphud.hasPremiumAccess();
      if (!mounted) return;
      await context.appState.setPro(isPro);
      message = isPro
          ? 'Premium restored on this device.'
          : 'No previous purchases were found.';
    } catch (_) {
      message = "Couldn't reach the store — please try again later.";
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Open a legal link (Privacy Policy / Terms of Use) in the external browser.
  /// Guarded so a launch failure shows a snackbar instead of crashing.
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
          ..showSnackBar(const SnackBar(content: Text('Could not open the link.')));
      }
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  /// Open the real system share sheet with an App Store link.
  /// Guarded so a failure shows a snackbar instead of crashing.
  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.share(
        'Check out Speaker & Headphone Test on the App Store: '
        'https://apps.apple.com/app/id6793187697',
      );
    } catch (_) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the share sheet.')),
        );
    }
  }
}

/// Hairline separator between grouped rows inside a card.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, thickness: 1, color: AppColors.separator),
      );
}
