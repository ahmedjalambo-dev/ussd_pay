import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'USSD Pay'**
  String get appTitle;

  /// No description provided for @chooseWallet.
  ///
  /// In en, this message translates to:
  /// **'Choose a wallet'**
  String get chooseWallet;

  /// No description provided for @chooseWalletSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick the wallet you are paying from.'**
  String get chooseWalletSubtitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get navHome;

  /// No description provided for @navFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get navFavorites;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @recipientTypeQuestion.
  ///
  /// In en, this message translates to:
  /// **'Who are you paying?'**
  String get recipientTypeQuestion;

  /// No description provided for @recipientTypeFriend.
  ///
  /// In en, this message translates to:
  /// **'A friend'**
  String get recipientTypeFriend;

  /// No description provided for @recipientTypeMerchant.
  ///
  /// In en, this message translates to:
  /// **'A merchant'**
  String get recipientTypeMerchant;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'059 912 3456'**
  String get phoneNumberHint;

  /// No description provided for @phoneSupportedPrefixes.
  ///
  /// In en, this message translates to:
  /// **'Jawwal 059 · Ooredoo 056'**
  String get phoneSupportedPrefixes;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @currencySymbol.
  ///
  /// In en, this message translates to:
  /// **'₪'**
  String get currencySymbol;

  /// No description provided for @pickFromContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get pickFromContacts;

  /// No description provided for @pickFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get pickFromFavorites;

  /// No description provided for @reviewPayment.
  ///
  /// In en, this message translates to:
  /// **'Review payment'**
  String get reviewPayment;

  /// No description provided for @reviewPaymentHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is sent yet — you will check the details first.'**
  String get reviewPaymentHint;

  /// No description provided for @confirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm payment'**
  String get confirmTitle;

  /// No description provided for @confirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check every detail before you dial. This sends real money.'**
  String get confirmSubtitle;

  /// No description provided for @walletLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletLabel;

  /// No description provided for @recipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipientLabel;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code to be dialed'**
  String get codeLabel;

  /// No description provided for @callNow.
  ///
  /// In en, this message translates to:
  /// **'Open dialer'**
  String get callNow;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesLabel;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rent June'**
  String get notesHint;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get codeCopied;

  /// No description provided for @pinNotice.
  ///
  /// In en, this message translates to:
  /// **'You will enter your wallet PIN in your carrier\'s own screen after dialing. USSD Pay never asks for it and never stores it.'**
  String get pinNotice;

  /// No description provided for @warnUnknownPrefix.
  ///
  /// In en, this message translates to:
  /// **'This is not a Jawwal (059) or Ooredoo (056) number. Check it before you continue — you can still pay.'**
  String get warnUnknownPrefix;

  /// No description provided for @errorPhoneEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a phone number'**
  String get errorPhoneEmpty;

  /// No description provided for @errorPhoneNonNumeric.
  ///
  /// In en, this message translates to:
  /// **'This does not contain a phone number'**
  String get errorPhoneNonNumeric;

  /// No description provided for @errorPhoneTooShort.
  ///
  /// In en, this message translates to:
  /// **'Too short — a number has 9 digits, starting 059 or 056'**
  String get errorPhoneTooShort;

  /// No description provided for @errorPhoneTooLong.
  ///
  /// In en, this message translates to:
  /// **'Too long — a number has 9 digits, starting 059 or 056'**
  String get errorPhoneTooLong;

  /// No description provided for @errorAmountRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get errorAmountRequired;

  /// No description provided for @carrierJawwal.
  ///
  /// In en, this message translates to:
  /// **'Jawwal'**
  String get carrierJawwal;

  /// No description provided for @carrierOoredoo.
  ///
  /// In en, this message translates to:
  /// **'Ooredoo'**
  String get carrierOoredoo;

  /// No description provided for @dialerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This device cannot dial USSD codes. The code has been copied — paste it into your phone\'s dialer.'**
  String get dialerUnavailable;

  /// No description provided for @dialerOpened.
  ///
  /// In en, this message translates to:
  /// **'Press call in your dialer to send the payment'**
  String get dialerOpened;

  /// No description provided for @emptyFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved recipients'**
  String get emptyFavoritesTitle;

  /// No description provided for @emptyFavoritesBody.
  ///
  /// In en, this message translates to:
  /// **'Save someone you pay often and their number will be one tap away.'**
  String get emptyFavoritesBody;

  /// No description provided for @emptyHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No payments yet'**
  String get emptyHistoryTitle;

  /// No description provided for @emptyHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Payments you dial will be listed here so you can repeat them.'**
  String get emptyHistoryBody;

  /// No description provided for @saveAsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Save as favorite'**
  String get saveAsFavorite;

  /// No description provided for @savedAsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedAsFavorite;

  /// No description provided for @favoriteNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get favoriteNameLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this recipient?'**
  String get deleteFavoriteTitle;

  /// No description provided for @deleteFavoriteMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from your favorites.'**
  String deleteFavoriteMessage(String name);

  /// No description provided for @repeatPayment.
  ///
  /// In en, this message translates to:
  /// **'Repeat'**
  String get repeatPayment;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get clearHistory;

  /// No description provided for @clearHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'All recorded payments will be deleted from this device.'**
  String get clearHistoryMessage;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutOffline.
  ///
  /// In en, this message translates to:
  /// **'USSD Pay works entirely offline. It makes no network connections and collects nothing.'**
  String get aboutOffline;

  /// No description provided for @aboutNoPin.
  ///
  /// In en, this message translates to:
  /// **'It never asks for, stores, or dials your wallet PIN.'**
  String get aboutNoPin;

  /// No description provided for @contactsPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission to read contacts was not granted. You can still type the number.'**
  String get contactsPermissionDenied;

  /// No description provided for @contactHasNoNumber.
  ///
  /// In en, this message translates to:
  /// **'That contact has no phone number.'**
  String get contactHasNoNumber;

  /// No description provided for @loadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet settings could not be read'**
  String get loadFailedTitle;

  /// No description provided for @loadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'assets/wallets.json is missing or invalid, so no payment can be built safely.'**
  String get loadFailedBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
