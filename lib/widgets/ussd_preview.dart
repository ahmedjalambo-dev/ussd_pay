import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays a USSD code exactly as it will be dialed.
///
/// Always forces left-to-right. A USSD code is a sequence of ASCII punctuation
/// and digits, and `*`, `#` are bidi-neutral: inside an Arabic RTL layout the
/// bidi algorithm reorders them, so `*268*1*0599123456*50#` can render as
/// `#50*0599123456*1*268*`. On a screen whose entire job is letting the user
/// verify the code before approving it, that is not a cosmetic bug.
class UssdPreview extends StatelessWidget {
  const UssdPreview({
    super.key,
    required this.code,
    this.fontSize = 26,
    this.emphasised = true,
  });

  final String code;
  final double fontSize;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // The LTR wrapper must remain the nearest Directionality above the text --
    // the widget test asserts exactly that.
    final text = Directionality(
      textDirection: TextDirection.ltr,
      child: SelectableText(
        code,
        textAlign: TextAlign.center,
        style: AppTheme.ussdCode(context, size: fontSize),
      ),
    );

    if (!emphasised) return text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gapLg,
        vertical: AppTheme.gapXl,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4), width: 2),
      ),
      // A code too wide for the box is scaled down, not scrolled and not
      // wrapped. Scrolling hid the start of the code under RTL -- the box
      // began at its right edge, so `*268*1*...` displayed as `268*1*...` and
      // the user was asked to approve a code they could not fully see.
      // Wrapping would break a number across lines. Shrinking keeps the whole
      // code on one line, on screen, at once.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: text,
      ),
    );
  }
}
