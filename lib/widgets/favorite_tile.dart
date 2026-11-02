import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../theme/app_theme.dart';

/// One compact favorites row, styled like [HistoryTile]: who, their number,
/// and which wallet and recipient type a payment to them uses.
///
/// While [selecting], the wallet-colour dot gives way to a checkbox; the
/// caller decides what [onTap] means in each mode.
class FavoriteTile extends StatelessWidget {
  const FavoriteTile({
    super.key,
    required this.favorite,
    required this.walletName,
    required this.walletColor,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Favorite favorite;
  final String? walletName;
  final Color? walletColor;
  final bool selecting;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListTile(
      minTileHeight: AppTheme.touchTarget,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.screenPadding,
      ),
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
      selectedColor: scheme.onSurface,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onTap?.call())
          : Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: walletColor ?? scheme.outline,
                shape: BoxShape.circle,
              ),
            ),
      title: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          favorite.name,
          // A name the user typed: a Latin or numeric one would otherwise be
          // reordered by bidi inside the Arabic layout.
          textDirection: directionOf(favorite.name),
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        [
          ltrIsolate(formatPhoneDisplay(favorite.number)),
          ?walletName,
          recipientTypeLabel(l10n, favorite.defaultType),
        ].join(' · '),
        style: theme.textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
