import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/recipient_type.dart';
import 'choice_tile.dart';

/// Friend/merchant toggle.
///
/// Rendered from the wallet's declared types, so a wallet that adds a third
/// type in `wallets.json` gets a third tile with no code change. Uses the same
/// [ChoiceTile] as the wallet picker, accented in the (branded) theme primary.
class RecipientTypeToggle extends StatelessWidget {
  const RecipientTypeToggle({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<String> types;
  final String? selected;
  final ValueChanged<String> onChanged;

  static IconData _iconFor(String typeKey) => switch (typeKey) {
        RecipientTypes.friend => Icons.person_rounded,
        RecipientTypes.merchant => Icons.storefront_rounded,
        _ => Icons.payments_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ChoiceTileRows(
      children: [
        for (final type in types)
          ChoiceTile(
            leading: Icon(
              _iconFor(type),
              size: 24,
              color: type == selected
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            label: recipientTypeLabel(l10n, type),
            selected: type == selected,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}
