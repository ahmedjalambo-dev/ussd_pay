import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/favorite.dart';
import '../models/history_entry.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../services/dialer_service.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';
import '../widgets/save_favorite_dialog.dart';
import '../widgets/ussd_preview.dart';

/// The mandatory review step.
///
/// This screen is the reason the app exists. There is no path to the dialer
/// that skips it, and nothing on it dials automatically: the user reads the
/// recipient, the amount, and the literal code, then chooses.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({
    super.key,
    required this.wallet,
    required this.recipientType,
    required this.phone,
    required this.amount,
    required this.ussdCode,
    this.recipientName,
  });

  final Wallet wallet;
  final String recipientType;
  final NormalizedPhone phone;
  final num amount;
  final String ussdCode;
  final String? recipientName;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  bool _dialing = false;

  Future<void> _dial() async {
    if (_dialing) return;
    setState(() => _dialing = true);

    final l10n = AppLocalizations.of(context);

    // Recorded before the hand-off, because once the dialer takes over the app
    // may be backgrounded and never told what happened. History records what
    // we dialed, not whether the carrier accepted it.
    await ref
        .read(historyProvider.notifier)
        .add(
          HistoryEntry(
            dialedAtUtc: DateTime.now().toUtc(),
            walletId: widget.wallet.id,
            recipientType: widget.recipientType,
            recipientNumber: widget.phone.local,
            recipientName: widget.recipientName,
            amount: widget.amount,
            ussdCode: widget.ussdCode,
          ),
        );

    final outcome = await DialerService.dial(widget.ussdCode);
    if (!mounted) return;

    setState(() => _dialing = false);
    _snack(
      outcome == DialOutcome.openedDialer
          ? l10n.dialerOpened
          : l10n.dialerUnavailable,
      duration: const Duration(seconds: 6),
    );
  }

  Future<void> _saveFavorite() async {
    final l10n = AppLocalizations.of(context);

    // The dialog owns its own controller and disposes it itself. Doing that
    // here, right after the await, tore the controller down while the dialog
    // was still animating out and still using it.
    final name = await showDialog<String>(
      context: context,
      // Prefilled only from a real name. Seeding it with the number produced
      // favorites literally named "056 845 0493", which is no more useful than
      // the number already shown beneath it -- and, being digits in free text,
      // bidi reordered it in the list.
      builder: (_) => SaveFavoriteDialog(initialName: widget.recipientName),
    );

    if (name == null || name.isEmpty || !mounted) return;

    await ref
        .read(favoritesProvider.notifier)
        .save(
          Favorite(
            name: name,
            number: widget.phone.local,
            walletId: widget.wallet.id,
            defaultType: widget.recipientType,
          ),
        );
    if (!mounted) return;
    _snack(l10n.savedAsFavorite);
  }

  void _snack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.confirmTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.gapMd,
            AppTheme.screenPadding,
            AppTheme.gapXl,
          ),
          children: [
            _CautionBanner(text: l10n.confirmSubtitle),
            const SizedBox(height: AppTheme.gapXl),

            // The amount is the largest thing on the screen: it is the detail a
            // hurried user is most likely to get wrong.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.gapXl,
                vertical: AppTheme.gapXxl,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primaryContainer,
                    scheme.primaryContainer.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Column(
                children: [
                  Text(
                    l10n.amountLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapSm),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '${formatAmountDisplay(widget.amount)} ${l10n.currencySymbol}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.gapLg),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.gapLg,
                vertical: AppTheme.gapXs,
              ),
              decoration: AppTheme.surface(context),
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.recipientLabel,
                    value:
                        widget.recipientName ??
                        formatPhoneDisplay(widget.phone.local),
                    secondary: widget.recipientName != null
                        ? formatPhoneDisplay(widget.phone.local)
                        : carrierLabel(l10n, widget.phone.carrier),
                  ),
                  const Divider(),
                  _DetailRow(
                    icon: Icons.account_balance_wallet_outlined,
                    iconAsset: widget.wallet.iconAsset,
                    label: l10n.walletLabel,
                    value: widget.wallet.nameFor(localeCode),
                    secondary: recipientTypeLabel(l10n, widget.recipientType),
                    accent: Color(widget.wallet.colorValue),
                  ),
                ],
              ),
            ),

            if (!widget.phone.isValid) ...[
              const SizedBox(height: AppTheme.gapMd),
              _Warning(text: l10n.warnUnknownPrefix),
            ],

            const SizedBox(height: AppTheme.gapXl),
            Text(l10n.codeLabel, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppTheme.gapMd),
            UssdPreview(code: widget.ussdCode),
            const SizedBox(height: AppTheme.gapMd),
            _PinNoticeInline(text: l10n.pinNotice),

            const SizedBox(height: AppTheme.gapXxl),
            FilledButton.icon(
              onPressed: _dialing ? null : _dial,
              icon: const Icon(Icons.phone_in_talk_rounded, size: 24),
              label: Text(l10n.callNow),
            ),
            const SizedBox(height: AppTheme.gapMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await DialerService.copy(widget.ussdCode);
                      if (!context.mounted) return;
                      _snack(l10n.codeCopied);
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    label: Text(l10n.copyCode, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveFavorite,
                    icon: const Icon(Icons.star_outline_rounded, size: 20),
                    label: Text(
                      l10n.saveAsFavorite,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.gapSm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }
}

class _CautionBanner extends StatelessWidget {
  const _CautionBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapMd),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 24,
            color: AppTheme.warning,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.secondary,
    this.accent,
    this.iconAsset,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? secondary;
  final Color? accent;

  /// Optional asset path shown instead of [icon]. When set (e.g. a wallet's
  /// brand mark) the image is clipped to the same rounded square as the icon
  /// badge so the row's vertical rhythm stays intact.
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconColor = accent ?? scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.gapLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailBadge(
            icon: icon,
            iconColor: iconColor,
            asset: iconAsset,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppTheme.gapXs),
                // Each line gets the direction its own content needs, while
                // the row itself stays in the app's direction. Wrapping these
                // in an LTR Directionality instead -- as this screen used to
                // -- also moved them to the left edge of an Arabic layout.
                Text(
                  value,
                  textDirection: directionOf(value),
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    textDirection: directionOf(secondary!),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBadge extends StatelessWidget {
  const _DetailBadge({
    required this.icon,
    required this.iconColor,
    this.asset,
  });

  final IconData icon;
  final Color iconColor;
  final String? asset;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final tint = BoxDecoration(
      color: iconColor.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
    );

    if (asset == null) {
      return Container(
        width: _size,
        height: _size,
        decoration: tint,
        child: Icon(icon, size: 22, color: iconColor),
      );
    }

    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: iconColor.withValues(alpha: 0.35), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        asset!,
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        // A missing asset must not break the confirmation screen; fall back to
        // the tinted icon instead.
        errorBuilder: (_, _, _) => DecoratedBox(
          decoration: tint,
          child: Icon(icon, size: 22, color: iconColor),
        ),
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 24,
            color: AppTheme.warning,
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _PinNoticeInline extends StatelessWidget {
  const _PinNoticeInline({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, size: 18, color: scheme.primary),
        const SizedBox(width: AppTheme.gapSm),
        Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}
