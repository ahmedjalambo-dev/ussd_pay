// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'USSD Pay';

  @override
  String get chooseWallet => 'Choose a wallet';

  @override
  String get chooseWalletSubtitle => 'Pick the wallet you are paying from.';

  @override
  String get navHome => 'Pay';

  @override
  String get navFavorites => 'Favorites';

  @override
  String get navHistory => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get recipientTypeQuestion => 'Who are you paying?';

  @override
  String get recipientTypeFriend => 'A friend';

  @override
  String get recipientTypeMerchant => 'A merchant';

  @override
  String get phoneNumberLabel => 'Phone number';

  @override
  String get phoneNumberHint => '059 912 3456';

  @override
  String get phoneSupportedPrefixes => 'Jawwal 059 · Ooredoo 056';

  @override
  String get amountLabel => 'Amount';

  @override
  String get currencySymbol => '₪';

  @override
  String get pickFromContacts => 'Contacts';

  @override
  String get pickFromFavorites => 'Favorites';

  @override
  String get reviewPayment => 'Review payment';

  @override
  String get reviewPaymentHint =>
      'Nothing is sent yet — you will check the details first.';

  @override
  String get confirmTitle => 'Confirm payment';

  @override
  String get confirmSubtitle =>
      'Check every detail before you dial. This sends real money.';

  @override
  String get walletLabel => 'Wallet';

  @override
  String get recipientLabel => 'Recipient';

  @override
  String get codeLabel => 'Code to be dialed';

  @override
  String get callNow => 'Open dialer';

  @override
  String get cancel => 'Cancel';

  @override
  String get done => 'Done';

  @override
  String get back => 'Back';

  @override
  String get notesLabel => 'Notes (optional)';

  @override
  String get notesHint => 'e.g. Rent June';

  @override
  String get copyCode => 'Copy code';

  @override
  String get codeCopied => 'Code copied';

  @override
  String get pinNotice =>
      'You will enter your wallet PIN in your carrier\'s own screen after dialing. USSD Pay never asks for it and never stores it.';

  @override
  String get warnUnknownPrefix =>
      'This is not a Jawwal (059) or Ooredoo (056) number. Check it before you continue — you can still pay.';

  @override
  String get errorPhoneEmpty => 'Enter a phone number';

  @override
  String get errorPhoneNonNumeric => 'This does not contain a phone number';

  @override
  String get errorPhoneTooShort =>
      'Too short — a number has 9 digits, starting 059 or 056';

  @override
  String get errorPhoneTooLong =>
      'Too long — a number has 9 digits, starting 059 or 056';

  @override
  String get errorAmountRequired => 'Enter an amount';

  @override
  String get carrierJawwal => 'Jawwal';

  @override
  String get carrierOoredoo => 'Ooredoo';

  @override
  String get dialerUnavailable =>
      'This device cannot dial USSD codes. The code has been copied — paste it into your phone\'s dialer.';

  @override
  String get dialerOpened => 'Press call in your dialer to send the payment';

  @override
  String get emptyFavoritesTitle => 'No saved recipients';

  @override
  String get emptyFavoritesBody =>
      'Save someone you pay often and their number will be one tap away.';

  @override
  String get emptyHistoryTitle => 'No payments yet';

  @override
  String get emptyHistoryBody =>
      'Payments you dial will be listed here so you can repeat them.';

  @override
  String get saveAsFavorite => 'Save as favorite';

  @override
  String get savedAsFavorite => 'Saved';

  @override
  String get favoriteNameLabel => 'Name';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get deleteFavoriteTitle => 'Delete this recipient?';

  @override
  String deleteFavoriteMessage(String name) {
    return '$name will be removed from your favorites.';
  }

  @override
  String get repeatPayment => 'Repeat';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryMessage =>
      'All recorded payments will be deleted from this device.';

  @override
  String get clear => 'Clear';

  @override
  String get language => 'Language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'Follow system';

  @override
  String get about => 'About';

  @override
  String get aboutOffline =>
      'USSD Pay works entirely offline. It makes no network connections and collects nothing.';

  @override
  String get aboutNoPin =>
      'It never asks for, stores, or dials your wallet PIN.';

  @override
  String get contactsPermissionDenied =>
      'Permission to read contacts was not granted. You can still type the number.';

  @override
  String get contactHasNoNumber => 'That contact has no phone number.';

  @override
  String get loadFailedTitle => 'Wallet settings could not be read';

  @override
  String get loadFailedBody =>
      'assets/wallets.json is missing or invalid, so no payment can be built safely.';

  @override
  String get retry => 'Retry';
}
