import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatting.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/history_entry.dart';
import '../models/wallet.dart';
import '../providers/app_providers.dart';
import '../screens/confirm_screen.dart';
import '../services/phone_normalizer.dart';
import '../theme/app_theme.dart';
import 'ussd_preview.dart';

/// Everything the compact row leaves out -- the dialed code, the note -- plus
/// the Repeat action.
class PaymentDetailsSheet extends ConsumerWidget {
  const PaymentDetailsSheet({
    super.key,
    required this.entry,
    required this.wallet,
    required this.localeCode,
  });

  final HistoryEntry entry;
  final Wallet? wallet;
  final String localeCode;

  static Future<void> show(
    BuildContext context, {
    required HistoryEntry entry,
    required Wallet? wallet,
    required String localeCode,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PaymentDetailsSheet(
      entry: entry,
      wallet: wallet,
      localeCode: localeCode,
    ),
  );

  /// Rebuilds the payment from a past entry and goes straight to confirmation.
  ///
  /// Straight to confirmation, not straight to the dialer: repeating a payment
  /// is still a payment, so it gets the same review step as a new one.
  void _repeat(BuildContext context, WidgetRef ref, Wallet wallet) {
    ref.read(paymentDraftProvider.notifier).repeat(entry, wallet);
    final navigator = Navigator.of(context)..pop();
    navigator.push(
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wallet = this.wallet;
    final name = entry.recipientName;
    final note = entry.note;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.gapLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.paymentDetails, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.gapLg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (name != null)
                        Text(
                          name,
                          textDirection: directionOf(name),
                          style: theme.textTheme.titleSmall,
                        ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          formatPhoneDisplay(entry.recipientNumber),
                          style: name == null
                              ? theme.textTheme.titleSmall
                              : theme.textTheme.bodyMedium,
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
                    style: theme.textTheme.titleLarge?.copyWith(
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
                ?wallet?.nameFor(localeCode),
                recipientTypeLabel(l10n, entry.recipientType),
                formatHistoryTimestamp(entry.dialedAtUtc, localeCode),
              ].join(' · '),
              style: theme.textTheme.labelSmall,
            ),
            if (entry.confirmedBy == ConfirmationSource.sms) ...[
              const SizedBox(height: AppTheme.gapSm),
              Row(
                children: [
                  Icon(
                    Icons.mark_chat_read_outlined,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppTheme.gapXs),
                  Text(
                    l10n.confirmedBySms,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: AppTheme.gapSm),
              Text(
                note,
                textDirection: directionOf(note),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.gapLg),
            UssdPreview(code: entry.ussdCode, fontSize: 18),
            const SizedBox(height: AppTheme.gapXl),
            FilledButton.icon(
              onPressed: wallet == null
                  ? null
                  : () => _repeat(context, ref, wallet),
              icon: const Icon(Icons.replay_rounded),
              label: Text(l10n.repeatPayment),
            ),
          ],
        ),
      ),
    );
  }
}
