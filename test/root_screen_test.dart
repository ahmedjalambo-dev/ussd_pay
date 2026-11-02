import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/add_favorite_screen.dart';
import 'package:ussd_pay/screens/root_screen.dart';

class _FakeFavorites extends FavoritesNotifier {
  _FakeFavorites(this._initial);

  final List<Favorite> _initial;

  @override
  List<Favorite> build() => _initial;
}

class _FakeHistory extends HistoryNotifier {
  @override
  List<HistoryEntry> build() => const [];
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

final _mum = Favorite(
  id: 'x',
  name: 'Mum',
  number: '0599123456',
  walletId: 'jawwal_pay',
  defaultType: 'friend',
);

/// Add favorite lives in the app bar, not in a floating button.
void main() {
  Future<void> pump(WidgetTester tester, List<Favorite> favorites) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoritesProvider.overrideWith(() => _FakeFavorites(favorites)),
          historyProvider.overrideWith(_FakeHistory.new),
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
          home: const RootScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder addAction() => find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('Add favorite'),
  );

  Future<void> openFavorites(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.star_outline_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('favorites tab: Add is an app-bar action that opens the form', (
    tester,
  ) async {
    await pump(tester, [_mum]);
    await openFavorites(tester);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(addAction(), findsOneWidget);

    await tester.tap(addAction());
    await tester.pumpAndSettle();
    expect(find.byType(AddFavoriteScreen), findsOneWidget);
  });

  testWidgets('an empty favorites list leaves Add to the empty state', (
    tester,
  ) async {
    await pump(tester, const []);
    await openFavorites(tester);

    expect(addAction(), findsNothing);
  });

  testWidgets('the pay tab has no Add action', (tester) async {
    await pump(tester, [_mum]);

    expect(addAction(), findsNothing);
  });
}
