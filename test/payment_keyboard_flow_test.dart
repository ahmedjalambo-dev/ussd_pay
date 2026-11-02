import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/payment_draft.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/providers/app_providers.dart';
import 'package:ussd_pay/screens/confirm_screen.dart';
import 'package:ussd_pay/screens/payment_screen.dart';

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() =>
      const AppSettings(locale: Locale('en'), themeMode: ThemeMode.dark);
}

/// Starts from a given draft, as a favorite or a return from Confirm would.
class _FakeDraft extends PaymentDraftNotifier {
  _FakeDraft(this._initial);

  final PaymentDraft _initial;

  @override
  PaymentDraft build() => _initial;
}

const _jawwal = Wallet(
  id: 'jawwal_pay',
  names: {'en': 'JawwalPay'},
  colorValue: 0xFF00A651,
  templates: {'friend': '*322*{phone}*{amount}#'},
);

void main() {
  Future<void> pump(
    WidgetTester tester, [
    PaymentDraft draft = const PaymentDraft(),
  ]) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith(_FakeSettings.new),
          paymentDraftProvider.overrideWith(() => _FakeDraft(draft)),
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
          home: const PaymentScreen(wallet: _jawwal),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Phone, amount, note: the screen's fields in order.
  Finder field(int i) => find.byType(EditableText).at(i);
  bool hasFocus(WidgetTester tester, int i) =>
      tester.widget<EditableText>(field(i)).focusNode.hasFocus;

  testWidgets('an empty payment opens on the phone, next walks the fields', (
    tester,
  ) async {
    await pump(tester);
    expect(hasFocus(tester, 0), isTrue);

    await tester.enterText(field(0), '0599123456');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(hasFocus(tester, 1), isTrue);

    await tester.enterText(field(1), '25');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(hasFocus(tester, 2), isTrue);
  });

  testWidgets('a draft with a number opens on the amount', (tester) async {
    await pump(tester, const PaymentDraft(rawPhoneInput: '0599123456'));
    expect(hasFocus(tester, 0), isFalse);
    expect(hasFocus(tester, 1), isTrue);
  });

  testWidgets('a complete draft focuses nothing', (tester) async {
    await pump(
      tester,
      const PaymentDraft(rawPhoneInput: '0599123456', amountInput: '25'),
    );
    for (var i = 0; i < 3; i++) {
      expect(hasFocus(tester, i), isFalse);
    }
  });

  testWidgets('done on the note opens Confirm, never the dialer', (
    tester,
  ) async {
    await pump(
      tester,
      const PaymentDraft(rawPhoneInput: '0599123456', amountInput: '25'),
    );

    await tester.showKeyboard(field(2));
    await tester.enterText(field(2), 'rent');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmScreen), findsOneWidget);
  });

  testWidgets('done with no amount stays put', (tester) async {
    await pump(tester, const PaymentDraft(rawPhoneInput: '0599123456'));

    await tester.showKeyboard(field(2));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmScreen), findsNothing);
  });
}
