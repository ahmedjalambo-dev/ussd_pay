import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/core/formatting.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/models/history_entry.dart';
import 'package:ussd_pay/widgets/history_tile.dart';

/// A history row titled by a bare number must keep its digits LTR yet sit on
/// the reading side of the layout. ListTile stretches the title to the full
/// row, so an LTR Text left alone aligns to the left edge even in Arabic.
void main() {
  final entry = HistoryEntry(
    id: 'a',
    dialedAtUtc: DateTime.utc(2026, 10, 6, 10),
    walletId: 'jawwal_pay',
    recipientType: 'friend',
    recipientNumber: '0599123456',
    amount: 10,
    ussdCode: '*322*0599123456*10#',
    status: HistoryStatus.done,
  );

  Future<void> pump(WidgetTester tester, Locale locale) async {
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
          body: HistoryTile(
            entry: entry,
            walletName: null,
            walletColor: null,
            localeCode: locale.languageCode,
            selecting: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final number = formatPhoneDisplay(entry.recipientNumber);
  Finder title() => find.text(number);

  /// Where the digits are actually painted, not where the Text box is: a box
  /// stretched across the row has its centre in the middle whichever edge
  /// the glyphs hug.
  double glyphCenter(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(title());
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: number.length),
    );
    final left = boxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);
    final right = boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b);
    return paragraph.localToGlobal(Offset((left + right) / 2, 0)).dx;
  }

  testWidgets('a number title sits on the right in Arabic', (tester) async {
    await pump(tester, const Locale('ar'));
    final width = tester.getSize(find.byType(Scaffold)).width;

    expect(glyphCenter(tester), greaterThan(width / 2));
    expect(tester.widget<Text>(title()).textDirection, TextDirection.ltr);
  });

  testWidgets('a number title sits on the left in English', (tester) async {
    await pump(tester, const Locale('en'));
    final width = tester.getSize(find.byType(Scaffold)).width;

    expect(glyphCenter(tester), lessThan(width / 2));
  });
}
