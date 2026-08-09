import 'package:flutter/material.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/recipient_type.dart';
import '../theme/app_theme.dart';

/// Big friend/merchant toggle.
///
/// Rendered from the wallet's declared types, so a wallet that adds a third
/// type in `wallets.json` gets a third segment with no code change.
class RecipientTypeToggle extends StatelessWidget {
  const RecipientTypeToggle({
    super.key,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  final List<String> types;
  final String? selected;
  final ValueChanged<String> onChanged;

  static IconData _iconFor(String typeKey) => switch (typeKey) {
        RecipientTypes.friend => Icons.person_rounded,
        RecipientTypes.merchant => Icons.storefront_rounded,
        _ => Icons.payments_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        for (final type in types) ...[
          Expanded(
            child: _Segment(
              icon: _iconFor(type),
              label: recipientTypeLabel(l10n, type),
              isSelected: type == selected,
              onTap: () => onChanged(type),
            ),
          ),
          if (type != types.last) const SizedBox(width: AppTheme.gapMd),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isSelected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              constraints: const BoxConstraints(minHeight: 100),
              padding: const EdgeInsets.symmetric(
                vertical: AppTheme.gapLg,
                horizontal: AppTheme.gapSm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                // A border as well as fill, so the selection survives a
                // washed-out screen in direct sunlight.
                border: Border.all(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(icon, size: 32, color: foreground),
                      if (isSelected)
                        PositionedDirectional(
                          end: -8,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: scheme.onPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.gapSm),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
