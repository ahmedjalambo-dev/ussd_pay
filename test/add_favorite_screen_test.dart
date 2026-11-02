import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/add_favorite_screen.dart';

/// In-memory stand-in for the Hive-backed notifier.
class _FakeFavorites extends FavoritesNotifier {
  _FakeFavorites(this._initial);

  final List<Favorite> _initial;

  @override
  List<Favorite> build() => _initial;

  /// Overwrites by id, as Hive's `put` does, so an edit replaces its row.
  @override
  Future<void> save(Favorite favorite) async =>
      state = [favorite, ...state.where((f) => f.id != favorite.id)];
}

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);
}

const _jawwal = Wallet(
  id: 'jawwal_pay',
  names: {'en': 'JawwalPay'},
  colorValue: 0xFF00A651,
  templates: {
    'friend': '*322*{phone}*{amount}#',
    'merchant': '*323*{phone}*{amount}#',
  },
);

/// Offers only one type, to check a type the wallet lacks is never saved.
const _palpay = Wallet(
  id: 'palpay',
  names: {'en': 'PalPay'},
  colorValue: 0xFF0055A4,
  templates: {'friend': '*400*{phone}*{amount}#'},
);

void main() {
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, [
    List<Favorite> initial = const [],
    Favorite? editing,
  ]) async {
    // Tall enough that the lazily built form has every field on screen.
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(() => _FakeFavorites(initial)),
          settingsProvider.overrideWith(_FakeSettings.new),
          walletsProvider.overrideWith((ref) async => const [_jawwal, _palpay]),
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
          // A route below, so saving has somewhere to pop back to.
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddFavoriteScreen(initial: editing),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(AddFavoriteScreen)),
    );
  }

  Finder phoneField() => find.byType(TextField).first;
  Finder nameField() => find.widgetWithText(TextField, 'Name');
  // FilledButton.icon builds a FilledButton subclass, which an exact-type
  // finder misses.
  Finder saveButton() => find.ancestor(
    of: find.text('Save'),
    matching: find.byWidgetPredicate((w) => w is FilledButton),
  );

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(saveButton());
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  List<Favorite> saved() => container.read(favoritesProvider);

  testWidgets('saves the normalized number, wallet and type', (tester) async {
    await pump(tester);

    await tester.ensureVisible(saveButton());
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.enterText(phoneField(), '+970 599 123 456');
    await tester.enterText(nameField(), '  Alice  ');
    await tester.pump();
    await tapSave(tester);

    final favorites = container.read(favoritesProvider);
    expect(favorites, hasLength(1));
    expect(favorites.single.name, 'Alice');
    expect(favorites.single.number, '0599123456');
    expect(favorites.single.walletId, 'jawwal_pay');
    expect(favorites.single.defaultType, 'friend');
    expect(find.byType(AddFavoriteScreen), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('an invalid number is refused', (tester) async {
    await pump(tester);

    await tester.enterText(phoneField(), '0599');
    await tester.enterText(nameField(), 'Alice');
    await tester.pump();
    await tapSave(tester);

    expect(saved(), isEmpty);
    expect(find.byType(AddFavoriteScreen), findsOneWidget);
  });

  testWidgets('a duplicate is flagged live and Save disabled', (tester) async {
    await pump(tester, [
      Favorite(
        id: 'x',
        name: 'Mum',
        number: '0599123456',
        walletId: 'jawwal_pay',
        defaultType: 'friend',
      ),
    ]);
    const message = 'This number is already saved as Mum';

    // Any typed form of the number is caught, before Save is ever tapped.
    await tester.enterText(phoneField(), '+970599123456');
    await tester.enterText(nameField(), 'Alice');
    await tester.pump();
    expect(find.text(message), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    // Another wallet is a different favorite, so the warning clears.
    await tester.tap(find.text('PalPay'));
    await tester.pump();
    expect(find.text(message), findsNothing);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets('next moves to the name, done saves', (tester) async {
    await pump(tester);

    await tester.enterText(phoneField(), '0599123456');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    final name = tester.widget<TextField>(nameField());
    expect(name.focusNode?.hasFocus, isTrue);

    await tester.enterText(nameField(), 'Alice');
    // A frame between typing and pressing done, as on a device.
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(saved().single.name, 'Alice');
  });

  testWidgets('the same number on another wallet is allowed', (tester) async {
    await pump(tester, [
      Favorite(
        id: 'x',
        name: 'Mum',
        number: '0599123456',
        walletId: 'jawwal_pay',
        defaultType: 'friend',
      ),
    ]);

    await tester.tap(find.text('PalPay'));
    await tester.pump();
    await tester.enterText(phoneField(), '0599123456');
    await tester.enterText(nameField(), 'Mum');
    await tester.pump();
    await tapSave(tester);

    expect(saved(), hasLength(2));
    expect(saved().first.walletId, 'palpay');
  });

  testWidgets('switching to a wallet without the chosen type resets it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('A merchant'));
    await tester.pump();
    await tester.tap(find.text('PalPay'));
    await tester.pump();
    expect(find.text('A merchant'), findsNothing);

    await tester.enterText(phoneField(), '0599123456');
    await tester.enterText(nameField(), 'Alice');
    await tester.pump();
    await tapSave(tester);

    expect(saved().single.walletId, 'palpay');
    expect(saved().single.defaultType, 'friend');
  });

  group('editing', () {
    final mum = Favorite(
      id: 'mum',
      name: 'Mum',
      number: '0599123456',
      walletId: 'jawwal_pay',
      defaultType: 'merchant',
      defaultAmount: 50,
    );
    final dad = Favorite(
      id: 'dad',
      name: 'Dad',
      number: '0599000111',
      walletId: 'jawwal_pay',
      defaultType: 'friend',
    );

    bool canSave(WidgetTester tester) =>
        tester.widget<FilledButton>(saveButton()).onPressed != null;

    testWidgets('opens pre-filled, with Save off until something changes', (
      tester,
    ) async {
      await pump(tester, [mum, dad], mum);

      expect(find.text('Edit favorite'), findsOneWidget);
      expect(
        tester.widget<TextField>(phoneField()).controller?.text,
        '0599123456',
      );
      expect(tester.widget<TextField>(nameField()).controller?.text, 'Mum');
      // Unchanged, it is not its own duplicate, and there is nothing to save.
      expect(find.textContaining('already saved'), findsNothing);
      expect(canSave(tester), isFalse);

      // The same number in another form is not a change.
      await tester.enterText(phoneField(), '+970599123456');
      await tester.pump();
      expect(canSave(tester), isFalse);

      await tester.tap(find.text('A friend'));
      await tester.pump();
      expect(canSave(tester), isTrue);
    });

    testWidgets('saving overwrites the row, keeping id and amount', (
      tester,
    ) async {
      await pump(tester, [mum, dad], mum);

      await tester.enterText(nameField(), 'Mother');
      await tester.enterText(phoneField(), '0569555444');
      await tester.pump();
      await tapSave(tester);

      expect(saved(), hasLength(2));
      final edited = saved().singleWhere((f) => f.id == 'mum');
      expect(edited.name, 'Mother');
      expect(edited.number, '0569555444');
      expect(edited.defaultType, 'merchant');
      expect(edited.defaultAmount, 50);
      expect(find.byType(AddFavoriteScreen), findsNothing);
      expect(find.text('Favorite updated'), findsOneWidget);
    });

    testWidgets("taking another favorite's number is flagged", (tester) async {
      await pump(tester, [mum, dad], mum);

      await tester.enterText(phoneField(), '0599000111');
      await tester.pump();
      expect(find.text('This number is already saved as Dad'), findsOneWidget);
      expect(canSave(tester), isFalse);
    });
  });
}
