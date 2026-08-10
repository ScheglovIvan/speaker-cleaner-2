import 'package:flutter/material.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/state/app_scope.dart';
import '../../core/state/languages.dart';
import '../../ui/components/components.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_dimens.dart';

/// Screen 0004 — Language Selection.
///
/// A single-select (radio) list of the supported display languages with a
/// sticky "Save" CTA. The choice is held as a local draft while the user
/// browses the list and is only committed to [AppState] (persisted + used to
/// re-localize the UI) when Save is tapped, at which point the screen pops back.
class Screen_0004 extends StatefulWidget {
  const Screen_0004({super.key});

  /// Canonical screen id (matches app_spec.json / screens.json).
  static const String screenId = '0004';

  @override
  State<Screen_0004> createState() => _Screen_0004State();
}

class _Screen_0004State extends State<Screen_0004> {
  /// The pending choice — seeded from the persisted language on first build,
  /// then updated locally until the user confirms with Save.
  String? _draftCode;

  String _selectedCode(BuildContext context) =>
      _draftCode ?? context.watchAppState.languageCode;

  void _save() {
    final code = _draftCode;
    final state = context.appState;
    if (code != null && code != state.languageCode) {
      state.setLanguage(code);
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final selected = _selectedCode(context);
    final dirty = _draftCode != null && _draftCode != context.watchAppState.languageCode;

    return AppScaffold(
      padded: false,
      topBar: AppTopBar(
        title: l.t('language_title'),
        showBack: true,
      ),
      bottomBar: AppButton.gradient(
        label: l.t('save_language'),
        onPressed: dirty ? _save : null,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.screenPadding,
              4,
              AppDimens.screenPadding,
              16,
            ),
            child: Text(
              l.t('language_helper'),
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.screenPadding,
                0,
                AppDimens.screenPadding,
                16,
              ),
              itemCount: kSupportedLanguages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final lang = kSupportedLanguages[index];
                final isSelected = lang.code == selected;
                return AppSelectableRow(
                  title: '${lang.flag}  ${lang.nativeName}',
                  subtitle: lang.nativeName == lang.englishName
                      ? null
                      : lang.englishName,
                  selected: isSelected,
                  onTap: () => setState(() => _draftCode = lang.code),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
