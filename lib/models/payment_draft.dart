import 'wallet.dart';

/// The in-progress payment, from the moment a wallet is tapped until the code
/// is handed to the dialer.
///
/// Held only in memory. It carries no PIN and never will: the PIN belongs to
/// the carrier's own USSD prompt, after dialing.
class PaymentDraft {
  const PaymentDraft({
    this.wallet,
    this.recipientType,
    this.rawPhoneInput = '',
    this.amountInput = '',
    this.recipientName,
    this.note = '',
  });

  final Wallet? wallet;

  /// Recipient type key, matching a key in the wallet's `templates`.
  final String? recipientType;

  /// Exactly what the user typed, before normalization. Kept verbatim so the
  /// field does not fight the user while they are still typing.
  final String rawPhoneInput;

  /// Digits as typed, without any thousands separator.
  final String amountInput;

  /// Set when the number came from a favorite or a contact.
  final String? recipientName;

  /// Optional free-text label the user attached to this payment, so history
  /// rows are recognisable at a glance. Never enters the dialed code.
  final String note;

  num? get amount {
    final parsed = num.tryParse(amountInput);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  PaymentDraft copyWith({
    Wallet? wallet,
    String? recipientType,
    String? rawPhoneInput,
    String? amountInput,
    String? recipientName,
    String? note,
    bool clearRecipientName = false,
  }) =>
      PaymentDraft(
        wallet: wallet ?? this.wallet,
        recipientType: recipientType ?? this.recipientType,
        rawPhoneInput: rawPhoneInput ?? this.rawPhoneInput,
        amountInput: amountInput ?? this.amountInput,
        recipientName:
            clearRecipientName ? null : (recipientName ?? this.recipientName),
        note: note ?? this.note,
      );
}
