import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/app_providers.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Navigation shell: pay, favorites, history, with settings in the app bar.
class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  static const int _historyIndex = 2;

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The pay tab carries its own "choose a wallet" heading, so the bar shows
    // the app name there instead of repeating it.
    final titles = [l10n.appTitle, l10n.navFavorites, l10n.navHistory];

    // Clear lives in the bar rather than under the list, so it stays put
    // while the user switches between the Done and Cancelled tabs -- it
    // clears both. Hidden when there is nothing to clear.
    final showClear =
        _index == _historyIndex && ref.watch(historyProvider).isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          if (showClear)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 26),
              tooltip: l10n.clearHistory,
              onPressed: () => HistoryScreen.confirmClear(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 26),
            tooltip: l10n.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // IndexedStack keeps each tab's scroll position without rebuilding.
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), FavoritesScreen(), HistoryScreen()],
      ),
      // Sizing, colours and label behaviour come from the theme's
      // navigationBarTheme so this stays a list of destinations.
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_outline_rounded),
            selectedIcon: const Icon(Icons.star_rounded),
            label: l10n.navFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_rounded),
            label: l10n.navHistory,
          ),
        ],
      ),
    );
  }
}
