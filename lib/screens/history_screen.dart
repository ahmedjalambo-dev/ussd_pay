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

  /// Asks, then wipes every history row in both tabs. Public so the root
  /// AppBar, which owns the Clear action, can call it.
  static Future<void> confirmClear(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final hasAny = ref.watch(historyProvider).isNotEmpty;
    final done = ref.watch(historyByStatusProvider(HistoryStatus.done));
    final cancelled = ref.watch(
      historyByStatusProvider(HistoryStatus.cancelled),
    );

    if (!hasAny) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l10n.emptyHistoryTitle,
        body: l10n.emptyHistoryBody,
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.historyTabDone(done.length)),
              Tab(text: l10n.historyTabCancelled(cancelled.length)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _HistoryList(
                  entries: done,
                  emptyIcon: Icons.check_circle_outline_rounded,
                  emptyTitle: l10n.emptyDoneTitle,
                  emptyBody: l10n.emptyDoneBody,
                ),
                _HistoryList(
                  entries: cancelled,
                  emptyIcon: Icons.cancel_outlined,
                  emptyTitle: l10n.emptyCancelledTitle,
                  emptyBody: l10n.emptyCancelledBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab's worth of history cards, each swipeable to delete.
class _HistoryList extends ConsumerWidget {
  const _HistoryList({
    required this.entries,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final List<HistoryEntry> entries;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyBody;

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

  /// Deletes at once and offers Undo, rather than asking first: a swipe is
  /// deliberate, and Undo puts the row back exactly as it was (same id,
  /// timestamp and status, so the same place in the same tab).
  void _delete(BuildContext context, WidgetRef ref, HistoryEntry entry) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(historyProvider.notifier);
    notifier.delete(entry.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.historyEntryDeleted),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => notifier.add(entry),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletsProvider).value ?? const <Wallet>[];
    final localeCode = ref.watch(settingsProvider).locale?.languageCode ?? 'ar';

    if (entries.isEmpty) {
      return EmptyState(icon: emptyIcon, title: emptyTitle, body: emptyBody);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        AppTheme.gapLg,
        AppTheme.screenPadding,
        AppTheme.gapLg,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.gapMd),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final wallet = wallets
            .where((w) => w.id == entry.walletId)
            .firstOrNull;

        return Dismissible(
          key: ValueKey(entry.id),
          background: const _DeleteBackground(
            alignment: AlignmentDirectional.centerStart,
          ),
          secondaryBackground: const _DeleteBackground(
            alignment: AlignmentDirectional.centerEnd,
          ),
          onDismissed: (_) => _delete(context, ref, entry),
          child: _HistoryCard(
            entry: entry,
            walletName: wallet?.nameFor(localeCode),
            walletColor: wallet != null ? Color(wallet.colorValue) : null,
            localeCode: localeCode,
            onRepeat: wallet == null
                ? null
                : () => _repeat(context, ref, entry, wallet),
          ),
        );
      },
    );
  }
}

/// What shows under a card while it is being swiped away.
///
/// Directional alignment, so the icon sits on the edge the card is uncovering
/// in both LTR and RTL: Dismissible's start-to-end swipe reveals the start
/// edge.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground({required this.alignment});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapXl),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Icon(
        Icons.delete_outline_rounded,
        size: 28,
        color: scheme.onErrorContainer,
      ),
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
