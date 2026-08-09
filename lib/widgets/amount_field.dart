import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';

/// Amount entry with a numeric keypad and quick-amount chips.
///
/// The controller holds a *displayed* value with thousands separators; the
/// caller reads [AmountField.parse] to get the plain number. Separators are
/// never allowed near `UssdService`.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  static const List<int> quickAmounts = [10, 20, 50, 100];

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Strips the display formatting and returns the raw number, or `null`.
  static num? parse(String displayed) {
    final cleaned = displayed.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = num.tryParse(cleaned);
    if (value == null || value <= 0) return null;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // As in PhoneField: digits LTR, decoration in the ambient direction.
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          inputFormatters: [_ThousandsSeparatorFormatter()],
          style: theme.textTheme.headlineMedium,
          decoration: InputDecoration(
            labelText: l10n.amountLabel,
            hintText: '0',
            hintTextDirection: TextDirection.ltr,
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapLg),
              child: Text(
                l10n.currencySymbol,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
        ),
        const SizedBox(height: AppTheme.gapMd),
        Wrap(
          spacing: AppTheme.gapSm,
          runSpacing: AppTheme.gapSm,
          children: [
            for (final amount in quickAmounts)
              _QuickAmount(
                amount: amount,
                onTap: () {
                  final text = formatAmountDisplay(amount);
                  controller.value = TextEditingValue(
                    text: text,
                    selection: TextSelection.collapsed(offset: text.length),
                  );
                  onChanged(text);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickAmount extends StatelessWidget {
  const _QuickAmount({required this.amount, required this.onTap});

  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          constraints: const BoxConstraints(minWidth: 76, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapLg),
          // Center with both factors set, not `Container(alignment:)`: an
          // unfactored Align expands to the Wrap's full line width, which
          // stacked the chips one per row.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Directionality(
              // "50 ₪" reads the same either way; forcing LTR keeps the digits
              // and the symbol in a stable order across languages.
              textDirection: TextDirection.ltr,
              child: Text(
                '${formatAmountDisplay(amount)} ${l10n.currencySymbol}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Adds thousands separators as the user types, keeping the caret sensible.
class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    // Reject anything that is not a plain positive number. Rejecting here
    // rather than at build time means a "*" can never reach the amount at all.
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final formatted = StringBuffer(formatAmountDisplay(int.tryParse(parts[0]) ?? 0));
    if (parts[0].isEmpty) {
      formatted
        ..clear()
        ..write('0');
    }
    if (parts.length > 1) formatted.write('.${parts[1]}');

    final text = formatted.toString();
    // Keep the caret at the end: the alternative is tracking separator
    // insertions, and mid-string editing of an amount is rare.
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
