import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/confirm_screen.dart';
import 'package:ussd_pay/services/phone_normalizer.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);
}

class _EmptyHistory extends HistoryNotifier {
  @override
  List<HistoryEntry> build() => const [];
}

const _wallet = Wallet(
  id: 'jawwalpay',
  names: {'en': 'JawwalPay'},
  colorValue: 0xFF6CA61C,
  templates: {'friend': '*268*1*{phone}*{amount}#'},
);

/// The confirm screen has no back arrow: Cancel (and the system back gesture)
/// is the only way out short of Done, so leaving after a dial is always an
/// answer. Before any dial there is nothing to answer, and Cancel just goes
/// back to the form.
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          historyProvider.overrideWith(_EmptyHistory.new),
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ConfirmScreen(
                        wallet: _wallet,
                        recipientType: 'friend',
                        phone: PhoneNormalizer.normalize('0599123456'),
                        amount: 5,
                        ussdCode: '*268*1*0599123456*5#',
                      ),
                    ),
                  ),
                  child: const Text('payment form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('payment form'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmScreen), findsOneWidget);
  }

  testWidgets('a Cancel button replaces the back arrow', (tester) async {
    await pump(tester);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('Cancel before any dial returns to the form, no questions', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ConfirmScreen), findsNothing);
    expect(find.text('payment form'), findsOneWidget);
  });

  testWidgets('system back before any dial does the same', (tester) async {
    await pump(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ConfirmScreen), findsNothing);
    expect(find.text('payment form'), findsOneWidget);
  });
}
