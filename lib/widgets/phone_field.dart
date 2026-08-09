import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';

/// Phone entry with live normalization feedback.
///
/// The field never rewrites what the user is typing -- fighting the cursor on a
/// number is maddening. Instead the canonical form is shown underneath, so the
/// user can see exactly what will be dialed as they type.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    required this.normalized,
    required this.onChanged,
    required this.onPickContact,
    required this.onPickFavorite,
    this.recipientName,
    this.showIssue = true,
  });

  final TextEditingController controller;
  final NormalizedPhone normalized;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickContact;
  final VoidCallback onPickFavorite;
  final String? recipientName;

  /// Suppressed until the user has actually entered something.
  final bool showIssue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final issueText = showIssue ? phoneIssueMessage(l10n, normalized.issue) : null;
    final warnOnly = isWarningOnly(normalized.issue);
    final issueColor = warnOnly ? AppTheme.warning : scheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The digits themselves are always LTR: an Arabic layout would
        // otherwise reorder them into something that does not match the code.
        // The *decoration* -- label, hint position, prefix icon -- deliberately
        // follows the ambient direction, so an Arabic screen keeps its label on
        // the right where the rest of the UI is.
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          textAlign: isRtl ? TextAlign.right : TextAlign.left,
          autocorrect: false,
          enableSuggestions: false,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
          decoration: InputDecoration(
            labelText: l10n.phoneNumberLabel,
            hintText: l10n.phoneNumberHint,
            // The hint is a number pattern, so it stays LTR even though the
            // label beside it is Arabic.
            hintTextDirection: TextDirection.ltr,
            prefixIcon: Icon(Icons.phone_outlined, size: 24, color: scheme.primary),
          ),
        ),
        const SizedBox(height: AppTheme.gapMd),
        _Feedback(
          normalized: normalized,
          recipientName: recipientName,
          issueText: issueText,
          issueColor: issueColor,
        ),
        const SizedBox(height: AppTheme.gapLg),
        Row(
          children: [
            Expanded(
              child: _PickerButton(
                icon: Icons.contacts_outlined,
                label: l10n.pickFromContacts,
                onPressed: onPickContact,
              ),
            ),
            const SizedBox(width: AppTheme.gapMd),
            Expanded(
              child: _PickerButton(
                icon: Icons.star_outline_rounded,
                label: l10n.pickFromFavorites,
                onPressed: onPickFavorite,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tonal action for pulling a number in from elsewhere.
class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        textStyle: Theme.of(context).textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }
}

/// What the app made of the number, shown under the field.
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.normalized,
    required this.recipientName,
    required this.issueText,
    required this.issueColor,
  });

  final NormalizedPhone normalized;
  final String? recipientName;
  final String? issueText;
  final Color issueColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final carrier = carrierLabel(l10n, normalized.carrier);
    final name = recipientName;

    // Nothing usable typed yet: say which prefixes work instead of leaving the
    // space blank. 056 is as supported as 059, and users could not tell.
    if (normalized.national.isEmpty && issueText == null) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.gapSm),
          Text(l10n.phoneSupportedPrefixes, style: theme.textTheme.bodySmall),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (normalized.national.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.gapMd,
              vertical: AppTheme.gapSm,
            ),
            decoration: BoxDecoration(
              color: normalized.isValid
                  ? scheme.primaryContainer
                  : issueColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  normalized.isValid
                      ? Icons.check_circle_rounded
                      : Icons.info_outline,
                  size: 20,
                  color: normalized.isValid
                      ? scheme.onPrimaryContainer
                      : issueColor,
                ),
                const SizedBox(width: AppTheme.gapSm),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    formatPhoneDisplay(normalized.local),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: normalized.isValid
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ),
                if (carrier != null) ...[
                  const SizedBox(width: AppTheme.gapSm),
                  Text(
                    carrier,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: normalized.isValid
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (name != null) ...[
          const SizedBox(height: AppTheme.gapSm),
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppTheme.gapSm),
              Expanded(
                child: Text(
                  name,
                  textDirection: directionOf(name),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
        if (issueText != null) ...[
          const SizedBox(height: AppTheme.gapSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, size: 20, color: issueColor),
              const SizedBox(width: AppTheme.gapSm),
              Expanded(
                child: Text(
                  issueText!,
                  style: theme.textTheme.bodySmall?.copyWith(color: issueColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
