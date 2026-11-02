import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/services/wallet_logo_loader.dart';

/// The shipped wallet logos are ~4400 px; posted as-is they would ride the
/// foreground-service intent and risk the Binder limit. They must come out
/// small, and a wallet without a logo must not stop a notification.
void main() {
  const shipped = Wallet(
    id: 'jawwalpay',
    names: {'en': 'JawwalPay'},
    colorValue: 0xFF6CA61C,
    templates: {'friend': '*268*1*{phone}*{amount}#'},
    iconAsset: 'assets/images/JawwalPay.png',
  );

  testWidgets('a shipped logo comes back as a small PNG, cached', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = WalletLogoLoader();
      final png = await loader.notificationLogo(shipped);
      expect(png, isNotNull);

      final codec = await ui.instantiateImageCodec(png!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, WalletLogoLoader.size);
      expect(frame.image.height, WalletLogoLoader.size);
      expect(png.lengthInBytes, lessThan(100 * 1024));

      expect(identical(await loader.notificationLogo(shipped), png), isTrue);
    });
  });

  testWidgets('no icon, or an asset that is missing: null, never a throw', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final loader = WalletLogoLoader();
      const noIcon = Wallet(
        id: 'plain',
        names: {'en': 'Plain'},
        colorValue: 0xFF000000,
        templates: {'friend': '*1*{phone}*{amount}#'},
      );
      expect(await loader.notificationLogo(noIcon), isNull);

      const missing = Wallet(
        id: 'missing',
        names: {'en': 'Missing'},
        colorValue: 0xFF000000,
        templates: {'friend': '*1*{phone}*{amount}#'},
        iconAsset: 'assets/images/does_not_exist.png',
      );
      expect(await loader.notificationLogo(missing), isNull);
    });
  });
}
