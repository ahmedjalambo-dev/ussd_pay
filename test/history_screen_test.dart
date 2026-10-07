import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/history_screen.dart';
import 'package:ussd_pay/screens/settings_screen.dart';

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
  Future<void> deleteMany(Iterable<String> ids) async {
    final gone = ids.toSet();
    state = state.where((e) => !gone.contains(e.id)).toList();
  }

  @override
  Future<void> restore(List<HistoryEntry> entries) async =>
      state = _sorted([...state, ...entries]);

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

/// Stands in for the root AppBar's selection mode, which owns the delete
/// action, without pulling in the other tabs and their storage.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(historySelectionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selection.active ? '${selection.ids.length} selected' : ''),
        actions: [
          if (selection.active) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: ref.read(historySelectionProvider.notifier).selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => HistoryScreen.deleteSelected(context, ref),
            ),
          ],
        ],
      ),
      body: const HistoryScreen(),
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<HistoryEntry> entries, {
    Widget home = const _Host(),
  }) async {
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
          home: home,
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

  testWidgets('long-press selects, delete removes all, Undo restores', (
    tester,
  ) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
      _entry('c', 'Carol', HistoryStatus.done, 9),
      _entry('d', 'Dave', HistoryStatus.done, 8),
    ]);
    expect(find.byType(Checkbox), findsNothing);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('1 selected'), findsOneWidget);

    // While selecting, a plain tap toggles rather than opening details.
    await tester.tap(find.text('Carol'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Payment details'), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsNothing);
    expect(find.text('Carol'), findsNothing);
    expect(find.text('Dave'), findsOneWidget);
    expect(find.text('Done (1)'), findsOneWidget);
    expect(find.text('2 payments deleted'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Done (3)'), findsOneWidget);
  });

  testWidgets('select all covers only the visible tab', (tester) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
      _entry('c', 'Carol', HistoryStatus.done, 9),
      _entry('b', 'Bob', HistoryStatus.cancelled, 11),
    ]);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('switching tabs ends the selection', (tester) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
      _entry('b', 'Bob', HistoryStatus.cancelled, 11),
    ]);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Cancelled (1)'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('a tap opens the details sheet with the dialed code', (
    tester,
  ) async {
    await pump(tester, [_entry('a', 'Alice', HistoryStatus.done, 10)]);

    expect(find.text('*322*0599123456*10#'), findsNothing);
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.text('Payment details'), findsOneWidget);
    expect(find.text('*322*0599123456*10#'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
  });

  testWidgets('Settings clears history after confirmation', (tester) async {
    await pump(tester, [
      _entry('a', 'Alice', HistoryStatus.done, 10),
    ], home: const SettingsScreen());

    await tester.scrollUntilVisible(find.text('Clear history'), 100);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('History cleared'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Clear history'),
        matching: find.byType(ListTile),
      ),
    );
    expect(tile.enabled, isFalse);
  });
}
