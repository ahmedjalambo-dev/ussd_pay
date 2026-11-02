import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/confirm_screen.dart';
import 'package:ussd_pay/screens/favorites_screen.dart';
import 'package:ussd_pay/screens/history_screen.dart';
import 'package:ussd_pay/screens/payment_screen.dart';
import 'package:ussd_pay/screens/root_screen.dart';
import 'package:ussd_pay/screens/settings_screen.dart';
import 'package:ussd_pay/services/sms_notification_source.dart';
import 'package:ussd_pay/tour/coach_mark_overlay.dart';
import 'package:ussd_pay/tour/tour_controller.dart';
import 'package:ussd_pay/widgets/wallet_card.dart';

class _MemoryStore implements TourStatusStore {
  _MemoryStore([this.status = TourStatus.notStarted]);
  TourStatus status;
  @override
  TourStatus read() => status;
  @override
  Future<void> write(TourStatus value) async => status = value;
}

class _Settings extends SettingsNotifier {
  _Settings(this._locale);
  final String _locale;
  @override
  AppSettings build() =>
      AppSettings(locale: Locale(_locale), themeMode: ThemeMode.dark);
}

class _History extends HistoryNotifier {
  _History(this._rows);
  final List<HistoryEntry> _rows;
  @override
  List<HistoryEntry> build() => _rows;
}

class _Favorites extends FavoritesNotifier {
  @override
  List<Favorite> build() => const [];
}

/// Off Android, so Settings shows no confirmation section and calls no
/// platform channel.
class _NoSms implements SmsNotificationSource {
  @override
  bool get isSupported => false;
  @override
  Future<bool> isAccessGranted() async => false;
  @override
  Future<void> openAccessSettings() async {}
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;
  @override
  Future<void> openBatterySettings() async {}
  @override
  Future<void> watch(List<String> senders) async {}
  @override
  Future<void> unwatch() async {}
  @override
  Stream<SmsNotification> get notifications => const Stream.empty();
}

const _wallets = [
  Wallet(
    id: 'jawwalpay',
    names: {'en': 'JawwalPay', 'ar': 'جوال باي'},
    colorValue: 0xFF6CA61C,
    templates: {'friend': '*268*1*{phone}*{amount}#'},
  ),
  Wallet(
    id: 'palpay',
    names: {'en': 'PalPay', 'ar': 'بال باي'},
    colorValue: 0xFF6A1B9A,
    templates: {'friend': '*100*{phone}*{amount}#'},
  ),
];

final _pastPayment = HistoryEntry(
  dialedAtUtc: DateTime.utc(2026, 10, 1),
  walletId: 'jawwalpay',
  recipientType: 'friend',
  recipientNumber: '0599123456',
  amount: 5,
  ussdCode: '*268*1*0599123456*5#',
);

