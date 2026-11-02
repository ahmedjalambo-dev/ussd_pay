import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/core/formatting.dart';
import 'package:ussd_pay/services/phone_normalizer.dart';
import 'package:ussd_pay/widgets/amount_field.dart';
import 'package:ussd_pay/widgets/phone_field.dart';

/// The number fields have to hold two directions at once.
///
/// The digits are LTR in any language -- an Arabic layout would otherwise
/// reorder them away from what gets dialed. The decoration around them (label,
/// hint position, prefix icon) must follow the *ambient* direction, or an
/// Arabic screen ends up with its labels stranded on the left. Wrapping the
/// whole field in an LTR Directionality gets the first part right and the
/// second part wrong, which is what these tests pin down.
void main() {
  Widget wrap(Widget child, Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  Widget phoneField() => PhoneField(
        controller: TextEditingController(),
        normalized: PhoneNormalizer.normalize(''),
        onChanged: (_) {},
        onPickContact: () {},
        onPickFavorite: () {},
      );

  Widget amountField() => AmountField(
        controller: TextEditingController(),
        onChanged: (_) {},
      );

  /// The direction the field's decoration will be laid out in.
  TextDirection ambientDirectionAt(WidgetTester tester, Finder field) {
    final directionality = tester.widget<Directionality>(
      find.ancestor(of: field, matching: find.byType(Directionality)).first,
    );
    return directionality.textDirection;
  }

  group('phone field', () {
    testWidgets('types digits LTR under Arabic', (tester) async {
      await tester.pumpWidget(wrap(phoneField(), const Locale('ar')));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.decoration?.hintTextDirection, TextDirection.ltr,
          reason: 'the hint is a number pattern, not prose');
    });

    testWidgets('leaves the decoration in the ambient RTL direction',
        (tester) async {
      await tester.pumpWidget(wrap(phoneField(), const Locale('ar')));

      expect(
        ambientDirectionAt(tester, find.byType(TextField)),
        TextDirection.rtl,
        reason: 'an LTR wrapper here strands the Arabic label on the left',
      );
      // Digits sit on the reading side rather than across the field from the
      // label they belong to.
      expect(
        tester.widget<TextField>(find.byType(TextField)).textAlign,
        TextAlign.right,
      );
    });

    testWidgets('stays fully LTR under English', (tester) async {
      await tester.pumpWidget(wrap(phoneField(), const Locale('en')));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.left);
      expect(
        ambientDirectionAt(tester, find.byType(TextField)),
        TextDirection.ltr,
      );
    });
  });

  group('user-supplied names', () {
    // A favorite saved as "056 845 0493" displayed as "0493 845 056" in the
    // Arabic list: free text carries no strong direction, so the bidi
    // algorithm reordered its digit groups to suit the paragraph around it.
    test('a numeric name renders left-to-right', () {
      expect(directionOf('056 845 0493'), TextDirection.ltr);
    });

    test('a Latin name renders left-to-right', () {
      expect(directionOf('Mahmoud'), TextDirection.ltr);
    });

    test('an Arabic name renders right-to-left', () {
      expect(directionOf('محمود'), TextDirection.rtl);
    });

    test('a mixed name follows its dominant script', () {
      expect(directionOf('محمود 0599'), TextDirection.rtl);
    });
  });

  group('amount field', () {
    testWidgets('types digits LTR under Arabic', (tester) async {
      await tester.pumpWidget(wrap(amountField(), const Locale('ar')));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
      expect(field.textAlign, TextAlign.right);
    });

    testWidgets('leaves the decoration in the ambient RTL direction',
        (tester) async {
      await tester.pumpWidget(wrap(amountField(), const Locale('ar')));

      expect(
        ambientDirectionAt(tester, find.byType(TextField)),
        TextDirection.rtl,
      );
    });
  });
}
