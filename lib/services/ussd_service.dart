/// Builds the USSD string that will actually be dialed.
///
/// Pure Dart, no Flutter imports. Every guard in here exists because the
/// failure mode is "money goes to the wrong place", not "screen looks wrong".
library;

import '../models/wallet.dart';

/// Thrown when a USSD string cannot be built safely.
///
/// Always surfaced to the user; never swallowed. Refusing to dial is always
/// better than dialing something we cannot vouch for.
class UssdBuildException implements Exception {
  const UssdBuildException(this.message);

  final String message;

  @override
  String toString() => 'UssdBuildException: $message';
}

abstract final class UssdService {
  /// Matches `{phone}`, `{amount}`, and any other placeholder a future
  /// `wallets.json` might introduce.
  static final RegExp _placeholder = RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}');

  /// Digits, optionally with a single decimal point.
  ///
  /// This is the injection guard. `*` and `#` are USSD *control* characters: an
  /// amount of `50*2*0599999999` would silently restructure the command into a
  /// different transaction against a different recipient. Values are data and
  /// must never contain control characters.
  static final RegExp _safeValue = RegExp(r'^[0-9]+(\.[0-9]+)?$');

  /// The placeholder names appearing in [template].
  static Set<String> placeholdersIn(String template) =>
      _placeholder.allMatches(template).map((m) => m.group(1)!).toSet();

  /// Substitutes [values] into [template] and returns the dialable string.
  ///
  /// Throws [UssdBuildException] if a value is unsafe, a placeholder has no
  /// value, or any placeholder survives substitution.
  static String build({
    required String template,
    required Map<String, String> values,
  }) {
    if (template.isEmpty) {
      throw const UssdBuildException('The USSD template is empty.');
    }

    for (final entry in values.entries) {
      final value = entry.value;
      if (value.isEmpty) {
        throw UssdBuildException('No value given for "{${entry.key}}".');
      }
      if (!_safeValue.hasMatch(value)) {
        throw UssdBuildException(
          'The value for "{${entry.key}}" is "$value". Only digits and a single '
          'decimal point are allowed -- characters such as "*" or "#" would '
          'change which transaction gets dialed.',
        );
      }
    }

    final required = placeholdersIn(template);
    for (final name in required) {
      if (!values.containsKey(name)) {
        throw UssdBuildException(
          'The template needs "{$name}", but no value was supplied.',
        );
      }
    }

    var result = template;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }

    // Belt and braces: if substitution somehow left a placeholder behind, we
    // would dial a literal "{phone}" at the carrier. Refuse instead.
    if (_placeholder.hasMatch(result)) {
      throw UssdBuildException(
        'The built code still contains an unsubstituted placeholder: "$result".',
      );
    }

    return result;
  }

  /// Builds the code for a wallet and recipient type.
  ///
  /// [localPhone] must already be normalized to the local `0XXXXXXXXX` form by
  /// `PhoneNormalizer.normalize`.
  ///
  /// There is deliberately no `pin` parameter here or anywhere else. The wallet
  /// PIN is entered in the carrier's own USSD prompt after dialing; putting it
  /// in the dialed string would leak it into the call log and into history.
  static String buildForWallet({
    required Wallet wallet,
    required String recipientType,
    required String localPhone,
    required num amount,
  }) {
    final template = wallet.templateFor(recipientType);
    if (template == null) {
      throw UssdBuildException(
        'Wallet "${wallet.id}" has no template for recipient type '
        '"$recipientType".',
      );
    }
    return build(
      template: template,
      values: {'phone': localPhone, 'amount': formatAmount(amount)},
    );
  }

  /// Renders [amount] the way the carrier expects it.
  ///
  /// Whole amounts lose their decimals (`50`, not `50.00`); fractional amounts
  /// get exactly two. Any thousands separator shown in the UI is presentation
  /// only and never reaches this function.
  static String formatAmount(num amount) {
    if (amount is double && (amount.isNaN || amount.isInfinite)) {
      throw const UssdBuildException('The amount is not a number.');
    }
    if (amount <= 0) {
      throw UssdBuildException(
        'The amount must be greater than zero (got $amount).',
      );
    }
    final rounded = double.parse(amount.toStringAsFixed(2));
    if (rounded == rounded.roundToDouble()) {
      return rounded.toInt().toString();
    }
    return rounded.toStringAsFixed(2);
  }
}
