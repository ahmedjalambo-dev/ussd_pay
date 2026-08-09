import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import 'payment_screen.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Favorite favorite,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteFavoriteTitle),
        content: Text(l10n.deleteFavoriteMessage(favorite.name)),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppTheme.dialogActionSize,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(favoritesProvider.notifier).delete(favorite.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    if (favorites.isEmpty) {
      return EmptyState(
        icon: Icons.star_outline_rounded,
        title: l10n.emptyFavoritesTitle,
        body: l10n.emptyFavoritesBody,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.gapLg,
        AppTheme.screenPadding,
        AppTheme.gapXl,
      ),
      itemCount: favorites.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gapMd),
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        final wallet =
            wallets.where((w) => w.id == favorite.walletId).firstOrNull;

        return _FavoriteCard(
          favorite: favorite,
          wallet: wallet,
          localeCode: localeCode,
          onDelete: () => _confirmDelete(context, ref, favorite),
          // Opens a pre-filled payment screen, never the confirmation screen
          // directly: the amount still has to be entered and reviewed.
          onTap: wallet == null
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

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.favorite,
    required this.wallet,
    required this.localeCode,
    required this.onDelete,
    required this.onTap,
  });

  final Favorite favorite;
  final Wallet? wallet;
  final String localeCode;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final walletName = wallet?.nameFor(localeCode);
    final brandColor =
        wallet != null ? Color(wallet!.colorValue) : scheme.outline;

    return Container(
      decoration: AppTheme.surface(context),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gapLg),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: brandColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    favorite.name.characters.firstOrNull ?? '?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.gapLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        favorite.name,
                        // A name the user typed: a Latin or numeric one would
                        // otherwise be reordered by bidi inside the Arabic
                        // layout.
                        textDirection: directionOf(favorite.name),
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      // Align outside, Directionality inside: the row sits on
                      // the reading side, the digits stay in dialing order.
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            formatPhoneDisplay(favorite.number),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      if (walletName != null) ...[
                        const SizedBox(height: AppTheme.gapXs),
                        Text(
                          '$walletName · '
                          '${recipientTypeLabel(l10n, favorite.defaultType)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 24),
                  tooltip: l10n.delete,
                  color: scheme.onSurfaceVariant,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
