import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/l10n/generated/app_localizations.dart';
import 'package:ussd_pay/widgets/save_favorite_dialog.dart';

/// Regression tests for the "save as favorite" crash.
///
/// The dialog used to be built inline on the confirmation screen, with the
/// screen creating the controller and disposing it right after
/// `await showDialog(...)`. That future completes the instant `Navigator.pop`
/// runs -- while the route is still animating out and the field is still
/// mounted -- so the field went on to touch a disposed controller and threw.
/// Settling the animation after the pop is what catches it.
void main() {
  Widget host({String? initialName, required void Function(String?) onResult}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final name = await showDialog<String>(
                context: context,
                builder: (_) => SaveFavoriteDialog(initialName: initialName),
              );
              onResult(name);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving does not throw while the dialog animates out',
      (tester) async {
    String? result;
    await tester.pumpWidget(host(onResult: (name) => result = name));
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Mahmoud');
    await tester.pump();
    await tester.tap(find.text('Save'));

    // The exit transition is exactly where the disposed controller used to be
    // touched, so settle through all of it rather than a single pump.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'Mahmoud');
  });

  testWidgets('cancelling does not throw either', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(host(onResult: (name) => result = name));
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), 'Mahmoud');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNull, reason: 'cancelling saves nothing');
  });

  testWidgets('the name is trimmed before it is returned', (tester) async {
    String? result;
    await tester.pumpWidget(host(onResult: (name) => result = name));
    await openDialog(tester);

    await tester.enterText(find.byType(TextField), '  Mahmoud  ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Mahmoud');
  });

  testWidgets('Save is disabled until the field has a name', (tester) async {
    // The old dialog accepted the tap, closed, and saved nothing, which read
    // as the button being broken.
    await tester.pumpWidget(host(onResult: (_) {}));
    await openDialog(tester);

    FilledButton saveButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );

    expect(saveButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'A');
    await tester.pump();
    expect(saveButton().onPressed, isNotNull);

    // Whitespace alone is not a name.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveButton().onPressed, isNull);
  });

  testWidgets('prefills the name it was given', (tester) async {
    await tester.pumpWidget(host(initialName: 'Layla', onResult: (_) {}));
    await openDialog(tester);

    expect(find.widgetWithText(TextField, 'Layla'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
      reason: 'a prefilled name is immediately savable',
    );
  });
}
