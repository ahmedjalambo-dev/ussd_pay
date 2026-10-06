import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/history_screen.dart';

/// In-memory stand-in for the Hive-backed notifier, so the screen can be
/// driven without opening encrypted boxes.
class _FakeHistory extends HistoryNotifier {
  _FakeHistory(this._initial);

  final List<HistoryEntry> _initial;

  @override
  List<HistoryEntry> build() => _sorted(_initial);

  @override
  Future<void> add(HistoryEntry entry) async =>
      state = _sorted([...state, entry]);

  @override
  Future<void> delete(String id) async =>
      state = state.where((e) => e.id != id).toList();

  @override
  Future<void> setStatus(String id, HistoryStatus status) async => state = [
        for (final e in state) e.id == id ? e.copyWith(status: status) : e,
      ];

  @override
  Future<void> clear() async => state = const [];

  static List<HistoryEntry> _sorted(List<HistoryEntry> entries) =>
      [...entries]..sort((a, b) => b.dialedAtUtc.compareTo(a.dialedAtUtc));
}

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);
}

HistoryEntry _entry(String id, String name, HistoryStatus status, int hour) =>
    HistoryEntry(
      id: id,
      dialedAtUtc: DateTime.utc(2026, 10, 6, hour),
      walletId: 'jawwal_pay',
      recipientType: 'friend',
      recipientNumber: '0599123456',
      recipientName: name,
      amount: 10,
      ussdCode: '*322*0599123456*10#',
      status: status,
    );

void main() {
  Future<void> pump(WidgetTester tester, List<HistoryEntry> entries) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyProvider.overrideWith(() => _FakeHistory(entries)),
          settingsProvider.overrideWith(_FakeSettings.new),
          walletsProvider.overrideWith((ref) async => const <Wallet>[]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('entries split into Done and Cancelled tabs', (tester) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
      _entry('b', 'Bob', HistoryStatus.cancelled, 11),
    ]);

    expect(find.text('Done (1)'), findsOneWidget);
    expect(find.text('Cancelled (1)'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsNothing);

    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('an empty tab shows its own empty state', (tester) async {
    await pump(tester, [_entry('a', 'Alice', HistoryStatus.done, 10)]);

    await tester.tap(find.text('Cancelled (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No cancelled payments'), findsOneWidget);
  });

  testWidgets('swiping deletes a card and Undo brings it back',
      (tester) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
      _entry('c', 'Carol', HistoryStatus.done, 9),
    ]);

    await tester.drag(find.text('Alice'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsNothing);
    expect(find.text('Done (1)'), findsOneWidget);
    expect(find.text('Payment deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Done (2)'), findsOneWidget);
  });
}
