import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/history_entry.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/ussd_preview.dart';
import 'confirm_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryMessage),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: AppTheme.dialogActionSize),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: AppTheme.dialogActionSize,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(historyProvider.notifier).clear();
    }
  }

  /// Rebuilds the payment from a past entry and goes straight to confirmation.
  ///
  /// Straight to confirmation, not straight to the dialer: repeating a payment
  /// is still a payment, so it gets the same review step as a new one.
  void _repeat(
    BuildContext context,
    WidgetRef ref,
    HistoryEntry entry,
    Wallet wallet,
  ) {
    ref.read(paymentDraftProvider.notifier).repeat(entry, wallet);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmScreen(
          wallet: wallet,
          recipientType: entry.recipientType,
          phone: PhoneNormalizer.normalize(entry.recipientNumber),
          recipientName: entry.recipientName,
          amount: entry.amount,
          ussdCode: entry.ussdCode,
          note: entry.note ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(historyProvider);
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l10n.emptyHistoryTitle,
        body: l10n.emptyHistoryBody,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.gapLg,
              AppTheme.screenPadding,
              AppTheme.gapSm,
            ),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gapMd),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final wallet = wallets
                  .where((w) => w.id == entry.walletId)
                  .firstOrNull;

              return _HistoryCard(
                entry: entry,
                walletName: wallet?.nameFor(localeCode),
                walletColor: wallet != null ? Color(wallet.colorValue) : null,
                localeCode: localeCode,
                onRepeat: wallet == null
                    ? null
                    : () => _repeat(context, ref, entry, wallet),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.screenPadding,
              AppTheme.gapXs,
              AppTheme.screenPadding,
              AppTheme.gapMd,
            ),
            child: TextButton.icon(
              onPressed: () => _confirmClear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(l10n.clearHistory),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entry,
    required this.walletName,
    required this.walletColor,
    required this.localeCode,
    required this.onRepeat,
  });

  final HistoryEntry entry;
  final String? walletName;
  final Color? walletColor;
  final String localeCode;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = walletColor ?? scheme.outline;

    return Container(
      decoration: AppTheme.surface(context),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gapLg,
              AppTheme.gapLg,
              AppTheme.gapLg,
              AppTheme.gapMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsetsDirectional.only(
                        top: 6,
                        end: AppTheme.gapMd,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final title =
                                  entry.recipientName ??
                                  formatPhoneDisplay(entry.recipientNumber);
                              return Text(
                                title,
                                textDirection: directionOf(title),
                                style: theme.textTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                formatPhoneDisplay(entry.recipientNumber),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.gapSm),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${formatAmountDisplay(entry.amount)} '
                        '${l10n.currencySymbol}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.gapSm),
                Text(
                  [
                    ?walletName,
                    recipientTypeLabel(l10n, entry.recipientType),
                    formatHistoryTimestamp(entry.dialedAtUtc, localeCode),
                  ].join(' · '),
                  style: theme.textTheme.labelSmall,
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.gapXs),
                  Text(
                    entry.note!,
                    textDirection: directionOf(entry.note!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.gapMd),
                UssdPreview(
                  code: entry.ussdCode,
                  fontSize: 15,
                  emphasised: false,
                ),
              ],
            ),
          ),
          const Divider(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onRepeat,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: Text(l10n.repeatPayment),
              style: TextButton.styleFrom(
                minimumSize: const Size(120, 52),
                shape: const RoundedRectangleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
