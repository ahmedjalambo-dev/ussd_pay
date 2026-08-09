/// Palestinian mobile number normalization.
///
/// Pure Dart, no Flutter imports, so it is directly unit-testable. Every input
/// form a user might paste, type, or pull from a contact must collapse to the
/// single local form the USSD templates expect: `0599123456`.
library;

/// Mobile operator inferred from the number's prefix.
enum Carrier {
  /// `059x` — Jawwal.
  jawwal,

  /// `056x` — Ooredoo (formerly Wataniya).
  ooredoo,

  /// Recognisable digits, but not a prefix we know. Warned about, never blocked.
  unknown,
}

/// Why a number failed validation. Drives a non-blocking warning in the UI.
enum PhoneIssue {
  /// Nothing typed yet.
  empty,

  /// Input contained no digits at all.
  nonNumeric,

  /// Fewer than 9 significant digits.
  tooShort,

  /// More than 9 significant digits.
  tooLong,

  /// Right length, but not `59` or `56`.
  unknownPrefix,
}

/// The result of normalizing one raw input string.
class NormalizedPhone {
  const NormalizedPhone({
    required this.local,
    required this.national,
    required this.carrier,
    required this.issue,
  });

  /// The form that goes into the USSD template: `0599123456`.
  ///
  /// When the input could not be resolved to 9 significant digits this holds
  /// the best-effort digit string instead, so the user can still see -- and
  /// deliberately dial -- what they typed.
  final String local;

  /// The 9-digit national significant number (`599123456`), or `''`.
  final String national;

  final Carrier carrier;

  /// `null` when the number is well-formed.
  final PhoneIssue? issue;

  /// True only for 9 significant digits behind a known Palestinian prefix.
  ///
  /// A false value warns; it never blocks the payment. Carriers add prefixes
  /// faster than apps get updated, and refusing to dial a number the user knows
  /// is correct would be worse than a warning.
  bool get isValid => issue == null;

  bool get isEmpty => local.isEmpty;

  @override
  String toString() =>
      'NormalizedPhone(local: $local, carrier: $carrier, issue: $issue)';

  @override
  bool operator ==(Object other) =>
      other is NormalizedPhone &&
      other.local == local &&
      other.national == national &&
      other.carrier == carrier &&
      other.issue == issue;

  @override
  int get hashCode => Object.hash(local, national, carrier, issue);
}

abstract final class PhoneNormalizer {
  /// Number of significant digits in a Palestinian mobile number, excluding the
  /// trunk `0` and any country code.
  static const int nationalLength = 9;

  static const String _jawwalPrefix = '59';
  static const String _ooredooPrefix = '56';

  static const int _asciiZero = 0x30;
  static const int _asciiNine = 0x39;
  static const int _arabicIndicZero = 0x0660;
  static const int _arabicIndicNine = 0x0669;
  static const int _extendedArabicIndicZero = 0x06F0;
  static const int _extendedArabicIndicNine = 0x06F9;
  static const int _plus = 0x2B;

  /// Converts Arabic-Indic (٠١٢٣٤٥٦٧٨٩) and Extended Arabic-Indic (۰۱۲۳۴۵۶۷۸۹)
  /// digits to ASCII, leaving everything else untouched.
  static String foldDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= _arabicIndicZero && rune <= _arabicIndicNine) {
        buffer.writeCharCode(_asciiZero + rune - _arabicIndicZero);
      } else if (rune >= _extendedArabicIndicZero && rune <= _extendedArabicIndicNine) {
        buffer.writeCharCode(_asciiZero + rune - _extendedArabicIndicZero);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Collapses any accepted input form to the local `0XXXXXXXXX` format.
  ///
  /// Accepts `+970`, `00970`, `970`, `+972`, `00972`, `972`, a leading `0`, or a
  /// bare 9-digit number, in any mix of ASCII and Arabic-Indic digits, with
  /// spaces, dashes, and RTL marks anywhere.
  static NormalizedPhone normalize(String raw) {
    final folded = foldDigits(raw);

    var hasLeadingPlus = false;
    final digitBuffer = StringBuffer();
    for (final rune in folded.runes) {
      if (rune >= _asciiZero && rune <= _asciiNine) {
        digitBuffer.writeCharCode(rune);
      } else if (rune == _plus && digitBuffer.isEmpty) {
        hasLeadingPlus = true;
      }
      // Everything else is dropped: spaces, NBSP, dashes, brackets, dots, and
      // the bidi marks (LRM/RLM/ALM, embeddings, isolates) that ride along on
      // numbers copied out of RTL text. The length check below catches the
      // cases where dropping a character actually mattered.
    }

    var digits = digitBuffer.toString();

    if (digits.isEmpty) {
      return NormalizedPhone(
        local: '',
        national: '',
        carrier: Carrier.unknown,
        issue: folded.trim().isEmpty ? PhoneIssue.empty : PhoneIssue.nonNumeric,
      );
    }

    digits = _stripCountryCode(digits, hasLeadingPlus: hasLeadingPlus);

    // Trunk prefix, e.g. what is left of `+970 0599123456` or a plain
    // `0599123456`.
    if (digits.length == nationalLength + 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != nationalLength) {
      return NormalizedPhone(
        local: digits,
        national: '',
        carrier: Carrier.unknown,
        issue: digits.length < nationalLength ? PhoneIssue.tooShort : PhoneIssue.tooLong,
      );
    }

    final carrier = carrierFor(digits);
    return NormalizedPhone(
      local: '0$digits',
      national: digits,
      carrier: carrier,
      issue: carrier == Carrier.unknown ? PhoneIssue.unknownPrefix : null,
    );
  }

  /// Removes a Palestinian (`970`) or Israeli (`972`) country code.
  ///
  /// A bare `970`/`972` with no `+` or `00` is only stripped when the total
  /// length makes it unambiguous. Stripping it from a shorter string would
  /// silently corrupt a number the user typed correctly.
  static String _stripCountryCode(String digits, {required bool hasLeadingPlus}) {
    const codes = ['970', '972'];

    for (final code in codes) {
      if (digits.startsWith('00$code')) return digits.substring(2 + code.length);
    }
    for (final code in codes) {
      if (!digits.startsWith(code)) continue;
      // `+970599123456` (12) or `+9700599123456` (13, redundant trunk zero).
      final unambiguous = hasLeadingPlus ||
          digits.length == code.length + nationalLength ||
          digits.length == code.length + nationalLength + 1;
      if (unambiguous) return digits.substring(code.length);
    }
    return digits;
  }

  /// Maps a 9-digit national number to its operator.
  static Carrier carrierFor(String national) {
    if (national.startsWith(_jawwalPrefix)) return Carrier.jawwal;
    if (national.startsWith(_ooredooPrefix)) return Carrier.ooredoo;
    return Carrier.unknown;
  }
}
