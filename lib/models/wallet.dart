/// Thrown when `assets/wallets.json` is malformed.
///
/// This is a fail-fast: a wallet with a broken template must never reach the
/// confirmation screen, because the user would be shown -- and would approve --
/// a code that does not do what it says.
class WalletConfigException implements Exception {
  const WalletConfigException(this.message);

  final String message;

  @override
  String toString() => 'WalletConfigException: $message';
}

/// A mobile wallet and its USSD templates, loaded from `assets/wallets.json`.
///
/// Nothing in `lib/` names a specific wallet; adding one is a JSON edit.
class Wallet {
  const Wallet({
    required this.id,
    required this.names,
    required this.colorValue,
    required this.templates,
    this.iconAsset,
  });

  /// Stable identifier, used as the foreign key in favorites and history.
  final String id;

  /// Locale code -> display name, e.g. `{'ar': 'جوال باي', 'en': 'JawwalPay'}`.
  final Map<String, String> names;

  /// ARGB value parsed from `colorHex`.
  final int colorValue;

  /// Optional asset path (e.g. `assets/images/JawwalPay.png`) for the wallet's
  /// brand mark. `null` means the UI should fall back to a generic icon.
  final String? iconAsset;

  /// Recipient type key -> USSD template, e.g. `'friend'` -> `'*268*1*{phone}*{amount}#'`.
  ///
  /// Insertion-ordered, so the UI toggle renders types in JSON order.
  final Map<String, String> templates;

  /// Recipient types this wallet supports, in the order declared in the JSON.
  List<String> get recipientTypes => templates.keys.toList(growable: false);

  /// Display name for [localeCode], falling back to English, then to any
  /// available name, then to [id]. Never throws -- a missing translation must
  /// not break the home screen.
  String nameFor(String localeCode) =>
      names[localeCode] ?? names['en'] ?? (names.isNotEmpty ? names.values.first : id);

  String? templateFor(String recipientType) => templates[recipientType];

  factory Wallet.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const WalletConfigException('Each wallet needs a non-empty string "id".');
    }

    final rawNames = json['name'];
    if (rawNames is! Map || rawNames.isEmpty) {
      throw WalletConfigException('Wallet "$id" needs a non-empty "name" object.');
    }
    final names = <String, String>{};
    rawNames.forEach((key, value) {
      if (key is String && value is String && value.isNotEmpty) {
        names[key] = value;
      }
    });
    if (names.isEmpty) {
      throw WalletConfigException('Wallet "$id" has no usable entries in "name".');
    }

    final rawTemplates = json['templates'];
    if (rawTemplates is! Map || rawTemplates.isEmpty) {
      throw WalletConfigException('Wallet "$id" needs a non-empty "templates" object.');
    }
    final templates = <String, String>{};
    rawTemplates.forEach((key, value) {
      if (key is! String || key.isEmpty) {
        throw WalletConfigException('Wallet "$id" has a non-string recipient type key.');
      }
      if (value is! String || value.isEmpty) {
        throw WalletConfigException('Wallet "$id" template "$key" must be a non-empty string.');
      }
      templates[key] = value;
    });

    final rawIcon = json['icon'];
    final iconAsset = rawIcon is String && rawIcon.isNotEmpty ? rawIcon : null;

    return Wallet(
      id: id,
      names: Map.unmodifiable(names),
      colorValue: _parseColorHex(json['colorHex'], id),
      iconAsset: iconAsset,
      templates: Map.unmodifiable(templates),
    );
  }

  /// Parses `#RRGGBB` or `#AARRGGBB`. Falls back to opaque grey rather than
  /// throwing: a bad colour is cosmetic, not a money bug.
  static int _parseColorHex(Object? raw, String walletId) {
    const fallback = 0xFF546E7A;
    if (raw is! String) return fallback;
    var hex = raw.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return fallback;
    return int.tryParse(hex, radix: 16) ?? fallback;
  }
}

/// The parsed contents of `assets/wallets.json`.
class WalletConfig {
  const WalletConfig({required this.schemaVersion, required this.wallets});

  final int schemaVersion;
  final List<Wallet> wallets;

  Wallet? byId(String id) {
    for (final wallet in wallets) {
      if (wallet.id == id) return wallet;
    }
    return null;
  }

  factory WalletConfig.fromJson(Map<String, dynamic> json) {
    final rawWallets = json['wallets'];
    if (rawWallets is! List || rawWallets.isEmpty) {
      throw const WalletConfigException('"wallets" must be a non-empty array.');
    }

    final wallets = <Wallet>[];
    final seenIds = <String>{};
    for (final entry in rawWallets) {
      if (entry is! Map<String, dynamic>) {
        throw const WalletConfigException('Every entry in "wallets" must be an object.');
      }
      final wallet = Wallet.fromJson(entry);
      if (!seenIds.add(wallet.id)) {
        throw WalletConfigException('Duplicate wallet id "${wallet.id}".');
      }
      wallets.add(wallet);
    }

    final version = json['schemaVersion'];
    return WalletConfig(
      schemaVersion: version is int ? version : 1,
      wallets: List.unmodifiable(wallets),
    );
  }
}
