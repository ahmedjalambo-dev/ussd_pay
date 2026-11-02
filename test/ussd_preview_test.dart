import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/widgets/ussd_preview.dart';

void main() {
  const code = '*268*1*0599123456*50#';

  Widget wrap(Widget child, TextDirection direction) => MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: child),
        ),
      );

  /// The direction actually applied to the code text, walking up from the
  /// widget that renders it.
  TextDirection renderedDirection(WidgetTester tester) {
    final textFinder = find.text(code);
    expect(textFinder, findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find
          .ancestor(of: textFinder, matching: find.byType(Directionality))
          .first,
    );
    return directionality.textDirection;
  }

  testWidgets('renders the code left-to-right inside an RTL layout',
      (tester) async {
    // The whole point of the confirmation screen is that the user can verify
    // the code. Under RTL, "*" and "#" are bidi-neutral, so without a forced
    // LTR the code renders reordered and the user approves something that does
    // not match what gets dialed.
    await tester.pumpWidget(wrap(const UssdPreview(code: code), TextDirection.rtl));

    expect(renderedDirection(tester), TextDirection.ltr);
  });

  testWidgets('renders left-to-right in an LTR layout too', (tester) async {
    await tester.pumpWidget(wrap(const UssdPreview(code: code), TextDirection.ltr));

    expect(renderedDirection(tester), TextDirection.ltr);
  });

  testWidgets('shows the code verbatim, unmodified', (tester) async {
    await tester.pumpWidget(wrap(const UssdPreview(code: code), TextDirection.rtl));

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, code, reason: 'the preview must not reformat the code');
  });

  testWidgets('shows the whole code, start included, in a narrow RTL box',
      (tester) async {
    // Regression: the code used to sit in a horizontal SingleChildScrollView,
    // which under RTL starts at its right edge. A code wider than the box
    // rendered with its leading "*" scrolled out of sight -- "*268*1*..."
    // reading as "268*1*...". On the screen whose whole purpose is verifying
    // the code before approving it, part of the code must never be off-box.
    const longCode = '*268*1*0568450493*1234567890#';

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: UssdPreview(code: longCode)),
            ),
          ),
        ),
      ),
    );

    final preview = tester.getRect(find.byType(UssdPreview));
    final rendered = tester.getRect(find.text(longCode));

    expect(rendered.left, greaterThanOrEqualTo(preview.left),
        reason: 'the start of the code is cut off');
    expect(rendered.right, lessThanOrEqualTo(preview.right),
        reason: 'the end of the code is cut off');
  });

  testWidgets('the unemphasised variant still forces LTR', (tester) async {
    // Used in history rows, where the same reordering bug would apply.
    await tester.pumpWidget(
      wrap(const UssdPreview(code: code, emphasised: false), TextDirection.rtl),
    );

    expect(renderedDirection(tester), TextDirection.ltr);
  });
}
