import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/confirmation_modes.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/settings_screen.dart';
import 'package:ussd_pay/services/sms_notification_source.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);

  @override
  Future<void> setConfirmationModes(
    String walletId,
    ConfirmationModes modes,
  ) async => state = state.copyWith(
    confirmation: {...state.confirmation, walletId: modes},
  );
}

class _EmptyHistory extends HistoryNotifier {
  @override
  List<HistoryEntry> build() => const [];
}

class _FakeSource implements SmsNotificationSource {
  _FakeSource({required this.granted, this.batteryFree = true});

  bool granted;
  bool batteryFree;
  int openedSettings = 0;
  int openedBattery = 0;

  @override
  bool get isSupported => true;
  @override
  Future<bool> isAccessGranted() async => granted;
  @override
  Future<void> openAccessSettings() async => openedSettings++;
  @override
  Future<bool> isIgnoringBatteryOptimizations() async => batteryFree;
  @override
  Future<void> openBatterySettings() async => openedBattery++;
  @override
  Future<void> watch(List<String> senders) async {}
  @override
  Future<void> unwatch() async {}
  @override
  Stream<SmsNotification> get notifications => const Stream.empty();
}

final _withSms = Wallet(
  id: 'jawwalpay',
  names: const {'en': 'JawwalPay'},
  colorValue: 0xFF6CA61C,
  templates: const {'friend': '*268*1*{phone}*{amount}#'},
  smsConfirmation: SmsConfirmationConfig(
    senders: const ['Jawwal Pay'],
    sentPatterns: [RegExp('(?<amount>1)(?<party>2)')],
  ),
);

const _withoutSms = Wallet(
  id: 'other',
  names: {'en': 'OtherPay'},
  colorValue: 0xFF000000,
  templates: {'friend': '*1*{phone}*{amount}#'},
);

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required _FakeSource source,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          historyProvider.overrideWith(_EmptyHistory.new),
          walletsProvider.overrideWith((ref) async => [_withSms, _withoutSms]),
          smsNotificationSourceProvider.overrideWithValue(source),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  SwitchListTile tile(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, title),
      );

  Future<void> tapSwitch(WidgetTester tester, String title) async {
    final finder = find.text(title);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  testWidgets('only wallets with SMS patterns get a card', (tester) async {
    await pump(tester, source: _FakeSource(granted: true));
    expect(find.text('JawwalPay'), findsOneWidget);
    expect(find.text('OtherPay'), findsNothing);
  });

  testWidgets('the last mode that is on cannot be turned off', (tester) async {
    final container = await pump(tester, source: _FakeSource(granted: true));

    // Defaults: ask only. Its switch is locked on.
    expect(tile(tester, 'Ask me (Done / Cancel)').onChanged, isNull);
    expect(tile(tester, 'Confirm by SMS').onChanged, isNotNull);

    await tapSwitch(tester, 'Confirm by SMS');
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).modesFor('jawwalpay'),
      const ConfirmationModes(sms: true, manual: true),
    );
    expect(find.text('Ask if no SMS arrives within 3 minutes'), findsOneWidget);

    await tapSwitch(tester, 'Ask me (Done / Cancel)');
    await tester.pumpAndSettle();
    expect(
      container.read(settingsProvider).modesFor('jawwalpay'),
      const ConfirmationModes(sms: true, manual: false),
    );
    // Now SMS is the last one on, and it is the locked one.
    expect(tile(tester, 'Confirm by SMS').onChanged, isNull);
  });

  testWidgets('turning SMS on without access explains, then opens settings', (
    tester,
  ) async {
    final source = _FakeSource(granted: false);
    final container = await pump(tester, source: source);

    await tapSwitch(tester, 'Confirm by SMS');
    await tester.pumpAndSettle();
    expect(find.text('Allow notification access'), findsOneWidget);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(source.openedSettings, 1);
    // Not on until access actually comes back granted.
    expect(container.read(settingsProvider).modesFor('jawwalpay').sms, isFalse);

    source.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).modesFor('jawwalpay').sms, isTrue);
  });

  testWidgets('with SMS on and battery restricted, offers the battery page', (
    tester,
  ) async {
    final source = _FakeSource(granted: true, batteryFree: false);
    await pump(tester, source: source);
    final notice = find.textContaining('run in the background');
    expect(notice, findsNothing, reason: 'irrelevant while SMS is off');

    await tapSwitch(tester, 'Confirm by SMS');
    await tester.pumpAndSettle();
    expect(notice, findsOneWidget);

    await tester.ensureVisible(find.text('Open'));
    await tester.tap(find.text('Open'));
    expect(source.openedBattery, 1);
  });

  testWidgets('returning without access leaves SMS off', (tester) async {
    final source = _FakeSource(granted: false);
    final container = await pump(tester, source: source);

    await tapSwitch(tester, 'Confirm by SMS');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).modesFor('jawwalpay').sms, isFalse);
  });
}
