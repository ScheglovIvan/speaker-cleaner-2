import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One destination in the [AppBottomBar].
class AppBottomBarItem {
  const AppBottomBarItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// The shared bottom tab bar (Clean / Modes / dB Level / Stereo).
///
/// A thin wrapper over [NavigationBar] so the persistent shell and any screen
/// that needs a tab bar render it identically from the design tokens.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<AppBottomBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.separator, width: 1),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onSelected,
        backgroundColor: Colors.transparent,
        elevation: 0,
        destinations: [
          for (final item in items)
            NavigationDestination(
              icon: Icon(item.icon, color: AppColors.textSecondary),
              selectedIcon: Icon(item.icon, color: AppColors.primary),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
