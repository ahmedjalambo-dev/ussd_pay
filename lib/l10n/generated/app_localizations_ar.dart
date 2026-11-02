// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'USSD Pay';

  @override
  String get chooseWallet => 'اختر المحفظة';

  @override
  String get chooseWalletSubtitle => 'اختر المحفظة التي ستدفع منها.';

  @override
  String get navHome => 'ادفع';

  @override
  String get navFavorites => 'المفضلة';

  @override
  String get navHistory => 'السجل';

  @override
  String get settings => 'الإعدادات';

  @override
  String get recipientTypeQuestion => 'لمن تدفع؟';

  @override
  String get recipientTypeFriend => 'صديق';

  @override
  String get recipientTypeMerchant => 'تاجر';

  @override
  String get phoneNumberLabel => 'رقم الهاتف';

  @override
  String get phoneNumberHint => '059 912 3456';

  @override
  String get phoneSupportedPrefixes => 'جوال 059 · أوريدو 056';

  @override
  String get amountLabel => 'المبلغ';

  @override
  String get currencySymbol => '₪';

  @override
  String get pickFromContacts => 'جهات الاتصال';

  @override
  String get pickFromFavorites => 'المفضلة';

  @override
  String get reviewPayment => 'مراجعة الدفعة';

  @override
  String get reviewPaymentHint => 'لم يُرسل شيء بعد — ستراجع التفاصيل أولاً.';

  @override
  String get confirmTitle => 'تأكيد الدفعة';

  @override
  String get confirmSubtitle =>
      'تحقق من كل التفاصيل قبل الاتصال. هذه أموال حقيقية.';

  @override
  String get walletLabel => 'المحفظة';

  @override
  String get recipientLabel => 'المستلم';

  @override
  String get codeLabel => 'الكود الذي سيتم طلبه';

  @override
  String get callNow => 'فتح شاشة الاتصال';

  @override
  String get cancel => 'إلغاء';

  @override
  String get done => 'تم';

  @override
  String get back => 'رجوع';

  @override
  String get notesLabel => 'ملاحظات (اختياري)';

  @override
  String get notesHint => 'مثلاً: إيجار حزيران';

  @override
  String get notifPaymentDecisionTitle => 'هل تمّت الدفعة؟';

  @override
  String notifPaymentDecisionBody(
    String wallet,
    String amount,
    String currency,
  ) {
    return '$wallet: $amount $currency';
  }

  @override
  String get notifActionDone => 'نعم، تمّت';

  @override
  String get notifActionCancel => 'لا، ألغِ';

  @override
  String get copyCode => 'نسخ الكود';

  @override
  String get codeCopied => 'تم نسخ الكود';

  @override
  String get pinNotice =>
      'ستدخل الرقم السري لمحفظتك في شاشة شركة الاتصالات نفسها بعد الطلب. تطبيق USSD Pay لا يطلبه ولا يخزّنه أبداً.';

  @override
  String get warnUnknownPrefix =>
      'هذا الرقم ليس جوال (059) ولا أوريدو (056). تأكد منه قبل المتابعة — يمكنك الدفع على أي حال.';

  @override
  String get errorPhoneEmpty => 'أدخل رقم الهاتف';

  @override
  String get errorPhoneNonNumeric => 'لا يحتوي هذا على رقم هاتف';

  @override
  String get errorPhoneTooShort =>
      'الرقم قصير — يتكوّن من ٩ خانات تبدأ بـ 059 أو 056';

  @override
  String get errorPhoneTooLong =>
      'الرقم طويل — يتكوّن من ٩ خانات تبدأ بـ 059 أو 056';

  @override
  String get errorAmountRequired => 'أدخل المبلغ';

  @override
  String get carrierJawwal => 'جوال';

  @override
  String get carrierOoredoo => 'أوريدو';

  @override
  String get dialerUnavailable =>
      'هذا الجهاز لا يستطيع طلب أكواد USSD. تم نسخ الكود — الصقه في شاشة الاتصال.';

  @override
  String get dialerOpened => 'اضغط زر الاتصال في شاشة الطلب لإتمام الدفعة';

  @override
  String get emptyFavoritesTitle => 'لا يوجد مستلمون محفوظون';

  @override
  String get emptyFavoritesBody =>
      'احفظ من تدفع له كثيراً ليصبح رقمه على بعد ضغطة واحدة.';

  @override
  String get emptyHistoryTitle => 'لا توجد دفعات بعد';

  @override
  String get emptyHistoryBody =>
      'ستظهر هنا الدفعات التي طلبتها لتتمكن من تكرارها.';

  @override
  String get saveAsFavorite => 'حفظ في المفضلة';

  @override
  String get savedAsFavorite => 'تم الحفظ';

  @override
  String get favoriteNameLabel => 'الاسم';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get recipientTypeSection => 'نوع المستلم';

  @override
  String get addFavorite => 'إضافة مفضلة';

  @override
  String get editFavorite => 'تعديل المفضلة';

  @override
  String get favoriteUpdated => 'تم تحديث المفضلة';

  @override
  String favoriteAlreadyExists(String name) {
    return 'هذا الرقم محفوظ مسبقاً باسم $name';
  }

  @override
  String favoritesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count مستلمين',
      two: 'تم حذف مستلمَين',
      one: 'تم حذف مستلم واحد',
    );
    return '$_temp0';
  }

  @override
  String get repeatPayment => 'تكرار';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get clearHistoryMessage =>
      'سيتم حذف كل الدفعات المسجلة، المكتملة والملغاة، من هذا الجهاز.';

  @override
  String get clear => 'مسح';

  @override
  String historyTabDone(int count) {
    return 'مكتملة ($count)';
  }

  @override
  String historyTabCancelled(int count) {
    return 'ملغاة ($count)';
  }

  @override
  String get emptyDoneTitle => 'لا توجد دفعات مكتملة';

  @override
  String get emptyDoneBody => 'ستظهر هنا الدفعات التي تؤكد إتمامها.';

  @override
  String get emptyCancelledTitle => 'لا توجد دفعات ملغاة';

  @override
  String get emptyCancelledBody =>
      'ستظهر هنا الدفعات التي ألغيتها أو لم تؤكدها.';

  @override
  String historyEntriesDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count دفعات',
      two: 'تم حذف دفعتين',
      one: 'تم حذف دفعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String selectedCount(int count) {
    return 'تم تحديد $count';
  }

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get cancelSelection => 'إلغاء التحديد';

  @override
  String get paymentDetails => 'تفاصيل الدفعة';

  @override
  String get data => 'البيانات';

  @override
  String get historyCleared => 'تم مسح السجل';

  @override
  String get undo => 'تراجع';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get about => 'عن التطبيق';

  @override
  String get aboutOffline =>
      'يعمل USSD Pay بدون إنترنت تماماً. لا يجري أي اتصال بالشبكة ولا يجمع أي بيانات.';

  @override
  String get aboutNoPin =>
      'لا يطلب الرقم السري لمحفظتك ولا يخزّنه ولا يرسله ضمن الكود.';

  @override
  String get contactsPermissionDenied =>
      'لم يتم منح إذن قراءة جهات الاتصال. يمكنك كتابة الرقم يدوياً.';

  @override
  String get contactHasNoNumber => 'جهة الاتصال هذه ليس لها رقم هاتف.';

  @override
  String get loadFailedTitle => 'تعذّرت قراءة إعدادات المحافظ';

  @override
  String get loadFailedBody =>
      'الملف assets/wallets.json مفقود أو غير صالح، لذا لا يمكن بناء أي دفعة بأمان.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get confirmationSection => 'تأكيد الدفع';

  @override
  String get confirmBySms => 'التأكيد عبر الرسائل';

  @override
  String confirmBySmsSubtitle(String wallet) {
    return 'اعتبار الدفعة مكتملة عند وصول رسالة $wallet';
  }

  @override
  String get confirmManually => 'اسألني (تمّت / إلغاء)';

  @override
  String get confirmManuallySubtitle => 'السؤال بعد فتح شاشة الاتصال';

  @override
  String get confirmManuallyFallbackSubtitle =>
      'السؤال إذا لم تصل رسالة خلال 3 دقائق';

  @override
  String get smsAccessTitle => 'السماح بالوصول للإشعارات';

  @override
  String smsAccessBody(String wallet) {
    return 'لتأكيد الدفعات عبر الرسائل، يحتاج USSD Pay إلى الوصول للإشعارات. يقرأ فقط رسائل $wallet، ولمدة 5 دقائق فقط بعد الدفع، ولا يحفظها ولا يرسلها لأي جهة.\n\nفي الشاشة التالية، فعّل USSD Pay.';
  }

  @override
  String get smsAccessOpenSettings => 'فتح الإعدادات';

  @override
  String get smsAccessMissing =>
      'الوصول للإشعارات متوقف، لذلك سيتم سؤالك لتأكيد الدفعات.';

  @override
  String get smsAccessGrant => 'السماح';

  @override
  String get notifWaitingSmsTitle => 'بانتظار رسالة التأكيد…';

  @override
  String get notifConfirmedSmsTitle => 'تم تأكيد الدفعة عبر الرسالة';

  @override
  String get confirmedBySms => 'تم التأكيد عبر الرسالة';

  @override
  String get batteryRestricted =>
      'اسمح لـ USSD Pay بالعمل في الخلفية (البطارية: بلا قيود)، ليعمل التأكيد عبر الرسائل وأنت في شاشة الاتصال.';

  @override
  String get batteryOpen => 'فتح';

  @override
  String get prevAttemptSameTitle => 'لقد بدأت هذه الدفعة مسبقاً';

  @override
  String prevAttemptSameBody(String time) {
    return 'فتحت شاشة الاتصال لها عند $time. إذا تمّت، فإن الاتصال مرة أخرى سيدفع المبلغ مرتين.';
  }

  @override
  String get prevAttemptOtherTitle => 'هل تمّت دفعتك السابقة؟';

  @override
  String prevAttemptOtherBody(String time) {
    return 'بدأت عند $time. أجب قبل أن تحلّ الدفعة الجديدة محل سؤالها.';
  }

  @override
  String get prevAttemptWentThrough => 'نعم، تمّت';

  @override
  String get prevAttemptTryAgain => 'لا، حاول مجدداً';

  @override
  String get prevAttemptNo => 'لا، لم تتم';
}
