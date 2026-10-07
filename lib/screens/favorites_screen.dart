import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/favorite_tile.dart';
import 'payment_screen.dart';

/// Saved recipients, in the same compact style as history. Long-press starts
/// selecting; while selecting, a tap toggles a row instead of opening it.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  /// Deletes every selected favorite at once and offers Undo, rather than
  /// asking first, as history does: selecting and pressing delete is already
  /// two deliberate steps, and Undo puts the rows back exactly as they were.
  /// Public so the root AppBar, which owns the delete action, can call it.
  static Future<void> deleteSelected(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = ref.read(favoritesSelectionProvider);
    final removed = ref
        .read(favoritesProvider)
        .where((f) => ids.contains(f.id))
        .toList(growable: false);
    if (removed.isEmpty) return;

    final notifier = ref.read(favoritesProvider.notifier);
    ref.read(favoritesSelectionProvider.notifier).clear();
    await notifier.deleteMany(removed.map((f) => f.id));

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.favoritesDeleted(removed.length)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => notifier.restore(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';
    final selection = ref.watch(favoritesSelectionProvider);
    final selector = ref.read(favoritesSelectionProvider.notifier);

    if (favorites.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline_rounded,
        title: l10n.emptyFavoritesTitle,
        body: l10n.emptyFavoritesBody,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.gapSm),
      itemCount: favorites.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: AppTheme.screenPadding,
        endIndent: AppTheme.screenPadding,
      ),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        final wallet = wallets
            .where((w) => w.id == favorite.walletId)
            .firstOrNull;

        return FavoriteTile(
          favorite: favorite,
          walletName: wallet?.nameFor(localeCode),
          walletColor: wallet != null ? Color(wallet.colorValue) : null,
          selecting: selection.isNotEmpty,
          selected: selection.contains(favorite.id),
          onLongPress: () => selector.toggle(favorite.id),
          onTap: selection.isNotEmpty
              ? () => selector.toggle(favorite.id)
              // Opens a pre-filled payment screen, never the confirmation
              // screen directly: the amount still has to be entered and
              // reviewed.
              : wallet == null
              ? null
              : () {
                  ref
                      .read(paymentDraftProvider.notifier)
                      .fromFavorite(favorite, wallet);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PaymentScreen(wallet: wallet),
                    ),
                  );
                },
        );
      },
    );
  }
}
