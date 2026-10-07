import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/history_entry.dart';
import '../theme/app_theme.dart';

/// One compact history row: who, which wallet and when, and how much.
///
/// While [selecting], the wallet-colour dot gives way to a checkbox; the
/// caller decides what [onTap] means in each mode.
class HistoryTile extends StatelessWidget {
  const HistoryTile({
    super.key,
    required this.entry,
    required this.walletName,
    required this.walletColor,
    required this.localeCode,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final HistoryEntry entry;
  final String? walletName;
  final Color? walletColor;
  final String localeCode;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title =
        entry.recipientName ?? formatPhoneDisplay(entry.recipientNumber);

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
          ? Checkbox(value: selected, onChanged: (_) => onTap())
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
          title,
          textDirection: directionOf(title),
          style: theme.textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: Text(
        [
          ?walletName,
          formatHistoryTimestamp(entry.dialedAtUtc, localeCode),
        ].join(' · '),
        style: theme.textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Directionality(
        textDirection: TextDirection.ltr,
        child: Text(
          '${formatAmountDisplay(entry.amount)} ${l10n.currencySymbol}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}
