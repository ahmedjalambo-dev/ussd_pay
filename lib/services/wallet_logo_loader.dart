import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/wallet.dart';

/// The wallet's brand logo, sized for a notification's large icon.
///
/// Downscaled, not passed through: the shipped PNGs are ~4400 px. A bitmap
/// that size rides inside the foreground-service intent for the SMS wait,
/// where it risks Android's ~1 MB Binder limit -- for a thumbnail drawn at
/// about 48dp. [size] covers xxxhdpi.
///
/// Cached per wallet: the decode is the slow part, and the same logo is
/// posted several times per payment (quiet, banner, fallback, confirmed).
///
/// Never throws. A wallet without an `icon`, or an asset that fails to
/// decode, gives `null` and the notification is simply posted without a
/// large icon -- a missing logo must never hold up the payment prompt.
class WalletLogoLoader {
  WalletLogoLoader({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const int size = 192;

  final AssetBundle _bundle;
  final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?> notificationLogo(Wallet wallet) {
    final asset = wallet.iconAsset;
    if (asset == null) return Future.value();
    return _cache.putIfAbsent(wallet.id, () => _load(asset));
  }

  Future<Uint8List?> _load(String asset) async {
    try {
      final data = await _bundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: size,
        targetHeight: size,
      );
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return png?.buffer.asUint8List();
    } on Object catch (e) {
      debugPrint('Wallet logo $asset could not be prepared: $e');
      return null;
    }
  }
}