void main() {
  late _MemoryStore store;

  setUp(() => store = _MemoryStore());

  Future<void> pump(
    WidgetTester tester, {
    String locale = 'en',
    List<HistoryEntry> history = const [],
    Future<List<Wallet>> Function()? wallets,
    bool settle = true,
  }) async {
    // A common phone (412 x 915 dp), so the tour is laid out as on a device.
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tourStatusStoreProvider.overrideWithValue(store),
          settingsProvider.overrideWith(() => _Settings(locale)),
          historyProvider.overrideWith(() => _History(history)),
          favoritesProvider.overrideWith(_Favorites.new),
          smsNotificationSourceProvider.overrideWithValue(_NoSms()),
          walletsProvider.overrideWith(
            (ref) => wallets?.call() ?? Future.value(_wallets),
          ),
        ],
        child: MaterialApp(
          locale: Locale(locale),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => TourOverlay(child: child!),
          home: const RootScreen(),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Finder tooltip() => find.byType(CoachMarkTooltip);
  Finder inTooltip(String text) =>
      find.descendant(of: tooltip(), matching: find.text(text));
  Finder navItem(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('the whole tour, driven by real taps', (tester) async {
    await pump(tester);

    // 1. Auto-started for a new user, on the first wallet.
    expect(inTooltip('Step 1 of 9'), findsOneWidget);
    expect(inTooltip('Start with a wallet'), findsOneWidget);
    expect(inTooltip('Tap the highlighted item to continue'), findsOneWidget);
    expect(inTooltip('Next'), findsNothing, reason: 'a tap step has no Next');

    // Outside the spotlight nothing reacts.
    await tapAndSettle(tester, find.byTooltip('Settings'));
    expect(find.byType(SettingsScreen), findsNothing);
    await tapAndSettle(tester, find.byType(WalletCard).last);
    expect(find.byType(PaymentScreen), findsNothing);

    // The real card, tapped through the spotlight, opens the real form.
    await tapAndSettle(tester, find.byType(WalletCard).first);
    expect(find.byType(PaymentScreen), findsOneWidget);
    expect(find.text('JawwalPay'), findsOneWidget);

    // 2-4. Next steps on the form; the autofocused keyboard is put away.
    expect(inTooltip('Who you are paying'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(inTooltip('Back'), findsNothing);
    await tapAndSettle(tester, inTooltip('Next'));
    expect(inTooltip('How much'), findsOneWidget);
    await tapAndSettle(tester, inTooltip('Back'));
    expect(inTooltip('Who you are paying'), findsOneWidget);
    await tapAndSettle(tester, inTooltip('Next'));
    await tapAndSettle(tester, inTooltip('Next'));
    expect(inTooltip('Review before anything is sent'), findsOneWidget);

    // Review is explained, never pressed: the spotlight absorbs it.
    await tapAndSettle(tester, find.text('Review payment'));
    expect(find.byType(ConfirmScreen), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    // 5. Back, with the real back arrow.
    await tapAndSettle(tester, inTooltip('Next'));
    expect(inTooltip('Back to your wallets'), findsOneWidget);
    await tapAndSettle(tester, find.byType(BackButton));
    expect(find.byType(PaymentScreen), findsNothing);

    // 6. The PIN notice, back on the Pay tab.
    expect(inTooltip('Your PIN stays yours'), findsOneWidget);
    expect(inTooltip('Step 6 of 9'), findsOneWidget);
    await tapAndSettle(tester, inTooltip('Next'));

    // 7-8. The real tabs.
    expect(inTooltip('Favorites'), findsOneWidget);
    await tapAndSettle(tester, navItem('History'));
    expect(inTooltip('Favorites'), findsOneWidget, reason: 'wrong tab');
    await tapAndSettle(tester, navItem('Favorites'));
    expect(find.byType(FavoritesScreen), findsOneWidget);
    expect(inTooltip('History'), findsOneWidget);
    await tapAndSettle(tester, navItem('History'));
    expect(find.byType(HistoryScreen), findsOneWidget);

    // 9. Settings, and done.
    expect(inTooltip('Step 9 of 9'), findsOneWidget);
    expect(store.status, TourStatus.notStarted, reason: 'not done yet');
    await tapAndSettle(tester, inTooltip('Finish'));
    expect(tooltip(), findsNothing);
    expect(store.status, TourStatus.completed);

    // The app is back to normal.
    await tapAndSettle(tester, find.byTooltip('Settings'));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Skip ends it for good and frees the app', (tester) async {
    await pump(tester);
    await tapAndSettle(tester, inTooltip('Skip tour'));

    expect(tooltip(), findsNothing);
    expect(store.status, TourStatus.skipped);
    await tapAndSettle(tester, find.byType(WalletCard).last);
    expect(find.byType(PaymentScreen), findsOneWidget);
  });

  testWidgets('not shown again once completed', (tester) async {
    store = _MemoryStore(TourStatus.completed);
    await pump(tester);
    expect(tooltip(), findsNothing);
  });

  testWidgets('system back on the form rewinds to the wallet step', (
    tester,
  ) async {
    await pump(tester);
    await tapAndSettle(tester, find.byType(WalletCard).first);
    await tapAndSettle(tester, inTooltip('Next'));
    expect(inTooltip('How much'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(PaymentScreen), findsNothing);
    expect(inTooltip('Start with a wallet'), findsOneWidget);
  });

  testWidgets('a returning user is not interrupted, and can replay it', (
    tester,
  ) async {
    await pump(tester, history: [_pastPayment]);
    expect(tooltip(), findsNothing);

    // Start the replay from another tab: it still begins on Pay.
    await tapAndSettle(tester, navItem('History'));
    await tapAndSettle(tester, find.byTooltip('Settings'));
    await tester.scrollUntilVisible(find.text('App tour'), 200);
    await tapAndSettle(tester, find.text('App tour'));

    expect(find.byType(SettingsScreen), findsNothing);
    expect(inTooltip('Start with a wallet'), findsOneWidget);
    await tapAndSettle(tester, find.byType(WalletCard).first);
    expect(find.byType(PaymentScreen), findsOneWidget);
  });

  testWidgets('while its target is loading the tour blocks nothing', (
    tester,
  ) async {
    final never = Completer<List<Wallet>>();
    await pump(tester, wallets: () => never.future, settle: false);
    // The spinner never settles; pump a few frames instead.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tooltip(), findsOneWidget, reason: 'running, but invisible');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Arabic: right-to-left, no overflow', (tester) async {
    await pump(tester, locale: 'ar');

    expect(inTooltip('ابدأ باختيار محفظة'), findsOneWidget);
    expect(
      Directionality.of(tester.element(inTooltip('ابدأ باختيار محفظة'))),
      TextDirection.rtl,
    );
    await tapAndSettle(tester, find.byType(WalletCard).first);
    expect(inTooltip('لمن ستدفع'), findsOneWidget);
    await tapAndSettle(tester, inTooltip('التالي'));
    expect(inTooltip('كم المبلغ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
