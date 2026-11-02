import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/theme/app_theme.dart';

/// The bundled font has to reach the component themes, not just the text theme.
///
/// `ThemeData(fontFamily: ...)` only applies to the text theme ThemeData
/// assembles internally. Component themes built from a locally constructed
/// TextTheme keep whatever family those styles carry -- null, meaning the
/// platform font. That left the app bar title, buttons and snack bars in
/// Roboto while the rest of the app was in Cairo.
void main() {
  for (final entry in {'dark': AppTheme.dark(), 'light': AppTheme.light()}.entries) {
    final name = entry.key;
    final theme = entry.value;

    group('$name theme uses ${AppTheme.fontFamily} everywhere', () {
      void expectFamily(String label, TextStyle? style) {
        expect(style, isNotNull, reason: '$label has no style at all');
        expect(
          style!.fontFamily,
          AppTheme.fontFamily,
          reason: '$label falls back to the platform font',
        );
      }

      test('text theme', () {
        expectFamily('displaySmall', theme.textTheme.displaySmall);
        expectFamily('titleLarge', theme.textTheme.titleLarge);
        expectFamily('bodyLarge', theme.textTheme.bodyLarge);
        expectFamily('labelSmall', theme.textTheme.labelSmall);
      });

      test('app bar title', () {
        expectFamily('appBarTheme.titleTextStyle',
            theme.appBarTheme.titleTextStyle);
      });

      test('buttons', () {
        expectFamily(
          'filledButton',
          theme.filledButtonTheme.style?.textStyle?.resolve(const {}),
        );
        expectFamily(
          'outlinedButton',
          theme.outlinedButtonTheme.style?.textStyle?.resolve(const {}),
        );
        expectFamily(
          'textButton',
          theme.textButtonTheme.style?.textStyle?.resolve(const {}),
        );
      });

      test('snack bar', () {
        expectFamily(
            'snackBarTheme.contentTextStyle', theme.snackBarTheme.contentTextStyle);
      });

      test('dialogs', () {
        expectFamily('dialogTheme.titleTextStyle', theme.dialogTheme.titleTextStyle);
        expectFamily(
            'dialogTheme.contentTextStyle', theme.dialogTheme.contentTextStyle);
      });

      test('input fields', () {
        expectFamily(
            'inputDecorationTheme.labelStyle', theme.inputDecorationTheme.labelStyle);
        expectFamily('inputDecorationTheme.hintStyle',
            theme.inputDecorationTheme.hintStyle);
        expectFamily('inputDecorationTheme.floatingLabelStyle',
            theme.inputDecorationTheme.floatingLabelStyle);
      });

      test('navigation bar labels', () {
        expectFamily(
          'navigationBarTheme.labelTextStyle',
          theme.navigationBarTheme.labelTextStyle?.resolve(const {}),
        );
        expectFamily(
          'navigationBarTheme.labelTextStyle (selected)',
          theme.navigationBarTheme.labelTextStyle
              ?.resolve(const {WidgetState.selected}),
        );
      });

      test('list tiles and chips', () {
        expectFamily(
            'listTileTheme.titleTextStyle', theme.listTileTheme.titleTextStyle);
        expectFamily('listTileTheme.subtitleTextStyle',
            theme.listTileTheme.subtitleTextStyle);
        expectFamily('chipTheme.labelStyle', theme.chipTheme.labelStyle);
      });
    });
  }

  testWidgets('USSD codes stay monospace', (tester) async {
    // The one deliberate exception: a code being checked against the dialer
    // must render in fixed columns, so it must not pick up the app font.
    late TextStyle style;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            style = AppTheme.ussdCode(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(style.fontFamily, 'monospace');
    expect(style.fontFamily, isNot(AppTheme.fontFamily));
  });
}
