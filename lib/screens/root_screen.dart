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
  static const int _favoritesIndex = 1;
  static const int _historyIndex = 2;

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // The pay tab carries its own "choose a wallet" heading, so the bar shows
    // the app name there instead of repeating it.
    final titles = [l10n.appTitle, l10n.navFavorites, l10n.navHistory];

    // While rows are selected on the favorites or history tab, the bar
    // becomes the selection's bar: it holds the delete action so it stays put
    // however far the list is scrolled.
    final historySelection = ref.watch(historySelectionProvider);
    final historySelector = ref.read(historySelectionProvider.notifier);
    final favoritesSelection = ref.watch(favoritesSelectionProvider);
    final favoritesSelector = ref.read(favoritesSelectionProvider.notifier);

    final onFavorites = _index == _favoritesIndex;
    final selectedCount = switch (_index) {
      _favoritesIndex => favoritesSelection.length,
      _historyIndex => historySelection.ids.length,
      _ => 0,
    };
    final selecting = selectedCount > 0;
    final clearSelection = onFavorites
        ? favoritesSelector.clear
        : historySelector.clear;

    return PopScope(
      // Back leaves selection first, as in any Android list.
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) clearSelection();
      },
      child: Scaffold(
        appBar: selecting
            ? AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 26),
                  tooltip: l10n.cancelSelection,
                  onPressed: clearSelection,
                ),
                title: Text(l10n.selectedCount(selectedCount)),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.select_all_rounded, size: 26),
                    tooltip: l10n.selectAll,
                    onPressed: onFavorites
                        ? favoritesSelector.selectAll
                        : historySelector.selectAll,
                  ),
                  // Editing is one row at a time, so Edit shows only while
                  // exactly one favorite is selected.
                  if (onFavorites && selectedCount == 1)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 26),
                      tooltip: l10n.edit,
                      onPressed: () =>
                          FavoritesScreen.editSelected(context, ref),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 26),
                    tooltip: l10n.delete,
                    onPressed: () => onFavorites
                        ? FavoritesScreen.deleteSelected(context, ref)
                        : HistoryScreen.deleteSelected(context, ref),
                  ),
                  const SizedBox(width: 4),
                ],
              )
            : AppBar(
                title: Text(titles[_index]),
                leading: IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 26),
                  tooltip: l10n.settings,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                ),
                actions: [
                  // Only on a non-empty favorites list: an empty one shows its
                  // own Add button in the empty state.
                  if (onFavorites && ref.watch(favoritesProvider).isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 26),
                      tooltip: l10n.addFavorite,
                      onPressed: () => FavoritesScreen.openAdd(context),
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
          onDestinationSelected: (index) {
            // Leaving a tab ends its selection.
            if (index != _favoritesIndex) favoritesSelector.clear();
            if (index != _historyIndex) historySelector.clear();
            setState(() => _index = index);
          },
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
      ),
    );
  }
}
