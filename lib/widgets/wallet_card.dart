import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/wallet.dart';
import '../theme/app_theme.dart';

/// A wallet's brand mark: on a [WalletCard], and on the add-favorite wallet
/// tiles.
///
/// Prefers the bundled brand image declared in `wallets.json`; falls back to a
/// generic wallet icon on a translucent circle when a wallet has no `icon`.
/// The image is clipped to a circle and given a hairline overlay so it reads
/// as an inset badge on the coloured card rather than a flat sticker.
class WalletMark extends StatelessWidget {
  const WalletMark({
    super.key,
    required this.wallet,
    required this.onBrand,
    this.size = 56,
  });

  final Wallet wallet;

  /// Tint for the fallback icon and its circle.
  final Color onBrand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = wallet.iconAsset;
    if (asset == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: onBrand.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.account_balance_wallet_rounded,
          size: size * 0.54,
          color: onBrand,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // shape: BoxShape.circle,
        // border: Border.all(color: onBrand.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing asset must not crash the home screen; fall back to the
        // generic tinted icon instead.
        errorBuilder: (_, _, _) => Container(
          color: onBrand.withValues(alpha: 0.18),
          alignment: Alignment.center,
          child: Icon(
            Icons.account_balance_wallet_rounded,
            size: size * 0.54,
            color: onBrand,
          ),
        ),
      ),
    );
  }
}

/// A large, high-contrast wallet button for the home screen.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.wallet,
    required this.localeCode,
    required this.onTap,
  });

  final Wallet wallet;
  final String localeCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final brandColor = Color(wallet.colorValue);
    // Pick the text colour from the brand colour's own luminance so a light
    // brand (or one edited into wallets.json later) stays readable.
    final onBrand =
        ThemeData.estimateBrightnessForColor(brandColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final hsl = HSLColor.fromColor(brandColor);
    // A shallow gradient to the darker end of the same hue. Wide enough to
    // read as depth, narrow enough that the brand colour is still the brand.
    final gradientEnd = hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.06).clamp(0.0, 1.0))
        .toColor();

    final types = wallet.recipientTypes
        .map((type) => recipientTypeLabel(l10n, type))
        .join(' · ');

    return Semantics(
      button: true,
      label: wallet.nameFor(localeCode),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            // Tinted with the brand colour rather than plain black, so the card
            // sits in its own light instead of floating on a grey smudge.
            BoxShadow(
              color: brandColor.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          clipBehavior: Clip.antiAlias,
          color: brandColor,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [brandColor, gradientEnd],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 124),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.gapXl,
                  vertical: AppTheme.gapXl,
                ),
                child: Row(
                  children: [
                    WalletMark(wallet: wallet, onBrand: onBrand),
                    const SizedBox(width: AppTheme.gapLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            wallet.nameFor(localeCode),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: onBrand,
                            ),
                          ),
                          const SizedBox(height: AppTheme.gapXs),
                          Text(
                            types,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: onBrand.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Chosen per direction: the chevron must point the way the
                    // user reads, and Icons.chevron_* do not auto-flip.
                    Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      size: 32,
                      color: onBrand.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
