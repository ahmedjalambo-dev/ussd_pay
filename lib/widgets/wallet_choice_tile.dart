import 'package:flutter/material.dart';

import '../models/wallet.dart';
import '../theme/app_theme.dart';
import 'wallet_card.dart';

/// A selectable wallet, shown with its brand mark, for forms that ask which
/// wallet something belongs to.
///
/// Selection is shown three ways -- brand-coloured border, tinted fill, and a
/// check badge -- so it survives bright sunlight and colour-blindness alike.
class WalletChoiceTile extends StatelessWidget {
  const WalletChoiceTile({
    super.key,
    required this.wallet,
    required this.localeCode,
    required this.selected,
    required this.onTap,
  });

  final Wallet wallet;
  final String localeCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = Color(wallet.colorValue);
    final radius = BorderRadius.circular(AppTheme.radiusMd);

    return Semantics(
      button: true,
      selected: selected,
      child: Stack(
        children: [
          Material(
            color: selected
                ? brand.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: selected
                  ? BorderSide(color: brand, width: 2)
                  : BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppTheme.touchTarget,
                ),
                padding: const EdgeInsets.all(AppTheme.gapMd),
                child: Row(
                  children: [
                    WalletMark(wallet: wallet, onBrand: brand, size: 40),
                    const SizedBox(width: AppTheme.gapMd),
                    Expanded(
                      child: Text(
                        wallet.nameFor(localeCode),
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            // Directional, so the badge sits on the trailing corner in both
            // Arabic and English.
            PositionedDirectional(
              top: AppTheme.gapXs,
              end: AppTheme.gapXs,
              child: Icon(Icons.check_circle_rounded, size: 20, color: brand),
            ),
        ],
      ),
    );
  }
}
