import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One numbered step of a form (payment, add favorite), on its own card.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    this.step,
    required this.title,
    required this.child,
  });

  /// The step number, or null for an unnumbered section (a short form where
  /// numbered steps would only add noise).
  final String? step;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: AppTheme.surface(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (step case final step?) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    step,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.gapMd),
              ],
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: AppTheme.gapLg),
          child,
        ],
      ),
    );
  }
}
