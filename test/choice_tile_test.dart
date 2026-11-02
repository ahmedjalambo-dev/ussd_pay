import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/wallet.dart';
import 'package:ussd_pay/widgets/choice_tile.dart';
import 'package:ussd_pay/widgets/recipient_type_toggle.dart';
import 'package:ussd_pay/widgets/wallet_choice_tile.dart';

/// The wallet picker and the recipient-type toggle are one control, and every
/// row of it is filled edge to edge.
void main() {
  const width = 400.0;

  Widget wrap(Widget child, [Locale locale = const Locale('en')]) =>
      MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      );

  Widget tile(String label) => ChoiceTile(
        leading: const Icon(Icons.star),
        label: label,
        selected: false,
        onTap: () {},
      );

  double widthOf(WidgetTester tester, String label) => tester
      .getSize(find.ancestor(
        of: find.text(label),
        matching: find.byType(ChoiceTile),
      ))
      .width;

  testWidgets('two tiles share the row and fill it', (tester) async {
    await tester.pumpWidget(
      wrap(ChoiceTileRows(children: [tile('a'), tile('b')])),
    );

    final a = widthOf(tester, 'a');
    expect(a, widthOf(tester, 'b'));
    expect(a * 2 + 12, closeTo(width, 0.01),
        reason: 'two tiles plus the gap span the whole row');
  });

  testWidgets('an odd last tile takes the whole row', (tester) async {
    await tester.pumpWidget(
      wrap(ChoiceTileRows(children: [tile('a'), tile('b'), tile('c')])),
    );

    expect(widthOf(tester, 'c'), width);
  });

  testWidgets('wallet and type tiles are the same widget', (tester) async {
    const wallet = Wallet(
      id: 'jawwal_pay',
      names: {'en': 'JawwalPay'},
      colorValue: 0xFF00A651,
      templates: {'friend': '*322*{phone}*{amount}#'},
    );
    String? picked;

    await tester.pumpWidget(
      wrap(
        Column(
          children: [
            WalletChoiceTile(
              wallet: wallet,
              localeCode: 'en',
              selected: true,
              onTap: () {},
            ),
            RecipientTypeToggle(
              types: const ['friend', 'merchant'],
              selected: 'friend',
              onChanged: (type) => picked = type,
            ),
          ],
        ),
      ),
    );

    expect(find.byType(ChoiceTile), findsNWidgets(3));
    await tester.tap(find.text('A merchant'));
    expect(picked, 'merchant');
  });

  testWidgets('the leading visual sits on the reading side in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(tile('a'), const Locale('ar')));

    final icon = tester.getCenter(find.byIcon(Icons.star));
    final label = tester.getCenter(find.text('a'));
    expect(icon.dx, greaterThan(label.dx));
  });
}
