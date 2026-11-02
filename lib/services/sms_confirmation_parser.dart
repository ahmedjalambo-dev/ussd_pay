/// Reads a wallet's "money sent" SMS and decides whether it confirms the
/// payment the user just dialed.
///
/// Pure Dart, no Flutter imports, so it is directly unit-testable. The only
/// thing a match can ever do is move a history row to Done: it never dials,
/// never builds a code, and nothing from the SMS (text, balance) is kept.
library;

import '../models/wallet.dart';
import 'phone_normalizer.dart';

/// What a sent-SMS says happened, reduced to the two facts a match checks.
class SmsParseResult {
  const SmsParseResult({required this.amountCents, this.recipientNumber});

  /// Integer cents, so `5`, `5.0` and `5.00` compare equal without floats.
  final int amountCents;

  /// Normalized local form (`0597501462`) when the SMS named the recipient by
  /// number; `null` when it named them some other way (a contact or account
  /// name), in which case only the wallet and amount can be checked.
  final String? recipientNumber;

  @override
  String toString() =>
      'SmsParseResult(amountCents: $amountCents, recipient: $recipientNumber)';
}

/// The payment waiting for its SMS.
class PendingConfirmation {
  const PendingConfirmation({
    required this.historyEntryId,
    required this.walletId,
    required this.amountCents,
    required this.recipientNumber,
    required this.startedAtUtc,
  });

  final String historyEntryId;
  final String walletId;
  final int amountCents;

  /// Normalized local form, as stored on the history row.
  final String recipientNumber;

  final DateTime startedAtUtc;
}

abstract final class SmsConfirmationParser {
  /// How long after dialing an SMS may still confirm the payment. Long enough
  /// for a slow SMS, short enough that an unrelated transfer of the same
  /// amount later in the day cannot be mistaken for this one.
  static const Duration window = Duration(minutes: 5);

  /// A party with at least this many digits is a phone number; anything else
  /// is a name and is not compared.
  static const int _minPhoneDigits = 9;

  /// Bidi marks and isolates that ride along in RTL SMS text and would break
  /// a literal-space pattern.
  static final RegExp _bidiMarks = RegExp(
    r'[\u200E\u200F\u061C\u202A-\u202E\u2066-\u2069]',
  );
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Parses [text] against [config]'s sent patterns. `null` means "not a
  /// sent-money SMS we understand" -- including every receive message.
  static SmsParseResult? parse(SmsConfirmationConfig config, String text) {
    final cleaned = PhoneNormalizer.foldDigits(text)
        .replaceAll(_bidiMarks, '')
        .replaceAll(_whitespace, ' ')
        .trim();

    for (final pattern in config.sentPatterns) {
      final match = pattern.firstMatch(cleaned);
      if (match == null) continue;
      final cents = toCents(match.namedGroup('amount') ?? '');
      if (cents == null) continue;
      return SmsParseResult(
        amountCents: cents,
        recipientNumber: _recipientNumber(match.namedGroup('party') ?? ''),
      );
    }
    return null;
  }

  /// Does [sms], received at [receivedAtUtc], confirm [pending]?
  ///
  /// The amount must match exactly and the SMS must arrive inside [window].
  /// The number is only compared when the SMS carried one -- but when it did
  /// and it differs, that is a different transfer, so there is no match.
  static bool matches(
    PendingConfirmation pending,
    SmsParseResult sms,
    DateTime receivedAtUtc,
  ) {
    if (sms.amountCents != pending.amountCents) return false;
    final elapsed = receivedAtUtc.difference(pending.startedAtUtc);
    if (elapsed.isNegative || elapsed > window) return false;
    final number = sms.recipientNumber;
    return number == null || number == pending.recipientNumber;
  }

  /// `5`, `5.0`, `5.00` and `1,000.00` to integer cents. More than two
  /// decimals is only accepted when the extra digits are zero; anything else
  /// is not an amount we can compare safely, so it is `null`.
  static int? toCents(String raw) {
    final value = raw.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    var fraction = parts.length > 1 ? parts[1] : '';
    if (fraction.length > 2) {
      if (fraction.substring(2).replaceAll('0', '').isNotEmpty) return null;
      fraction = fraction.substring(0, 2);
    }
    return whole * 100 + int.parse(fraction.padRight(2, '0'));
  }

  /// Cents for an amount the app dialed. `UssdService` only lets through
  /// digits with at most one decimal point, so rounding is exact in practice.
  static int amountToCents(num amount) => (amount * 100).round();

  static String? _recipientNumber(String party) {
    final digits = party.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _minPhoneDigits) return null;
    final normalized = PhoneNormalizer.normalize(party);
    // A digit string that does not normalize to a 10-digit local number is
    // still a number -- just not one we can vouch for. Keep the raw digits so
    // it fails the comparison instead of being waved through as a "name".
    return normalized.national.isEmpty ? digits : normalized.local;
  }
}
