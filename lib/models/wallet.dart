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

/// How to recognise this wallet's "money sent" SMS, so a payment can be
/// confirmed from the carrier's own message instead of the user's say-so.
///
/// Data, not code, for the same reason as the templates: carriers reword
/// their SMS, and fixing a pattern must be a JSON edit.
class SmsConfirmationConfig {
  const SmsConfirmationConfig({
    required this.senders,
    required this.sentPatterns,
  });

  /// Notification titles the SMS arrives under, e.g. `Jawwal Pay`. Compared
  /// with [normalizeSender] on both sides, so case and spacing do not matter.
  final List<String> senders;

  /// Each has an `amount` and a `party` named group. They describe SENT
  /// messages only: a receive SMS must never match, or incoming money would
  /// confirm an outgoing payment.
  final List<RegExp> sentPatterns;

  bool isSender(String title) {
    final normalized = normalizeSender(title);
    return senders.any((s) => normalizeSender(s) == normalized);
  }

  /// Lowercase with all whitespace removed. The native listener applies the
  /// same folding before it forwards anything.
  static String normalizeSender(String raw) =>
      raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  factory SmsConfirmationConfig.fromJson(Object? json, String walletId) {
    if (json is! Map) {
      throw WalletConfigException(
        'Wallet "$walletId" "smsConfirmation" must be an object.',
      );
    }
    final rawSenders = json['senders'];
    final senders = rawSenders is List
        ? rawSenders.whereType<String>().where((s) => s.trim().isNotEmpty)
        : const <String>[];
    if (senders.isEmpty) {
      throw WalletConfigException(
        'Wallet "$walletId" "smsConfirmation.senders" must list at least one '
        'sender name.',
      );
    }

    final rawPatterns = json['sentPatterns'];
    if (rawPatterns is! List || rawPatterns.isEmpty) {
      throw WalletConfigException(
        'Wallet "$walletId" "smsConfirmation.sentPatterns" must be a '
        'non-empty array.',
      );
    }
    final patterns = <RegExp>[];
    for (final raw in rawPatterns) {
      if (raw is! String || raw.isEmpty) {
        throw WalletConfigException(
          'Wallet "$walletId" has an empty SMS pattern.',
        );
      }
      final RegExp pattern;
      try {
        pattern = RegExp(raw, unicode: true);
      } on FormatException catch (e) {
        throw WalletConfigException(
          'Wallet "$walletId" SMS pattern "$raw" does not compile: '
          '${e.message}',
        );
      }
      // Without both groups a pattern could "match" while telling us nothing
      // about the amount -- which is the one thing the match must check.
      for (final group in const ['amount', 'party']) {
        if (!raw.contains('(?<$group>')) {
          throw WalletConfigException(
            'Wallet "$walletId" SMS pattern "$raw" needs a (?<$group>...) '
            'group.',
          );
        }
      }
      patterns.add(pattern);
    }

    return SmsConfirmationConfig(
      senders: List.unmodifiable(senders),
      sentPatterns: List.unmodifiable(patterns),
    );
  }
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
    this.smsConfirmation,
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

  /// `null` when the wallet ships no SMS patterns; the "Confirm by SMS"
  /// setting is then hidden and payments are confirmed by hand.
  final SmsConfirmationConfig? smsConfirmation;

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

    final rawSms = json['smsConfirmation'];

    return Wallet(
      id: id,
      names: Map.unmodifiable(names),
      colorValue: _parseColorHex(json['colorHex'], id),
      iconAsset: iconAsset,
      templates: Map.unmodifiable(templates),
      smsConfirmation: rawSms == null
          ? null
          : SmsConfirmationConfig.fromJson(rawSms, id),
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
