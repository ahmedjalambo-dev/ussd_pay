import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One option in a single-choice group: a leading visual and a label.
///
/// Shared by the wallet picker and the recipient-type toggle so both read as
/// the same control. Selection is shown by a thicker accent border *and* a
/// tint, so it survives bright sunlight and colour-blindness alike.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final Widget leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Border and tint colour when selected; defaults to the theme primary.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = this.accent ?? scheme.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: selected
              ? BorderSide(color: accent, width: 2)
              : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTheme.touchTarget),
            padding: const EdgeInsets.all(AppTheme.gapMd),
            child: Row(
              children: [
                leading,
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays tiles out two to a row, each row filled edge to edge.
///
/// Rows of [Expanded] rather than a `Wrap` of fixed widths: an odd last tile
/// takes the whole row instead of leaving a gap beside it, and an option added
/// in `wallets.json` still needs no code change.
class ChoiceTileRows extends StatelessWidget {
  const ChoiceTileRows({super.key, required this.children});

  final List<Widget> children;

  static const int _perRow = 2;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += _perRow) {
      final rowTiles = children.sublist(
        i,
        (i + _perRow).clamp(0, children.length),
      );
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppTheme.gapMd));
      rows.add(
        // IntrinsicHeight so a label that wraps taller in one tile does not
        // leave its neighbour shorter.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < rowTiles.length; j++) ...[
                if (j > 0) const SizedBox(width: AppTheme.gapMd),
                Expanded(child: rowTiles[j]),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
