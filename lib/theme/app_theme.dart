import 'package:flutter/material.dart';

/// The app's design tokens and component styling.
///
/// Everything visual is defined here: screens and widgets read from
/// `Theme.of(context)` rather than declaring their own sizes and colours, so a
/// change lands in one place instead of eighty.
///
/// The constraints behind the numbers have not changed -- this is still an app
/// used on cheap handsets, outdoors, in a hurry, often on a low battery. Type
/// stays large, tap targets stay generous, contrast stays high, and dark is
/// still the default. What changed is that those constraints are now expressed
/// as a coherent scale instead of ad-hoc values.
abstract final class AppTheme {
  // --- Spacing ------------------------------------------------------------

  /// Horizontal padding for screen content.
  static const double screenPadding = 20;

  static const double gapXs = 4;
  static const double gapSm = 8;
  static const double gapMd = 12;
  static const double gapLg = 16;
  static const double gapXl = 24;
  static const double gapXxl = 32;

  // --- Shape --------------------------------------------------------------

  /// Chips and small inline surfaces.
  static const double radiusSm = 12;

  /// Buttons and input fields.
  static const double radiusMd = 16;

  /// Cards and list rows.
  static const double radiusLg = 20;

  /// Hero surfaces, dialogs, and bottom sheets.
  static const double radiusXl = 28;

  /// Kept for callers that referred to the old single card radius.
  static const double cardRadius = radiusLg;

  /// Minimum height for anything tappable. Comfortably above the 48dp
  /// guideline, because these are money actions and often taken in a hurry.
  static const double touchTarget = 60;

  /// Minimum size for a button in a dialog's action row.
  ///
  /// The screen-level button themes below use `Size.fromHeight`, whose *width*
  /// is `double.infinity` -- what full-width primary actions want, but in a
  /// dialog it overflows the action row and stacks the buttons vertically.
  /// Still a 48dp target, just a finite width.
  static const Size dialogActionSize = Size(88, 48);

  // --- Colour -------------------------------------------------------------

  /// The app's typeface, bundled in `assets/fonts/`.
  ///
  /// Applies to everything except [ussdCode], which stays monospace so a code
  /// the user is verifying renders in fixed columns.
  static const String fontFamily = 'IBM Plex Sans';

  /// Arabic glyphs are not in IBM Plex Sans; they fall through to the Arabic
  /// sibling family. Wired as a fallback rather than swapped by locale so a
  /// screen mixing Arabic recipient names with Latin amounts still renders
  /// each script in the right family.
  static const List<String> fontFamilyFallback = <String>['IBM Plex Sans Arabic'];

  /// A blue that reads as trustworthy next to both wallet brand colours
  /// (green and purple) without competing with either.
  static const Color _seed = Color(0xFF2563EB);

  /// Blue-tinted ink rather than neutral black: at OLED-friendly darkness it
  /// still belongs to the same palette as the primary.
  static const Color _darkSurface = Color(0xFF0B1220);
  static const Color _lightSurface = Color(0xFFF5F7FB);

  /// Non-blocking warnings -- an unrecognised carrier prefix, mainly. Amber
  /// rather than the scheme's error red, because these never stop a payment.
  static const Color warning = Color(0xFFE0A800);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  /// Soft, layered shadow. Two low-alpha layers read as depth; one heavy layer
  /// reads as a drop shadow from 2010.
  static List<BoxShadow> shadow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      // Shadows are invisible on a near-black surface; depth in dark mode comes
      // from the surface-container steps and a hairline border instead.
      return const [];
    }
    return const [
      BoxShadow(
        color: Color(0x0F0F172A),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
      BoxShadow(
        color: Color(0x0A0F172A),
        blurRadius: 2,
        offset: Offset(0, 1),
      ),
    ];
  }

  /// The hairline that separates a card from the surface behind it in dark
  /// mode, where [shadow] has nothing to work with.
  static Border? hairline(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness != Brightness.dark) return null;
    return Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
    );
  }

  /// Card-like decoration used by the hand-built surfaces across the app.
  static BoxDecoration surface(
    BuildContext context, {
    Color? color,
    double radius = radiusLg,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: color ?? scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
      border: hairline(context),
      boxShadow: shadow(context),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      // Above the M3 default so text survives direct sunlight, but below the
      // 0.5 this app used to run at, which flattened every tone into a hard
      // primary and was most of why the UI looked cheap.
      contrastLevel: 0.3,
    );

    final surface = isDark ? _darkSurface : _lightSurface;

    // The family has to be applied here, not left to `ThemeData.fontFamily`.
    // That parameter only reaches the text theme ThemeData assembles; the
    // component themes below are handed *this* local, and a style with a null
    // family falls back to the platform font. That is what left the app bar
    // title, the buttons, and the snack bars in Roboto.
    final textTheme = _textTheme(scheme).apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Still set, so widgets that build their own TextStyle from scratch
      // rather than reading the text theme also get IBM Plex Sans (with the
      // Arabic sibling as a fallback for Arabic glyphs).
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(touchTarget),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        // A visible focus ring: on a field whose value becomes a payment, the
        // user should never be unsure which one they are typing into.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 2.5),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // A little above the M3 default so Arabic descenders and the taller
        // label weight the app uses do not touch the bar edge.
        height: 84,
        backgroundColor: isDark ? scheme.surfaceContainer : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium?.copyWith(
            height: 1.35,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 26,
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: gapMd, vertical: gapMd),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 14,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.bodyLarge?.copyWith(color: scheme.onInverseSurface),
        insetPadding: const EdgeInsets.all(gapLg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// One type scale for the whole app.
  ///
  /// Sizes start where most apps' end: nothing below 14, body at 16. The
  /// display sizes exist for the confirmation screen's amount, which is the
  /// single detail a hurried user is most likely to get wrong.
  static TextTheme _textTheme(ColorScheme scheme) {
    final onSurface = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return TextTheme(
      // The amount on the confirmation screen.
      displaySmall: TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.25,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: muted,
      ),
      bodySmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      labelMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: onSurface,
      ),
      labelSmall: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: muted,
      ),
    );
  }

  /// Style for any USSD code shown to the user.
  ///
  /// Monospace and tabular so digits line up and cannot be misread, and large
  /// enough to check at arm's length. Deliberately *not* the app font: it is
  /// proportional, and a code the user is being asked to verify against the
  /// dialer must render in fixed columns. Always render inside an LTR
  /// [Directionality] -- see `UssdPreview`.
  static TextStyle ussdCode(BuildContext context, {double size = 26}) =>
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Roboto Mono', 'Courier New', 'monospace'],
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        height: 1.4,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
