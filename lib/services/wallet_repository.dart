import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/wallet.dart';

/// Loads the wallet/USSD configuration from `assets/wallets.json`.
///
/// The asset is the single source of truth for carrier codes. Nothing in `lib/`
/// hardcodes a wallet, so updating a code that a carrier changed is a JSON edit
/// and a rebuild -- no logic changes, no risk of touching the money path.
class WalletRepository {
  WalletRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const String assetPath = 'assets/wallets.json';

  final AssetBundle _bundle;
  WalletConfig? _cached;

  /// Parses raw JSON text. Exposed so tests can run against the real asset file
  /// without a Flutter binding.
  static WalletConfig parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw WalletConfigException('$assetPath is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const WalletConfigException(
        '$assetPath must contain a JSON object.',
      );
    }
    return WalletConfig.fromJson(decoded);
  }

  /// Loads and caches the configuration. Read once at startup.
  Future<WalletConfig> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final source = await _bundle.loadString(assetPath);
    return _cached = parse(source);
  }
}
