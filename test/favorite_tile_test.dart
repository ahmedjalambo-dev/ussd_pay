import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/favorite.dart';
import 'package:ussd_pay/widgets/favorite_tile.dart';

/// The subtitle shares one Text between the spaced phone number and Arabic
/// labels. Without an LTR isolate, bidi lays the digit groups out right to
/// left, showing a different number from the one being paid.
void main() {
  final favorite = Favorite(
    id: 'a',
    name: 'Alice',
    number: '0599123456',
    walletId: 'jawwal_pay',
    defaultType: 'friend',
  );

  Future<void> pump(
    WidgetTester tester,
    Locale locale, {
    bool selecting = false,
  }) async {
    await tester.pumpWidget(
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
          body: FavoriteTile(
            favorite: favorite,
            walletName: 'جوال باي',
            walletColor: null,
            selecting: selecting,
            selected: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The painted x-position of each digit group, in reading order of the
  /// string.
  List<double> groupPositions(WidgetTester tester) {
    final finder = find.textContaining('059');
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    final text = paragraph.text.toPlainText();
    return ['059', '912', '3456'].map((group) {
      final start = text.indexOf(group);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + group.length),
      );
      return boxes.first.left;
    }).toList();
  }

  testWidgets('the number keeps dialing order inside Arabic', (tester) async {
    await pump(tester, const Locale('ar'));
    final x = groupPositions(tester);

    expect(x[0], lessThan(x[1]));
    expect(x[1], lessThan(x[2]));
  });

  testWidgets('selecting swaps the colour dot for a checkbox', (tester) async {
    await pump(tester, const Locale('en'));
    expect(find.byType(Checkbox), findsNothing);

    await pump(tester, const Locale('en'), selecting: true);
    expect(find.byType(Checkbox), findsOneWidget);
  });
}
