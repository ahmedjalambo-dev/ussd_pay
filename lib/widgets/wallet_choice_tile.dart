import 'package:flutter/material.dart';

import '../models/wallet.dart';
import 'choice_tile.dart';
import 'wallet_card.dart';

/// A selectable wallet, shown with its brand mark, for forms that ask which
/// wallet something belongs to.
///
/// A [ChoiceTile] accented in the wallet's own brand colour, so it matches the
/// recipient-type toggle beside it.
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
    final brand = Color(wallet.colorValue);

    return ChoiceTile(
      leading: WalletMark(wallet: wallet, onBrand: brand, size: 40),
      label: wallet.nameFor(localeCode),
      selected: selected,
      accent: brand,
      onTap: onTap,
    );
  }
}
