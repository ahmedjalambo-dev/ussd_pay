import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/favorites_screen.dart';
import 'package:ussd_pay/screens/payment_screen.dart';

/// In-memory stand-in for the Hive-backed notifier. Ordered like storage:
/// by id descending, which for time-prefixed ids is most recently added first.
class _FakeFavorites extends FavoritesNotifier {
  _FakeFavorites(this._initial);

  final List<Favorite> _initial;

  @override
  List<Favorite> build() => _sorted(_initial);

  @override
  Future<void> save(Favorite favorite) async => state = _sorted([
    ...state.where((f) => f.id != favorite.id),
    favorite,
  ]);

  @override
  Future<void> deleteMany(Iterable<String> ids) async {
    final gone = ids.toSet();
    state = state.where((f) => !gone.contains(f.id)).toList();
  }

  @override
  Future<void> restore(List<Favorite> favorites) async =>
      state = _sorted([...state, ...favorites]);

  static List<Favorite> _sorted(List<Favorite> favorites) =>
      [...favorites]..sort((a, b) => b.id.compareTo(a.id));
}

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);
}

const _wallet = Wallet(
  id: 'jawwal_pay',
  names: {'en': 'JawwalPay'},
  colorValue: 0xFF00A651,
  templates: {'friend': '*322*{phone}*{amount}#'},
);

Favorite _favorite(String id, String name) => Favorite(
  id: id,
  name: name,
  number: '0599123456',
  walletId: 'jawwal_pay',
  defaultType: 'friend',
);

/// Stands in for the root AppBar's selection mode, which owns the delete
/// action, without pulling in the other tabs and their storage.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(favoritesSelectionProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(selection.isNotEmpty ? '${selection.length} selected' : ''),
        actions: [
          if (selection.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.select_all_rounded),
              onPressed: ref
                  .read(favoritesSelectionProvider.notifier)
                  .selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => FavoritesScreen.deleteSelected(context, ref),
            ),
          ],
        ],
      ),
      body: const FavoritesScreen(),
    );
  }
}

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, List<Favorite> favorites) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(() => _FakeFavorites(favorites)),
          settingsProvider.overrideWith(_FakeSettings.new),
          walletsProvider.overrideWith((ref) async => const [_wallet]),
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
          home: const _Host(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );
  }

  List<String> names() =>
      container.read(favoritesProvider).map((f) => f.name).toList();

  testWidgets('rows show number, wallet and type', (tester) async {
    await pump(tester, [_favorite('a', 'Alice')]);

    expect(find.text('Alice'), findsOneWidget);
    expect(find.textContaining('059 912 3456'), findsOneWidget);
    expect(find.textContaining('JawwalPay'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('long-press selects, delete removes all, Undo restores order', (
    tester,
  ) async {
    await pump(tester, [
      _favorite('c', 'Carol'),
      _favorite('b', 'Bob'),
      _favorite('a', 'Alice'),
    ]);
    expect(names(), ['Carol', 'Bob', 'Alice']);

    await tester.longPress(find.text('Carol'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.text('1 selected'), findsOneWidget);

    // While selecting, a plain tap toggles rather than opening a payment.
    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
    expect(find.byType(PaymentScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(names(), ['Bob']);
    expect(find.text('2 recipients deleted'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(names(), ['Carol', 'Bob', 'Alice']);
  });

  testWidgets('select all covers every favorite', (tester) async {
    await pump(tester, [_favorite('b', 'Bob'), _favorite('a', 'Alice')]);

    await tester.longPress(find.text('Alice'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.select_all_rounded));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
  });

  testWidgets('a tap opens a pre-filled payment screen', (tester) async {
    await pump(tester, [_favorite('a', 'Alice')]);

    await tester.tap(find.text('Alice'));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentScreen), findsOneWidget);

    final draft = container.read(paymentDraftProvider);
    expect(draft.recipientName, 'Alice');
    expect(draft.rawPhoneInput, '0599123456');
  });
}
