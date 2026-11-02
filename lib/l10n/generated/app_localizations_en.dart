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
  String get notifPaymentDecisionTitle => 'Did the payment go through?';

  @override
  String notifPaymentDecisionBody(
    String wallet,
    String amount,
    String currency,
  ) {
    return '$wallet: $amount $currency';
  }

  @override
  String get notifActionDone => 'Yes, done';

  @override
  String get notifActionCancel => 'No, cancel';

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
  String get edit => 'Edit';

  @override
  String get recipientTypeSection => 'Recipient type';

  @override
  String get addFavorite => 'Add favorite';

  @override
  String get editFavorite => 'Edit favorite';

  @override
  String get favoriteUpdated => 'Favorite updated';

  @override
  String favoriteAlreadyExists(String name) {
    return 'This number is already saved as $name';
  }

  @override
  String favoritesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients deleted',
      one: '1 recipient deleted',
    );
    return '$_temp0';
  }

  @override
  String get repeatPayment => 'Repeat';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryMessage =>
      'All recorded payments, done and cancelled, will be deleted from this device.';

  @override
  String get clear => 'Clear';

  @override
  String historyTabDone(int count) {
    return 'Done ($count)';
  }

  @override
  String historyTabCancelled(int count) {
    return 'Cancelled ($count)';
  }

  @override
  String get emptyDoneTitle => 'No completed payments';

  @override
  String get emptyDoneBody =>
      'Payments you confirm as done will be listed here.';

  @override
  String get emptyCancelledTitle => 'No cancelled payments';

  @override
  String get emptyCancelledBody =>
      'Payments you cancel or leave unanswered will be listed here.';

  @override
  String historyEntriesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments deleted',
      one: '1 payment deleted',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String get paymentDetails => 'Payment details';

  @override
  String get data => 'Data';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get undo => 'Undo';

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

  @override
  String get confirmationSection => 'Payment confirmation';

  @override
  String get confirmBySms => 'Confirm by SMS';

  @override
  String confirmBySmsSubtitle(String wallet) {
    return 'Mark the payment done when the $wallet SMS arrives';
  }

  @override
  String get confirmManually => 'Ask me (Done / Cancel)';

  @override
  String get confirmManuallySubtitle => 'Ask after you open the dialer';

  @override
  String get confirmManuallyFallbackSubtitle =>
      'Ask if no SMS arrives within 3 minutes';

  @override
  String get smsAccessTitle => 'Allow notification access';

  @override
  String smsAccessBody(String wallet) {
    return 'To confirm payments by SMS, USSD Pay needs notification access. It only looks at messages from $wallet, only for 5 minutes after you pay, and never saves or sends them anywhere.\n\nOn the next screen, turn on USSD Pay.';
  }

  @override
  String get smsAccessOpenSettings => 'Open settings';

  @override
  String get smsAccessMissing =>
      'Notification access is off, so payments are confirmed by asking you.';

  @override
  String get smsAccessGrant => 'Allow';

  @override
  String get notifWaitingSmsTitle => 'Waiting for the confirmation SMS…';

  @override
  String get notifConfirmedSmsTitle => 'Payment confirmed by SMS';

  @override
  String get confirmedBySms => 'Confirmed by SMS';

  @override
  String get batteryRestricted =>
      'Allow USSD Pay to run in the background (Battery: No restrictions), so SMS confirmation works while you are in the dialer.';

  @override
  String get batteryOpen => 'Open';

  @override
  String get prevAttemptSameTitle => 'You already started this payment';

  @override
  String prevAttemptSameBody(String time) {
    return 'You opened the dialer for it at $time. If it went through, dialing again will pay twice.';
  }

  @override
  String get prevAttemptOtherTitle => 'Did your previous payment go through?';

  @override
  String prevAttemptOtherBody(String time) {
    return 'Started at $time. Answer before the new payment replaces its question.';
  }

  @override
  String get prevAttemptWentThrough => 'Yes, it went through';

  @override
  String get prevAttemptTryAgain => 'No, try again';

  @override
  String get prevAttemptNo => 'No, it failed';

  @override
  String get cancelPaymentTitle => 'Cancel this payment?';

  @override
  String get cancelPaymentBody =>
      'It will be recorded as cancelled (not sent). Only do this if the payment failed or you stopped it.';

  @override
  String get cancelPaymentStay => 'Keep it';

  @override
  String get cancelPaymentConfirm => 'Yes, cancel';

  @override
  String tourStepCounter(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get tourNext => 'Next';

  @override
  String get tourBack => 'Back';

  @override
  String get tourSkip => 'Skip tour';

  @override
  String get tourFinish => 'Finish';

  @override
  String get tourTapToContinue => 'Tap the highlighted item to continue';

  @override
  String get tourWalletTitle => 'Start with a wallet';

  @override
  String get tourWalletBody =>
      'Each card is a mobile wallet. Tap this one to see how a payment is filled in. Nothing is sent during the tour.';

  @override
  String get tourPhoneTitle => 'Who you are paying';

  @override
  String get tourPhoneBody =>
      'Type the number in any form, or pick it from your contacts or favorites. The number that will be used appears underneath.';

  @override
  String get tourAmountTitle => 'How much';

  @override
  String get tourAmountBody =>
      'Type the amount, or tap a quick amount below the field.';

  @override
  String get tourReviewTitle => 'Review before anything is sent';

  @override
  String get tourReviewBody =>
      'Review shows you the exact USSD code. Nothing is dialed until you check it and open the dialer yourself.';

  @override
  String get tourBackTitle => 'Back to your wallets';

  @override
  String get tourBackBody =>
      'Tap back to leave this form. Your payment is never sent from here.';

  @override
  String get tourPinTitle => 'Your PIN stays yours';

  @override
  String get tourPinBody =>
      'You type your wallet PIN on your carrier\'s own screen. USSD Pay never asks for it, so anything that does is not us.';

  @override
  String get tourFavoritesTitle => 'Favorites';

  @override
  String get tourFavoritesBody =>
      'Save people you pay often, then pay them with the number already filled in. Tap Favorites.';

  @override
  String get tourHistoryTitle => 'History';

  @override
  String get tourHistoryBody =>
      'Every payment you hand to the dialer is listed here as done or cancelled, ready to repeat. Tap History.';

  @override
  String get tourSettingsTitle => 'Settings';

  @override
  String get tourSettingsBody =>
      'Language, theme, and how your payments are confirmed. Tap Settings.';

  @override
  String get tourConfirmSmsTitle => 'Confirmed by the wallet\'s SMS';

  @override
  String get tourConfirmSmsBody =>
      'A payment stays Cancelled until it is confirmed. With this on, the wallet\'s own \"money sent\" SMS confirms it for you while you are still in the dialer. It needs notification access, and no SMS is stored.';

  @override
  String get tourConfirmAskTitle => 'The Done / Cancel notification';

  @override
  String get tourConfirmAskBody =>
      'After you open the dialer, a notification asks \"Did the payment go through?\". Answer it from the pulldown without coming back. It stays silent while you read the USSD screen, and pops up only after you have been away for a while. Keep at least one of the two on.';

  @override
  String get tourReplayTitle => 'See this tour again';

  @override
  String get tourReplayBody => 'Come back here any time to replay the tour.';

  @override
  String get help => 'Help';

  @override
  String get appTour => 'App tour';

  @override
  String get appTourSubtitle => 'Replay the guided tour of the app';
}
