import 'package:flutter/widgets.dart' show TextDirection;
// intl exports its own TextDirection class; the framework's enum is the one
// widgets take.
import 'package:intl/intl.dart' hide TextDirection;

import '../l10n/generated/app_localizations.dart';
import '../models/recipient_type.dart';
import '../services/phone_normalizer.dart';

/// Amounts are always shown in ASCII digits, in Arabic as well as English.
///
/// The USSD code itself is necessarily ASCII, and showing `٥٠` in the amount
/// field beside `*268*1*0599123456*50#` on the confirmation screen invites the
/// user to wonder whether they match. One digit set everywhere removes the
/// question.
final NumberFormat _amountFormat = NumberFormat.decimalPattern('en');

/// `1234.5` -> `1,234.50`; `50` -> `50`.
///
/// Presentation only. The separator never reaches `UssdService`.
String formatAmountDisplay(num amount) {
  if (amount == amount.roundToDouble()) {
    return _amountFormat.format(amount.toInt());
  }
  return NumberFormat('#,##0.00', 'en').format(amount);
}

/// `0599123456` -> `059 912 3456`, for readability. Falls back to the input
/// unchanged if it is not the expected length.
String formatPhoneDisplay(String local) {
  if (local.length != 10) return local;
  return '${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
}

/// The direction a piece of *user-supplied* text should render in.
///
/// Names are free text, and the bidi algorithm reorders a run of digits or
/// Latin letters to suit the surrounding paragraph: a favorite saved as
/// "056 845 0493" renders "0493 845 056" inside an Arabic layout. Detecting
/// per string keeps each name internally correct while the layout around it
/// stays in the app's language.
///
/// For text the app itself builds -- USSD codes, amounts -- do not use this;
/// those are unconditionally LTR.
TextDirection directionOf(String text) =>
    Bidi.detectRtlDirectionality(text) ? TextDirection.rtl : TextDirection.ltr;

/// Wraps [text] in a Unicode left-to-right isolate (LRI ... PDI).
///
/// For a phone number that shares one `Text` with Arabic labels, where a
/// `Directionality` wrapper cannot reach it: without the isolate, the
/// space-separated digit groups of `059 912 3456` are laid out right to left
/// as `3456 912 059` -- a different number from the one being paid.
String ltrIsolate(String text) =>
    '${String.fromCharCode(0x2066)}$text${String.fromCharCode(0x2069)}';

String recipientTypeLabel(AppLocalizations l10n, String typeKey) =>
    switch (typeKey) {
      RecipientTypes.friend => l10n.recipientTypeFriend,
      RecipientTypes.merchant => l10n.recipientTypeMerchant,
      // A type added to wallets.json that the app has no translation for still
      // renders, using its raw key.
      _ => typeKey,
    };

String? carrierLabel(AppLocalizations l10n, Carrier carrier) =>
    switch (carrier) {
      Carrier.jawwal => l10n.carrierJawwal,
      Carrier.ooredoo => l10n.carrierOoredoo,
      Carrier.unknown => null,
    };

/// The message shown under the phone field. `null` when the number is fine.
String? phoneIssueMessage(AppLocalizations l10n, PhoneIssue? issue) =>
    switch (issue) {
      null => null,
      PhoneIssue.empty => l10n.errorPhoneEmpty,
      PhoneIssue.nonNumeric => l10n.errorPhoneNonNumeric,
      PhoneIssue.tooShort => l10n.errorPhoneTooShort,
      PhoneIssue.tooLong => l10n.errorPhoneTooLong,
      // Not an error: a valid-looking number on a prefix we do not recognise.
      // Worded as a warning because we still let the payment through.
      PhoneIssue.unknownPrefix => l10n.warnUnknownPrefix,
    };

/// True when the issue should warn (amber) rather than block-looking (red).
bool isWarningOnly(PhoneIssue? issue) => issue == PhoneIssue.unknownPrefix;

String formatHistoryTimestamp(DateTime utc, String localeCode) {
  final local = utc.toLocal();
  return DateFormat.yMMMd(localeCode).add_jm().format(local);
}
